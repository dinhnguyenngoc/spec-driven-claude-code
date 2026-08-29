# Getting Started — Brownfield (repo đã có code / đang chạy production)

> **Dành cho ai / để làm gì:** bạn lần đầu đem kit vào một dự án **đã có code** và muốn biết cần **bắt đầu từ đâu, gõ lệnh gì, theo thứ tự nào** — từ lúc onboard (Phase A, chạy **một lần**) đến khi phát triển tính năng hằng ngày (Phase B, lặp lại **mỗi khi có thay đổi**). Tập tin này là checklist về thứ tự lệnh kèm link tra cứu; chi tiết từng lệnh nằm trong tài liệu được trỏ tới.
>
> 💡 Bạn không muốn nhớ lệnh? Vẫn có thể chỉ **mô tả công việc cần làm bằng ngôn ngữ tự nhiên** — Claude tự xác định luồng và trả về checklist (xem [quick-start.md](quick-start.md)).

---

## Bước 0 — Cài kit (chọn đúng 1 trong 2 cách)

> Chưa có kit? Xem cách lấy ở [README_VN.md](README_VN.md) §Bắt đầu nhanh.

| Sản phẩm của bạn | Cách cài đặt | Sau đó |
|---|---|---|
| **1 repo** | Copy thư mục `.claude/` vào **thư mục gốc của repo** | Lệnh `/discover` sẽ tự điền `PROJECT_PROFILE.md` (mặc định kit đã khai `Mode: brownfield`) |
| **Nhiều repo** (microservices) | Copy thư mục `.claude/` vào **thư mục cha** chứa các repo — KHÔNG copy vào từng repo con | Lệnh `/discover` chạy tại thư mục cha: tự phát hiện repo con, hỏi xác nhận, sinh workspace profile (`Mode: workspace`) + tập tin cấu hình rút gọn cho từng repo con. Chi tiết: [`.claude/CLAUDE.md`](.claude/CLAUDE.md) §Workspace Mode |

> Muốn các artifact (tài liệu do kit sinh ra) bằng ngôn ngữ khác tiếng Việt thì sửa `Output Language` trong tập tin [.claude/PROJECT_PROFILE.md](.claude/PROJECT_PROFILE.md) (1 dòng).

---

## Phase A — Onboard (chạy MỘT LẦN, chỉ đọc — không sửa code nghiệp vụ)

Mục đích: dựng **bộ tài liệu làm nền tảng (baseline) khớp với code thật** để mọi thay đổi sau này có cơ sở để đối chiếu. Thứ tự bắt buộc:

| # | Lệnh | Làm gì | Bạn nhận được |
|---|------|-----------------|----------------|
| 1 | `/discover` | Khảo sát tech stack/cấu trúc dự án, xác nhận build/chạy được, ghi nhận tình trạng hệ thống (health) và các dấu hiệu rủi ro (red-flag) | `PROJECT_PROFILE.md` (được cập nhật) + `docs/CODEBASE_MAP.md` (mục lục các endpoint — điểm truy cập của hệ thống) |
| 2 | `/spec` | **REVERSE** (chế độ dựng tài liệu từ code có sẵn) — sinh ra User Stories **đúng như hệ thống đang chạy** (as-is) từ code (nếu hệ thống lớn thì làm từng lát bằng `--scope`) | `specs/SPEC.md` baseline (`v1.0 Baseline`) + `specs/EVIDENCE.md` (bản đồ bằng chứng: mỗi user story trỏ tới đúng dòng code sinh ra nó, để kiểm chứng lại được) |
| 3 | `/arch` | **REVERSE** — mô tả kiến trúc đúng như đang có + **ADR (bản ghi quyết định kiến trúc)** suy ra từ code | `architecture/` làm nền tảng (baseline) |
| 4 | `/infra` | **REVERSE-BOOTSTRAP** (dựng mới theo đúng hiện trạng) — dựng Docker chạy local khớp với code thật | `docker/` + `docker-compose.yml` (chạy được `docker compose up`) |
| 5 | `/scan` *(khuyến nghị, độc lập)* | Chụp baseline bảo mật trước khi bắt đầu chỉnh sửa / bổ sung tính năng cho dự án | `security/SCAN_REPORT.md` |
| 6 | `/discover-system` *(chỉ chạy khi có nhiều repo — chạy 1 lần tại thư mục cha, SAU khi các repo xong bước 1–4)* | Gộp discovery từng repo thành bản đồ hệ thống của toàn bộ dự án | `architecture/system/` + `specs/system/` |

**⛔ Phase A KHÔNG chạy `/test`, `/review`, `/verify`, `/deploy`.** Lý do: chưa có spec cho thay đổi code thì không có "đúng" để kiểm tra — Phase A chỉ **đo/mô tả**, không kiểm đúng-sai (xem [`.claude/rules/brownfield.md`](.claude/rules/brownfield.md)); production vốn đang chạy rồi nên cũng không có "first deploy". Các lệnh đó thuộc Phase B, theo từng thay đổi.

