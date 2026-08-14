# Changelog

Toàn bộ thay đổi đáng chú ý của **AI SDLC Kit** được ghi tại đây. Định dạng theo
[Keep a Changelog](https://keepachangelog.com/); phiên bản theo [SemVer](https://semver.org/).
Các phiên bản trước `v1.3.0` (`v1.0.0`, `v1.1.0`, `v1.2.0`) được đánh dấu bằng git tag tương ứng.

## [1.6.0] — 2026-08-13

> Bản này gồm 5 nhóm thay đổi: **(1) Output Language cấu hình được** — ngôn ngữ artifact
> không còn fix cứng tiếng Việt mà khai trong `PROJECT_PROFILE.md` (thiếu field → mặc định
> Vietnamese, backward-compat tuyệt đối); **(2) `/spec` bổ sung 3 thành phần nghiệp vụ**
> (bảng Goals & Success Metrics 2 cấp, Ma trận phân quyền, class tag ✅❌⚠️ cho scenario);
> **(3) lệnh mới `/export-docs`** — biên dịch artifact của kit thành tài liệu chuẩn công ty
> (PRD/SDD…) theo template fill-only + mapping manifest ở tầng EXTENSION (toàn bộ đã
> sandbox-verify: 5 kịch bản /spec + 4 kịch bản /export-docs, có negative control);
> **(4) bộ override PHP / Laravel đủ bộ** (lang + framework + test, kèm scanner
> `scanners/php.sh`) — stack thứ 3 sau C# và Node.js; **(5) gia cố toàn kit qua 3 vòng
> audit 20/20 lệnh** (vòng 1–2 vá lỗi đúng-sai + khép chuỗi khóa NFR, vòng 3 rà
> "vai trò + phụ thuộc + tối ưu" per-command — chi tiết các mục Audit bên dưới).

### Added
- **`Output Language` — field CONFIG mới trong Project Profile** — giá trị = tên tiếng Anh
  của ngôn ngữ (`Vietnamese`, `English`, `Japanese`…); prose/artifact/hội thoại theo ngôn
  ngữ khai, code + identifier luôn English; `English` → mọi thứ English. **Thiếu field →
  mặc định Vietnamese** (repo cấu hình trước khi field ra đời không bị lật ngôn ngữ giữa
  dự án). Workspace: 1 sản phẩm = 1 ngôn ngữ — `/discover` hỏi 1 lần, ghi đồng nhất root +
  mọi repo con.
- **`/spec` + BA agent — 3 thành phần mới trong SPEC** (input trực tiếp cho PRD công ty):
  §Goals & Success Metrics (Business/Product + KPI/baseline/timeframe — tách bạch với NFR
  gate-đo-được); §Permission Matrix (role × action, 🔒 ownership kèm footnote; REVERSE
  derive từ bằng chứng authz, endpoint thiếu authz → `⚠️ no authz observed`); **class tag
  bắt buộc** `@happy`/`@negative`/`@edge` cạnh mỗi `@US-XXX-Snn` (mỗi story ≥ 1 `@happy`,
  story chỉ-có-happy phải ghi 1 dòng lý do). Gate 1 disk-check thêm 3 check máy-kiểm-được,
  **scope theo change-set** — SPEC cũ không false-fail, DELTA không retag story legacy.
- **Lệnh mới `/export-docs <target>`** — render artifact kit thành tài liệu chuẩn công ty:
  fill-only (cấm bịa, thiếu nguồn → `N/A + lý do` hoặc marker `[CẦN <role/lệnh>]`),
  source-comment từng section, cấm tự ký sign-off; PRD đòi SPEC `Status: Approved`
  (`--draft` → watermark); **transform ID 1:1 ổn định** `@US-XXX-Snn → AC-{us}.{Snn}.01`
  (class tag → ✅❌⚠️, append-only vĩnh viễn qua `exports/TRACE_MAP.md` — refresh không đổi
  ID); FR = Epic, đánh số lần đầu rồi bất biến; gate export: heading census, residue,
  **cross-ref nội bộ phải resolve**, TRACE_MAP 2 chiều đủ, diagram fidelity 1:1. Engine +
  schema = CORE; template công ty đặt `.claude/local/doc-templates/` (EXTENSION — kèm
  manifest ISC PRD 14 hàng + SDD 19 hàng cho nội bộ, đã gitignore khỏi repo public).
- **`.claude/templates/export-docs/MAPPING_MANIFEST.md`** — schema manifest + enum
  transform/on-missing để user ngoài tự khai template công ty của họ.
- **`/spec --wireframes` — wireframe as-is cho brownfield REVERSE (opt-in)** — mặc định
  REVERSE vẫn miễn wireframe; cờ này (hoặc "kèm wireframe") vẽ wireframe **as-is** từ bằng
  chứng code (state thiếu → `⚠️ not observed`, cấm beautify; visual sign-off vẫn waived),
  chạy được ngay trong lần REVERSE hoặc **post-hoc** trên baseline đã Approved
  (documentation supplement — không thêm Revision History row, chỉ pointer-swap UI/UX
  Notes). `--prototype` bị từ chối trong REVERSE (app đang chạy là click-through truth).
  UI/UX Designer thêm §REVERSE Mode; manifest ISC sửa lý do On-missing cho khớp.
- **`/spec --propose-goals` — đề xuất goals có nhãn cho brownfield REVERSE (opt-in)** —
  repo không có evidence mục tiêu → orchestrator HỎI (không tự quyết): để `N/A` hay để BA
  **suy diễn có nhãn** lớp business-intent (Goals, Business Need, Expected Outcomes,
  Impact if Not Done) từ hành vi sản phẩm quan sát được. Kỷ luật chống bịa: nhãn chuẩn
  `📝P-nn` + căn cứ suy diễn bắt buộc · **chỉ định tính — mọi con số (KPI/baseline/
  timeframe) = `[CẦN PO]`** · pairing 1:1 với Open Questions (disk-check máy kiểm) ·
  PO xác nhận mới gỡ nhãn (row `Amended`); `/export-docs` mang nhãn theo nguyên vẹn,
  không bao giờ promote đề xuất thành fact. BA agent thêm §Proposed Content.
- **`/spec` guard mới "No transport-only stories" + user-perspective trong REVERSE** —
  disk-check Gate 1 thêm check máy: story của sản phẩm UI mà mọi scenario đều phrasing
  transport (`POST /…`, HTTP status) → FAIL; REVERSE notes ghi rõ trích behavior từ code
  nhưng diễn đạt theo người dùng, evidence `file:line` → HTML comment/Appendix. Đóng đúng
  lỗ hổng semantic đã lọt qua Gate 1 trong thực chiến (SPEC LinkVault v1.0).
- **`/export-docs` — Audience register** — manifest khai `Audience: stakeholder | engineer`
  per target: PRD (stakeholder) dịch identifier kỹ thuật sang ngôn ngữ nghiệp vụ (API path
  → hành động, tên cột → khái niệm; class/method không bao giờ mang theo), SDD (engineer)
  giữ nguyên; số/threshold render ở cả hai. Gate export liệt kê thêm danh sách nhãn `📝P-nn`.

- **Stack PHP + Laravel — bộ override thứ 3 đủ bộ** — `rules/overrides/lang-php.md`
  (PHP 8.2+/Composer/PSR-12 Pint/strict_types; PHPStan/Larastan baseline + ratchet cho
  brownfield) + `framework-php-laravel.md` (Controller mỏng → Service/Action, FormRequest,
  RFC 7807 qua exception handler — greenfield align 400, **brownfield giữ 422 as-is**;
  Sanctum + rate-limit budget kit; Eloquent N+1/soft-delete/audit/optimistic-concurrency;
  Monolog JSON + correlation-id; Docker php-fpm/FrankenPHP đủ 20 must-haves; §Frontend
  Blade/Livewire/Inertia định vị ngắn) + `test-php.md` (**Pest khuyến nghị mặc định,
  brownfield GIỮ PHPUnit — không ép migrate**; template A SQLite in-memory //build,
  template B MySQL/Postgres container thật //test; `.env.testing` host-isolation; PCOV
  80/75 + delta/ratchet). Wiring: bảng overrides tech-stack + template Profile + tín hiệu
  `composer.json`/`artisan` ở `/discover`+`/spec` + canonical command `php artisan test` +
  scanner `scanners/php.sh` (composer audit prod-block/dev-advisory, PHPStan, Semgrep p/php
  diff-scoped, dangerous-grep PHP/Blade). Legacy giữ nguyên stack — override chỉ ghi khác
  biệt, nguyên tắc agnostic không đổi.

### Changed
- **`CLAUDE.md` §Output Language + §Output Clarity** — tổng quát hoá theo field mới và
  chuyển sang English (hoàn tất chuẩn "kit source = English"; 2 section này là ngoại lệ
  cuối cùng còn tiếng Việt).
- **19 command** — chỉ thị ngôn ngữ trong prompt spawn sub-agent đổi từ literal
  `Vietnamese` → resolve từ `Project Profile → Output Language`.
- **`/discover`** — Phase 0 (workspace) hỏi Output Language 1 lần ghi mọi profile; Phase 4
  hỏi khi sinh profile (đề xuất mặc định = ngôn ngữ user đang chat); gate + disk-check
  kiểm field.
- **`/spec` gate** — disk-check dùng **anchor trung lập ngôn ngữ** (dòng `| G-`, marker
  ✅/🔒/—) thay vì grep heading tiếng Anh — heading artifact render theo Output Language.
- **`PROJECT_PROFILE.md` (template)** — thêm field `Output Language` + hàng bảng giá trị
  hợp lệ; `rules/output-style.md` cập nhật chú thích tương ứng.
- **`/arch` Phase 3** — thêm khuyến nghị (non-gate) khai `example` cho schema
  request/response trong `openapi.yaml` — Swagger UI hiển thị được và `/export-docs` carry
  sample **verbatim** thay vì construct giá trị minh họa (`export-docs.md` §API sample
  derivation).
- **`/arch` §2.5 — Flow Disposition (mandatory)** — liệt kê ứng viên sequence-diagram bằng
  3 nguồn máy-móc (spec flows · external dependency trong container diagram · REVERSE:
  failure-semantics path từ `CODEBASE_MAP.md`), mỗi ứng viên 1 hàng disposition trong
  `ARCHITECTURE.md` (vẽ hoặc `Waived + lý do`); Gate 2 + disk-check thêm 2 item máy-kiểm.
  Đóng lớp lỗi "có tiêu chí, thiếu check độ phủ" — flow phức tạp nhất bị bỏ sót im lặng
  (ca thật: bookmark-create + title auto-fetch, SSRF surface, không được vẽ dù thỏa §2.5).
- **`/infra` + `/deploy` — gate item "As-is refresh (KB sync)"** — hạ tầng/deploy đổi trạng
  thái thực thi xong phải quét `architecture/` (trừ `adr/` — hồ sơ quyết định, đi đường
  supersede) theo tên lệnh backtick: viết lại as-is statement vừa hết đúng (kèm ghi chú ngày),
  resolve OQ row thuộc lệnh; check máy `pre-`/<cmd>`` = 0. Phía ghi: `/arch` REVERSE bắt buộc
  marker máy-đọc cho as-is claim có tính thời điểm; CONFORMANCE-GATE refresh chú thích
  "planned" khi change thực hiện ADR đã chốt. Đóng lớp staleness "KB đúng hành vi nhưng cũ
  trạng thái thực thi" (phát hiện khi rà KB-sync 2026-07-27).
- **`/infra` + `/deploy` — hợp đồng trình bày sau gate** — `/infra` Gate 9 PASS: **để stack
  chạy tiếp** + orchestrator PHẢI trình bảng Service & URL (đọc từ `docker compose ps` thật
  + port mapping trong compose, không đọc từ trí nhớ) kèm khối lệnh vận hành nhanh; `/deploy`
  tuyên bố `STAGED` PHẢI kèm **service board sống** (Image:tag, State, host port, URL đã
  smoke kèm HTTP status thật) — data vốn đã có ở Exit-Criteria re-run, giờ bắt buộc hiển thị
  cho user thay vì chỉ nằm trong RUNBOOK.
- **`/test` + `/verify` — Results board + failure capture chuẩn hóa** — sau Gate 6/Gate 11,
  orchestrator PHẢI trình bảng thống kê đọc từ output thật của lần re-run (suite ×
  pass/fail/skip/duration, 3 số coverage, `n/m` AC scenario; verify thêm NFR-vs-threshold)
  + bảng failed-case `Test | @US-Snn | Input/data | Expected → Actual | Evidence | BUG-###`;
  `/test` có root artifact cố định `reports/test-artifacts/` (4 luật determinism của
  `verify.md` §Phase 6 áp verbatim, capture `retain-on-failure`, `.gitignore` kèm theo);
  template TEST_REPORT §1 + VERIFY_REPORT §3 bổ sung field input/data + expected→actual.
  Drill-down = HTML report native (Playwright / reportgenerator) — không chế dashboard riêng.
- **`/plan` — §Impact Analysis bắt buộc (bức tranh tổng thể trước khi build)** — Phase 1
  phải ghi kết quả survey thành section thứ 2 của plan.md: dòng blast radius + bảng
  change-item → component/endpoint/data/screen ảnh hưởng (mọi ô có evidence từ
  CODEBASE_MAP/component-diagram/openapi), cột Risk nối vào kỷ luật sẵn có
  (characterization, widen STRIDE, backward-compat AC); Gate 3 trình Impact Analysis
  TRƯỚC task breakdown + 2 check mới (evidence-based, reconcile surface↔task);
  `/review` thêm input "diff changed-files vs blast radius đã khai" (bắt scope-creep).
  Áp mọi mode — greenfield first-pass = bản đồ thành-phần-sẽ-tạo.
- **`/discover` — External-Structure Inventory (tổng quát hóa mô hình DB-object)** — endpoint
  inventory phủ cả message consumer / scheduled job / CLI (REVERSE: actor = hệ upstream);
  2 inventory conditional mới: Messaging (topic → chiều → schema class `file:line` → group)
  + Cache-structure (key pattern → kiểu → TTL → ai ghi/đọc); red-flag mới `Message schema
  not in repo` / `External structure not in repo` / `Caller not in repo`; luật blind-spot
  CÓ ĐIỀU KIỆN: config phía hạ tầng (partition/retention/eviction/crontab) không thu thập
  từ hệ sống — chỉ thành red-flag/OQ khi ngữ nghĩa hành vi phụ thuộc (giả định ordering/
  replay, Redis-như-durable-store); remedy = người export snapshot vào repo, đúng kỷ luật
  stored-proc. `/spec` REVERSE (consumer story) + `/arch` REVERSE (Integration Contracts)
  + `brownfield.md` checklist nối theo. Evidence = repo-only, kit không bao giờ tự kết nối.
- **Cô lập hạ tầng thật — 3 lớp lưới máy-kiểm** — `/discover`: **pre-flight** đọc config
  test legacy TRƯỚC khi chạy suite (host ngoài loopback/container → không chạy + finding
  "suite not run — shared infra"; cấm "sửa" bằng placeholder làm hỏng số đo) + red-flag
  mới `Config source outside repo` (Registry/ODBC/machine.config/vault — giá trị là điểm
  mù có tên); `/test` Gate 6: **connection tripwire theo WHITELIST** — grep toàn bộ log
  lần re-run, host ngoài whitelist (loopback/compose-service/TestContainers) = FAIL —
  bắt được cả nguồn không khai báo trước được (hosted service sót, hardcode trong method,
  giá trị đọc từ Registry) + strict-mode network-isolated runner làm v2-trigger;
  `/infra` Gate 9 + `/deploy` pre-check: **compose self-containment** — endpoint lớp hạ
  tầng resolve về service trong compose + mọi connection-key nướng trong image có env
  override (chặn fallback âm thầm về config thật). `testing.md` §host-isolation: hợp đồng
  được chứng minh bằng tripwire, không chỉ bằng kỷ luật.
- **System layer đủ 2 nửa + export cấp hệ** — `/discover-system` sinh thêm `specs/system/`
  (4 view PROJECTION: requirements-map · goals-catalog · glossary-system · nfr-catalog —
  reference-first, banner GENERATED, regenerate-only, per-repo luôn thắng) + 4 check
  xuyên-repo tầng YÊU CẦU (`⚠️ term conflict` / `goal overlap` / `NFR inconsistency` /
  staleness theo SPEC version) — bổ khuyết cho tầng contract sẵn có; requirements-drift
  vào chung drift-check. `/export-docs` thêm **`Scope: system`**: chạy tại workspace root,
  nguồn = `specs/system/` + `architecture/system/`, precondition **system layer FRESH**
  (STOP khi drift), ID per-repo **qualified theo Service id** (`AC-{svc}.{us}.{n}`) chống
  đụng độ 23 repo, TRACE_MAP root riêng. Workspace disk-check exception mở cho
  `specs/system/` + `exports/` ở root; `/spec` Gate 1 (workspace) nudge staleness sau
  sign-off. Local: clone 2 template `ISC_SYSTEM_PRD/SDD` + 2 target manifest. Re-sync
  **incremental**: Phase 0 change-detection bằng bash (so version-stamp `last-synced` vs
  SPEC version + hash §Service Contracts, ~0 token) → chỉ đọc lại repo `CHANGED`,
  carry-forward repo `UNCHANGED` từ view (đúng ngữ nghĩa projection), join xuyên-repo tính
  lại trên dữ liệu ghép; full-regenerate bắt buộc khi lần đầu / registry đổi / `--full` /
  view mất banner — disk-check tự grep version repo UNCHANGED, không tin báo cáo.
- **Connection inventory + guided schema export (paved road, không phá never-connect)** —
  `/discover` thêm **Connection inventory** (1 hàng/connection: engine · host/db · nguồn
  `file:line` · dùng bởi · status `resolved`/`placeholder`/`outside repo`, **credential luôn
  mask**) — một danh sách, ba nơi tiêu thụ: người dùng duyệt export · tripwire `/test` lấy
  làm nguồn known-host · self-containment `/infra`+`/deploy` lấy làm danh sách key phải
  override (trước đây mỗi gate tự parse). **Phase 1b — guided schema export**: chỉ chạy khi
  có blind spot DDL; kit liệt kê → **user duyệt TỪNG connection** (mặc định NO, hàng nghi
  production phải nói rõ môi trường) → script `scripts/export-db-schema.sh` đọc connection
  **từ file config** (secret không bao giờ lên CLI/chat/log — password truyền qua env var
  `SQLCMDPASSWORD`/`MYSQL_PWD`/`PGPASSWORD`), dump **schema-only, zero data row** → commit
  snapshot kèm banner provenance → evidence trở lại repo-resident. Duyệt chỉ có hiệu lực cho
  **đúng lần export đó**, không thành ngoại lệ thường trực. `/spec` REVERSE thêm guard: app
  data-centric mà repo không có bằng chứng schema → surface + chỉ đường, không spec mù.
  Engine: SQL Server · MySQL · PostgreSQL · **Oracle** (`DBMS_METADATA.GET_DDL` ra DDL text
  phía client — không dùng Data Pump vì `.dmp` là binary nằm trên máy chủ DB; connect string
  đi qua **stdin** của `sqlplus`, không lên argv; `--owner` cho schema khác user; **lọc
  `generated='N'` + tách 3 statement** — bug tìm được khi test thật: sequence hệ thống của
  cột IDENTITY làm `DBMS_METADATA` ném `ORA-31603`, abort cả câu SELECT, snapshot mất sạch
  table/view/package) · **MongoDB** (`getCollectionInfos()` +
  `getIndexes()`, zero document, kèm `BEHAVIOR-CRITICAL.md` liệt kê **TTL index** (dữ liệu
  tự biến mất) · **unique index** (409 duplicate-key) · **validator** · **view** — các hành
  vi vô hình khi đọc code; `/discover` detect theo tín hiệu Mongo `createIndex`/
  `expireAfterSeconds`/`$jsonSchema`/`createView`; Atlas Triggers/Functions/Search nằm
  ngoài database → red-flag + hướng dẫn `appservices pull` export tay). `database-mongodb.md`
  thêm §H.1 Reverse-engineering blind spots; `database-oracle.md` thêm mục
  Reverse-engineering (PL/SQL trong DB). Disk-check thêm check **no-credential-leaked** trên
  mọi artifact sinh ra.
- **Chính sách MCP cho database: ĐÁNH GIÁ RỒI LOẠI (quyết định dựa trên đo đạc, 2026-08-07)**
  — luật never-connect ghi rõ **áp cả khi phiên có sẵn MCP database tool**: output nằm trong
  hội thoại chứ không trong repo → **không được làm nguồn nội dung SPEC/ARCH**; và kit
  **không dùng MCP làm đường export**, không có nấc MCP trong transport ladder. Lý do đo được:
  ① **an toàn không được bảo đảm và trôi giữa các bản** — DBHub 1.2.0 đã **bỏ cờ `--readonly`**,
  mặc định phơi `execute_sql` toàn quyền ghi (chứng minh trên DB throwaway: `CREATE TABLE` rồi
  `DROP TABLE` đều thành công), trong khi MongoDB MCP v2.0.0 vẫn lọc write dưới `--readOnly`
  → bảo đảm phụ thuộc "đang cài server nào, bản nào"; ② **fidelity chỉ là tên, không phải DDL**
  — `search_objects` trả `{"name":"users","schema":"public"}` trong khi `pg_dump` trả
  `CREATE TABLE …` chạy lại được; `collection-indexes` lỗi ngoài Atlas nên tầng TTL/unique
  không về; ③ **độ phủ không đều** — DBHub có Postgres/MySQL/SQL Server/SQLite/MariaDB nhưng
  **không có Oracle và MongoDB**. Hết thang bậc → **ghi nhận điểm mù** (giữ red-flag), KHÔNG
  hạ chuẩn bằng công cụ kém tin cậy. `/inspect --live` probe bằng client của chính engine
  (local hoặc container); ai vẫn muốn dùng MCP thì **bảo đảm duy nhất là tài khoản DB chỉ
  `SELECT`**, không phải cờ read-only của server.
- **Phase 1b — Transport ladder (thứ tự bắt buộc khi kết nối/xuất schema gặp trở ngại)** —
  ① CLI trên máy → ② **CLI chạy trong container** (`docker run --rm --network …` hoặc
  `docker exec <db-container>`; **fidelity đầy đủ, không đụng gì vào máy** — đã kiểm chứng:
  xuất trọn 3 engine với zero client cài local) → ③ phương án cùng fidelity của engine
  (`sqlcmd` thay `mssql-scripter`, chạy client đúng docker network). Ba bước này **không hỏi
  user**. Hết cách → **MỘT** thông báo kèm nguyên nhân + 3 lựa chọn: (a) **kit tự cài CLI sau
  khi user duyệt lệnh hiển thị nguyên văn** (ngoại lệ có kiểm soát của §Boundary: chỉ package
  manager, cấm `curl | sh`/sudo-pipe/sửa PATH, mặc định NO, ghi vào health snapshot vì máy đã
  đổi, cài lỗi thì KHÔNG leo thang quyền) · (b) export ở nơi khác có sẵn client (jump host,
  máy chủ DB, CI, DBA) rồi commit file — vẫn cùng fidelity · (c) bỏ qua → giữ red-flag,
  **kết thúc đúng của thang bậc là ghi nhận điểm mù, không phải hạ chuẩn công cụ**. **Trở ngại KHÔNG bao giờ được tự "khắc phục"**: sai auth/thiếu
  quyền → STOP (retry = khoá tài khoản thật: Oracle `FAILED_LOGIN_ATTEMPTS`, SQL Server,
  rate-limited auth), thiếu privilege → xin grant read-only, mạng/firewall → báo, không sửa
  môi trường.
- **`/spec --scope` — Scoped REVERSE (dựng baseline theo lát cắt)** — hệ legacy 500 endpoint
  không thể reverse một lần, và việc tiếp quản/port thường chỉ cần một phần: `--scope` nhận
  selector (route · handler · `module:Name`, phân tách bằng dấu phẩy) **khớp trên endpoint
  inventory** của `CODEBASE_MAP.md` — không khớp gì / khớp tất cả → **STOP** kèm danh sách đã
  khớp. Chống đúng cạm bẫy cốt lõi (**SPEC phiến diện trông y hệt SPEC đầy đủ** → Phase 0 lần
  sau kết luận DELTA và phần còn lại của repo vĩnh viễn không được spec): SPEC **tự khai độ
  phủ** — header `Coverage: full | partial (scoped)` + section mới **§Scope & Coverage** liệt
  kê entry point đã phủ VÀ **chưa phủ** (cả hai **suy ra từ inventory**, hợp của chúng phải
  bằng đúng inventory — Gate 1 + disk-check kiểm máy). Chạy `--scope` lần nữa = **mở rộng độ
  phủ** (append-only, Revision History `Added — coverage extended: …`), không viết lại phần
  đã có; red-flag ngoài scope vẫn được liệt kê là *known, not yet specced*; phủ đủ 100% →
  lật `Coverage: full`. Phase 0 thêm nhánh: change chạm vùng **chưa phủ** → **STOP**, bắt
  reverse vùng đó trước (DELTA lên spec chưa từng mô tả = đoán, không phải delta).
- **Thay đổi database trong brownfield — 3 luật còn thiếu** — `rules/database.md` thêm
  **§Expand-contract** (hệ đang chạy có old code + new code cùng sống → schema change là
  chuỗi 4 pha Expand → Backfill → Switch → Contract; **cấm một bước**: RENAME/DROP COLUMN,
  thêm `NOT NULL` không default, thu hẹp kiểu, thêm unique index lên cột đang trùng — muốn
  làm phải có ADR + cửa sổ downtime) + **§DB-resident objects are source code** (proc/trigger/
  function/view: mọi thay đổi phải là **migration script versioned trong repo**; **cấm sửa
  thẳng trong DB rồi export ngược** — export chỉ để dựng baseline lần đầu, không phải kênh
  thay đổi; repo là source of truth, DB là deployment target). `rules/brownfield.md` thêm
  checklist item: change đổi schema/DB-object → migration trong repo + **refresh
  `db/schema-snapshot/` NGAY TRONG cùng change-set** (re-export từ TestContainer của `/test`
  sau khi migration đã apply — chính là target state, không chạm DB thật) + expand-contract.
  `/review` thêm input **Schema-evidence freshness**: diff có migration đổi schema mà snapshot
  không đổi → 🟡 finding; ngược lại snapshot đổi mà không có migration → dấu hiệu ai đó sửa
  tay trong DB. Đóng lớp lỗi "bằng chứng schema mục ngay sau change đầu tiên".
- **Multi-stack trong 1 repo — luật khai báo tường minh** — `/discover` Phase 4 + template
  Profile (CLAUDE.md): repo có >1 backend stack → `Core:` khai TẤT CẢ kèm scope path
  (chủ đạo trước), mỗi stack kích hoạt bộ override cho vùng của nó — cấm chọn-một-bỏ-một
  (silent-drop nửa codebase khỏi mọi gate downstream; các tầng dưới — endpoint inventory,
  /scan multi-dispatch — vốn đã polyglot sẵn); 2 framework cùng ngôn ngữ → as-is +
  red-flag `dual framework — migration in progress?` + OQ. Kèm vá sync: template Phase 4
  của discover.md bổ sung nhánh PHP (sót từ gói PHP/Laravel).
- **Audit `/test` — nối 3 sợi dây bị đứt (giao việc mà người nhận không biết)** — `/test`
  giữ nguyên cấu trúc (Gate 6 vốn đã đủ check máy nên **không tách** `§Orchestrator
  disk-check` riêng, tránh nhân bản canonical), chỉ vá 3 chỗ luật đã ban nhưng không tới
  nơi thi hành: (1) **schema-snapshot** — `brownfield.md` + `/build` đều giao *"re-export từ
  TestContainer của `/test`"* trong khi `test.md` không hề nhắc → thêm Task 7 (re-export từ
  chính container đã apply migration, **cấm export từ DB thật** vì sẽ ghi lại state CŨ làm
  baseline mới) + gate item cùng change-set; (2) **Dual-Implementation Parity** — luật
  MANDATORY của `rules/testing.md` (sinh ra từ một bug drift thật thoát cả `/build` lẫn
  `/test`) chưa từng được `test.md` trỏ tới → gate item: cùng một rule ở ≥ 2 nơi thì phải
  **differential test** chạy cả hai trên cùng bảng input, *hai bộ test per-side cùng xanh
  KHÔNG thỏa mãn*; (3) **artifact canonical path** — luật `reports/test-artifacts/` mới thêm
  chưa có răng → gate item: `report/` phải có results.json/.trx sau run, run đỏ phải để lại
  trace/screenshot ở `runner/` (rỗng = runner chạy bằng cờ CLI ad-hoc thay vì config đã
  commit → lần sau bằng chứng lỗi không tái lập được).
