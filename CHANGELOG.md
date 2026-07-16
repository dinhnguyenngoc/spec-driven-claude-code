# Changelog

Toàn bộ thay đổi đáng chú ý của **AI SDLC Kit** được ghi tại đây. Định dạng theo
[Keep a Changelog](https://keepachangelog.com/); phiên bản theo [SemVer](https://semver.org/).
Các phiên bản trước `v1.3.0` (`v1.0.0`, `v1.1.0`, `v1.2.0`) được đánh dấu bằng git tag tương ứng.

## [1.4.0] — 2026-07-16

> Bản này là **đợt audit gia cố toàn kit — 19/19 lệnh**: mọi Quality Gate giờ có lớp kiểm
> độc lập của orchestrator (không tin báo cáo sub-agent), mọi sub-agent có đường escalation
> thay vì tự quyết/tự ký, đường override stack (Node core / 5 DB / ELK) thông suốt từ lệnh
> tới agent, và hoàn tất các đồng bộ STAGING-only còn sót từ v1.3.0. Không xoá nội dung nào —
> thuần bổ sung và chính-xác-hoá.

### Added
- **Orchestrator disk-check cho mọi gate** — 12 lệnh ngoài danh sách §Verification After
  Delegation nhận block kiểm bất biến cơ học riêng (so tập hợp scenario/RC/OPEN, Evidence
  không rỗng, score-honesty, template residue, `git status` read-only…); 7 lệnh trong danh
  sách nhận pointer "orchestrator tự chạy lại lệnh quyết định gate".
- **Phase ownership / return-early cho mọi lệnh** — sub-agent không với tới user: waiver,
  stakeholder ack, Security-Lead/QA sign-off, `ACK_NO_SCAN`, chọn license, quyết định chạm
  production… → **return early**, orchestrator lấy quyết định ở main loop.
- **`architecture/design-system.md`** — điểm đáp mới cho design system (`/arch` §2.6):
  tokens + state-per-component matrix + component contracts; khép chuỗi `/spec` wireframes
  → `/arch` design system → `/build` FE.
- **Join-key mới có producer thật** — `OPEN-###` (TEST_REPORT §12 → `/review` disposition)
  và `Service id` (Profile ← `/discover` → `/discover-system`).
- **`ascii-diagram-guide.md` §8 UI Wireframe** — mẫu vẽ màn hình + bảng control conventions
  cho `/spec` Phase 2.5.
- **`A-xx` disposition trên `/fix-issue`** — assumption phải được user duyệt → AC amendment
  + Revision History; không quyết định behavior nào sống chỉ trong commit body.

### Changed
- **Join-key thống nhất**: `RC-X.Y` → **`RC-N`** (10 chỗ/7 file) · `T-XX` → **`Task N.N`**
  (7 chỗ/4 file) — producer định nghĩa, consumer theo.
- **Stack Profile note viết lại trên build/test/infra/deploy/docs/debug/simplify/fix-issue**
  + blockquote override cho 5 agent — diệt trọn họ khẳng định sai *"core/test stack does not
  change"*; Node core giờ có đường ánh xạ lệnh (npm/prisma/jest) ở mọi tầng.
- **Brownfield scoping**: `/verify` Phase-5 đòi 100% theo **change-set** (baseline tích lũy,
  B4 = scoped minimum) · REVERSE **miễn wireframe + visual sign-off** (per-change cho màn
  hình bị chạm) · delta-coverage + ratchet đồng bộ 5 điểm còn thiếu.
- **`/plan` Prerequisites**: architecture chuyển từ Optional → Required (greenfield Gate 2 /
  brownfield conformance verdict 1-câu-hỏi); spec phải `Status: Approved` (cả `/arch`).
- **`/test` E2E transport theo vị trí pipeline** — greenfield trước `/infra` chạy Playwright
  trên stack local + TestContainers; compose overlay do Test Engineer author khi thiếu.

### Hardened
- **Chặn fabricated sign-off** — sub-agent tự điền bảng Approval/ack/waiver bị gọi tên và
  cấm tường minh ở `/secure`, `/scan`, `/verify`, `/deploy`.
- **BLOCKING-if-run thực thi tại consumer** — `/build` kiểm Gate 4 APPROVED, `/infra` kiểm
  Gate 8 green, `/deploy` ghi chú `/review`-if-run; `RR-N` coverage nâng SHOULD → MUST.
- **Read-only guarantee kiểm bằng `git` thật** — `/discover`, `/discover-system` (mọi repo
  sạch), `/simplify` (diff đúng scope + green-before/after).
- **`/hotfix` ranh giới production** — rollback production do human operator thực hiện (kit
  đưa procedure + digest); chặn false-recovery "rollback staging nhưng báo đã khôi phục".

### Fixed
- Di tích tiền-v1.3.0: release-manager (prod-server, canary tự động, đếm 7/5 section),
  technical-writer ("no staging tier"), hotfix ("on live"), README×2 (`/deploy → Production`),
  VERIFY template ("production-config").
- Dangling refs & nits: `UI_DESIGN_SYSTEM.md` → `architecture/design-system.md` · typo
  `ai↔ai` → `api↔api` · link ví dụ ADR sai convention · comment `data-us` lệch cơ chế ·
  near-miss "fix the id" mâu thuẫn read-only ở `/discover-system` · sót tiếng Việt trong
  heading `/scan`.
- Mặt tiền: README×2 + quick-start bổ sung `/inspect` (thiếu từ v1.3.0), đếm đúng 19 lệnh;
  `/inspect` phủ split-layout (`specs/user-stories/*`).

### ⚠️ Upgrade notes (behavior changes)
- **Mọi gate giờ yêu cầu disk-check của orchestrator PASS trước khi present** — flow tự động
  cũ trình gate thẳng từ báo cáo sub-agent sẽ dừng sớm hơn (đúng thiết kế).
- **Brownfield `/verify` không còn fail trên baseline chưa phủ** — Phase-5 scope theo
  change-set; script coverage nạp tập scenario theo Mode.
- **`/plan` từ chối chạy khi thiếu `architecture/`** hoặc spec còn `Draft`.
- Tooling grep token cũ (`RC-X.Y`, `T-XX`) phải đổi sang `RC-N` / `Task N.N`;
  Profile có field optional mới `Service id` (multi-repo).

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
