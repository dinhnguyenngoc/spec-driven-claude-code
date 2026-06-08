#!/usr/bin/env python3
"""
.claude/scripts/scan-summarize.py
-----------------------------------------------------------------------------
Đọc output từ mọi scanner trong security/{sast-results,dependency-audit,container-scan}/
và emit 1 file SCAN_SUMMARY.json structured để agent /scan đọc nhanh.

Output schema:
{
  "scan_date": "YYYY-MM-DD HH:MM:SS",
  "totals": {"critical": N, "high": N, "medium": N, "low": N, "unknown": N},
  "tools_run": ["gitleaks", "dotnet", "npm-audit", ...],
  "tools_missing": ["semgrep", "trivy", ...],
  "findings": [
    {
      "id": "F-001",
      "source": "gitleaks | dotnet-vuln | npm-audit | semgrep | trivy | roslyn | grep | hadolint",
      "severity": "Critical | High | Medium | Low | Unknown",
      "category": "secret | dependency | sast | container | dockerfile | xss",
      "title": "<short>",
      "file": "<path:line>",
      "details": "<short description>",
      "fix": "<remediation hint if available>"
    }
  ],
  "compensating_controls": [
    {"missing_tool": "...", "fallback_used": "...", "must_add_to_pipeline": true|false}
  ]
}

Cách dùng: stdout là JSON. Bash script redirect → security/SCAN_SUMMARY.json
"""

import json
import os
import re
import sys
from datetime import datetime
from pathlib import Path

SEC = Path("security")
SAST = SEC / "sast-results"
DEPS = SEC / "dependency-audit"
CONT = SEC / "container-scan"


def normalize_severity(s):
    """Chuẩn hoá severity string từ nhiều tool về Critical/High/Medium/Low/Unknown."""
    if not s:
        return "Unknown"
    s = str(s).lower().strip()
    if s in ("critical", "crit"):
        return "Critical"
    if s in ("high", "error"):
        return "High"
    if s in ("medium", "moderate", "warning", "warn"):
        return "Medium"
    if s in ("low", "info", "note"):
        return "Low"
    return "Unknown"


def safe_load_json(path):
    """Load JSON file, trả về None nếu lỗi (file thường chứa cả log của tool)."""
    try:
        with open(path) as f:
            text = f.read()
        # Một số tool ghi text trước JSON — tìm JSON object/array đầu tiên
        for start_char, end_char in [('{', '}'), ('[', ']')]:
            idx = text.find(start_char)
            if idx >= 0:
                try:
                    return json.loads(text[idx:])
                except json.JSONDecodeError:
                    continue
        return None
    except (OSError, json.JSONDecodeError):
        return None


def load_tool_inventory():
    """Đọc tooling-availability.txt → (installed_tools, missing_tools)."""
    installed, missing = [], []
    path = SAST / "tooling-availability.txt"
    if not path.exists():
        return installed, missing
    for line in path.read_text().splitlines():
        m = re.match(r"^(\S+):\s+(.+)$", line)
        if not m:
            continue
        name, status = m.group(1), m.group(2)
        if "MISSING" in status:
            missing.append(name)
        else:
            installed.append(name)
    return installed, missing


def parse_gitleaks(findings, finding_id):
    """gitleaks JSON: array of findings với Description, File, StartLine, Match."""
    path = SAST / "gitleaks.json"
    data = safe_load_json(path)
    if not data or not isinstance(data, list):
        return finding_id
    for item in data:
        findings.append({
            "id": f"F-{finding_id:03d}",
            "source": "gitleaks",
            "severity": "High",  # mọi secret leak = High
            "category": "secret",
            "title": item.get("Description") or item.get("RuleID") or "Hardcoded secret",
            "file": f"{item.get('File', '?')}:{item.get('StartLine', '?')}",
            "details": (item.get("Match") or "")[:120],
            "fix": "Remove from code; rotate secret; use User Secrets / Key Vault",
        })
        finding_id += 1
    return finding_id


