# Getting Started — Greenfield (xây dự án từ số 0)

> **Dành cho ai / để làm gì:** bạn bắt đầu một dự án **chưa có code** và muốn biết **gõ lệnh gì, theo thứ tự nào** từ ý tưởng đến bản chạy thử đầu tiên trên staging (máy chủ thử nghiệm). Đây là **một pipeline tuyến tính 12 bước**. File này chỉ là checklist về thứ tự lệnh kèm link tra cứu; chi tiết từng lệnh nằm trong tài liệu được trỏ tới.
>
> 💡 Không muốn nhớ lệnh? Chỉ cần **mô tả việc bằng ngôn ngữ tự nhiên** ("tôi muốn xây app đặt lịch phòng họp…") — Claude tự xác định luồng và trả về checklist (xem [quick-start.md](quick-start.md)).

---

## Bước 0 — Cài kit

1. Copy thư mục `.claude/` vào **thư mục gốc của repo (thư mục dự án) mới** — cách lấy kit xem [README_VN.md](README_VN.md) §Bắt đầu nhanh.
2. Sửa nội dung tập tin [.claude/PROJECT_PROFILE.md](.claude/PROJECT_PROFILE.md):
   - Sửa dòng `Mode:` thành **`greenfield`** (kit khai sẵn mặc định là `brownfield`).
   - Khai tech stack (bộ công nghệ sẽ dùng) — các mục bỏ trống thì sẽ dùng các giá trị mặc định: C# 12 + ASP.NET Core 8 + EF Core 8 + SQL Server + Next.js.
   - Khai `Output Language` nếu muốn các artifact (tài liệu do kit sinh ra) bằng ngôn ngữ khác tiếng Việt.

   *(Quên bước này cũng không sao — lệnh `/spec` tự phát hiện `Mode: brownfield` không khớp với repo rỗng (greenfield), đề nghị sửa và chỉ cập nhật khi bạn xác nhận.)*

---

## Pipeline 12 bước — chạy theo đúng thứ tự

Mở Claude Code tại thư mục dự án, bắt đầu bằng lệnh: **`/spec <mô tả yêu cầu của bạn>`**. Mỗi bước kết thúc bằng một cổng kiểm soát chất lượng (Quality Gate) — bạn duyệt bằng cách trả lời ngay trong chat (đồng ý thì sang bước sau, chưa ưng thì nêu chỗ cần chỉnh). **Cổng báo đỏ thì không đi tiếp** — bảo Claude sửa rồi chạy lại đúng bước đó, không nhảy sang bước kế.

| # | Lệnh | Làm gì (1 dòng) | Cổng chặn trước bước sau |
|---|------|-----------------|--------------------------|
| 1 | `/spec <yêu cầu>` | Viết User Stories + Acceptance Criteria (yêu cầu theo góc nhìn người dùng + tiêu chí nghiệm thu); có UI thì kèm ASCII wireframes, thêm `--prototype` nếu cần bản click thử | **Bạn/stakeholder duyệt spec** (Gate 1 — luôn chờ người ký) |
| 2 | `/arch` | Thiết kế kiến trúc, viết ADR (bản ghi quyết định kiến trúc), định nghĩa API contract | **Bạn duyệt** kiến trúc Claude trình bày; có đủ ADR + API contract |
| 3 | `/plan` | Chia spec thành các task nhỏ có thứ tự phụ thuộc | Mỗi task là một mẩu tính năng hoàn chỉnh, chạy được đầu-cuối (vertical slice), quan hệ phụ thuộc rõ ràng |
| 4 | `/secure`* | Lập threat model (bản phân tích nguy cơ bảo mật, theo phương pháp STRIDE) trước khi code | Không còn nguy cơ bảo mật nghiêm trọng (critical) |
| 5 | `/build` | Code theo TDD (viết test trước, code sau), làm từng mẩu tính năng hoàn chỉnh, luôn build được | Toàn bộ unit test đều pass, code biên dịch không lỗi |
| 6 | `/test` | Kiểm thử với database/dịch vụ ngoài thật (TestContainers/E2E — cần Docker) | Coverage (tỷ lệ code được test) ≥ 80%, toàn bộ test đều pass |
| 7 | `/review`* | Review code theo 5 trục | Đã xử lý hết feedback nghiêm trọng (critical) |
| 8 | `/scan`* | Quét lỗ hổng bảo mật sau khi code xong | Không còn lỗ hổng critical/high |
| 9 | `/infra` | Đóng gói Docker để chạy local | `docker compose up` chạy được, các service đều healthy |
| 10 | `/docs`* | Sinh tài liệu dự án | Có đủ 4 tài liệu: getting-started · API · deploy · troubleshooting; README đã cập nhật |
| 11 | `/verify`* *(khuyến nghị mạnh)* | Kiểm từng acceptance criteria trên **đúng bản build sẽ phát hành** | 100% tình huống nghiệm thu (scenario) đều có test kiểm chứng tương ứng và đều pass |
| 12 | `/deploy` | Đưa lên **staging** (`STAGED`) — bước tự động cuối của kit | Đưa lên production là bước làm tay, sau khi người quyết định đi tiếp hay dừng (go/no-go) |