- **Audit `/review` — đồng bộ nốt nửa còn lại xuống người thực thi review** — đợt gia cố
  trước đã đẩy **định dạng báo cáo** xuống agent (7 section · `Relates-to` · Evidence-per-PASS
  · score-honesty) nhưng **nội dung checklist thì chưa**: grep `anti-vacuous` và
  `Dual-implementation parity` = **0** ở cả agent/skill/reference/template, chỉ sống trong
  `review.md`, trong khi agent §1 Correctness đang là câu hỏi cảm tính *"Does the
  implementation match requirements?"*. Vá: `code-reviewer.md` §1 Correctness thêm 3 bullet
  (**scenario coverage** → wired path + test khẳng định *Then* · **anti-vacuous** → mở test
  hỏi *"còn xanh nếu tính năng bị xóa lặng lẽ không?"* · **dual-implementation parity** →
  differential test) + trỏ canonical về `review.md §Cross-layer conformance` (**không** sinh
  nguồn thứ hai); `references/code-review-checklist.md` §Tests nâng dòng yếu *"Tests actually
  assert behavior (not just run)"* thành phép thử anti-vacuous cụ thể. Kèm 2 vá nhỏ:
  `review.md §Review Checklist` khai tầng + lần đầu trỏ tới checklist canonical 5 trục của
  chính nó (`references/code-review-checklist.md` — trước đó CLAUDE.md/agent/skill đều trỏ,
  **riêng command thì không**); `code-reviewer.md §Review Output Format` khai rõ khối 4 phần
  là **tóm tắt cho chat**, file báo cáo theo §Output File (khối ngắn đứng trên khối đúng →
  sub-agent dễ xuất nhầm rồi rớt disk-check "all 7 sections").