---

## Phase B — Phát triển tính năng (lặp lại MỖI khi có thay đổi)

Chọn luồng theo việc, nhớ **các lệnh chung** ở cuối chu trình: `/build → /test → /review → /verify → /deploy`.

| Việc của bạn | Luồng | Checklist lệnh |
|---|---|---|
| **Thêm tính năng MỚI** | **B1** | **Lõi bắt buộc:** `/spec <mô tả>` (chỉ mô tả phần tính năng mới) → `/arch` (để đối chiếu với baseline kiến trúc từ Phase A, chỉ xác nhận "không đổi kiến trúc", thường rất nhanh; nếu phát hiện CÓ đổi thì xem mục *Khi nào đổi kiến trúc?* bên dưới) → `/plan` → `/build` → `/test` → `/deploy` (staging — khi muốn đóng gói 1 hoặc nhiều tính năng mới cho release)<br>**Tăng cường (tùy chọn):** `/secure` (nếu mở kết nối ra ngoài: thanh toán / đăng nhập qua bên thứ ba (SSO) / webhook) · `/review` · `/scan` · `/verify` (khuyến nghị trước deploy) |
| **Sửa tính năng ĐÃ CÓ** | **B2** | Thứ tự các bước giống như B1, khác ở chỗ bạn đang sửa thứ **đang chạy**, nên có 2 lớp bảo hiểm: **(1)** trước khi đổi code, `/build` tự viết test "chụp" **cách hệ thống đang hoạt động** (behavior) và chạy PASS (gọi là *characterization test* — không phải lệnh riêng); sau khi sửa, test nào fail sẽ chỉ ra đúng chỗ hành vi bị đổi, phát hiện ngay thay đổi ngoài ý muốn; **(2)** `/test` kiểm tra thêm rằng client đang gọi API/đọc dữ liệu cũ vẫn chạy y như trước — không phá vỡ giao kết cũ mà client đang dựa vào (*backward-compat*) |
| Fix bug chưa release | **B3** | `/fix-issue` → `/test` → `/review` → `/verify` → `/deploy` (bỏ spec/arch/plan — không có yêu cầu nghiệp vụ mới) |
| Sự cố trên production | **B4** | `/hotfix` (câu hỏi đầu tiên: quay về bản cũ (rollback) hay vá tiếp lên bản đang chạy (fix-forward)) — lệnh `/hotfix` tự gọi lần lượt `/fix-issue` + `/verify` + `/deploy` |
| Nâng cấp kiến trúc / công nghệ | **B5** | `/arch` (thiết kế lại — redesign + ADR bắt buộc) → `/plan` (strangler-fig) → các lệnh chung — **không viết lại toàn bộ một lần (big-bang rewrite)**. 3 lối vào (tính năng kéo theo · chủ động đổi công nghệ · kiến trúc không đáp ứng) — chi tiết ở mục *Khi nào đổi kiến trúc?* ngay dưới |

<sub>Tùy chọn (optional) = *quyền không chạy*, không phải *quyền fail*: **đã chạy thì cổng chặn (blocking)**. `/test` và `/arch` không thuộc nhóm tùy chọn.</sub>

**Câu hỏi hay gặp nhất — "test/review chạy trên toàn repo hay phần tôi sửa?"** → **VIẾT theo các tính năng thay đổi, CHẠY toàn bộ**: test mới chỉ viết cho vùng đổi, nhưng test case sẵn có chạy full mỗi vòng; `/review` chỉ review các thay đổi. Chi tiết + cây quyết định đầy đủ B1–B5: [`.claude/references/brownfield-pipeline.md`](.claude/references/brownfield-pipeline.md).

### Khi nào đổi kiến trúc? — 3 lối vào B5

> Mục này dành cho người ra quyết định kiến trúc. Lần đầu dùng kit bạn có thể bỏ qua — khi nào `/arch` báo cần đổi kiến trúc thì quay lại đọc.

Mọi thay đổi kiến trúc đều đi qua **B5 (ADR bắt buộc)**, chỉ khác lối vào:

