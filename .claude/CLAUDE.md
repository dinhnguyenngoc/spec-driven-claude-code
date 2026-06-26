# Spec-driven Development with Claude Code

## Overview

This project uses Claude AI as an intelligent development agent with structured workflows, specialized sub-agents, and mandatory coding standards.

---

## Output Language (MANDATORY)

> **Áp dụng cho mọi lệnh, mọi agent, mọi sub-agent — không có ngoại lệ trừ khi user yêu cầu rõ ràng bằng ngôn ngữ khác.**

### Ngôn ngữ tiếng Việt — bắt buộc

Mọi nội dung sau đây **PHẢI** được viết bằng **tiếng Việt**:

- **Hội thoại với user** — mọi câu trả lời, giải thích, câu hỏi xác nhận
- **Artifact của workflow SDLC**:
  - `specs/` — SPEC.md, user stories, acceptance criteria
  - `architecture/` — ARCHITECTURE.md, ADRs, mô tả diagram
  - `plans/` — sprint plans, plan.md, todo.md (tiêu đề task)
  - `security/` — THREAT_MODEL.md, PRE_DEV_REVIEW.md, SCAN_REPORT.md
  - `reports/` — CODE_REVIEW.md và các báo cáo khác
  - `docs/` — getting-started, deployment, troubleshooting, hướng dẫn
- **Báo cáo, summary, status update**
- **Commit message body** (phần mô tả chi tiết sau dòng tiêu đề)
- **PR description, release notes**
- **Comment giải thích logic nghiệp vụ** trong code (WHY)

### Giữ nguyên tiếng Anh — không dịch

Những thành phần sau **PHẢI giữ nguyên tiếng Anh** để đảm bảo tính chuẩn và khả năng tra cứu:

- **Code** — tên biến, hàm, class, interface, namespace, file name
- **Identifier kỹ thuật** — route URL, cache key, DB table/column, env var, Kafka topic
- **Keyword kỹ thuật / thuật ngữ chuẩn** — REST, JWT, OAuth2, Clean Architecture, SOLID, TDD, CQRS, CAP, RFC 7807, OWASP, STRIDE, EF Core, Dapper, v.v.
- **Tên công nghệ, framework, thư viện** — ASP.NET Core, Next.js, SQL Server, Redis, Kafka, Docker, Prometheus, Grafana
- **HTTP method, status code label** — `GET`, `POST`, `200 OK`, `404 Not Found`
- **Conventional Commit type** — `feat`, `fix`, `docs`, `refactor`, `test`, `chore`, `perf`
- **Tiêu đề commit (dòng đầu tiên)** — theo Conventional Commits, viết bằng tiếng Anh
- **Code comment giải thích cú pháp / kỹ thuật thuần** — giữ tiếng Anh nếu là khái niệm chuẩn

### Quy tắc trộn ngôn ngữ

Khi viết artifact tiếng Việt có chứa thuật ngữ kỹ thuật, **không dịch** thuật ngữ — giữ nguyên trong ngữ cảnh tiếng Việt:

```markdown
✅ Đúng:
- Sử dụng pattern Repository để tách biệt tầng truy cập dữ liệu.
- Áp dụng JWT Bearer authentication với refresh token expire sau 7 ngày.
- Endpoint `POST /api/v1/users` trả về `201 Created` kèm Location header.

❌ Sai:
- Sử dụng mẫu Kho lưu trữ để tách biệt tầng truy cập dữ liệu.
- Áp dụng xác thực Mã thông báo Web JSON với mã thông báo làm mới hết hạn sau 7 ngày.
```

### Khi sub-agent được spawn

Khi orchestrator delegate task cho sub-agent (qua tool `Agent`), prompt gửi cho sub-agent **PHẢI** chỉ thị rõ ràng:
> "Output language: Vietnamese for prose/artifacts, English for code and technical identifiers (see `.claude/CLAUDE.md` → Output Language)."

Để đảm bảo sub-agent không vô tình xuất tiếng Anh do prompt training mặc định.

---

## Output Clarity (MANDATORY)

> **Áp dụng cho mọi artifact của mọi lệnh/agent.** Bổ trợ cho §Output Language (quy định *ngôn ngữ*) — mục này quy định *độ rõ ràng*. Hai thứ kết hợp: vừa **đúng ngôn ngữ**, vừa **mạch lạc, dễ hiểu**.

Mọi artifact SDLC (`specs/`, `architecture/`, `plans/`, `security/`, `reports/`, `docs/`…) PHẢI viết **rõ ràng cho đúng đối tượng đọc**:

- **Mở đầu bằng tóm tắt ngôn-ngữ-thường** (*cái gì / vì sao / cho ai*) trước khi vào chi tiết.
- **Viết cho người đọc:** SPEC / wireframe / release-notes → stakeholder (ngôn ngữ thường nhất); ARCHITECTURE / ADR / report → engineer (kỹ thuật nhưng vẫn rõ + giải thích *why*); runbook / troubleshooting → operator (từng bước, rõ ràng).
- **Giải thích thuật ngữ & viết tắt** ở lần đầu; **nêu lý do một dòng** cho mỗi quyết định + con số/ngưỡng; phân tầng nội dung (tóm tắt → chi tiết → tham chiếu); câu ngắn, bảng/list thay cho khối văn dày; **bôi đậm quyết định then chốt**.
- Rõ ràng **không** đồng nghĩa với đơn-giản-hoá-sai — giữ độ chính xác + tên định danh/standard (theo §Output Language).

> Chuẩn đầy đủ + anti-pattern + self-check: [`rules/output-style.md`](rules/output-style.md). Đây là tiêu chí **kiểm được** ở DoR và `/review`.

---

## Progress Visibility (MANDATORY)

> **Áp dụng cho mọi lệnh SDLC nhiều bước / có spawn sub-agent** (`/spec`, `/arch`, `/plan`, `/build`, `/test`, `/review`, `/scan`, `/infra`, `/docs`, `/verify`, `/deploy`, `/discover`, `/fix-issue`, `/hotfix`…). Bổ trợ §Output Language + §Output Clarity (quy định *nội dung*); mục này quy định *khả năng theo dõi tiến trình trên chat*.

Output nội bộ của sub-agent (tool `Agent`) **KHÔNG stream về chat của user** — chỉ trả về cho orchestrator. Nếu orchestrator im lặng, user không biết gì đang diễn ra trong suốt thời gian sub-agent chạy (thường vài phút) → trải nghiệm "hộp đen". Vì vậy orchestrator **PHẢI**:

1. **TodoWrite checklist sống** — đầu mỗi lệnh dài, tạo todo list theo các phase của lệnh; cập nhật `in_progress` / `completed` qua từng bước để user nhìn thấy tiến độ.
2. **Narrate từng bước** — một dòng *trước* mỗi sub-agent/bước nặng ("đang giao BA viết SPEC…") và một dòng *sau* khi nhận kết quả ("xong → 9 stories, 38 scenarios").
3. **Giữ sub-agent chuyên trách** — KHÔNG chuyển sang chạy inline chỉ để "cho dễ thấy"; thiết kế agent-per-command vẫn đúng (context sạch), chỉ cần **bọc bằng todo + narrate**. Khoảng im lặng được phép tồn tại **chỉ trong lúc một sub-agent đang chạy**, khi user đã biết nó đang làm gì.

> Vẫn giữ kỷ luật verify trên đĩa sau khi sub-agent báo xong → xem §Verification After Delegation ngay dưới.

---

## Verification After Delegation (MANDATORY)

> **Áp dụng cho mọi lệnh có spawn sub-agent làm thay đổi/kiểm chứng** (`/build`, `/test`, `/infra`, `/verify`, `/deploy`, `/fix-issue`, `/hotfix`…).

**Báo cáo "xanh" của sub-agent KHÔNG phải ground truth.** Trước khi tuyên bố một gate/step PASS, orchestrator **PHẢI tự chạy lại các check *quyết-định-gate* trên đĩa** và đọc kết quả thật — không tin mù summary của sub-agent:

1. **Re-run lệnh canonical quyết định gate** (chỉ những lệnh quyết định pass, không phải mọi thứ): `dotnet build -c Release` + `dotnet test` · `npm run typecheck && npm test && npm run build` · `docker compose up` + healthcheck + smoke. Đọc **exit code / số test / health thật**.
2. **Đối chiếu invariant then chốt trên đĩa**: file artifact tồn tại đúng chỗ, digest khớp lock, không có file production bị sửa ngoài phạm vi, scenario coverage khớp số.
3. **Khi lệch** giữa báo cáo và đĩa → tin đĩa, surface ngay, sửa trước khi đi tiếp.