def parse_secrets_grep(findings, finding_id):
    """Fallback grep output (khi gitleaks missing)."""
    path = SAST / "secrets-grep.txt"
    if not path.exists() or path.stat().st_size == 0:
        return finding_id
    for line in path.read_text().splitlines():
        # format: path:line:matched_text
        m = re.match(r"^([^:]+):(\d+):(.*)$", line)
        if not m:
            continue
        findings.append({
            "id": f"F-{finding_id:03d}",
            "source": "grep (gitleaks fallback)",
            "severity": "Medium",  # grep có false-positive cao
            "category": "secret",
            "title": "Possible hardcoded secret",
            "file": f"{m.group(1)}:{m.group(2)}",
            "details": m.group(3).strip()[:120],
            "fix": "Manually verify; if real secret: rotate + move to env/vault",
        })
        finding_id += 1
    return finding_id


def parse_dotnet_vuln(findings, finding_id):
    """dotnet list package --vulnerable --format json output."""
    path = DEPS / "nuget-vulnerable.json"
    if not path.exists():
        return finding_id
    # File có thể chứa nhiều JSON objects (mỗi project 1 cái) — đọc raw
    text = path.read_text()
    # Tìm tất cả JSON objects {projects: [...]}
    for match in re.finditer(r'\{"projects":\s*\[.*?\]\s*\}', text, re.DOTALL):
        try:
            data = json.loads(match.group())
        except json.JSONDecodeError:
            continue
        for proj in data.get("projects", []):
            proj_name = proj.get("path", "?")
            for fw in proj.get("frameworks", []):
                for pkg in fw.get("topLevelPackages", []) + fw.get("transitivePackages", []):
                    for vuln in pkg.get("vulnerabilities", []):
                        findings.append({
                            "id": f"F-{finding_id:03d}",
                            "source": "dotnet-vuln",
                            "severity": normalize_severity(vuln.get("severity")),
                            "category": "dependency",
                            "title": f"{pkg.get('id')} {pkg.get('resolvedVersion')} — {vuln.get('advisoryUrl', 'no URL')}",
                            "file": proj_name,
                            "details": f"Package: {pkg.get('id')} {pkg.get('resolvedVersion')}",
                            "fix": f"Upgrade {pkg.get('id')}; check advisory: {vuln.get('advisoryUrl', '')}",
                        })
                        finding_id += 1
    return finding_id


def parse_npm_audit(findings, finding_id):
    """npm audit --json output — supports multi-package layout (npm-audit-<safe>.json).

    Production runtime files: npm-audit-<safe>.json (block-relevant)
    Full audit files: npm-audit-full-<safe>.json (informational only — không add findings)
    """
    # Tìm cả file legacy single (npm-audit.json) lẫn pattern mới (npm-audit-<safe>.json)
    files = list(DEPS.glob("npm-audit.json")) + list(DEPS.glob("npm-audit-*.json"))
    # Loại trừ npm-audit-full-* (informational only)
    files = [f for f in files if "full" not in f.name]
    for path in files:
        data = safe_load_json(path)
        if not data:
            continue
        # Suy ra package location từ tên file: npm-audit-web.json → "web"
        pkg_location = path.stem.replace("npm-audit-", "") or "root"
        vulns = data.get("vulnerabilities", {}) if isinstance(data, dict) else {}
        for pkg_name, info in vulns.items():
            sev = normalize_severity(info.get("severity"))
            via = info.get("via", [])
            if isinstance(via, list) and via:
                first = via[0]
                title = first.get("title", "n/a") if isinstance(first, dict) else str(first)
                url = first.get("url", "") if isinstance(first, dict) else ""
            else:
                title, url = "n/a", ""
            findings.append({
                "id": f"F-{finding_id:03d}",
                "source": f"npm-audit ({pkg_location})",
                "severity": sev,
                "category": "dependency",
                "title": f"{pkg_name}: {title}",
                "file": f"{pkg_location}/package.json",
                "details": f"Range: {info.get('range', '?')}; advisory: {url}",
                "fix": f"npm audit fix; or upgrade {pkg_name}",
            })
            finding_id += 1
    return finding_id


