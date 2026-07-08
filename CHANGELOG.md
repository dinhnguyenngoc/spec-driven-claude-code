# Changelog

Toàn bộ thay đổi đáng chú ý của **AI SDLC Kit** được ghi tại đây. Định dạng theo
[Keep a Changelog](https://keepachangelog.com/); phiên bản theo [SemVer](https://semver.org/).
Các phiên bản trước `v1.3.0` (`v1.0.0`, `v1.1.0`, `v1.2.0`) được đánh dấu bằng git tag tương ứng.

## [1.3.0] — 2026-07-07

> Bản này bổ sung tầng quản trị cho kit (layering + versioning), lệnh `/inspect` để tra hiện
> trạng có bằng chứng, siết mạnh kỷ luật brownfield, và đưa `/deploy` về đúng ranh giới STAGING.
> Phần lớn số dòng còn lại là chuẩn hoá ngôn ngữ nguồn của kit sang English (output runtime vẫn tiếng Việt).

### Added
- **`/inspect`** — lệnh mới tra hiện trạng phần mềm: read-only, 3 tầng bằng chứng (records → code → live)
  + phát hiện mismatch + xếp hạng PROVEN/DESCRIBED. Được wire vào routing như ngoại lệ câu-hỏi-hiện-trạng.
- **Kit Layering** — mô hình 3 tầng **CORE / CONFIG / EXTENSION** + precedence `local/ > PROJECT_PROFILE > base`.
- **`PROJECT_PROFILE.md`** — tách thành file CONFIG riêng, user-owned, an toàn qua kit upgrade.
- **`local/`** (EXTENSION) — `KIT_DEVIATIONS.md` + `README.md` cho tuỳ biến team.
- **`KIT_VERSION`** — file marker phiên bản (nền cho upgrade-manifest Phase 2).
- **Dual-Implementation Parity** (`rules/testing.md`) — chống bug-class "1 quy tắc có ≥2 biểu diễn → drift":
  ưu tiên khử bản thứ 2, nếu buộc reimplement → **differential test** bắt buộc.
- **`/spec` Phase 0** — auto-detect Mode (ARGS × CODE × DISCOVERY) → STOP / REVERSE / DELTA.
- **`README_EN.md`**.

### Changed
- **`/deploy` = STAGING-only** — Status tối đa `STAGED`; promote production là bước **thủ công ngoài kit**
  (least privilege, `DEPLOY_RUNBOOK §8`). Từ vựng `SUCCEEDED` → `STAGED` toàn bộ.
- **Coverage gate theo Mode** — greenfield whole-repo; brownfield **delta-coverage + ratchet**.
- **`/scan`** tái cấu trúc quanh script auto-detect stack → dispatch per-stack → `SCAN_SUMMARY.json` → STRIDE re-eval.
- **Hook `log-command-stats.py`** — thêm cột **cost** (ước tính USD theo list-price từng model) + **duration** + humanize token (K/M/B).
- Templates (OWASP/STRIDE/CODE_REVIEW/RUNBOOK_RELEASE/TEST_REPORT/VERIFY_REPORT) & agents đồng bộ với STAGED + coverage-by-mode.

### Hardened
- **SCAN guard 3 trạng thái** — thiếu `SCAN_REPORT` giờ **block** (cần `ACK_NO_SCAN=1` + ghi ngoại lệ vào
  RELEASE_NOTES), thay vì pass thầm lặng.
- **Host-isolation mở rộng** — `IHostedService`/Kafka consumer phải tắt/redirect trong test ·
  `ASPNETCORE_ENVIRONMENT=Testing` + `appsettings.Testing.json` · auto-migrate trỏ container ·
  **cấm sửa config production** để test pass (`git status` chứng minh).
- Fixture guidance: **arm64** azure-sql-edge; nạp **raw DDL** (stored procedure/trigger) vào TestContainer.

### Internal
- Chuẩn hoá ngôn ngữ nguồn kit (`.md`) sang English; giữ tiếng Việt ở `CLAUDE.md` §Output Language/§Output Clarity + `PROJECT_PROFILE.md`.
- `rules/brownfield.md` + `references/brownfield-pipeline.md` viết lại (Measure vs Verify · Upfront vs Per-change ·
  WRITE-per-delta-RUN-everything · cây quyết định 9 tình huống).

### ⚠️ Upgrade notes (behavior changes)
- `/deploy` KHÔNG còn tự tuyên bố production `SUCCEEDED` — tối đa `STAGED`; script/kỳ vọng cũ dựa trên
  `SUCCEEDED` phải đổi. Production do bước promote thủ công (RUNBOOK §8) điền.
- Deploy khi **chưa** chạy `/scan` giờ **fail** trừ khi set `ACK_NO_SCAN=1` (+ ghi ngoại lệ vào RELEASE_NOTES §Known risks).
- Coverage gate brownfield chuyển sang **delta + ratchet** (không còn ép 80% whole-repo mỗi PR).

## [1.2.0] — 2026-06-26

> Full-kit audit pass — audit per-command toàn bộ 18 lệnh (rubric 5-lens), dựa trên một
> dry-run pipeline `/spec`→`/deploy` trên sản phẩm mẫu. Siết 4 chuỗi cross-cutting để bịt rò lỗi.

### Hardened
- **RC-N Required Control join-key** — `/secure` mint → `/review` cite → `/scan` verify (trước đây chuỗi gãy: consumer cite RC-X.Y nhưng không producer nào mint).
- **Producer→consumer handoff testing** — scenario-traceability → `/plan` → `/build` → `/fix-issue` (nav-state / context / event-name test ở cả 2 đầu).
- **NFR completeness** — `/spec` surface (kể cả security headers, responsive) → `/arch` completeness-check → `/plan` baseline sweep (không rớt NFR thầm lặng).
- **Evidence-over-assertion** — compliance cần citation, review score neo vào findings, gate cần exit-0, `/simplify` green-baseline, verify-on-disk.

### Added
- **`/discover-system`** — system map multi-repo.
- Rule **`output-style.md`** (clarity); template fill-only `system/` + `wireframes/`; Node.js stack overrides; guidance arm64 (azure-sql-edge, Alpine globalization).
- Codify **Progress Visibility** + **Verification-After-Delegation** thành rule kit-wide MANDATORY.

## [1.1.0] — 2026-06-10

> Dễ dùng hơn, brownfield đầy đủ hơn, chạy nhanh hơn — đồng bộ toàn kit sau chuỗi audit 6 thư mục + deep-dive 17 lệnh.

### Added
- **§Natural-Language Task Routing** (CLAUDE.md) — Mode + luồng + checklist + 2 chế độ User/Claude-driven.
- 4 template fill-only: `TEST_REPORT` · `VERIFY_REPORT` · `CODE_REVIEW` · `RUNBOOK_RELEASE` (templates/ 2→6).
- Kích hoạt 3 override Node.js (lang / framework / test).

### Changed
- Commands (17): chỉ thị Output Language cho mọi prompt spawn sub-agent; chuẩn hoá 14 Quality Gate + ngữ nghĩa optional·BLOCKING-if-run (Gate 4/7/8/11).
- Agents (11): vá drift persona — scenario ID `@US-XXX-Snn`; agents biết vai trò brownfield; Code Reviewer 4 nhãn canonical + report 7 mục; Release Manager đúng ownership DEPLOY_RUNBOOK.
- Khép kín traceability: scenario `@US-XXX-Snn` (single source), RC controls, digest match, P0/P1 handoff, Five-Axis 1-5.
- Brownfield: cây quyết định 6→9 tình huống (B5-lite, `/simplify`, deprecate); §Scope per-change "VIẾT theo delta, CHẠY toàn bộ" wiring 3 lớp.
- TestContainers chuyển **collection fixture** 1-container-per-suite (chạy nhanh hơn).

## [1.0.0] — 2026-06-08

> Initial release — bộ kit SDLC theo quy chuẩn định sẵn cho Claude Code.

### Added
- 17 slash-command workflow (`/spec` → `/deploy`) + 5 lệnh hỗ trợ.
- 11 agent chuyên biệt (BA, Architect, Backend/Frontend Dev, Security, QA…).
- 17 rule kỹ thuật bắt buộc + 8 override theo stack (PostgreSQL, Node.js, ELK…).
- 4 skill, 10 reference checklist, template STRIDE/OWASP, security scanners.
- Hỗ trợ 2 mode **greenfield** + **brownfield** với quality gate giữa các phase; README song ngữ (EN + VN).

[1.3.0]: https://github.com/dinhnguyenngoc/spec-driven-claude-code/releases/tag/v1.3.0
[1.2.0]: https://github.com/dinhnguyenngoc/spec-driven-claude-code/releases/tag/v1.2.0
[1.1.0]: https://github.com/dinhnguyenngoc/spec-driven-claude-code/releases/tag/v1.1.0
[1.0.0]: https://github.com/dinhnguyenngoc/spec-driven-claude-code/releases/tag/v1.0.0
