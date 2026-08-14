# Spec-driven Development with Claude Code

> **Biến một ý tưởng thành phần mềm sẵn sàng production — từng lệnh một.**
> Bộ kit SDLC hoàn chỉnh, theo quy chuẩn định sẵn cho [Claude Code](https://claude.com/claude-code): các agent chuyên biệt, workflow theo slash-command, các quy tắc kỹ thuật bắt buộc, và các quality gate giữ cho AI làm việc kỷ luật từ `/spec` đến `/deploy`.

🌏 **[English → README.md](README.md)**

---

> Tôi đã từng để AI code hộ, rất nhanh, rất ưng ý, rất wow — xong 2 tuần sau bug lòi ra, sửa chỗ này thì bug chỗ khác, và không trả lời được câu hỏi "cái này test chưa, bảo mật có ổn không". Vibe-coding sướng ở tốc độ nhưng đánh đổi bằng thứ dev thực chiến không được phép mất: kiểm soát.
>
> Tôi xây dựng bộ kit này để lấy lại quyền kiểm soát đó — mà không đánh mất tốc độ.

---

## Đây là gì?

Đây **không phải** một ứng dụng. Đây là một **bộ cấu hình `.claude/`** mà bạn đặt vào bất kỳ dự án nào, để Claude Code không còn là một công cụ autocomplete thông minh, mà hành xử như một **đội kỹ thuật phần mềm có kỷ luật**.

Thay vì bảo AI "xây cho tôi một app" rồi cầu may, bạn điều phối một **pipeline 12 bước**, trong đó mỗi bước:

- được sở hữu bởi một **agent chuyên biệt** (Business Analyst, Architect, Backend Dev, Security Auditor, …),
- tạo ra một **artifact cụ thể** (`specs/`, `architecture/`, `plans/`, `src/`, `tests/`, `reports/`…),
- và phải vượt qua một **quality gate** trước khi bước tiếp theo bắt đầu.

Kết quả là tuân thủ đúng trình tự và kỷ luật bạn mong đợi ở một đội ngũ thực thụ — requirements trước code, test trước implementation, security trước deploy — nhưng được thực thi bởi các AI agent mà bạn điều phối chỉ bằng một slash command.

Nói ngắn gọn, kit đóng vai trò một **[harness](https://walkinglabs.github.io/learn-harness-engineering/en/)** — một lớp quy tắc tường minh và vòng lặp kiểm chứng, buộc mọi lệnh SDLC tuân theo cùng một chuẩn và cho kết quả có thể tái lập, thay vì để model tự ứng biến khác nhau mỗi lần chạy.

> 💡 **Lấy cảm hứng từ** triết lý agentic-workflow của [BMAD-METHOD](https://github.com/bmad-code-org/BMAD-METHOD), nhưng được xây dựng để trở thành một SDLC chặt chẽ, gate-driven cho **C# / ASP.NET Core 8** (kèm các override **Node.js / Next.js** được hỗ trợ đầy đủ).

---

## Vì sao nên dùng?

| Không có kit | Có kit |
|--------------|--------|
| "Xây cho tôi app bookmark" → một mớ code, không có kế hoạch | `/spec` → User Stories & Acceptance Criteria bạn duyệt trước |
| AI tự bịa cấu trúc mỗi lần một kiểu | Mọi dự án theo cùng quy tắc **Clean Architecture** |
| Test viết sau cùng (hoặc không bao giờ) | **TDD bắt buộc** — test fail trước, gate coverage ≥80% |
| Bảo mật là chuyện tính sau | **STRIDE threat model** trước khi code, **OWASP scan** trước khi deploy |
| "Máy tôi chạy được mà" | `/verify` chạy trên **đúng artifact** sẽ ship |
| Code style không nhất quán giữa các phiên | 17 **quy tắc bắt buộc** áp dụng cho mọi dòng code |

---

## Pipeline 12 bước

```
PHASE 1 — REQUIREMENTS & DESIGN        PHASE 2 — DEVELOPMENT & QUALITY      PHASE 3 — SECURITY & DEPLOY
┌─────────────────────────────┐        ┌──────────────────────────┐        ┌───────────────────────────────────┐
│ /spec  → Business Analyst   │        │ /build → Frontend/Backend│        │ /scan   → Security Auditor        │
│ /arch  → Systems Architect  │   ──▶  │ /test  → Test Engineer   │   ──▶  │ /infra  → Backend Developer       │
│ /plan  → Project Manager    │        │ /review→ Code Reviewer   │        │ /docs   → Technical Writer        │
│ /secure→ Security Auditor   │        │                          │        │ /verify → Test Engineer           │
└─────────────────────────────┘        └──────────────────────────┘        │ /deploy → Release Manager         │
        specs/ architecture/                  src/ tests/ reports/          └───────────────────────────────────┘
        plans/ security/                                                         security/ docker/ docs/ reports/
```

Mỗi mũi tên là một **quality gate**. Bạn không thể promote một build fail test, và không nên `/deploy` một artifact mà `/verify` chưa duyệt. (Các bước optional được đánh dấu trong tài liệu; security gate là blocking.)

---

## Bắt đầu nhanh (cách đơn giản nhất)

### 1. Đưa kit vào dự án của bạn

```bash
# Cách A — tạo dự án mới hoàn toàn từ kit này
git clone https://github.com/dinhnguyenngoc/spec-driven-claude-code.git my-new-project
cd my-new-project
rm -rf .git && git init        # biến nó thành của bạn

# Cách B — copy kit vào dự án có sẵn
cp -r path/to/spec-driven-claude-code/.claude  my-existing-project/.claude
```

Điều duy nhất quan trọng là thư mục **`.claude/`** phải nằm ở gốc dự án. Mở thư mục đó trong Claude Code (CLI, VS Code, hoặc JetBrains) là bạn đã sẵn sàng.

### 2. Nói cho nó biết bạn muốn xây gì

```text
/spec Tôi muốn xây LinkVault — một trình quản lý bookmark cá nhân, nơi user có thể
đăng ký, lưu bookmark (URL, title, tags), tìm kiếm, và đánh dấu favorite.
```

Agent **Business Analyst** sẽ hỏi các câu làm rõ, rồi viết `specs/SPEC.md` với User Stories và Acceptance Criteria. **Hãy đọc và duyệt** trước khi đi tiếp.

### 3. Đi hết pipeline

Chạy các lệnh theo thứ tự, đọc duyệt từng artifact trên đường đi:

```text
/arch      → thiết kế hệ thống, ADR, API contract   → architecture/
/plan      → chia task thành các vertical slice       → plans/todo.md
/secure    → STRIDE threat model (optional)           → security/
/build     → implement theo TDD                       → src/ + web/ + tests/
/test      → QA với dependency thật                   → tests/
/review    → code review năm trục                     → reports/
/scan      → quét lỗ hổng bảo mật                     → security/
/infra     → cấu hình Docker                          → docker/ + docker-compose.yml
/docs      → tài liệu                                 → docs/
/verify    → exercise trên artifact thật              → reports/VERIFY_REPORT.md
/deploy    → đưa artifact đã verify lên staging → STAGED (promote production = thủ công, RUNBOOK §8)
```

> **Đó là toàn bộ vòng lặp.** Để làm prototype nhanh, bạn chỉ cần `/spec → /plan → /build → /test`. Để lên production, đi đủ 12 bước.

### 4. Giữ to-do list trung thực

Mở [plans/todo.md](plans/todo.md) bất cứ lúc nào để xem việc đã xong (`- [x]`) và việc tiếp theo. Orchestrator chỉ tick task sau khi đã verify.

---

## Các lệnh (commands)

### Pipeline SDLC chính

| # | Lệnh | Agent | Làm gì | Output |
|---|------|-------|--------|--------|
| 1 | `/spec` | Business Analyst | User Stories & Acceptance Criteria **trước** khi code | `specs/` |
| 2 | `/arch` | Systems Architect | Kiến trúc, diagram, ADR, API contract | `architecture/` |
| 3 | `/plan` | Project Manager | Chia nhỏ thành task có thứ tự phụ thuộc | `plans/` |
| 4 | `/secure` ⃰ | Security Auditor | Threat model trước phát triển (STRIDE) | `security/PRE_DEV_REVIEW` |
| 5 | `/build` | Frontend/Backend Dev | Implement theo TDD, vertical slice | `src/`, `web/`, `tests/` |
| 6 | `/test` | Test Engineer | QA với dependency thật (TestContainers) | `tests/` |
| 7 | `/review` ⃰ | Code Reviewer | Review năm trục cho thay đổi | `reports/CODE_REVIEW` |
| 8 | `/scan` ⃰ | Security Auditor | Quét lỗ hổng sau phát triển | `security/SCAN_REPORT` |
| 9 | `/infra` | Backend Developer | Docker + docker-compose cho local dev | `docker/` |
| 10 | `/docs` ⃰ | Technical Writer | Getting-started, API, deployment docs | `docs/` |
| 11 | `/verify` ⃰ | Test Engineer | Exercise mọi feature trên artifact thật | `reports/VERIFY_REPORT` |
| 12 | `/deploy` | Release Manager | Đưa artifact đã verify lên staging — promote production là bước thủ công (RUNBOOK §8) | Staging (`STAGED`) |

<sub>⃰ = bước optional, nhưng **blocking nếu chạy** (security gate là không thể thương lượng).</sub>

**Tham số optional (để bạn biết mà dùng):**
- **`/spec`** — với sản phẩm có UI, **ASCII wireframes sinh mặc định**; thêm **`--prototype`** (hoặc nói *"kèm prototype"*) để sinh thêm clickable HTML prototype cho stakeholder click-through duyệt. Với **baseline brownfield REVERSE**, wireframe mặc định được miễn — thêm **`--wireframes`** để vẽ wireframe **as-is** từ UI đang chạy (chạy bổ sung được cả sau khi baseline đã duyệt).
- **`/arch`** — Rejection ADR (component stack cố ý loại trừ) mặc định gộp **một bảng**; thêm **`--adr=per-component`** (hoặc nói *"ADR riêng cho từng component"*) để mỗi component loại trừ là một ADR đầy đủ (vd audit/compliance).

### Lệnh hỗ trợ

| Lệnh | Mục đích |
|------|----------|
| `/discover` | **Onboard brownfield** — khảo sát codebase có sẵn, verify build/run, sinh Project Profile |
| `/discover-system` | **Multi-repo** — gom discovery per-repo thành bản đồ hệ thống (service catalog, call-graph, journey xuyên service); read-only, tài liệu một chiều |
| `/inspect` | **Hỏi hiện trạng** — trả lời "tính năng X có chưa / Y cấu hình ra sao?" bằng 3 tầng bằng chứng (records → code → live); read-only, không gate |
| `/debug` | Debug có hệ thống — tìm root cause, không vá triệu chứng |
| `/simplify` | Giảm độ phức tạp mà không đổi behavior |
| `/fix-issue` | Phân tích và sửa bug trong chu kỳ dev (kết thúc ở `/review`) |
| `/hotfix` | Khôi phục hệ thống **đang chạy** — triage rollback vs fix-forward, vá, re-verify, redeploy |
| `/export-docs` | **Xuất tài liệu chuẩn công ty** — biên dịch artifact kit (SPEC / ARCHITECTURE / reports) vào template PRD/SDD riêng của công ty bạn: fill-only, kèm trace map ID 2 chiều (`exports/`); template đặt ở `.claude/local/doc-templates/` |

---

## Các agent

Mỗi lệnh gọi một chuyên gia có playbook riêng (trong [.claude/agents/](.claude/agents/)):

| Agent | Chuyên môn |
|-------|-----------|
| 📊 **Business Analyst** | Requirements, user story, acceptance criteria |
| 🏗️ **Systems Architect** | Kiến trúc scalable, ADR, thiết kế API |
| 📋 **Project Manager** | Lập kế hoạch sprint, chia nhỏ task |
| 🔒 **Security Auditor** | Threat modeling (STRIDE), đánh giá lỗ hổng |
| 🔧 **Backend Developer** | ASP.NET Core, EF Core, SQL Server, Redis, REST |
| 🖥️ **Frontend Developer** | Next.js, React, TypeScript, UI hiện đại |
| 🎨 **UI/UX Designer** | Trải nghiệm trực quan, dễ tiếp cận |
| 🧪 **Test Engineer** | Chiến lược test, TDD, coverage, TestContainers, E2E |
| 👀 **Code Reviewer** | Review năm trục (Correctness, Readability, Architecture, Security, Performance) |
| 📝 **Technical Writer** | API reference, runbook, troubleshooting |
| 🚀 **Release Manager** | Build, staged rollout, versioning, release notes |

---

## Hai mode: Greenfield & Brownfield

Kit tự phát hiện bạn đang ở tình huống nào (khai trong [.claude/PROJECT_PROFILE.md](.claude/PROJECT_PROFILE.md), đối chiếu chéo với hiện trạng thật của repo):

| Mode | Khi nào | Bắt đầu thế nào |
|------|---------|-----------------|
| 🌱 **Greenfield** | Xây từ đầu, chưa có code | `/spec <ý tưởng>` → đi 12 bước |
| 🏚️ **Brownfield** | Đã có code legacy / đang chạy production | `/discover` trước → reverse-`/spec` → reverse-`/arch` → rồi lặp |

> 🧭 **Lần đầu dùng kit? Đi theo checklist từng bước cho đúng mode của bạn:** [getting-started-greenfield.md](getting-started-greenfield.md) · [getting-started-brownfield.md](getting-started-brownfield.md) (phân biệt Phase A onboard chạy-một-lần vs Phase B lặp-mỗi-tính-năng, và cách cài 1-repo vs nhiều-repo).

**Nguyên tắc xử lý brownfield** (kích hoạt tự động): viết characterization test trước khi đụng vào code legacy chưa có test, mặc định backward-compatible, bắt buộc ADR khi đổi kiến trúc, và dùng pattern strangler-fig khi nâng cấp. Xem [.claude/rules/brownfield.md](.claude/rules/brownfield.md).

---

## Những gì được áp đặt (rules)

Mọi dòng code tuân theo các **quy tắc bắt buộc** trong [.claude/rules/](.claude/rules/). Điểm nổi bật:

- **Clean Architecture** — `Api → Core ← Infrastructure`, không rò rỉ cross-layer
- **Clean Code & SOLID** — ≤3 tham số, method đơn nhiệm, không flag param, async đúng cách
- **TDD** — test fail trước, coverage ≥80% line / ≥75% branch
- **Security first** — không hardcode secret, parameterized query, kỷ luật JWT, kiểm OWASP
- **Lỗi RFC 7807**, quy ước REST, structured logging với correlation ID
- **Docker baseline** — multi-stage build, non-root user, health check, resource limit, image scanning

### Quality gate (không được bỏ qua các gate blocking)

```
/spec → /arch     PRD đã duyệt · mọi story có acceptance criteria
/arch → /plan     kiến trúc đã review · ADR đã ghi · API contract đã định
/build → /test    mọi unit test pass · code biên dịch được
/test → /review   coverage ≥ 80% · mọi test pass
/scan → /infra    không có lỗ hổng critical/high (nếu chạy /scan)
/infra → /docs    docker build được · compose up healthy
/verify → /deploy artifact đã test == artifact promote (nếu chạy /verify)
```

---

## Tùy biến cho stack của bạn

Kit mặc định dùng **stack** (C# 12 + ASP.NET Core 8 + EF Core 8 + SQL Server + Next.js). Để dùng công nghệ ngoại vi khác, sửa [.claude/PROJECT_PROFILE.md](.claude/PROJECT_PROFILE.md) (tầng CONFIG do bạn sở hữu — nâng cấp kit không đụng tới) và **override** tương ứng tự kích hoạt:

| Muốn dùng… | Khai báo trong Profile | File override |
|------------|------------------------|---------------|
| PostgreSQL / MySQL / Oracle / MongoDB | `Database: PostgreSQL` | [.claude/rules/overrides/database-*.md](.claude/rules/overrides/) |
| Backend Node.js (Express/NestJS/Fastify) | `Core: Node.js + …` | [.claude/rules/overrides/lang-nodejs.md](.claude/rules/overrides/) |
| Backend PHP (Laravel) | `Core: PHP + Laravel + …` | [.claude/rules/overrides/lang-php.md](.claude/rules/overrides/) |
| Observability ELK | `Observability: ELK` | [.claude/rules/overrides/monitoring-elk.md](.claude/rules/overrides/) |

Override chỉ thay phần dialect/backend-specific — mọi nguyên lý agnostic (parameterized query, structured logging, TDD…) giữ nguyên.

Profile cũng khai **`Output Language`** cho artifact (mặc định: `Vietnamese`) — đổi thành `English` (hoặc tên ngôn ngữ bất kỳ) thì mọi artifact + hội thoại theo ngôn ngữ đó; code, identifier và thuật ngữ kỹ thuật chuẩn luôn giữ English.

---

## Cấu trúc repository

```
.claude/
├── CLAUDE.md          # Bộ não — pipeline, gate, Project Profile, index rules
├── commands/          # 20 workflow slash-command (/spec, /arch, /build, …)
├── agents/            # 11 playbook agent chuyên biệt
├── rules/             # 17 quy tắc kỹ thuật bắt buộc
│   └── overrides/     # 11 override theo stack (Postgres, Node.js, PHP/Laravel, ELK, …)
├── skills/            # Kỹ thuật tái dùng (tdd, code-review, …)
├── references/        # 10 reference/checklist (security, testing, docker, a11y, multi-repo, …)
├── templates/         # template fill-only: STRIDE · OWASP · TEST_REPORT · VERIFY_REPORT · CODE_REVIEW · RUNBOOK_RELEASE · wireframes · system (/discover-system) · export-docs (schema mapping-manifest)
├── hooks/             # Lifecycle hook (thống kê lệnh)
└── scripts/           # Scanner bảo mật (dotnet, nodejs, python, php, docker) + export DB schema

# Sinh ra trong quá trình làm việc:
specs/  architecture/  plans/  security/  src/  web/  tests/  reports/  docker/  docs/  exports/
```

> 📖 Nguồn chân lý duy nhất cho toàn bộ workflow là [.claude/CLAUDE.md](.claude/CLAUDE.md) — bắt đầu từ đó nếu bạn muốn tìm hiểu sâu.

---

## Ví dụ thực tế: LinkVault

Kit đi kèm một bản brief mẫu, [README1.txt](README1.txt), cho **LinkVault** — trình quản lý bookmark cá nhân (auth, CRUD bookmark, tags, search, web UI đơn giản). Đây là lần chạy đầu tiên hoàn hảo:

```text
/spec        # dán requirements LinkVault từ README1.txt
/arch        # thiết kế solution Clean Architecture + API
/plan        # chia thành các slice xây được
/build       # implement, test trước
/test        # chứng minh với dependency thật
```

Đến cuối bạn sẽ có một app ASP.NET Core + Next.js chạy được, có test, có tài liệu — và cảm nhận được cách cả pipeline vận hành.

---

## Câu hỏi thường gặp (FAQ)

**Có bắt buộc chạy đủ 12 bước không?**
Không. Các bước bắt buộc là `/spec`, `/arch`, `/plan`, `/build`, `/test`, `/infra`, `/deploy`. Phần còn lại (`/secure`, `/review`, `/scan`, `/docs`, `/verify`) là optional — nhưng nếu chạy thì gate của chúng là blocking. Với production, rất khuyến nghị chạy tất cả.

**Có dùng được cho ngôn ngữ khác C# không?**
Có — kit hiện đã có override Node.js / TypeScript và PHP / Laravel, và kiến trúc được thiết kế để công nghệ ngoại vi (DB, observability) đổi qua Project Profile.

**Artifact sinh ra bằng ngôn ngữ gì?**
Theo field `Output Language` khai trong [.claude/PROJECT_PROFILE.md](.claude/PROJECT_PROFILE.md) — mặc định `Vietnamese`; đổi 1 dòng thành `English` hay ngôn ngữ khác đều được. Code, identifier và thuật ngữ kỹ thuật chuẩn luôn giữ English.

**Đổi model mặc định hoặc behavior ở đâu?**
[.claude/settings.json](.claude/settings.json) (model, permission mode, hooks).

**Khác nhau giữa `/fix-issue` và `/hotfix`?**
`/fix-issue` sửa code trong chu kỳ dev (chưa release). `/hotfix` khôi phục thứ **đang chạy live** — bổ sung triage rollback, re-verify, và runbook sự cố.

---

## License

Dự án này được cấp phép theo **MIT License** — xem file [LICENSE](LICENSE) để biết chi tiết.

Triết lý workflow lấy cảm hứng từ [BMAD-METHOD](https://github.com/bmad-code-org/BMAD-METHOD).