def parse_semgrep(findings, finding_id):
    """semgrep --json output — supports multi-stack files (semgrep-<stack>.json + legacy semgrep.json)."""
    files = list(SAST.glob("semgrep.json")) + list(SAST.glob("semgrep-*.json"))
    for path in files:
        data = safe_load_json(path)
        if not data:
            continue
        stack_tag = path.stem.replace("semgrep-", "").replace("semgrep", "generic")
        for result in data.get("results", []):
            extra = result.get("extra", {})
            findings.append({
                "id": f"F-{finding_id:03d}",
                "source": f"semgrep ({stack_tag})",
                "severity": normalize_severity(extra.get("severity")),
                "category": "sast",
                "title": result.get("check_id", "semgrep rule"),
                "file": f"{result.get('path', '?')}:{result.get('start', {}).get('line', '?')}",
                "details": (extra.get("message") or "")[:200],
                "fix": (extra.get("fix") or extra.get("metadata", {}).get("references", ["see semgrep docs"])[0])[:200],
            })
            finding_id += 1
    return finding_id


def parse_retire(findings, finding_id):
    """retire.js --outputformat json — vulnerable JS lib detection.

    Schema: array of files với {file, results: [{component, version, vulnerabilities: [...]}]}
    """
    for path in SAST.glob("retire-*.json"):
        data = safe_load_json(path)
        if not data:
            continue
        for item in (data if isinstance(data, list) else data.get("data", [])):
            file_loc = item.get("file", "?")
            for result in item.get("results", []):
                comp = result.get("component", "?")
                ver = result.get("version", "?")
                for vuln in result.get("vulnerabilities", []) or []:
                    sev = normalize_severity(vuln.get("severity"))
                    info = ", ".join(vuln.get("identifiers", {}).get("summary", []) or []) \
                           or vuln.get("info", ["n/a"])[0] if vuln.get("info") else "n/a"
                    findings.append({
                        "id": f"F-{finding_id:03d}",
                        "source": "retire.js",
                        "severity": sev,
                        "category": "dependency",
                        "title": f"{comp} {ver} — {info[:100]}",
                        "file": file_loc,
                        "details": info[:200],
                        "fix": f"Upgrade {comp} away from {ver}",
                    })
                    finding_id += 1
    return finding_id


def parse_pip_audit(findings, finding_id):
    """pip-audit --format json: dependencies[] với vulns[]."""
    for path in DEPS.glob("pip-audit*.json"):
        data = safe_load_json(path)
        if not data:
            continue
        for dep in data.get("dependencies", []):
            for vuln in dep.get("vulns", []):
                findings.append({
                    "id": f"F-{finding_id:03d}",
                    "source": "pip-audit",
                    "severity": normalize_severity(vuln.get("severity", "Medium")),  # pip-audit không luôn có severity
                    "category": "dependency",
                    "title": f"{dep.get('name')} {dep.get('version')}: {vuln.get('id', '?')}",
                    "file": "requirements.txt / pyproject.toml",
                    "details": (vuln.get("description") or "")[:200],
                    "fix": f"Upgrade {dep.get('name')} to {', '.join(vuln.get('fix_versions', []) or ['(no fix)'])}",
                })
                finding_id += 1
    return finding_id


def parse_bandit(findings, finding_id):
    """bandit -f json: results[] với {filename, line_number, issue_severity, test_name, issue_text}."""
    path = SAST / "bandit.json"
    data = safe_load_json(path)
    if not data:
        return finding_id
    for result in data.get("results", []):
        findings.append({
            "id": f"F-{finding_id:03d}",
            "source": "bandit",
            "severity": normalize_severity(result.get("issue_severity")),
            "category": "sast",
            "title": f"{result.get('test_id', '?')}: {result.get('test_name', '?')}",
            "file": f"{result.get('filename', '?')}:{result.get('line_number', '?')}",
            "details": (result.get("issue_text") or "")[:200],
            "fix": result.get("more_info", "See bandit docs"),
        })
        finding_id += 1
    return finding_id


