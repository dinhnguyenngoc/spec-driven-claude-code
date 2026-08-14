# Getting Started — Brownfield (repo đã có code / đang chạy production)

> **Dành cho ai / để làm gì:** bạn lần đầu đem kit vào một dự án **đã có code** và muốn biết **gõ lệnh gì, theo thứ tự nào** — từ ngày onboard (Phase A, chạy **một lần**) đến nhịp phát triển tính năng hằng ngày (Phase B, lặp **mỗi thay đổi**). File này chỉ là checklist thứ tự + link; chi tiết từng lệnh nằm trong tài liệu được trỏ tới.
>
> 💡 Không muốn nhớ lệnh? Vẫn có thể chỉ **mô tả việc bằng ngôn ngữ tự nhiên** — Claude tự route ra checklist (xem [quick-start.md](quick-start.md)). File này dành cho người muốn chủ động nắm thứ tự.

---

## Bước 0 — Cài kit (chọn đúng 1 trong 2 cách)

| Sản phẩm của bạn | Cách cài | Sau đó |
|---|---|---|
| **1 repo** | Copy folder `.claude/` vào **gốc của repo** | `/discover` sẽ tự điền `PROJECT_PROFILE.md` (mặc định kit đã khai `Mode: brownfield`) |
| **Nhiều repo** (microservices) | Copy `.claude/` vào **thư mục cha** chứa các repo — KHÔNG copy vào từng repo con | `/discover` chạy tại thư mục cha: tự phát hiện repo con, hỏi xác nhận, sinh workspace profile (`Mode: workspace`) + profile mỏng cho từng repo con. Chi tiết: [`.claude/CLAUDE.md`](.claude/CLAUDE.md) §Workspace Mode |

> Muốn artifact bằng ngôn ngữ khác tiếng Việt → sửa field `Output Language` trong [.claude/PROJECT_PROFILE.md](.claude/PROJECT_PROFILE.md) (1 dòng).

---

## Phase A — Onboard (chạy MỘT LẦN, read-only trên business code)

Mục đích: dựng **bộ tài liệu baseline khớp code thật** để mọi thay đổi sau này có nền đối chiếu. Thứ tự bắt buộc:

| # | Lệnh | Làm gì (1 dòng) | Bạn nhận được |
|---|------|-----------------|----------------|
| 1 | `/discover` | Khảo sát stack/cấu trúc, xác nhận build/chạy được, chụp health + red-flags | `PROJECT_PROFILE.md` (điền thật) + `docs/CODEBASE_MAP.md` (mục lục endpoint) |
| 2 | `/spec` | **REVERSE** — sinh User Stories **as-is** từ code (hệ lớn → làm từng lát bằng `--scope`) | `specs/SPEC.md` baseline (`v1.0 Baseline`) |
| 3 | `/arch` | **REVERSE** — mô tả kiến trúc đúng như đang có + ADR suy ra | `architecture/` baseline |
| 4 | `/infra` | **REVERSE-BOOTSTRAP** — dựng Docker chạy local khớp code thật | `docker/` + `docker-compose.yml` (chạy được `docker compose up`) |
| 5 | `/scan` *(khuyến nghị, độc lập)* | Chụp baseline bảo mật trước khi bắt đầu sửa gì | `security/SCAN_REPORT.md` |
| 6 | `/discover-system` *(chỉ nhiều repo — chạy 1 lần tại thư mục cha, SAU khi các repo xong bước 1–4)* | Gộp discovery từng repo thành bản đồ hệ thống | `architecture/system/` + `specs/system/` |

**⛔ Phase A KHÔNG chạy `/test`, `/review`, `/verify`, `/deploy`.** Lý do 1 dòng: chưa có spec thì không có "đúng" để kiểm — Phase A chỉ *đo/mô tả* (Measure-vs-Verify, [`.claude/rules/brownfield.md`](.claude/rules/brownfield.md)); production vốn đang chạy rồi nên cũng không có "first deploy". Các lệnh đó thuộc Phase B, theo từng thay đổi.

---

## Phase B — Phát triển (lặp MỖI thay đổi)

Chọn luồng theo việc, nhớ **1 xương sống chung** ở đuôi: `/build → /test → /review → /verify → /deploy`.