> **Vì sao bắt buộc:** trong pipeline thực tế, kỷ luật này đã bắt được những lỗi *report-nói-xanh-nhưng-đĩa-đỏ* mà không gate nào khác bắt — vd `npm test` chuyển RED sau khi thêm Playwright (sub-agent vẫn báo PASS), và container API crash khi khởi động lại (deploy báo SUCCEEDED). Đây là đánh đổi có chủ đích: tốn thêm thời gian re-run, đổi lấy việc chặn **false-green**. Chỉ re-run check *quyết định gate*, không lạm dụng chạy lại toàn bộ.

---

## Project Mode & Profile

This kit supports **two modes**. The mode + peripheral technologies are declared in the `## Project Profile` section (placed directly below in each repo). If **no** Project Profile is present → defaults to **greenfield** + the default stack (`rules/tech-stack.md`).

| Mode | When | Pipeline |
|------|------|----------|
| **greenfield** | Building from scratch, no existing code | The 12-step linear pipeline below |
| **brownfield** | Legacy code already exists / is running in production | **Phase A discovery** (`/discover` → `/spec` reverse → `/arch` reverse) + branched development flows (B1–B5) |

**Brownfield activates:**
- `rules/brownfield.md` (legacy discipline: characterization test, backward-compat, ADR-to-change, measure-vs-verify).
- `/spec`, `/arch`, `/plan` read the Mode to change behavior (see §Brownfield Mode in each command).
- Peripheral technologies that differ from the default → `rules/overrides/*` per the Profile declaration.

**Project Profile template** (each repo fills this in; `/discover` generates it automatically for brownfield):

```markdown
## Project Profile
- Mode: greenfield | brownfield
- Core: C# 12 + ASP.NET Core 8 + EF Core 8 (base) | Node.js → rules/overrides/lang-nodejs.md + framework-nodejs-web.md + test-nodejs.md
- Database: SQL Server (base) | Oracle → rules/overrides/database-oracle.md | MySQL → rules/overrides/database-mysql.md | PostgreSQL → rules/overrides/database-postgres.md | MongoDB → rules/overrides/database-mongodb.md
- Observability: Serilog/Grafana (base) | ELK → rules/overrides/monitoring-elk.md
- Structure: Clean Architecture | N-tier | monolith
- Frontend: <if any>
```

> **Brownfield pipeline summary:**
> - **Phase A (one-time):** `/discover` → `/spec` (reverse) → `/arch` (reverse) → `/infra` (reverse-bootstrap). `/scan` is recommended, independent. `/verify` and `/deploy` are **not part of Phase A** — they are execution commands for per-change work in Phase B (production deploy = touches production state, not baseline documentation).
> - **Phase B (iterative):** B1 new feature · B2 modify feature (characterization test first) · B3 `/fix-issue` · B4 `/hotfix` · B5 architecture upgrade (`/arch` redesign + ADR).
> - **Scope per-change:** `/test`/`/verify` **VIẾT theo delta, CHẠY toàn bộ** suite đã automated (regression net); `/review` chỉ review diff/slice của thay đổi. Bảng chi tiết + cây quyết định 9 tình huống: [`references/brownfield-pipeline.md`](references/brownfield-pipeline.md) §Scope per-change.
> - **Quick lookup of command order per flow:** [`references/brownfield-pipeline.md`](references/brownfield-pipeline.md). Detailed discipline: [`rules/brownfield.md`](rules/brownfield.md).

---

## Natural-Language Task Routing (entry point)

Khi user mô tả một việc bằng **ngôn ngữ thường** ("thêm tính năng X", "sửa tính năng Y", "fix bug Z", "có sự cố trên production", "nâng cấp <dependency/kiến trúc>", "dọn nợ kỹ thuật chỗ W"…), **TRƯỚC KHI làm bất kỳ việc gì khác**, trả lời theo format 3 phần:

1. **Mode** — greenfield hay brownfield: xác định từ `Project Profile → Mode` + tín hiệu thực tế của repo (đã có source code business chưa), **nêu rõ căn cứ**. Profile lệch hiện trạng → cảnh báo và dừng, không tự đi tiếp.
2. **Luồng** — gọi tên: greenfield 12 bước, hoặc B1 / B2 / B3 / B4 / B5 / B5-lite / `/simplify` (cây quyết định: [`references/brownfield-pipeline.md`](references/brownfield-pipeline.md)).
3. **Checklist lệnh theo thứ tự** + kỷ luật then chốt của luồng (vd: B2 → characterization test TRƯỚC khi sửa · B1 mở surface ngoài → nên chạy `/secure` · B5 → ADR + strangler-fig · scope: VIẾT theo delta, CHẠY toàn bộ suite).