def parse_trivy(findings, finding_id):
    """Trivy JSON: Results[].Vulnerabilities[]."""
    for trivy_file in CONT.glob("trivy-*.json"):
        data = safe_load_json(trivy_file)
        if not data:
            continue
        for result in data.get("Results", []):
            target = result.get("Target", "?")
            for vuln in result.get("Vulnerabilities", []) or []:
                findings.append({
                    "id": f"F-{finding_id:03d}",
                    "source": f"trivy ({trivy_file.name})",
                    "severity": normalize_severity(vuln.get("Severity")),
                    "category": "container" if "fs" not in trivy_file.name else "dependency",
                    "title": f"{vuln.get('PkgName')}: {vuln.get('VulnerabilityID')}",
                    "file": target,
                    "details": (vuln.get("Title") or vuln.get("Description") or "")[:200],
                    "fix": f"Upgrade to {vuln.get('FixedVersion', 'no fix available')}",
                })
                finding_id += 1
    return finding_id


def parse_roslyn(findings, finding_id):
    """roslyn.log: text format — line có 'warning CAxxxx:' hoặc 'error CAxxxx:'."""
    path = SAST / "roslyn.log"
    if not path.exists():
        return finding_id
    pattern = re.compile(r"^(.+?)\((\d+),\d+\):\s+(warning|error)\s+(\w+):\s+(.+?)(\s*\[|$)")
    seen = set()
    for line in path.read_text().splitlines():
        m = pattern.match(line.strip())
        if not m:
            continue
        file_line, severity_word, code, msg = m.group(1), m.group(3), m.group(4), m.group(5)
        key = (file_line, m.group(2), code)
        if key in seen:
            continue
        seen.add(key)
        findings.append({
            "id": f"F-{finding_id:03d}",
            "source": "roslyn",
            "severity": "High" if severity_word == "error" else "Medium",
            "category": "sast",
            "title": f"{code}: {msg[:100]}",
            "file": f"{file_line}:{m.group(2)}",
            "details": msg[:200],
            "fix": "See Microsoft Code Analysis docs for " + code,
        })
        finding_id += 1
    return finding_id


def parse_frontend_xss(findings, finding_id):
    """frontend-xss-grep.txt: section-based plain text."""
    path = SAST / "frontend-xss-grep.txt"
    if not path.exists():
        return finding_id
    current_section = None
    for line in path.read_text().splitlines():
        if line.startswith("==="):
            current_section = line.strip("= ").strip()
            continue
        if line.strip() == "(none)" or not line.strip():
            continue
        # path:line:content
        m = re.match(r"^([^:]+):(\d+):(.*)$", line)
        if not m:
            continue
        findings.append({
            "id": f"F-{finding_id:03d}",
            "source": "grep (frontend XSS)",
            "severity": "Medium",
            "category": "xss",
            "title": f"Suspect pattern: {current_section}",
            "file": f"{m.group(1)}:{m.group(2)}",
            "details": m.group(3).strip()[:200],
            "fix": "Sanitize via DOMPurify; centralize token storage; remove inline scripts",
        })
        finding_id += 1
    return finding_id


def parse_eslint(findings, finding_id):
    """eslint --format json — supports multi-package layout (eslint-<safe>.json + legacy eslint.json)."""
    files = list(SAST.glob("eslint.json")) + list(SAST.glob("eslint-*.json"))
    for path in files:
        data = safe_load_json(path)
        if not data or not isinstance(data, list):
            continue
        pkg_location = path.stem.replace("eslint-", "") or "root"
        for file_result in data:
            file_path = file_result.get("filePath", "?")
            for msg in file_result.get("messages", []):
                sev = "High" if msg.get("severity") == 2 else "Medium"
                findings.append({
                    "id": f"F-{finding_id:03d}",
                    "source": f"eslint ({pkg_location})",
                    "severity": sev,
                    "category": "sast",
                    "title": f"{msg.get('ruleId', 'unknown')}: {(msg.get('message') or '')[:100]}",
                    "file": f"{file_path}:{msg.get('line', '?')}",
                    "details": (msg.get("message") or "")[:200],
                    "fix": "Fix per eslint rule docs",
                })
                finding_id += 1
    return finding_id