| Việc của bạn | Luồng | Checklist lệnh |
|---|---|---|
| **Thêm tính năng MỚI** | **B1** | **Lõi bắt buộc:** `/spec <mô tả>` (chỉ spec phần delta) → `/arch` (conformance — đối chiếu với baseline kiến trúc từ Phase A, chỉ xác nhận "không đổi kiến trúc", thường rất nhanh; nếu phát hiện CÓ đổi → xem mục *Khi nào đổi kiến trúc?* bên dưới) → `/plan` → `/build` → `/test` → `/deploy` (staging — khi đóng đợt release, gộp được nhiều tính năng)<br>**Tăng cường (optional):** `/secure` (nếu mở surface ngoài: payment/SSO/webhook) · `/review` · `/scan` · `/verify` (khuyến nghị trước deploy) |
| **Sửa tính năng ĐÃ CÓ** | **B2** | Như B1, khác ở chỗ bạn đang sửa thứ **đang chạy**, nên có 2 lớp bảo hiểm: **(1)** trước khi đổi code, `/build` tự viết test "chụp" behavior hiện tại và chạy PASS (gọi là *characterization test* — không phải lệnh riêng) → sau khi sửa, test nào fail chỉ ra đúng chỗ behavior bị đổi, phát hiện ngay thay đổi ngoài ý muốn; **(2)** `/test` kiểm thêm rằng client đang gọi API/đọc dữ liệu cũ vẫn chạy y như trước — không vỡ contract hiện hữu (*backward-compat*) |
| Fix bug chưa release | **B3** | `/fix-issue` → `/test` → `/review` → `/verify` → `/deploy` (bỏ spec/arch/plan — không có yêu cầu nghiệp vụ mới) |
| Sự cố trên production | **B4** | `/hotfix` (câu hỏi đầu tiên: rollback hay fix-forward) — orchestrator tự nối `/fix-issue` + `/verify` + `/deploy` |
| Nâng cấp kiến trúc / công nghệ | **B5** | `/arch` (redesign + ADR bắt buộc) → `/plan` (strangler-fig) → xương sống — **không big-bang rewrite**. 3 lối vào (tính năng kéo theo · chủ động đổi công nghệ · kiến trúc không đáp ứng) → mục *Khi nào đổi kiến trúc?* ngay dưới |

<sub>Optional = *quyền không chạy*, không phải *quyền fail*: **đã chạy thì gate là blocking**. `/test` và `/arch` không thuộc nhóm optional.</sub>

**Câu hỏi hay gặp nhất — "test/review chạy trên toàn repo hay phần tôi sửa?"** → **VIẾT theo delta, CHẠY toàn bộ**: test mới chỉ viết cho vùng đổi, nhưng suite sẵn có chạy full mỗi vòng (lưới regression); `/review` chỉ review diff. Chi tiết + cây quyết định đầy đủ B1–B5: [`.claude/references/brownfield-pipeline.md`](.claude/references/brownfield-pipeline.md).

### Khi nào đổi kiến trúc? — 3 lối vào B5

Mọi thay đổi kiến trúc đều đi qua **B5 (ADR bắt buộc)**, chỉ khác lối vào:

| Lối vào | Đi thế nào |
|---|---|
| **1. Tính năng B1/B2 kéo theo** — lộ ra tại `/arch` conformance | Phần chi tiết ngay bên dưới — tách 2 đợt hoặc gộp 1 đợt |
| **2. Chủ động thêm/đổi công nghệ** (thêm Redis, thêm Kafka, đổi ELK ↔ Grafana/Prometheus…) | **B5 trực tiếp**: `/arch` redesign + ADR — căn cứ (số đo hoặc lý do chiến lược) ghi trong ADR, không "muốn là thêm". Đổi công nghệ **ngoại vi** → cập nhật thêm [.claude/PROJECT_PROFILE.md](.claude/PROJECT_PROFILE.md) để override tương ứng kích hoạt |
| **3. Kiến trúc hiện tại không đáp ứng** — red-flag ghi nhận từ Phase A, hoặc trigger đo được khi vận hành (P95 vượt SLO, DB CPU > 70%, team > 15 dev…) | Red-flag từ Phase A **không sửa ngay trong Phase A** (Phase A read-only) → vào backlog; mỗi hạng mục khi được ưu tiên = **một B5**; việc lớn (tách service, thêm worker / API gateway) chia nhiều đợt strangler-fig |