Sau đó **hỏi user chọn chế độ thực thi** (mặc định KHÔNG tự chạy khi chưa hỏi):
- **User-driven** — user tự chạy từng lệnh, tự duyệt từng gate.
- **Claude-driven** — Claude chạy tuần tự các lệnh nhưng **dừng ở mỗi Quality Gate** chờ duyệt; các điểm cần sign-off của con người (Gate 1 stakeholder approval, review verdict, promote production) **luôn** chờ — bất kể chế độ nào.

---

## Project Profile

> **Điền block này cho project của bạn.** Nó cấu hình mode + peripheral stack cho cả pipeline. Giá trị dưới đây là **mặc định mẫu** (greenfield trên base stack) — thay bằng lựa chọn thật của project. Nếu onboard codebase legacy → chạy `/discover` để kit tự sinh lại block này (đặt `Mode: brownfield`). Nếu xây từ đầu → giữ `Mode: greenfield` và khai báo stack mục tiêu.

- **Mode:** greenfield  *(greenfield = xây từ đầu; brownfield = đã có code legacy → chạy `/discover` trước)*
- **Core:** C# 12 + ASP.NET Core 8 (`net8.0`) + EF Core 8 (base) | Node.js → `rules/overrides/lang-nodejs.md` + `framework-nodejs-web.md` + `test-nodejs.md`
- **Database:** SQL Server 2022 → base `rules/database.md` (no override). InMemory provider cho test/design-time. | Oracle / MySQL / PostgreSQL / MongoDB → `rules/overrides/database-*.md`
- **Observability:** Serilog (structured JSON: Console + rolling File) → base `rules/monitoring.md`. | ELK → `rules/overrides/monitoring-elk.md`
- **Structure:** Clean Architecture 3-layer (`MyApp.Api` → `MyApp.Core` ← `MyApp.Infrastructure`) | N-tier | monolith
- **Frontend:** <nếu có — vd: Next.js + React + TypeScript + Zustand + TanStack Query + React Hook Form + Zod + Tailwind + shadcn/ui; test Vitest + Testing Library; hoặc "none / API-only">
- **Service id:** <chỉ multi-repo — id chuẩn của service NÀY cho system catalog của `/discover-system`; bỏ trống nếu single-repo>

---

## Development Workflow (AI SDLC)

Follow this **12-step workflow** (3 phases) for all feature development (greenfield mode; for brownfield see §Project Mode & Profile):

```
┌───────────────────────────────────────────────────────────────────────────────────┐
│                                 AI SDLC PIPELINE                                  │
├───────────────────────────────────────────────────────────────────────────────────┤
│                                                                                   │
│  ┌─────────────────────────────────────────────────────────────────────────────┐  │
│  │  PHASE 1: REQUIREMENTS & DESIGN                                             │  │
│  │                                                                             │  │
│  │  /spec ────→ /arch ────→ /plan ────→ /secure*                               │  │
│  │    │           │           │            │                                   │  │
│  │   BA          SA          PM       SecArch                                  │  │
│  │    │           │           │            │                                   │  │
│  │  specs/    architecture/  plans/    security/                               │  │
│  │                                     PRE_DEV_REVIEW                          │  │
│  └─────────────────────────────────────────────────────────────────────────────┘  │
│                                         │                                         │
│                                         ▼                                         │
│  ┌─────────────────────────────────────────────────────────────────────────────┐  │
│  │  PHASE 2: DEVELOPMENT & QUALITY                                             │  │
│  │                                                                             │  │
│  │  /build ────→ /test ────→ /review*                                          │  │
│  │     │           │            │                                              │  │
│  │    Dev         QA       Reviewer                                            │  │
│  │     │           │            │                                              │  │
│  │   src/       tests/      reports/                                           │  │
│  │   tests/                 CODE_REVIEW                                        │  │
│  └─────────────────────────────────────────────────────────────────────────────┘  │
│                                         │                                         │
│                                         ▼                                         │
│  ┌─────────────────────────────────────────────────────────────────────────────┐  │
│  │  PHASE 3: SECURITY & DEPLOYMENT                                             │  │
│  │                                                                             │  │
│  │  /scan* ──→ /infra ──→ /docs* ──→ /verify* ──→ /deploy                      │  │
│  │     │          │          │          │           │                          │  │
│  │  SecScan    Backend    Writer       QA        Release                       │  │
│  │     │          │          │          │           │                          │  │
│  │  security/  docker/     docs/     reports/    DEPLOYED                       │  │
│  │  SCAN_REPORT                      VERIFY_REPORT                              │  │
│  └─────────────────────────────────────────────────────────────────────────────┘  │
│                                                                                   │
└───────────────────────────────────────────────────────────────────────────────────┘

Legend: * = Optional (other commands are required)
```