- **Audit `/scan` — vá false-green trên gate BLOCKING: coverage của scanner từ vô hình
  thành bắt buộc công bố** — Gate 8 vốn soi rất kỹ *thứ đã quét* (`totals`/`tools_missing`/
  `sast_scope` + disk-check "đọc JSON thật") nhưng **không hề biết thứ gì đã bị bỏ quét**;
  có 3 đường im lặng: (1) **stack ở thư mục con không được detect** — dotnet/nodejs/python/
  java dùng `find -maxdepth 4` còn **go/ruby/php chỉ `[ -f ]` ở gốc**, nên Laravel ở
  `backend/composer.json` → `php.sh` không chạy → 0 finding PHP, không một dòng cảnh báo
  (đúng lúc kit vừa ban luật multi-stack "khai TẤT CẢ kèm scope path"); (2) **detect được
  nhưng không có scanner** — `java`/`go`/`ruby` nằm trong `detect_stacks()` mà không có
  plugin nào, chỉ `log ... skipping` ra stdout → không vào JSON/report/gate, quét repo Java
  ra report **trông sạch**; (3) **`stacks_scanned` là bản liệt kê thứ hai đã trôi** —
  `detect_stacks_scanned()` suy ngược từ sự tồn tại file output và chỉ biết 4 stack, `php.sh`
  chạy thành công vẫn không bao giờ xuất hiện. Vá: `_common.sh` cho go/ruby/php dùng cùng
  `find -maxdepth 4`; `scan-all.sh` ghi `security/sast-results/stack-coverage.txt`
  (`<stack>: scanned` / `<stack>: NO SCANNER (…)`, cùng khuôn `tooling-availability.txt`);
  `scan-summarize.py` **xóa hẳn** `detect_stacks_scanned()` → đọc file đó làm sự thật + emit
  `stacks_unscanned` (đúng ưu tiên 1 của `rules/testing.md` §Dual-Implementation Parity:
  **loại bỏ bản thứ hai** thay vì viết differential test cho nó); Gate 8 thêm điều kiện chặn
  *"unscanned stack không được công bố"* + disk-check "Coverage surfaced" (`stacks_scanned`
  rỗng khi repo rõ ràng có code = `scan-all.sh` chưa chạy xong → re-run, cấm sign-off).
  Nguyên tắc: kit không thể ship scanner cho mọi ngôn ngữ, nhưng **"không quét" tuyệt đối
  không được đọc thành "không tìm thấy gì"**. Kèm: `scan.md` Phase 4 nhận thêm input
  `CODE_REVIEW.md §6 Compliance Check` — rule đã PASS kèm Evidence thì không dựng lại,
  WARNING/FAIL là **lead phải xác minh** (đóng bàn giao mà `/review` §6 hứa suốt nhưng
  `/scan` chưa bao giờ nhận: `Compliance Check` = 0 lần trong scan.md).