**Lối vào 1 chi tiết — đang B1/B2 thì phát hiện cần đổi:** `/spec` đã ký xong, đến `/arch` thì lượt conformance phát hiện thiết kế cần vượt baseline (vd tính năng cần thêm Redis cache). **Đây là gate làm đúng việc, không phải sự cố** — và **không phải làm lại `/spec`**: spec mô tả WHAT/WHY nên giữ nguyên; chính NFR trong spec (vd "P95 < 200ms") là căn cứ cho ADR. `/arch` chuyển sang chế độ **redesign** ngay trong lượt đó (lối vào B5): sinh ADR + kế hoạch migration, Gate 2 duyệt. Từ đây chọn 1 trong 2 cách đi tiếp:

| Cách | Khi nào chọn | Luồng tiếp theo |
|---|---|---|
| **Tách 2 đợt** *(khuyến nghị khi thêm/thay thành phần hạ tầng: Redis, Kafka, đổi DB…)* | Muốn mỗi release một loại rủi ro, rollback độc lập | **Đợt 1 — nền (B5, behavior KHÔNG đổi):** `/plan` (strangler-fig) → `/build` (+ `/infra` cập nhật compose) → `/test` (suite cũ phải xanh nguyên — bằng chứng "không gì đổi") → `/deploy`. **Đợt 2 — tính năng (B1/B2 tiếp tục):** `/arch` (conformance — giờ PASS vì baseline đã có Redis) → `/plan` → `/build` → `/test` → `/deploy` |
| **Gộp 1 đợt** | Arch delta nhỏ (1 ADR nhẹ — thêm 1 interface/1 bảng), hoặc deadline ép và chấp nhận trade-off (**ghi rõ vào ADR**) | MỘT `/plan` với 2 nhóm task có thứ tự: nhóm nền trước (seam → adapter sau feature-flag) → nhóm tính năng khai phụ thuộc vào nền → xương sống chạy 1 lượt. Một release — rollback là cả gói |

Chi tiết B5 + strangler-fig: [`brownfield-pipeline.md` §B5](.claude/references/brownfield-pipeline.md).

---

## Sai lầm hay gặp của người mới

1. **Chạy `/test`/`/verify` ngay trong Phase A** → chưa có spec để đối chiếu; hãy để chúng cho Phase B.
2. **Quên characterization test ở B2** → sửa code mà không có test "chụp" hiện trạng trước đó, nên nếu lỡ làm đổi một behavior không định đổi thì không gì báo cho bạn biết — chỉ phát hiện khi user gặp lỗi.
3. **Spec DELTA cho vùng chưa từng reverse** (baseline `Coverage: partial`) → `/spec` sẽ STOP và yêu cầu reverse vùng đó trước (`--scope`) — đó là hành vi đúng, đừng ép bỏ qua.
4. **Nhiều repo nhưng copy kit vào từng repo con** → sai mô hình; một kit ở thư mục cha, repo con chỉ nhận CONFIG do `/discover` sinh.
5. **Refactor "tiện tay" ngoài phạm vi thay đổi** → kit chặn có chủ đích (No Gratuitous Refactor); nợ kỹ thuật ghi backlog, xử lý bằng `/simplify` riêng.

## Tra cứu tiếp

| Cần gì | Đọc |
|---|---|
| Toàn cảnh pipeline, gates, agents | [`.claude/CLAUDE.md`](.claude/CLAUDE.md) |
| Cây quyết định + chi tiết từng luồng B | [`.claude/references/brownfield-pipeline.md`](.claude/references/brownfield-pipeline.md) |
| Kỷ luật legacy (characterization, backward-compat, ADR) | [`.claude/rules/brownfield.md`](.claude/rules/brownfield.md) |
| Sản phẩm nhiều repo | [`.claude/references/microservices-multirepo.md`](.claude/references/microservices-multirepo.md) |
| Dự án xây từ số 0 | [getting-started-greenfield.md](getting-started-greenfield.md) |