### Phase 1: Requirements & Design

| # | Command | Agent | Purpose | Output |
|---|---------|-------|---------|--------|
| 1 | `/spec` | Business Analyst | Spec before code — User Stories & Acceptance Criteria for new features | `specs/` |
| 2 | `/arch` | Systems Architect | Design system architecture with diagrams, ADRs, and API contracts | `architecture/` |
| 3 | `/plan` | Project Manager | Decompose specs into small, verifiable tasks with dependency ordering | `plans/` |
| 4 | `/secure` | Security Auditor | Pre-development security review with threat modeling (STRIDE) | `security/PRE_DEV_REVIEW` |

### Phase 2: Development & Quality

| # | Command | Agent | Purpose | Output | Docker |
|---|---------|-------|---------|--------|--------|
| 5 | `/build` | Frontend/Backend Dev | Implement tasks incrementally using TDD and vertical slices | `src/`, `web/`, `tests/` | ❌ Not required |
| 6 | `/test` | Test Engineer | QA verification with real dependencies — the quality gate before review | `tests/` | ✅ Required |
| 7 | `/review` | Code Reviewer | Review a pull request or branch changes using the Five-Axis Framework | `reports/CODE_REVIEW` | — |

> **Testing Strategy:** `/build` uses Unit Tests (Mock) + Integration Tests (In-Memory) — Docker not required. `/test` uses TestContainers + E2E Tests — Docker required. See details in [`.claude/rules/testing.md`](rules/testing.md).

### Phase 3: Security & Deployment

| # | Command | Agent | Purpose | Output |
|---|---------|-------|---------|--------|
| 8 | `/scan` | Security Auditor | Post-development security scanning and vulnerability assessment | `security/SCAN_REPORT` |
| 9 | `/infra` | Backend Developer | Setup Docker infrastructure for local development | `docker/` |
| 10 | `/docs` | Technical Writer | Generate comprehensive project documentation | `docs/` |
| 11 | `/verify`\* | Test Engineer | Post-deploy verification — exercise every feature (acceptance criteria) against the real deployed artifact. **Step optional · BLOCKING if run.** Strongly recommended before production promote; required inside `/hotfix` orchestrator | `reports/VERIFY_REPORT` |
| 12 | `/deploy` | Release Manager | Promote the verified artifact with staged rollout | Production |

> **Why `/verify` is strongly recommended (but optional) before `/deploy`:** `/test` runs in a test environment over an in-process transport — it cannot exercise the production-config × real-network × real-client intersection where CORS, security headers, env-gating middleware, TLS, and container-networking bugs live. `/verify` runs the acceptance-criteria suite against the **exact artifact that will ship**. Step is **optional** in the standard pipeline, but **BLOCKING if run** — when `/verify` is executed, `/deploy` may only promote a digest with a passing report. `/verify` remains **required** inside the `/hotfix` orchestrator (Step 4 re-verify on patched digest). See [`.claude/commands/verify.md`](commands/verify.md).

### Supporting Commands

| Command | Purpose |
|---------|---------|
| `/discover` | **Brownfield Phase A** — onboard a legacy repo: survey stack/structure, verify build/run, snapshot health, generate the Project Profile (read-only) |
| `/discover-system` | **Multi-repo** — aggregate per-repo discovery across a workspace into a system-wide map (service catalog, call-graph, cross-service journeys). Read-only, one-way documentation. See [`references/microservices-multirepo.md`](references/microservices-multirepo.md) |
| `/debug` | Systematic debugging and error recovery — find root cause, not symptoms |
| `/simplify` | Reduce complexity without changing behavior — code simplification |
| `/fix-issue` | Analyze and fix a reported bug or issue systematically (dev-time → `/review`; if the bug was found by `/verify`/`/hotfix`, the caller re-verifies the patched digest instead) |
| `/hotfix` | Restore a live/released system — triage rollback vs fix-forward, patch, re-verify, redeploy with audit trail (incident-time) |

> **`/fix-issue` vs `/hotfix`:** `/fix-issue` fixes code during the dev cycle (not yet released, ends at `/review`). `/hotfix` is a **thin orchestrator** for an artifact that is **already live** — it triages rollback-vs-fix-forward, then reuses `/fix-issue` (the fix) + `/verify` (proves the patch on the real artifact) + `/deploy` (promotes rollback-ready), along with patch versioning + a post-incident runbook. See [`.claude/commands/hotfix.md`](commands/hotfix.md).