- **Audit `/infra` — `docker-patterns.md` không còn dạy 2 lỗi mà `infra.md` đã vá sẵn** —
  file tham chiếu Docker (511 dòng, được **7 nơi** trỏ tới, kể cả `scanners/docker.sh`) đang
  dạy: (1) `HEALTHCHECK … curl -f` ở 3 chỗ — **image .NET runtime không có `curl`**; bản
  Debian cũng không có `wget`, alpine chỉ có busybox `wget` → probe fail âm thầm, container
  kẹt `unhealthy`, **chặn thẳng Gate 9** (*"all services healthy"*), trong khi Dockerfile
  canonical của `infra.md` `apk add wget` rồi dùng `wget --spider` đúng vì lý do đó;
  (2) `### Minimal Base Image` khuyên *"✅ dùng alpine"* với `aspnet:8.0-alpine` mà **0 chữ**
  về icu-libs — `infra.md` ghi rõ tổ hợp này làm **SqlClient/Npgsql CRASH khi connect**
  (banner "tag discipline" ở đầu file chỉ miễn trừ *tag*, không đụng tới điều này);
  (3) `start-period` 5s / thiếu hẳn → container bị chấm unhealthy trong lúc còn khởi động
  (.NET + EF migration cần ~20s). Vá: 3 mẫu HEALTHCHECK (Dockerfile ×2 + compose) chuyển
  sang `wget --spider` + `start-period=20s` kèm chú thích *"probe binary phải TỒN TẠI trong
  image"*, §Minimal Base Image thêm cảnh báo icu-libs + `DOTNET_SYSTEM_GLOBALIZATION_INVARIANT`.
  Không xóa mẫu nào — sau khi vá, reference bổ trợ (layer-cache, security hardening) thay vì
  tranh chấp với lệnh. Kèm: `infra.md` §Stack Profile note thêm nhánh **Core = PHP** (2 hình
  dạng container theo `framework-php-laravel.md §J`, HEALTHCHECK theo hình dạng, `.dockerignore`
  thêm `vendor/`/`storage/logs`, migration → `php artisan migrate --force`) — trước đó `php`
  xuất hiện **0 lần** trong toàn bộ infra.md dù kit đã ship gói PHP/Laravel, lặp lại đúng lớp
  lỗi "thêm stack nhưng quên nhánh ở lệnh hạ nguồn" từng vá ở `discover.md`.
- **Audit `/docs` — bảo vệ `docs/CODEBASE_MAP.md` khỏi chính `/docs` + nhánh PHP** — `/docs`
  là lệnh **duy nhất** được giao tái cấu trúc thư mục `docs/`, mà `docs/CODEBASE_MAP.md`
  (do `/discover` ghi) lại sống ở đó và được **8 lệnh đọc** — `/spec` REVERSE và `/arch`
  reverse **STOP** khi thiếu nó. Trước bản này: cây `docs/` canonical ở Phase 3 **không liệt
  kê** file đó, luật `PRESERVE` và mục disk-check "Preserve check" chỉ phủ `README.md`/
  `CHANGELOG.md` gốc → một lần "dọn cho khớp cấu trúc" là gãy dây chuyền 8 lệnh. Vá: thêm
  `CODEBASE_MAP.md` vào cây + ghi chú *"not ours to manage — cite/link được, cấm sửa/di
  chuyển/đổi tên/xóa"*, disk-check kiểm `git diff --quiet -- docs/CODEBASE_MAP.md`. Kèm:
  Stack Profile note thêm nhánh **Core = PHP** (API doc từ `scribe`/`l5-swagger` hoặc
  `php artisan route:list` đối chiếu `openapi.yaml`, khối lệnh `dotnet` ánh xạ sang
  `composer install`/`php artisan migrate --force`) — grep xác nhận **0 dòng** về API-doc
  tooling trong cả 3 override PHP, tức kiến thức này không suy ra được từ đâu khác; đây là
  lần thứ 3 cùng lớp lỗi "thêm stack nhưng quên nhánh ở lệnh hạ nguồn" (`discover.md` →
  `infra.md` → `docs.md`).
- **Audit `/verify` — hợp đồng E2E áp đúng bước hay chạy nhất + nối mắt cuối của chuỗi
  set-check NFR** — (1) **E2E assertion contract** (`When` phải đi qua control thật · cấm
  `if (exists) act()` · assert rồi **reload** chứng minh persistence · **network tripwire**
  ≥400) khai canonical ở `verify.md` §Phase 3, grep toàn kit chỉ thấy ở **2 file**
  (verify.md + VERIFY_REPORT_TEMPLATE) — **`test.md` = 0**, dù `/test` cũng viết E2E
  (`tests/e2e/`, Gate 6 có ô *"E2E tests for critical paths"*). Nghịch lý: **bước bắt buộc
  chạy mọi lần (Gate 6) viết E2E yếu hơn bước tùy chọn chạy 1 lần (Gate 11)**. Vá: `test.md`
  thêm 1 blockquote nêu 4 điều kiện dạng gạch đầu dòng + trỏ canonical (**không chép**),
  `verify.md` khai rõ hợp đồng là *"canonical for every E2E test in the kit — `/test`'s
  Gate-6 suite included; never fork a second copy"*. (2) **Chuỗi toàn vẹn NFR đứt ở mắt
  cuối**: `/arch` có *"every spec NFR → mechanism row / §Security line / tagged OQ — no
  silent drop"* (4 lần), `/plan` có NFR set reconciliation, **`/verify` = 0** — Gate 11 chỉ
  đòi *"những cái đã đo"* đạt ngưỡng, nên một lần verify đo latency mà **im lặng bỏ qua NFR
  accessibility** (kit khai WCAG AA là default-on cho mọi màn hình) vẫn `SUCCEEDED`; trớ trêu
  vì `/verify` là bước **duy nhất** chứng minh được NFR trên artifact thật. Vá: Phase 4 thêm
  completeness rule (mỗi NFR **một hàng** ở §4, đúng 1 disposition: measured ·
  not-runtime-measurable *nêu rõ đã kiểm ở gate nào* · waived *owner+lý do*), Gate 11 nâng ô
  Phase 4 thành **set-check**, đoạn mở Gate 11 thêm "Phase-4 NFR set-check" cạnh Phase-5 sẵn
  có, template §4 dựng khung **bảng** (set-check cần hàng để đếm, một câu mô tả không đếm được).
- **Audit `/deploy` — đóng mâu thuẫn "rollback < 1 phút" vs migration destructive (phát hiện
  nặng nhất cả đợt audit 12 lệnh)** — `/deploy` hứa *"**Target: < 1 minute.** Rollback restarts
  containers with the **previously tagged image**"* (đưa **code cũ** về) trong khi Step 5 vừa
  chạy migration (**schema mới còn nguyên**). `rules/database.md` §Expand-contract liệt kê
  đúng những thao tác khiến code cũ **không chạy nổi** với schema mới (`RENAME`/`DROP COLUMN`,
  `NOT NULL` không default, thu hẹp kiểu, unique index trên dữ liệu có sẵn) — nhưng grep
  `expand-contract`: `database.md` ✓ `brownfield.md` ✓ `build.md` ✓ **`deploy.md` = 0**. Tức
  kit nối luật tới nơi *viết* migration mà **không** nối tới nơi migration **chạy lên hệ thống
  đang sống** và cũng là nơi phát ra lời hứa rollback. Ô checklist duy nhất liên quan lại mờ:
  *"Database migrations reviewed"* — không định nghĩa review **cái gì**; Option A của Database
  Rollback ghi *"only if migration was reversible"* mà **không ai kiểm điều kiện đó**. Kịch bản
  thật: release có `DROP COLUMN` → sự cố → Quick Rollback → app **chết ngay lúc khởi động**;
  đường lui còn lại là restore backup = **mất toàn bộ dữ liệu ghi sau deploy**. Vá (không chép
  luật, cả 3 chỗ đều trỏ `database.md` §Expand-contract): ① Pre-Deploy Checklist nâng ô mờ
  thành **phân loại destructive / non-destructive** kèm hệ quả *"image-tag rollback KHÔNG khả
  dụng"*; ② blockquote ngay tại Step 5 — destructive thì phải theo **expand-contract** hoặc có
  **ADR + cửa sổ downtime**, *"khôi phục backup là sự cố mất dữ liệu, không phải rollback"*;
  ③ §Rollback Procedures nêu **điều kiện làm cho "< 1 phút" đúng** (schema còn tương thích
  ngược với image trước); ④ Exit Criteria mở rộng ô rollback thành **code AND data** — migration
  đổi schema mà RUNBOOK §4 không nêu đường lui thật (tag / pha expand-contract / backup + RTO +
  cửa sổ mất dữ liệu) = **không được khai STAGED**. Nguyên tắc giữ nguyên như `stacks_unscanned`
  của `/scan`: **không cấm** destructive migration (có ca hợp lệ), nhưng **"không có đường lui"
  tuyệt đối không được vô hình**. Kèm: Stack Profile note thêm nhánh **Core = PHP**
  (`php artisan migrate --force`, `--isolated` khi nhiều instance, `config:cache`/`route:cache`
  + caveat `env()` → `null`) — **đóng trọn** lỗ hổng PHP sau 4 lần lặp (`discover` → `infra`
  → `docs` → `deploy`).
- **Audit `/discover` — vá 2 hợp đồng gãy do chính đợt audit này tạo ra** — set-check ngược
  (hạ nguồn *đòi* §gì ở `CODEBASE_MAP` mà `/discover` không *hứa* sinh ra) lộ 2 lỗi, cả hai
  đều mới thêm ở các lượt audit trước, chưa commit: (1) **`/secure` trích dẫn một section
  không tồn tại** — `secure.md` bảo Security Auditor cite *"`CODEBASE_MAP.md`
  §security-posture row"* làm evidence id, trong khi `/discover` chỉ hứa **6** inventory
  (Endpoint · Red-flag · Connection · DB-object · Messaging · Cache-structure); grep toàn kit:
  chuỗi đó xuất hiện **đúng 1 lần** — chính câu trích dẫn nó. Trớ trêu vì đó là câu luật
  chống bịa (*"Never a fabricated task id"*): làm theo thì hoặc bó tay, hoặc bịa đúng thứ
  đang cấm → thay bằng nguồn có thật (ADR id · section `ARCHITECTURE.md` · **`file:line`
  nơi control được wire** — với brownfield đó CHÍNH LÀ bằng chứng). (2) **disk-check tự mâu
  thuẫn** — Phase 1b (thêm ở lượt trước) ra lệnh *"Commit the snapshot"* tạo
  `db/schema-snapshot/`, mục credential-leak của disk-check còn grep vào đó, nhưng mục
  **read-only guarantee** (có từ trước) chỉ cho phép 3 addition không gồm nó → orchestrator
  chạy đúng disk-check sẽ **revert chính output mà Gate đòi hỏi**. Kèm: cụm *"health-snapshot
  doc"* xuất hiện 5 lần mà **không nơi nào định nghĩa tên file** → whitelist vốn không kiểm
  bằng máy được; nay ghim thành **section `§Health snapshot` bên trong `CODEBASE_MAP.md`**
  (bớt một artifact vô danh thay vì đặt tên cho nó; red-flag vốn đã có §riêng nên hết trùng).
  Sau bản vá, `/discover` có **đúng một** danh sách "được phép thêm" (3 đường dẫn) và được
  trích dẫn ở **cả hai** nơi kiểm — gate workspace + disk-check — thay vì hai bản lệch nhau.