| Lối vào | Đi thế nào |
|---|---|
| **1. Tính năng B1/B2 kéo theo** — lộ ra tại `/arch` nếu phát hiện CẦN thay đổi kiến trúc | Phần chi tiết ngay bên dưới — tách 2 đợt hoặc gộp 1 đợt |
| **2. Chủ động thêm/đổi công nghệ** (thêm Redis, thêm Kafka, đổi ELK ↔ Grafana/Prometheus…) | **B5 trực tiếp**: `/arch` redesign + ADR — căn cứ (số đo hoặc lý do chiến lược) ghi trong ADR, không phải "muốn là thêm". Đổi công nghệ **ngoại vi** thì cập nhật thêm [.claude/PROJECT_PROFILE.md](.claude/PROJECT_PROFILE.md) để override tương ứng được kích hoạt |
| **3. Kiến trúc hiện tại không đáp ứng** — red-flag ghi nhận từ Phase A, hoặc trigger đo được khi vận hành (P95 vượt SLO, DB CPU > 70%, team > 15 dev…) | Red-flag từ Phase A **không sửa ngay trong Phase A** (Phase A read-only) mà đưa vào backlog; mỗi hạng mục khi được ưu tiên là **một B5**; việc lớn (tách service, thêm worker / API gateway) chia nhiều đợt strangler-fig |

**Chi tiết Lối vào 1 — đang B1/B2 thì phát hiện cần đổi kiến trúc:** `/spec` đã ký xong, đến `/arch` thì phát hiện thiết kế cần vượt baseline (vd tính năng cần thêm Redis cache). **Đây là gate làm đúng việc, không phải sự cố** — và **không phải làm lại `/spec`**: spec mô tả WHAT/WHY nên giữ nguyên; chính NFR trong spec (vd "P95 < 200ms") là căn cứ cho ADR. `/arch` chuyển sang chế độ **redesign** ngay trong lượt đó (lối vào B5): sinh ra ADR + kế hoạch migration, Gate 2 duyệt. Từ đây chọn 1 trong 2 cách đi tiếp:

| Cách | Khi nào chọn | Luồng tiếp theo |
|---|---|---|
| **Tách 2 đợt** *(khuyến nghị khi thêm/thay thành phần hạ tầng: Redis, Kafka, đổi DB…)* | Muốn mỗi release một loại rủi ro, rollback độc lập | **Đợt 1 — đổi kiến trúc (B5, nghiệp vụ KHÔNG đổi):** `/plan` (strangler-fig) → `/build` (+ `/infra` cập nhật compose) → `/test` (test case cũ phải xanh — bằng chứng "không gì thay đổi") → `/deploy`.<br /> **Đợt 2 — đổi tính năng (B1/B2 tiếp tục):** `/arch` (conformance — giờ PASS vì baseline đã có Redis) → `/plan` → `/build` → `/test` → `/deploy` |
| **Gộp 1 đợt** | Kiến trúc thay đổi nhỏ (1 ADR nhẹ — thêm 1 interface/1 bảng), hoặc deadline ép và chấp nhận đánh đổi (**ghi rõ vào ADR**) | MỘT `/plan` với 2 nhóm task có thứ tự: nhóm đổi kiến trúc trước → nhóm đổi tính năng (phụ thuộc vào nhóm đổi kiến trúc). Nếu đúng thì release — không thì rollback cả gói (2 nhóm) |

Chi tiết B5 + strangler-fig: [`brownfield-pipeline.md` §B5](.claude/references/brownfield-pipeline.md).

---

## Sai lầm hay gặp của người mới

1. **Nhiều repo nhưng copy kit vào từng repo con** → sai mô hình; một kit ở thư mục cha, repo con chỉ nhận tập tin cấu hình do lệnh `/discover` sinh.
2. **Yêu cầu spec cho vùng code chưa từng được dựng tài liệu** (baseline mới phủ một phần — `Coverage: partial`) → `/spec` sẽ dừng và yêu cầu dựng tài liệu vùng đó trước (`--scope`) — đó là hành vi đúng, đừng ép bỏ qua.
3. **Quên characterization test ở B2** → sửa code mà không có test "chụp" hiện trạng trước đó, nên nếu lỡ làm đổi một hành vi không định đổi thì không gì báo cho bạn biết — chỉ phát hiện khi user gặp lỗi.
4. **Refactor "tiện tay" ngoài phạm vi thay đổi** → kit chặn có chủ đích (No Gratuitous Refactor — không refactor ngoài phạm vi thay đổi); nợ kỹ thuật ghi backlog, xử lý bằng `/simplify` riêng.

## Tra cứu tiếp

| Cần gì | Đọc |
|---|---|
| Dự án xây từ số 0 | [getting-started-greenfield.md](getting-started-greenfield.md) |
| Sản phẩm nhiều repo | [`.claude/references/microservices-multirepo.md`](.claude/references/microservices-multirepo.md) *(tiếng Anh)* |
| Toàn cảnh pipeline, các cổng, các agent | [`.claude/CLAUDE.md`](.claude/CLAUDE.md) *(tiếng Anh)* |
| Kỷ luật legacy (characterization, backward-compat, ADR) | [`.claude/rules/brownfield.md`](.claude/rules/brownfield.md) *(tiếng Anh)* |
| Cây quyết định + chi tiết từng luồng B | [`.claude/references/brownfield-pipeline.md`](.claude/references/brownfield-pipeline.md) *(tiếng Anh)* |