<sub>* = bước tùy chọn (optional), nhưng **đã chạy thì cổng chặn (blocking) — phải pass mới đi tiếp**. Bộ bắt buộc: `/spec` `/arch` `/plan` `/build` `/test` `/infra` `/deploy`. Làm production: khuyến nghị chạy đủ 12.</sub>

**Theo dõi tiến độ:** mở tập tin `plans/todo.md` (sinh ra khi chạy lệnh `/plan`) bất cứ lúc nào — các task làm xong sẽ được tick `- [x]`.

---

## Sau lần deploy đầu — tính năng tiếp theo

Dự án của bạn giờ thuộc nhóm "đã có code đang chạy" (brownfield). Chạy `/discover` một lần: kit nhận ra dự án do chính nó xây nên chỉ quét nhanh để tạo chỉ mục điều hướng (tập tin `docs/CODEBASE_MAP.md`) — vài phút, không làm lại tài liệu — và đề nghị đổi `Mode:` sang `brownfield`.

Sau đó gõ `/spec <tính năng mới>` như bình thường: spec mới chỉ là phần bổ sung (DELTA), không viết lại phần cũ. Nhịp làm việc từ đây theo [getting-started-brownfield.md](getting-started-brownfield.md) §Phase B.

---

## Sai lầm hay gặp của người mới

1. **Nhảy thẳng vào `/build` khi chưa có spec/plan** → mất truy vết spec → code → test; kit sẽ yêu cầu quay lại đúng thứ tự.
2. **Duyệt spec qua loa ở Gate 1** → mọi bước sau xây trên yêu cầu sai; sửa ở Gate 1 là rẻ nhất.
3. **Bỏ `/test` vì "unit test ở `/build` xanh rồi"** → `/build` chỉ test với dữ liệu giả trong bộ nhớ (in-memory); `/test` mới kiểm với database/dịch vụ ngoài thật (bắt các bug chỉ lộ ra khi chạy thật).
4. **Chạy bước tùy chọn rồi bỏ qua cổng đỏ của nó** → tùy chọn là *quyền không chạy*, không phải *quyền fail*: đã chạy thì cổng chặn (blocking).
5. **Trả lời mơ hồ khi Claude hỏi ở `/spec`** → hỏi-không-đoán là cơ chế chống "spec bịa"; câu trả lời của bạn chính là spec.

## Tra cứu tiếp

| Cần gì | Đọc |
|---|---|
| Toàn cảnh pipeline, các cổng, các agent | [`.claude/CLAUDE.md`](.claude/CLAUDE.md) *(tiếng Anh)* |
| Đổi stack (Node.js, PHP/Laravel, PostgreSQL, ELK…) | [.claude/PROJECT_PROFILE.md](.claude/PROJECT_PROFILE.md) + [`.claude/rules/overrides/`](.claude/rules/overrides/) *(tiếng Anh)* |
| Dự án đã có code sẵn | [getting-started-brownfield.md](getting-started-brownfield.md) |