- **Audit `/fix-issue` (+ `/hotfix` triage) — đóng nốt lỗ schema-change trên đường bug-fix** —
  (1) **fix kèm đổi schema = điểm mù hoàn toàn**: `fix-issue.md` có `migration`/`schema`/
  `expand-contract` = **0/0/0**, trong khi nhiều bug fix *chính là* migration (sai kiểu cột,
  thiếu unique constraint) và đường `/hotfix` viết fix **dưới áp lực sự cố** — đúng lúc dễ
  `DROP`/`RENAME` một bước nhất; `/build` (nơi viết migration luồng thường) đã có blockquote
  từ trước, nơi viết migration luồng bug thì chưa. Thêm nữa, luồng dev-time (`/fix-issue` →
  `/review`) **không đi qua `/test` Task 7** → không ai refresh `db/schema-snapshot/`. Vá:
  blockquote ở §5 Implement (migration theo `database.md` §Expand-contract + refresh snapshot
  **trong cùng change-set**, nêu rõ lý do "nobody downstream will refresh it for you") + 1 ô
  Bug Fix Checklist cưỡng chế (classified non-destructive/destructive + snapshot refreshed).
  (2) **từ mờ tại điểm quyết định khẩn cấp**: `hotfix.md` Step 1 triage rollback dựa trên
  *"no non-revertable migration involved"* — thuật ngữ không định nghĩa, không trỏ đi đâu
  (đúng lớp lỗi *"migrations reviewed"* vừa vá ở `/deploy`); nay định nghĩa = danh sách
  destructive của `database.md` §Expand-contract **và** nối vào mắt xích RUNBOOK §4 mà bản vá
  `/deploy` vừa tạo — người trực sự cố **đọc** đường lui đã ghi sẵn thay vì **suy** dưới áp
  lực. (3) Stack Profile note thêm nhánh **Core = PHP** (`php artisan test`/`vendor/bin/pest`,
  `pint --test`, `phpstan analyse`) — lần thứ 5 của lớp lỗi này. Đã kiểm và KHÔNG sửa:
  danh sách "inherited from `/fix-issue`" của `/hotfix` đối chiếu từng mục đều có thật
  (không phải hợp đồng treo); `/hotfix` không có Stack Profile note là **đúng** — nó không
  chứa lệnh stack-specific nào; hai lối ra dev-time/re-verify nhất quán với CLAUDE.md.
- **Audit `/hotfix` — 2 drift quanh mép, lõi orchestrator đã kín** — đã kiểm và XÁC NHẬN
  không phải lỗi: Step 4 *"minimum: bug area"* vs *"Gate 11 must PASS"* không mâu thuẫn
  (`verify.md` §Phase 5 định nghĩa nguyên văn **B4 hotfix = scoped minimum**, khớp từng chữ);
  handshake `HOTFIX_MODE=1` có đủ hai đầu (hotfix set, deploy `exit 1` khi thiếu lock); Exit
  Criteria nhúng sẵn VAD kiểm artifact hotfix-unique trên đĩa; trim/promote không tự ký được
  (§Phase ownership return-early). Vá 2 drift: (1) **Phase-4 NFR set-check** (vừa thêm ở lượt
  audit `/verify`) thiếu carve-out B4 mà Phase 5 có → hotfix operator hoặc bỏ qua im lặng cả
  Phase 4 (tái sinh đúng lỗi luật này chặn) hoặc chặn hotfix hàng giờ đo lại soak/stress; nay
  nối 1 mệnh đề: bộ NFR tự động re-run **as-is** (đo đã script hoá = đường rẻ), phép đo thật
  sự quá nặng cho incident-time → hàng **waived** (owner + lý do, ghi vào incident note cùng
  kỷ luật trim-audit của Step 5) — *"lối tắt hợp lệ là hàng waived nhìn thấy được, không bao
  giờ là section bị bỏ qua im lặng"*. (2) **danh sách field incident note trôi 3-vs-1**:
  Step 6 canonical có **5 field** (gồm `affected users` — dữ liệu lõi đánh giá severity),
  nhưng bảng Output + đoạn VAD + ô Exit Criteria chỉ 4 → gate kiểm bản 4, field thứ 5 âm thầm
  thành tùy chọn; nay cả 4 danh sách trùng khít 5 field.
- **Audit `/debug` — thông đường disposition cho A-xx ở 4 ngả + nhánh PHP** — `/debug` là
  lệnh hands-on-code (Step 4 tự quyết "đâu là behavior đúng": fix query hay dedupe UI?) nên
  chịu luật MANDATORY §2.5 *"no behavior decision may live only in code"*. Prompt spawn đã
  bắt ghi Assumptions log nhưng đường đi chỉ khai cho MỘT ngả: *"joins the running `/build`
  phase's log, dispositioned at Gate 5"* — trong khi `/debug` có 4 ngả (resume `/build` ·
  re-run `/test` · `/review` · standalone dev-local); 3 ngả sau **không có Gate 5 nào đang
  chạy** → A-xx ghi xong không ai duyệt, và checklist đóng lệnh cũng không có ô A-xx
  (`/fix-issue` có, cưỡng chế cả hai lối ra). Vá hai-đầu (cùng logic FI1): sửa dấu ngoặc
  trong prompt (không có phase đang chạy → **user disposition trước khi debug đóng**, cùng
  cơ chế `/fix-issue`) + 1 ô checklist (approved behavior-changing assumption chảy về
  `specs/` dạng AC amendment). Kèm nhánh **Core = PHP** cho note (lần thứ 6: `php artisan
  test`/`pest --filter`, **Xdebug** step-debug, `DB::enableQueryLog()`/Telescope thay EF Core
  query logging). Đã kiểm và KHÔNG sửa: không cần lời nhắc schema như `/fix-issue` — các ngả
  của `/debug` đều quay lại pipeline nơi `/build` blockquote + `/test` Task 7 đã phủ (khác
  lỗ B3 dev-exit của `/fix-issue`); ranh giới read-only khi chạy trong `/test` đã có boundary
  note riêng; không trùng lặp `/fix-issue` (cửa vào khác, nội dung trỏ nhau không chép).
- **Audit `/simplify` — vá điểm mù của lời hứa "behavior unchanged" + biển chỉ đường B5** —
  lõi an toàn vốn rất chắc (Step 0 baseline xanh + characterization-first mọi mode, Step 6
  revert-ngay, orchestrator verification 3 mục) nhưng có một ca mà **"behavior unchanged theo
  test" và "behavior unchanged thật" tách rời nhau**: xóa public surface (route/DTO/event
  schema/exported function) "trông chết" — **consumer bên ngoài không hiện trong test net**,
  nên xóa xong suite vẫn xanh mà client đang chạy thì gãy; bảng quyết định
  `brownfield-pipeline.md` đã xếp việc này là *"Removing/deprecating a feature → B2 + ADR
  (breaking by design)"* nhưng `simplify.md` có `contract`/`API`/`backward` = **0** — luật có
  trong bảng, người bên trong lệnh không biết. Vá hai-đầu: blockquote *"Public surface is not
  'dead code'"* ngay tại §Remove Dead Code (nơi cám dỗ phát sinh) + orchestrator check mở
  rộng *"added"* → *"added **or removed/renamed** public surface"* (nơi soát diff), cả hai
  trỏ về bảng quyết định. Kèm: (2) Red Flags thêm **lối leo thang B5** — định tuyến vào
  `/simplify` đã có ở decision tree nhưng `B5`/`ADR` = 0/0 bên trong lệnh, phát hiện "class
  phức tạp vì layering sai" thì không có biển chỉ đường ra (so: `/arch` CONFORMANCE-GATE có
  hẳn *"YES: stop, switch to the B5 flow"*); (3) nhánh **Core = PHP** cho note (lần thứ 7:
  `pest`, `match` thay switch, backed enum, early return theo `lang-php.md`).