---

## Quality Gates

Each phase transition has mandatory quality gates:

```
┌─────────────────────────────────────────────────────────────────┐
│                       QUALITY GATES                             │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  GATE 1: /spec → /arch                                          │
│  ✓ PRD approved by stakeholder                                  │
│  ✓ All user stories have acceptance criteria                   │
│  ✓ (UI) ASCII wireframe + visual sign-off (prototype opt-in)    │
│                                                                 │
│  GATE 2: /arch → /plan                                          │
│  ✓ Architecture reviewed                                       │
│  ✓ ADRs documented for key decisions                           │
│  ✓ API contracts defined                                       │
│                                                                 │
│  GATE 3: /plan → /secure                                        │
│  ✓ Tasks broken into vertical slices                           │
│  ✓ Dependencies mapped                                         │
│                                                                 │
│  GATE 4: /secure → /build  (step optional · BLOCKING if run)    │
│  ✓ Threat model completed (if /secure run)                     │
│  ✓ Security requirements defined (if /secure run)              │
│  ✓ No critical security concerns (if /secure run)              │
│                                                                 │
│  GATE 5: /build → /test                                         │
│  ✓ All unit tests pass                                         │
│  ✓ Code compiles without errors                                │
│                                                                 │
│  GATE 6: /test → /review                                        │
│  ✓ Code coverage ≥ 80%                                         │
│  ✓ All tests pass                                              │
│                                                                 │
│  GATE 7: /review → /scan  (Optional)                            │
│  ✓ Five-axis review passed (if /review run)                    │
│  ✓ All critical feedback addressed (if /review run)            │
│                                                                 │
│  GATE 8: /scan → /infra  (step optional · BLOCKING if run)      │
│  ✓ No critical/high vulnerabilities (if /scan run)             │
│  ✓ OWASP Top 10 checks pass (if /scan run)                     │
│                                                                 │
│  GATE 9: /infra → /docs                                         │
│  ✓ Docker builds successfully                                  │
│  ✓ docker-compose up runs all services healthy                 │
│                                                                 │
│  GATE 10: /docs → /verify  (Optional)                           │
│  ✓ All documentation complete (if /docs run)                   │
│  ✓ README updated (if /docs run)                               │
│                                                                 │
│  GATE 11: /verify → /deploy  (step optional · BLOCKING if run) │
│  ✓ Artifact digest tested == digest promoted (if /verify run)  │
│  ✓ Liveness + API contract pass (if /verify run)               │
│  ✓ E2E journeys pass per user story (if UI, if /verify run)    │
│  ✓ NFRs measured against spec thresholds (if /verify run)      │
│  ✓ 100% AC scenarios have verify test (if /verify run)         │
│  Note: /verify remains REQUIRED inside /hotfix orchestrator    │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## Core Principles

### Code Quality
- **Test-Driven Development** — Write failing tests first, then implement
- **Incremental Implementation** — Small vertical slices, always buildable
- **Five-Axis Review** — Correctness, Readability, Architecture, Security, Performance

### Security First
- **Pre-Development Security** — Threat modeling before coding
- **Post-Development Security** — Vulnerability scanning before deploy
- **Security by Design** — Not afterthought

### Philosophy
- Progress over perfection
- Fix root causes, not symptoms
- The simplest thing that could work
- Tests are proof, not afterthought

---

## Mandatory Rules

All rules in `.claude/rules/` are **mandatory** and must be followed:

### Foundations (master reference)
| Rule | Description |
|------|-------------|
| `principles-and-practices.md` | **Master reference** — design principles (SOLID, YAGNI, KISS, DRY, Composition, Tell-Don't-Ask), best practices (TDD, code review, idempotency, ADR, postmortem), architecture default (Modular Monolith + Clean Architecture), Docker baseline (20 must-haves), NFR-dependent infrastructure (Redis/Kafka/sharding/CDN — opt-in by trigger). Referenced by every SDLC command. |
| `output-style.md` | **Output clarity (artifacts)** — every artifact reads clearly for its audience: plain-language summary first, jargon defined, decisions & numbers justified, register matched to reader (stakeholder / engineer / operator). Complements § Output Language; applies to all commands/agents. |

### Code Quality
| Rule | Description |
|------|-------------|
| `clean-code.md` | Variables, functions, SOLID, async/await |
| `code-style.md` | C# formatting, braces, `var` usage, file-scoped namespaces |
| `error-handling.md` | `AppException`, ProblemDetails (RFC 7807), global middleware |

### Architecture & Design
| Rule | Description |
|------|-------------|
| `tech-stack.md` | Approved technologies (ASP.NET Core 8, SQL Server, Redis, EF Core) |
| `system-design.md` | CAP theorem, caching, scaling, queues |
| `project-structure.md` | Clean Architecture, folder organization |
| `api-conventions.md` | REST standards, response envelopes |
| `frontend.md` | Next.js/React/TypeScript, Zustand, TanStack Query, Tailwind |

### Data & Naming
| Rule | Description |
|------|-------------|
| `naming-conventions.md` | Cache keys, DB, queues, env vars |
| `database.md` | EF Core + Dapper patterns, transactions, N+1 prevention |

### Operations
| Rule | Description |
|------|-------------|
| `security.md` | **CRITICAL** — Never violate security rules |
| `monitoring.md` | Prometheus, Grafana, logging, alerting (base; `overrides/monitoring-elk.md` when the Profile declares ELK) |
| `testing.md` | Coverage thresholds, test patterns |
| `git-workflow.md` | Branching strategy, conventional commits |
| `brownfield.md` | **Brownfield only** — legacy discipline: characterization test, backward-compat, ADR-to-change, measure-vs-verify (active when `Mode: brownfield`) |

---

## Available Agents

Invoke the right agent for each task type. Agent definitions are stored in `.claude/agents/`:

### Development Agents
| Agent | File | When to Invoke | SDLC Phase |
|-------|------|---------------|------------|
| 🖥️ **Frontend Developer** | `frontend-developer.md` | Expert frontend developer specializing in Next.js, React, TypeScript, and modern UI development | `/build` |
| 🔧 **Backend Developer** | `backend-developer.md` | Expert backend developer specializing in ASP.NET Core, Entity Framework Core, SQL Server, Redis, and REST API design | `/build`, `/infra` |
| 🏗️ **Systems Architect** | `systems-architect.md` | Principal systems architect who designs scalable, reliable system architectures | `/arch` |

### Quality Agents
| Agent | File | When to Invoke | SDLC Phase |
|-------|------|---------------|------------|
| 👀 **Code Reviewer** | `code-reviewer.md` | Senior Staff Engineer perspective for five-axis code review | `/review` |
| 🧪 **Test Engineer** | `test-engineer.md` | Senior SDET who owns end-to-end quality — test strategy, TDD coaching, coverage policy, TestContainers/E2E execution, and bug triage | `/test`, `/verify` |
| 🔒 **Security Auditor** | `security-auditor.md` | Security engineer for vulnerability detection and threat modeling | `/secure`, `/scan` |

### Product & Operations Agents
| Agent | File | When to Invoke | SDLC Phase |
|-------|------|---------------|------------|
| 📊 **Business Analyst** | `business-analyst.md` | Requirements engineer who elicits, analyzes, and documents what to build and why | `/spec` |
| 📋 **Project Manager** | `project-manager.md` | Strategic project manager who plans sprints, defines requirements, and ensures delivery | `/plan` |
| 🎨 **UI/UX Designer** | `ui-ux-designer.md` | Expert designer who creates intuitive, beautiful, and accessible user experiences | `/spec`, `/arch` |
| 📝 **Technical Writer** | `technical-writer.md` | Technical writer who produces developer-facing documentation — API references, getting-started guides, deployment runbooks, troubleshooting | `/docs` |
| 🚀 **Release Manager** | `release-manager.md` | Release engineer who owns build, staged rollout, version tagging, release notes, and post-deploy verification | `/deploy` |

> **Note:** `/infra` (local Docker) is owned by the Backend Developer agent. `/verify` (post-deploy verification on the real artifact) is owned by the Test Engineer agent, collaborating with the Release Manager. `/deploy` (production rollout) is owned by the Release Manager agent.

---

## Project Structure

```
project-root/
│
├── specs/                          # /spec output
│   ├── SPEC.md
│   ├── user-stories/               # split layout only (> 20 stories / multi-epic)
│   └── wireframes/                 # UI products: README + screens/ + flows/ (+ prototype/ opt-in)
│
├── architecture/                   # /arch output
│   ├── ARCHITECTURE.md
│   ├── adr/
│   ├── diagrams/
│   └── api/
│
├── plans/                          # /plan output
│   ├── sprint-*.md
│   ├── plan.md
│   └── todo.md
│
├── security/                       # /secure + /scan output
│   ├── THREAT_MODEL.md
│   ├── PRE_DEV_REVIEW.md
│   └── SCAN_REPORT.md
│
├── src/                            # /build output — backend (ASP.NET Core / Node)
│
├── web/                            # /build output — frontend (Next.js/React), if any — canonical FE folder
│
├── tests/                          # /build + /test output
│   ├── unit/
│   ├── integration/
│   └── e2e/
│
├── reports/                        # /review + /verify output
│   ├── CODE_REVIEW.md
│   ├── VERIFY_REPORT.md            # /verify — gate verdict for /deploy
│   ├── VERIFY_MATRIX.md            # /verify — acceptance-criteria → test traceability
│   ├── verify-artifact.lock        # /verify — digest tested == digest promoted
│   └── incidents/                  # /hotfix — incident notes (INC-<id>.md: timeline, MTTR, prevention)
│
├── docker/                         # /infra output — Dockerfile only
│   └── Dockerfile
├── docker-compose.yml              # /infra output — at repo root so `context: .` works
├── docker-compose.test.yml         # optional E2E overlay
├── docker-compose.deploy.yml       # optional release-tag overlay
├── .dockerignore                   # MUST be at repo root (build context)
│
├── docs/                           # /docs output
│   ├── getting-started.md
│   ├── api/
│   ├── deployment.md
│   └── troubleshooting.md
│
└── .claude/                        # AI Agent Configuration
    ├── agents/
    ├── commands/
    ├── rules/
    ├── skills/
    ├── references/
    ├── templates/                  # fill-only boilerplates: STRIDE/OWASP (/secure,/scan) · TEST_REPORT (/test) · VERIFY_REPORT (/verify) · CODE_REVIEW (/review) · RUNBOOK_RELEASE (/deploy) · wireframes (/spec)
    ├── scripts/                    # scan-all.sh + scan-summarize.py for /scan
    └── CLAUDE.md