def parse_hadolint(findings, finding_id):
    """hadolint --format json — supports multi-Dockerfile (hadolint-<safe>.json + legacy hadolint.json)."""
    files = list(SAST.glob("hadolint.json")) + list(SAST.glob("hadolint-*.json"))
    for path in files:
        data = safe_load_json(path)
        if not data or not isinstance(data, list):
            continue
        for item in data:
            findings.append({
                "id": f"F-{finding_id:03d}",
                "source": "hadolint",
                "severity": normalize_severity(item.get("level")),
                "category": "dockerfile",
                "title": f"{item.get('code')}: {(item.get('message') or '')[:100]}",
                "file": f"{item.get('file', '?')}:{item.get('line', '?')}",
                "details": item.get("message") or "",
                "fix": "See hadolint rules docs",
            })
            finding_id += 1
    return finding_id


def build_compensating_controls(missing):
    """Map missing tools → compensating control description (matches scan.md matrix)."""
    matrix = {
        "gitleaks": ("Manual regex grep over *.cs/*.ts/*.py/*.go/*.json/*.yml (see secrets-grep.txt)", True),
        "semgrep": ("Native analyzers per stack: Roslyn (.NET), eslint-plugin-security (Node), bandit (Python), gosec (Go)", True),
        "trufflehog": ("Same as gitleaks fallback", False),
        "snyk": ("Stack-native: dotnet list package --vulnerable, npm audit, pip-audit, govulncheck", False),
        "trivy": ("Defer to /infra when image is built", True),
        "hadolint": ("Manual review against .claude/references/docker-patterns.md", False),
        "pip-audit": ("Use safety as alternative; or pip list --outdated + manual CVE check", True),
        "bandit": ("Use ruff --select S (bandit-like rules) or semgrep p/python", True),
        "govulncheck": ("Use staticcheck + manual review of go.sum vs CVE database", True),
        "retire": ("npm audit covers most cases; retire.js detects vulnerable CDN-loaded libs", False),
    }
    controls = []
    for tool in missing:
        if tool in matrix:
            fallback, must_add = matrix[tool]
            controls.append({
                "missing_tool": tool,
                "fallback_used": fallback,
                "must_add_to_pipeline": must_add,
            })
    return controls


def detect_stacks_scanned():
    """Suy ra stack đã scan từ file output có mặt trong security/*."""
    stacks = []
    if (DEPS / "nuget-vulnerable.json").exists() or (SAST / "roslyn.log").exists():
        stacks.append("dotnet")
    if list(DEPS.glob("npm-audit*.json")) or list(SAST.glob("eslint*.json")) or (SAST / "frontend-xss-grep.txt").exists():
        stacks.append("nodejs")
    if list(DEPS.glob("pip-audit*.json")) or (SAST / "bandit.json").exists():
        stacks.append("python")
    if list(CONT.glob("trivy-*.json")) or list(SAST.glob("hadolint*.json")):
        stacks.append("docker")
    return stacks


def main():
    findings = []
    next_id = 1

    # Parse từng nguồn (mỗi parser tự safe-fail nếu file không tồn tại)
    # Universal
    next_id = parse_gitleaks(findings, next_id)
    next_id = parse_secrets_grep(findings, next_id)
    # .NET stack
    next_id = parse_dotnet_vuln(findings, next_id)
    next_id = parse_roslyn(findings, next_id)
    # Node.js stack
    next_id = parse_npm_audit(findings, next_id)
    next_id = parse_eslint(findings, next_id)
    next_id = parse_retire(findings, next_id)
    next_id = parse_frontend_xss(findings, next_id)
    # Python stack
    next_id = parse_pip_audit(findings, next_id)
    next_id = parse_bandit(findings, next_id)
    # Multi-stack
    next_id = parse_semgrep(findings, next_id)
    # Container / Docker
    next_id = parse_trivy(findings, next_id)
    next_id = parse_hadolint(findings, next_id)

    # Tally severity
    totals = {"critical": 0, "high": 0, "medium": 0, "low": 0, "unknown": 0}
    for f in findings:
        totals[f["severity"].lower()] += 1

    installed, missing = load_tool_inventory()

    summary = {
        "scan_date": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
        "totals": totals,
        "tools_installed": installed,
        "tools_missing": missing,
        "stacks_scanned": detect_stacks_scanned(),
        "compensating_controls": build_compensating_controls(missing),
        "findings_count": len(findings),
        "findings": findings,
    }

    json.dump(summary, sys.stdout, indent=2, ensure_ascii=False)


if __name__ == "__main__":
    main()