- **Audit `/inspect` — nối nguồn bằng chứng DB mới nâng cấp + chốt môi trường cho write-probe** —
  hai điểm mù đều là hệ quả của các bản vá gần đây: (1) **câu hỏi cấu-trúc-DB** (*"proc X làm
  gì?"*, *"bảng Y có unique index?"*) — `db/schema-snapshot/` + `§DB-object inventory` vừa
  thành sự thật phía-repo hạng nhất (3 luồng refresh, `/arch` cite, `/review` soi freshness)
  nhưng Phase 1/2 của `/inspect` chưa nhắc; nặng hơn, hỏi `--live` mà **snapshot ≠ DB sống**
  thì bảng mismatch rơi vào hàng *"artifact old/stale → re-`/deploy`"* — **chẩn đoán sai**
  (redeploy không chữa DB bị sửa tay). Vá: Phase 2 chỉ đường index qua §DB-object inventory →
  DDL đã commit (probe sống không thay thế), bảng mismatch +1 hàng **Schema drift** (điều tra
  + corrective migration, reverse smell `/review` soi). (2) **write-probe có kỷ luật dữ liệu
  (throwaway prefix) nhưng không có kỷ luật MÔI TRƯỜNG** — không dòng nào hỏi probe chĩa vào
  đâu; theo văn bản cũ, POST thử rate-limit vào production là hợp lệ. Vá: write-probe chỉ nhắm
  stack tự dựng (compose/staging); đích production → **chỉ read-only** (GET/HEAD), answer khai
  rõ *"write path not probed"* — nhất quán ranh giới sẵn có (deploy dừng STAGED, rollback do
  người vận hành). Đã kiểm và KHÔNG sửa: chuỗi trích dẫn tier Records đúng vị trí hết (không
  dính bản vá health-snapshot); free-text contract khớp CLAUDE.md từng ý; stack-agnostic thật
  nên không cần nhánh PHP.
- **Audit `/discover-system` — vá 2 lỗ cùng họ "hứa mà không sinh" ở aggregator đa-repo** —
  lõi lệnh vốn đã gia cố kỹ (Phase 0 incremental bash-first, near-miss contract-id, service-id
  uniqueness, reference-first views, carry-forward verification) — không sửa gì ở lõi. Hai lỗ
  quanh mép: (1) **`contracts/event-catalog.md` được hứa ở 3 nơi, không nơi nào sinh ra** —
  có trong cây output, reference gán hẳn vai trò (*"topic·schema·producer·consumers +
  cross-service REST"*), template fill-only đầy đủ 2 section, nhưng grep toàn lệnh: không
  phase nào có bước viết, gate/disk-check không kiểm — trong khi dữ liệu để điền thì Phase 2
  bước 2 đã gom xong (toàn bộ Exposes/Consumes rows). Vá: +1 sub-bullet ghi catalog ngay tại
  bước match (dangling/near-miss mang cờ ⚠️ vào catalog luôn — *"catalog states what IS,
  including what is broken"*) + 1 gate item set-check (row của catalog = union của step-2
  output, không contract row nào rơi im lặng giữa call-graph và catalog). (2) **cột `Owner`
  không có nguồn thượng nguồn** — template catalog + Phase 1 + reference đều đòi, nhưng schema
  Project Profile không có field owner, `/discover` không sinh → áp lực bịa (suy từ git log /
  tên folder), cùng họ `§security-posture`. Vá bằng 1 câu: `owner` là **user-supplied** (hỏi
  một lần ở lần tổng hợp đầu, carry-forward về sau), **cấm suy diễn** từ git history / tên
  folder; chưa biết → `—`. Đã kiểm và KHÔNG sửa: hợp đồng với `/export-docs` system-scope
  (chỉ đòi freshness — Phase 4 conformance đáp ứng), mọi input đòi từ repo thành viên đều có
  producer thật (Service id ← `/discover` · §Service Contracts ← `/arch` §3.2).
- **Audit `/export-docs` (lượt cuối — khép chuỗi 20/20 lệnh) — +1 gate item Label fidelity
  cho `📝P-nn`** — lệnh khỏe nhất kit: các bản vá phiên trước (C4 granularity, API sample
  derivation, System-scope ID, freshness) đứng vững khi soi lại; chuỗi producer `📝P-nn` đầy
  đủ (`/spec --propose-goals` → BA §label+pairing → gate `/spec`); schema manifest dạy đủ 5/5
  field lệnh đòi; §C4 granularity được phủ **bắc cầu** (row manifest khai nguồn riêng từng
  section + item Diagram fidelity so với nguồn đã khai) nên không thêm item thừa. Một khoảng
  hở duy nhất: luật giữ nhãn proposal có ở **nơi làm** (fill rule: *"never strip the label or
  promote a proposal to fact"*) và **nơi trình bày** (Phase 3: count must match) nhưng không
  có ở **nơi chặn** — blocking checklist thiếu item, mà disk-check chỉ re-run *"the mechanical
  checks above"*. Nhãn bị lột = goal suy diễn chưa được PO xác nhận nằm trong PRD công ty như
  sự thật đã duyệt — đúng lớp bịa lệnh này sinh ra để chặn. Vá: +1 gate item **(sources
  carrying `📝P-nn`) Label fidelity** — grep hai phía, count + id khớp 1:1, lột nhãn/nâng
  proposal thành fact = gate FAIL; điều kiện hoá cùng khuôn các item `(…-carrying targets)`
  sẵn có, disk-check tự phủ vì item giờ nằm trong "above". Hai hạng mục user đã hoãn
  (repeat-marker engine check · Design-vs-Evidence layer) giữ nguyên trạng thái hoãn.
- **Rà lại `/spec` (lượt 2, sau khi 19 lệnh kia đã audit) — NFR nhận khóa `NFR-xx`** —
  set-check ngược "19 lượt sau đòi gì mới ở `specs/`" bác 4 nghi vấn (header `Version` cho
  `discover-system` ✓ BA:234 · REVERSE biết DB-object inventory ✓ · DoR có item NFR ✓ ·
  producer đủ cho `📝P-nn`/G-xx/Glossary/class-tags ✓) và lộ đúng 1 khoảng hở: **NFR là phần
  tử duy nhất trong chuỗi traceability không có ID** (`@US-XXX-Snn` · `G-xx` · `RC-N` ·
  `ADR-NNN` · `F-NNN` · `BUG-###` · `A-xx` · `OPEN-###` · `@SYS-US-NNN` · `📝P-nn` — riêng
  NFR match bằng tên tự do), trong khi sau đợt audit đã có **ba** set-check key vào "the NFR
  rows in `specs/SPEC.md §NFR`": `/arch` mechanism completeness (×2 chỗ) · `/plan` NFR set
  reconciliation (*"extract the NFR rows"*) · `/verify` Phase-4 (vừa thêm phiên này). Diff
  một danh sách không khóa = drift-bằng-diễn-đạt-lại lọt qua máy (spec ghi *"P95 latency
  < 200ms"*, report ghi *"API response time"* → không nối nổi). Vá tại nguồn, hạ nguồn 0
  sửa (set-check viết "the NFR rows" chung chung nên có khóa là tự dùng): BA agent §NFR thêm
  **artifact shape** — bảng khóa `| ID | Category | Requirement (measurable) | Target/
  Threshold |`, ID phẳng `NFR-01…` **append-only** như `G-xx` (Category là cột riêng nên đổi
  phân loại không đổi ID; bảng elicitation cũ giữ nguyên vai trò hướng dẫn hỏi); DoR item
  *"identified"* → *"identified as keyed `NFR-xx` rows"*; disk-check `/spec` thêm anchor
  ngôn-ngữ-trung-lập `| NFR-` cạnh `| G-` sẵn có (tự thừa hưởng scoping Baseline/DELTA).
- **Rà lại `/arch` (lượt 2) — bảng NFR-mechanism mang khóa `NFR-xx`, khép mắt giữa của chuỗi
  join** — mọi bản vá lượt đầu còn nguyên (Flow Disposition ×5, Data Model gate, hedge check,
  chặn spec partial, §Service Contracts); phát hiện duy nhất là gợn sóng của bản vá NFR-xx
  vừa áp ở `/spec`: template bảng `| Requirement | Target | Architectural answer |` không có
  khóa, trong khi **ba** consumer join qua đúng bảng này (Completeness rule của chính `/arch`
  diff với spec §NFR — spec giờ keyed, arch keyless; `/plan` *"extract the mechanism rows"*;
  `/verify` Phase-4 disposition *"name the `/arch` mechanism row"*). Spec keyed + arch keyless
  = chuỗi spec↔arch↔plan↔verify vẫn đứt ở mắt giữa. Vá theo kiểu **tiền tố trong ô**
  (`NFR-01 · Availability`) — không thêm cột vì bảng 3 cột đang được 3 nơi trích dẫn; nối 1
  câu vào Completeness rule + mở rộng mục disk-check "NFR mechanisms": hàng **không có id**
  trở thành tín hiệu chẩn đoán miễn phí — đó là NFR do rules bắt buộc mà spec bỏ sót → route
  ngược về spec (amendment/OQ), không để hàng vô danh. B5 REDESIGN cố ý KHÔNG nối
  expand-contract (đã đòi ADR + migration plan strangler-fig; cơ học schema thuộc
  `database.md` và bị gate ở `/build`/`/deploy` — thêm ở arch là chép luật chéo tầng).
- **Rà lại `/plan` (lượt 2) — tầng task nhận khóa `NFR-xx`, khép TRỌN chuỗi join NFR 4 tầng** —
  bản vá lượt đầu còn nguyên 5/5 (Impact Analysis, ADR disposition, NFR reconciliation, Task
  block completeness, expand-contract note). Phát hiện duy nhất: tầng task là mắt cuối chưa
  keyed — Task block có trường `Scenarios covered` với luật *"exact scenario IDs — story-level
  mapping is NOT enough"* nhưng **không có trường tương đương cho NFR**; reconciliation Gate 3
  match bằng *"task AC or a dedicated task"* = so diễn đạt, trong khi spec + arch vừa keyed.
  Vá 3 chạm: (1) Task block thêm trường **điều kiện** `NFRs covered: NFR-xx, …` (chỉ task giao
  NFR mechanism — không vào Task-block-completeness, không bắt task thường khai `—` gây nhiễu;
  lưới tổng vẫn là reconciliation); (2) gate item NFR coverage chèn *"matched **by `NFR-xx`
  id** … never by paraphrase"*; (3) disk-check reconciliation diff bằng trường mới / AC cite
  id. Kết quả: chuỗi NFR keyed trọn **spec → arch → plan → verify** — cùng kỷ luật join-key
  đã có của scenario (`@US-XXX-Snn` → Scenarios covered → test) áp sang NFR.
- **Rà lại `/secure` (lượt 2) — mode baseline chảy vào STRIDE_TEMPLATE** — bản vá cũ nguyên
  6/6 (baseline run, owner cross-check, inventories, A05, evidence-id fix, câu phủ định
  `security-posture`); nghi vấn thời-tự *"task id assigned when `/plan` runs"* **bị bác**
  (câu nằm trong bullet Baseline run — brownfield Phase A chưa có plan; Prerequisites khai
  plan chỉ bắt buộc per-change); gợn sóng NFR-xx = không (chỉ đọc NFR làm input, không
  set-check). Phát hiện duy nhất: **mode baseline (vá ở lượt đầu) chưa bao giờ chảy vào
  template mà agent thực sự điền** — `STRIDE_TEMPLATE.md` đòi task-id **vô điều kiện** ở
  dòng cai quản §D (*"EVERY mitigation must map to a task ID that already exists in
  plans/plan.md"*) và ở self-check (điều cuối agent đọc trước khi nộp), trong khi baseline
  run không có `plans/plan.md` → agent phải chọn giữa **bịa task id** (đúng tội *"Never a
  fabricated task id"*) và rớt self-check. Vá 2 dòng: cả hai mở nhánh điều kiện trỏ về
  `secure.md` §Baseline run làm canonical (evidence id cho control đã có, `Backlog` +
  Residual-Risk row cho gap); dòng placeholder ví dụ 101 giữ nguyên (dòng 104 cai quản cả
  block). OWASP_TEMPLATE kiểm sạch (0 chỗ đòi task-id).
- **Rà lại `/build` (lượt 2 — khép trọn vòng rà lại 5 lệnh audit-sớm)** — lệnh sạch nhất
  trong 5 lệnh rà lại: bản vá lượt đầu nguyên 6/6 (disk-check 5 mục — đã có sẵn cả
  *"(Schema-touching tasks) Migration + snapshot"*, blockquote migration trỏ expand-contract,
  Blast radius hai đầu khớp `/review`); cố ý KHÔNG thêm rule "Cover the NFR" song song
  "Cover the scenario" (mechanism nằm trong AC của task, ngưỡng đo thuộc `/verify` Phase-4 —
  thêm là lặp kỷ luật AC). Một sửa duy nhất: Prerequisites dòng 21 liệt kê trường task block
  (*"AC, Scenarios covered, Files to modify, Tests to add"*) **thiếu trường `NFRs covered`**
  vừa sinh ở `/plan` — đúng lớp enumeration-drift của danh sách field incident note; vá 1
  dòng kèm mệnh đề điều kiện giữ nguyên ngữ nghĩa trường gốc. **Tổng kết 2 vòng README2.txt:
  20/20 lệnh lượt đầu + 5/5 lệnh audit-sớm rà lượt hai** (`/spec` NFR-xx artifact shape ·
  `/arch` mechanism row keyed · `/plan` NFRs covered · `/secure` baseline→template ·
  `/build` enumeration) — chuỗi khóa NFR 4 tầng khép kín là kết quả xuyên suốt của vòng hai.
- **Rà lại `/test` (lượt 2) — ví dụ mẫu của agent không còn dạy bar yếu** — command sạch
  (bản vá 5/5 nguyên: Task 7, parity, artifacts, E2E contract blockquote, Results board;
  Gate 6 "12 sections" khớp template 12/12), nhưng `test-engineer.md` — agent viết E2E cho
  **cả** Gate 6 lẫn Gate 11 — grep `round-trip`/`reload`/`Dual-Implementation` = **0/0/0**,
  và nặng hơn: **§E2E Test Anchors kết thúc ở `ToBeVisibleAsync`** — assert presence, không
  reload, đúng nguyên văn lớp lỗi mà E2E assertion contract sinh ra để chặn (và là lớp bug
  user từng gặp: E2E pass rỗng trên optimistic UI). Ví dụ mẫu dạy mạnh hơn văn luật — agent
  copy mẫu là chở bar yếu vào cả hai gate. Vá: (1) khối mẫu nối bước round-trip
  (`ReloadAsync()` → re-assert, comment *"only a server-persisted write passes — effect, not
  presence"*) + chú thích trỏ canonical `verify.md` §Phase 3 (*"a journey that stops at
  `ToBeVisibleAsync` verifies the render, not the feature"*); (2) bảng §Anti-patterns +2
  hàng: **Presence-only E2E assert** · **Per-side tests for a dual-encoded rule** — hai
  smell có tiền sử bug thật mà hàng "No assertion" không bắt được. Cố ý KHÔNG đẩy sang
  agent: Task 7 snapshot (bước quy trình orchestrator cầm) + connection tripwire (gate item
  ghi rõ orchestrator chạy) — đúng phân vai command-vs-agent.
- **Rà lại `/review` (lượt 2) — từ vựng `Relates-to` đồng bộ 4 bản + nhận khóa `NFR-xx`** —
  bản vá lượt đầu nguyên 4/4 (agent 3 bullet + canonical pointer, reference anti-vacuous,
  two-layer note, chat-vs-file note); §6 Compliance khớp hình với hand-off `/scan` đọc. Một
  mạch hai lỗi: từ vựng `Relates-to` liệt kê ở **4 chỗ** (MANDATORY note · gate item · agent
  · template) — gate item **đã trôi sẵn** (thiếu `S1..E10`: finding gắn `Relates-to: S3`
  thỏa canonical nhưng trượt từ vựng của chính gate), và **cả 4 chưa có `NFR-xx`** dù chuỗi
  khóa NFR 4 tầng vừa khép — finding *"P95 chưa đạt"* phải ép vào `Task N.N`, mất thông tin
  *NFR nào* đúng lúc `/verify` Phase-4 cần trích *"verified at a `/review` compliance row"*.
  Vá 4 dòng word-level, đồng bộ về một bộ 6 loại: `US-XXX | NFR-xx | RC-N | ADR-NNN |
  Task N.N | S1..E10`.
- **Rà lại `/scan` (lượt 2) — bảng compensating-controls thoát thời trước-PHP (gợn PHP lần
  thứ 8, lần này trong code)** — bản vá lượt đầu nguyên 6/6 (maxdepth, stack-coverage handoff,
  `stacks_unscanned`, Gate 8, input §6); nghi vấn "docker.sh dạy curl cũ" bị bác (chỉ là con
  trỏ chung); phpstan vắng trong tool inventory là **thiết kế đúng** (php.sh chạy
  `vendor/bin/phpstan` project-local). Lỗi thật: `php.sh` khi thiếu `composer` ghi *"skipping
  dependency audit (grep-based checks still run)"* — grep chỉ bắt dangerous-pattern, **không
  bắt CVE** → audit CVE của stack PHP biến mất im lặng, vì `build_compensating_controls`
  đứng nguyên ở bộ tool trước-PHP: chuỗi `"semgrep"` liệt kê native 4 stack thiếu PHP, chuỗi
  `"snyk"` thiếu `composer audit`, và **không có entry `"composer"`** → composer thiếu chỉ
  nằm trong `tools_missing`, không sinh hàng compensating-control → điều kiện chặn Gate 8
  (*"must_add_to_pipeline: true but not flagged"*) không bao giờ kích hoạt. Vá +1 entry
  `"composer"` (`must_add=True` — không fallback nào phủ được CVE) + 2 chuỗi liệt kê; **test
  thật** trong sandbox: composer MISSING → hàng compensating-control xuất hiện với
  `must_add_to_pipeline: True` → cơ chế Gate 8 sẵn có tự kích hoạt, không cần sửa gate.
- **Rà lại `/infra` (lượt 2) — hợp đồng treo phía PRODUCER: template compose nhận
  `image: ${IMAGE_TAG:-dev}`** — bản vá lượt đầu nguyên (docker-patterns 4/4 wget + icu-libs,
  nhánh PHP); compose healthcheck của infra vốn đã dùng wget (tự nhất quán). Lỗi thật:
  `deploy.md` nhắc `IMAGE_TAG` **4 lần** và ghi rõ *"If your compose still hardcodes tags,
  **fix it in `/infra`** before deploying"* — nhưng `infra.md` = **0** lần, service `api`
  trong template chỉ có `build:` không `image:` → mọi repo greenfield scaffold từ template
  tới `/deploy` đều trượt: compose build ra ảnh tên mặc định, không tag semver được,
  digest-lock và quick-rollback (`IMAGE_TAG="${PREV_VERSION}" … --no-deps api`) không hoạt
  động, user bị đá ngược sửa thứ `/infra` đáng lẽ phát đúng từ đầu — phiên bản producer-side
  của lớp "luật có, người thi hành không biết". Vá hai đầu: template +3 dòng
  (`image: myapp-api:${IMAGE_TAG:-dev}` + comment nêu digest-lock/rollback đứng trên dòng
  này; local → `:dev`, deploy → semver, không vi phạm "no `:latest`") + 1 item Gate 9 chặn
  tại nguồn (*"Catch it HERE — discovered at deploy time it sends the user back to re-run
  `/infra`"*); ảnh bên-thứ-ba giữ pin tag chính xác theo item sẵn có.
- **Rà lại `/docs` (lượt 2) — cặp build+run của Deployment Guide chạy nối được nhau + Phase 0
  đọc incident notes** — bản vá lượt đầu nguyên 4/4 (CODEBASE_MAP ×4, not-ours-to-manage,
  byte-identical guard, nhánh PHP). Hai lỗi nhỏ: (1) Phase 6 dòng build
  `docker build -t app:${VERSION}` đứng ngay trên dòng run `IMAGE_TAG=${VERSION} docker
  compose … up -d` mà **hai dòng không ghép được với nhau** — compose tìm ảnh theo key
  `image:` (`myapp-api:${IMAGE_TAG}`), ảnh `app:${VERSION}` vừa build bị bỏ rơi, compose tự
  build/pull lại; đồng thời lệch đường canonical `deploy.md` Step 2 → sửa thành
  `IMAGE_TAG=${VERSION} docker compose build` (tài liệu operator giờ dạy đúng đường pipeline
  đi). (2) Bảng audit Phase 0 (14 nguồn) chưa có hàng `reports/incidents/INC-*.md` — nguồn
  troubleshooting giàu nhất kit (sự cố production thật, 5 field chuẩn: timeline · MTTR ·
  affected users · root cause · preventive action) → +1 hàng cùng khuôn hàng TEST_REPORT,
  điều kiện hoá *"(if any hotfix ran)"*.
- **Rà lại `/verify` (lượt 2) — khóa `NFR-xx` chốt sổ ở tầng cuối** — bản vá trong-chuỗi
  nguyên 5/5 (E2E canonical + chống fork, Completeness rule, B4 carve-out, set-check kép,
  bảng §4); nghi vấn format `verify-artifact.lock` không ai định nghĩa **bị bác đẹp**
  (`verify.md:63` khai write-format `"<version> <digest>"` khớp từng ký tự với
  `read -r LOCK_VER LOCK_DIG` bên `/deploy`). Một lỗi: chuỗi khóa NFR đã keyed ở 3 tầng
  (spec bảng ID · arch tiền tố · plan `NFRs covered`) nhưng **đích đến** — bảng §4 của
  VERIFY_REPORT — hàng ví dụ vẫn `<P95 latency>` trần và completeness rule không nói row key
  bằng gì → Gate-11 set-check diff spec-keyed ↔ §4-unkeyed = mắt cuối match bằng tên, đúng
  chỗ mọi tầng hội tụ. Vá 3 sửa word-level: rule nối *"keyed by its `NFR-xx` id"*, dòng dẫn
  bảng nêu id là join key, ô ví dụ thành `NFR-01 · <P95 latency>` (cùng kiểu tiền tố arch).
  Chuỗi NFR giờ keyed trọn **cả 4 artifact shape**: spec sinh → arch mang → plan giao →
  verify chốt sổ.
- **Rà lại `/deploy` (lượt 2 — khép trọn vòng 2 cho cả 12 lệnh pipeline) — RUNBOOK template
  nhận slot đường-lui** — bản vá lượt đầu nguyên 5/5; agent Release Manager **được minh oan**
  (đã dạy sẵn two-phase awareness + red-flag destructive, không cần sửa). Lỗi thật — lớp SE2
  lặp lại: Exit Criteria (lượt đầu) đòi *"RUNBOOK §4 states which path actually applies"* và
  `/hotfix` triage (lượt fix-issue) **đọc** đúng câu đó, nhưng `RUNBOOK_RELEASE_TEMPLATE` §A.4
  — skeleton agent điền — vẫn bản trước-luật: dạy lời hứa *"< 1 minute"* **vô điều kiện**
  (đúng thứ deploy.md vừa điều kiện hoá) và **không có slot** cho câu khai đường-lui → runbook
  ra lò thiếu đúng câu mà gate chặn và hotfix trông cậy. Vá 2 dòng: heading §4 nối điều kiện
  *"valid while the schema stays backward-compatible with the previous image"*; thân §4 mở
  đầu bằng slot bắt buộc 3 disposition (image-tag · expand-contract phase — name the phase ·
  backup-restore + RTO + data-loss window) lặp đúng bộ từ vựng Exit Criteria; RELEASE_NOTES
  §4 và §8 promote link về §4 nên tự thừa hưởng.
- **Rà lại `/hotfix` (lượt 2) — gỡ ngôn ngữ phiên-làm-việc rò vào file kit** — bản vá các
  lượt trước nguyên vẹn (triage row, affected users 4/4, HOTFIX_MODE 2/2); chuỗi ba-đầu
  đường-lui khớp đúng vai (deploy = luật, RUNBOOK §4 = slot, hotfix = reader); Step 5
  *"revert < 1 minute"* trích *"per `/deploy` §Rollback"* nên tự thừa hưởng điều kiện mới.
  Một residue do chính đợt audit tạo: hàng triage ghi *"(Exit-Criteria requirement **since
  the `/deploy` audit**)"* — "the /deploy audit" là lịch sử phiên làm việc, không phải khái
  niệm kit; người dùng kit không thể biết "audit nào". Quét toàn kit (loại trừ audit
  trail/log/columns, `composer audit`, `npm audit`…) xác nhận đây là chỗ rò **duy nhất** →
  sửa word-level thành *"(a `/deploy` Exit-Criteria requirement)"* — tên bất biến của luật
  thay cho mốc sự kiện phiên; CORE file tự đứng, không tham chiếu quá trình tạo ra nó.
- **Rà lại `/debug` (lượt 2) — bảng Rationalizations nhận hàng chặn "nới assertion"** —
  bản vá lượt đầu nguyên 4/4 (A-xx 4-ngả, Xdebug/PHP, boundary test-code). Khe hở duy nhất:
  `/debug` là nơi **duy nhất được sửa test code trong `/test`** — đúng chỗ cám dỗ *"assertion
  chặt quá — nới ra cho xanh"* phát sinh dưới áp lực; bảng §Common Rationalizations chặn họ
  hàng của nó (*"It's just flaky"*, *"Let's just retry"*) nhưng thiếu chính nó, trong khi đổi
  expectation LÀ một quyết định behavior (luật A-xx của chính lệnh) và nới một assert E2E
  (bỏ re-assert sau reload vì "reload làm nó flaky") là âm thầm phá E2E contract. Vá +1 hàng
  nối về hai luật sẵn có (A-xx + `verify.md` §Phase 3) — khép **tam giác test-code**:
  test-engineer *viết* đúng bar (ví dụ round-trip) · code-reviewer *soát* đúng bar
  (anti-vacuous) · debugger *sửa* không được hạ bar.
- **Rà lại `/simplify` (lượt 2) — điểm mù ngoài-test-net thứ hai: cơ chế NFR** — bản vá lượt
  đầu nguyên 4/4; §Identify Opportunities được minh oan (8 pattern đều cấu trúc thuần, không
  dạy gỡ cache). Chuỗi NFR-xx vừa khép làm lộ điểm mù cùng cấu trúc với public-surface (vá
  lượt đầu): code hiệu năng (`AsNoTracking`, compiled query, cache, index, rate limiter)
  **trông giống hệt complexity thừa**, gỡ nó → **toàn suite vẫn xanh** (ngưỡng đo ở `/verify`
  Phase 4, không trong test net) — nhưng nó chính là mechanism `/arch` cam kết trong bảng NFR
  keyed và `/plan` đã giao task. Chesterton's Fence bảo "investigate" nhưng danh sách điều tra
  (git history · tests · comments · hỏi team) thiếu đúng artifact trả lời bằng máy — `grep NFR
  simplify.md` = 0. Vá +1 bullet vào danh sách investigate (đặt TRƯỚC "Ask team members" —
  tra bảng trước, hỏi người sau): *"budget, not complexity — 'all tests still green' proves
  nothing here"*, tựa vào bảng NFR-mechanism + Red Flag B5 sẵn có. Cặp điểm-mù-ngoài-net của
  lệnh giờ khép đủ: public surface (consumer không hiện trong net) + NFR mechanism (ngưỡng
  không hiện trong net).
- **Rà lại `/inspect` (lượt 2) — chuỗi records nhận mắt ops** — bản vá lượt đầu nguyên 3/3
  (DB-resident routing, hàng Schema drift, chốt môi trường write-probe); "NFR" generic ở
  Phase 0 được minh oan (artifact tự mang khóa NFR-xx nên citation chảy tự nhiên). Một nguồn
  thiếu: Purpose khai câu hỏi ops thuộc phạm vi (*"how is Y configured?"*) nhưng chuỗi truy
  vết Phase 1 dừng ở RELEASE_NOTES — `DEPLOY_RUNBOOK` = 0 toàn file, trong khi nó vừa thành
  record **có cấu trúc bắt buộc** (§3 bảng smoke từng service · §4 câu khai đường-lui — slot
  bắt buộc từ lượt `/deploy`); câu hỏi *"release này rollback bằng đường nào?"* có câu trả
  lời tier-Records nằm đúng ở đó, agent theo chuỗi cũ sẽ trả lời từ nguồn mỏng hơn hoặc nhảy
  sang live tier (vốn opt-in). Vá 1 dòng: chèn mắt `DEPLOY_RUNBOOK.md (§3 + §4)` vào chuỗi,
  đứng đúng thứ tự vòng đời (sau verify, trước release notes).
- **Rà lại `/discover-system` (lượt 2 — KHÉP TRỌN HAI VÒNG cho toàn bộ 20 lệnh)** — bản vá
  lượt đầu nguyên 3/3 (event-catalog bước sinh + gate item, owner user-supplied); 4 view
  `specs/system/` không có template là **thiết kế có chủ ý** (Phase 3b khai inline chính
  xác + gate cưỡng chế cấu trúc + view regenerate-only — được minh oan). Một bất đối xứng:
  trong 4 view Phase 3b, `requirements-map` có `{service: @US}`, `goals-catalog` có
  *"labeled by source"*, `glossary` quote cả hai — riêng **`nfr-catalog` im lặng** về
  chống đụng-ID, vì câu đó viết từ thời NFR chưa có khóa; sau chuỗi NFR-xx vòng 2, mọi
  repo đều mang `NFR-01…` → view gom side-by-side các hàng key đụng nhau mà không khai
  gắn nguồn. Vá 1 dòng word-level: *"every service's `NFR-xx` rows side by side, **labeled
  by source** (ids collide across repos — same discipline as `G-xx` above)"* — bốn view về
  cùng một chuẩn, vế `⚠️ NFR inconsistency` nguyên văn.
- **`.gitignore`** — chặn tài sản nội bộ công ty (`.claude/local/doc-templates/`,
  `newdocs/`) khỏi repo public; `.claude/local/README.md` + `KIT_DEVIATIONS.md` vẫn tracked.
- **Mặt tiền** — `README.md`/`README_VN.md` mở đầu bằng đoạn hook "vibe-coding đánh đổi
  kiểm soát" trước mục What-is-this. Thêm 2 checklist cho người mới:
  `getting-started-brownfield.md` (Bước 0 chọn cách cài 1-repo vs workspace · Phase A
  onboard 1 lần `/discover → /spec reverse → /arch reverse → /infra` + `/scan` khuyến nghị,
  nêu rõ vì sao KHÔNG chạy `/test`/`/verify`/`/deploy` ở Phase A · Phase B bảng B1–B5 rút
  gọn + sai lầm hay gặp) và `getting-started-greenfield.md` (bảng 12 bước + gate 1 dòng/bước);
  chỉ chứa thứ tự + link, không nhân bản chi tiết lệnh — canon vẫn ở `CLAUDE.md` +
  `brownfield-pipeline.md`; móc link từ README ×2 (§Two modes) + quick-start (đầu file +
  bảng tra cứu).
- **Audit vòng 3 (2026-08-11) — rà per-command "vai trò + phụ thuộc + tối ưu" trên 20/20
  lệnh** — ~46 edit nhỏ + 6 template mới, không xóa nội dung; `/inspect` clean bill. Ba khuôn
  xuyên suốt: (1) **spawn-prompt mang đủ dữ kiện hội thoại/pre-computed** mà sub-agent không
  đọc được từ đĩa — NFR list (`/spec`) · Mode/flow B1–B5 (`/arch` `/plan` `/review`) ·
  delta-vs-baseline (`/secure`) · `SCAN_DIFF_BASE` (`/scan`) · `Scope:` 3 chế độ (`/verify`,
  `/hotfix` nối tên `B4 hotfix`) · mệnh đề A-xx-return khép bộ ba `/build` `/fix-issue`
  `/debug` · target-repo + Service id (`/discover`) · Mode/CHANGED-list/owner
  (`/discover-system`) — và cố tình KHÔNG thêm khi mode suy được từ đĩa (`/infra` `/docs`);
  (2) **vá drift canonical-vs-summary**: `EnsureCreatedAsync` → `Database.MigrateAsync()`
  (bảng migration `build.md` + fixture test-engineer — migration tự nó là thứ được test) ·
  `php.sh` vào `scan.md` (đổi diễn đạt sang auto-discovery chống tái diễn) · RUNBOOK 7→8
  section ở gate `/deploy` · lệnh build của RM agent về canonical path `IMAGE_TAG` + pointer
  thứ-tự-bước · Impact Analysis thiếu ở PM §Deliverables · bộ ba scenario-coverage /
  anti-vacuous / dual-parity sync đủ 4 bản code-review (command/agent/checklist/skill, bằng
  pointer không nhân bản) · chuẩn skip-test tuyệt đối (TE agent khớp Gate 6) · quick-view
  label Gate 9 (BE agent) · link hỏng trong template Getting Started (TW agent) · khối
  Target 2 thiếu `Audience:`/`Scope:` (MAPPING_MANIFEST) · Permission Matrix nối vào input
  `/secure` (hợp đồng cross-file 2 chiều với `/spec`); (3) **vá footgun lệnh shell trong ví
  dụ**: `git add .` → stage đích danh (build Step 5), `git checkout -- .` → revert đích danh
  (simplify Step 6 — `-- .` xóa cả việc dở không liên quan). Kèm **6 template fill-only mới
  `templates/system/`** (journey · event-catalog · 4 view `specs/system/`) — lời hứa "copy
  and fill, do not re-author" của `/discover-system` đủ 10/10 file output.
- **Đồng nhất ngôn ngữ kit source (English) + token trung lập (2026-08-12)** — dịch 2 section
  residue tiếng Việt sang English: `database-oracle.md` §Reverse-engineering (**đồng thời sửa
  câu "MCP làm fallback" còn sót — mâu thuẫn với quyết định loại MCP khỏi transport ladder
  2026-08-07**, thay bằng pointer về §Phase 1b ladder) và `database-mongodb.md` §H.1; hai chuỗi
  output hardcode tiếng Việt đổi sang English kèm ghi chú *phrased per Output Language*
  (watermark `--draft` của `/export-docs`, inference-basis `📝P-nn` của BA agent); marker
  handoff **`[CẦN <role>]` → `[NEEDS <role>]`** đồng bộ 4 file (spec · export-docs · BA agent ·
  MAPPING_MANIFEST) — artifact của dự án English-output không còn mang token Việt. Lưu ý
  migration: doc-templates/manifest local đã copy trước đó cần tự cập nhật enum On-missing
  theo token mới; các bản export cũ giữ `[CẦN]` cho tới lần re-export kế tiếp.

## [1.5.0] — 2026-07-19

> Bản này thêm **Workspace Mode** — MỘT bộ kit đặt ở thư mục cha của sản phẩm nhiều repo
> (`myproject/.claude`) dùng chung cho mọi repo con: phiên làm việc mở ở workspace, mọi
> lệnh tự xác định repo đích rồi ghi output vào đúng repo đó; repo con chỉ giữ CONFIG
> (`PROJECT_PROFILE.md`). **Backward-compatible tuyệt đối**: không khai `Mode: workspace`
> → hành vi kit không đổi một ly.

### Added
- **`CLAUDE.md` §Workspace Mode** — meta-mode `workspace` + `Repos:` registry cho profile
  thư mục cha; scope-resolution 4 bước (xác định repo đích — không chắc thì HỎI → đọc
  per-repo profile → mọi path/git theo repo đích → cross-repo: chốt contract trước,
  provider → consumer); workspace disk-check gắn mọi gate (artifact không rơi ở workspace
  root, `git status` repo không-đích sạch).
- **`/discover` Phase 0 — Workspace scope check** — detect-once-then-declare: ≥2 git repo
  con + root không có business code → liệt kê, hỏi xác nhận + duyệt `Service id` → ghi
  registry → lặp Phase 1–4 per repo, output vào từng repo.
- **Khối Workspace Mode chuẩn trên 16 lệnh** (`arch` `plan` `secure` `build` `test`
  `review` `scan` `infra` `docs` `verify` `deploy` `fix-issue` `hotfix` `debug` `simplify`
  `inspect`) — chỉ trỏ về §Workspace Mode; logic sống đúng một chỗ.
- **`microservices-multirepo.md` Pattern C — Workspace-kit** — layout khuyến nghị cho
  cross-repo hằng ngày; A/B giữ nguyên cho kit-in-repo.

### Changed
- **`/spec` Phase 0 Mode Auto-Detection** — thêm workspace precondition: resolve repo đích
  trước, 3 tín hiệu (ARGS/CODE/DISCOVERY) dò BÊN TRONG repo đích — chặn false-greenfield
  khi CODE probe chạy ở workspace root (nơi không có build manifest).
- **`/discover-system`** — danh sách service đọc từ `Repos:` registry (canonical); dò thư
  mục hạ xuống làm cross-check → cờ `⚠️ unregistered repo` / dangling registry row.
- **`microservices-multirepo.md`** — chính-xác-hoá nguyên tắc: "Do NOT lump N repos into
  a single /discover run" → "không gộp N repo vào MỘT Profile" (workspace mode vẫn
  per-repo: mỗi repo một profile, một discovery riêng).
- **`PROJECT_PROFILE.md` (template)** — thêm tình huống dùng thứ 3 (sản phẩm nhiều repo)
  + giá trị `workspace` vào bảng Mode (chỉ hợp lệ ở thư mục cha).
- Mặt tiền: `quick-start.md` hàng `/inspect` bổ sung ví dụ tra version tính năng
  (*"export CSV được thêm ở version nào, gồm những scenario gì?"*) + chỉ nguồn đọc
  (`SPEC.md` §Revision History · `CHANGELOG.md`/`RELEASE_NOTES`).

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