```

---

## Available Skills

Specialized skills for complex operations (stored in `.claude/skills/`):

| Skill | Description |
|-------|-------------|
| `tdd` | Write tests before code using RED-GREEN-REFACTOR cycle |
| `code-review` | Five-axis code review for comprehensive quality assessment |
| `incremental-implementation` | Build features in thin vertical slices with continuous verification |
| `security-review` | Skill to perform a thorough security audit of the codebase |

> **Note:** SDLC workflow commands (`/spec`, `/arch`, `/build`, etc.) are defined in `.claude/commands/`.

---

## Reference Checklists

Quick references in `.claude/references/`:

| Reference | Use For |
|-----------|---------|
| `security-checklist.md` | Pre-deploy security verification |
| `performance-checklist.md` | Core Web Vitals, optimization |
| `accessibility-checklist.md` | WCAG 2.1 AA compliance |
| `ascii-diagram-guide.md` | ASCII diagram standards for architecture docs |
| `code-review-checklist.md` | Five-axis code review framework |
| `deployment-checklist.md` | Pre-deployment verification gates |
| `docker-patterns.md` | Dockerfile and docker-compose best practices |
| `scenario-traceability.md` | Scenario-level traceability rule (`@US-XXX-Snn` → task/test mapping across all gates) |
| `brownfield-pipeline.md` | Brownfield quick lookup — Phase A discovery order + Phase B flows (B1–B5) |
| `microservices-multirepo.md` | Multi-repo quick lookup — per-repo pipeline + one-way system layer (`/discover-system`), backward-compat as cross-service safety |

---

## Agent Behavior Guidelines

1. **Follow the complete workflow** — `/spec` → `/arch` → `/plan` → `/secure` → `/build` → `/test` → `/review` → `/scan` → `/infra` → `/docs` → `/verify` → `/deploy`
2. **Respect quality gates** — Never skip blocking gates (security reviews)
3. **Apply mandatory rules** — All rules in `.claude/rules/` are non-negotiable
4. **Test first** — Write failing tests before implementing
5. **Security first** — Threat model before coding, scan before deploying
6. **Incremental changes** — Small commits, always buildable
7. **Explain before acting** — Describe changes before making them
8. **Fix root causes** — Don't patch symptoms
9. **Use the right agent** — Invoke specialized agents for their domains
10. **Document everything** — If it's not documented, it doesn't exist
11. **Keep `plans/todo.md` truthful** — Tick every completed task (`- [x]`) before reporting done. When work is delegated to sub-agents, the orchestrator owns the tick and applies it after the sub-agent's success report. A task without its tick is not done.

