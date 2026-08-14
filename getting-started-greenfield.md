# Getting Started — Greenfield (xây dự án từ số 0)

> **Dành cho ai / để làm gì:** bạn bắt đầu một dự án **chưa có code** và muốn biết **gõ lệnh gì, theo thứ tự nào** từ ý tưởng đến bản deploy staging đầu tiên. Greenfield đơn giản hơn brownfield: đúng **một pipeline tuyến tính 12 bước**, không có phase onboard. File này chỉ là checklist thứ tự + link; chi tiết từng lệnh nằm trong tài liệu được trỏ tới.
>
> 💡 Không muốn nhớ lệnh? Chỉ cần **mô tả việc bằng ngôn ngữ tự nhiên** ("tôi muốn xây app đặt lịch phòng họp…") — Claude tự route ra checklist (xem [quick-start.md](quick-start.md)).

---

## Bước 0 — Cài kit

1. Copy folder `.claude/` vào **gốc repo mới**.
2. Sửa [.claude/PROJECT_PROFILE.md](.claude/PROJECT_PROFILE.md): đổi **`Mode: greenfield`** (kit ship mặc định `brownfield`), khai stack dự định (bỏ trống phần nào → dùng base: C# 12 + ASP.NET Core 8 + SQL Server + Next.js) và `Output Language` nếu muốn artifact bằng ngôn ngữ khác tiếng Việt.

---

## Pipeline 12 bước — chạy theo đúng thứ tự

Bắt đầu bằng: **`/spec <mô tả yêu cầu của bạn>`**. Mỗi bước kết thúc bằng một Quality Gate; pass gate rồi mới sang bước sau.

| # | Lệnh | Làm gì (1 dòng) | Gate chặn trước bước sau |
|---|------|-----------------|--------------------------|
| 1 | `/spec <yêu cầu>` | User Stories + Acceptance Criteria (+ ASCII wireframes nếu có UI; `--prototype` nếu cần bản click-thử) | **Bạn/stakeholder duyệt spec** (Gate 1 — luôn chờ người ký) |
| 2 | `/arch` | Thiết kế kiến trúc, ADR, API contract | Architecture reviewed, ADR + contract đủ |
| 3 | `/plan` | Bẻ spec thành task nhỏ có thứ tự phụ thuộc | Task là vertical slice, dependency rõ |
| 4 | `/secure`* | Threat model (STRIDE) trước khi code | Không còn critical concern |
| 5 | `/build` | Code theo TDD, lát cắt dọc, luôn build được | Unit tests pass, compile sạch |
| 6 | `/test` | QA với dependency thật (TestContainers/E2E — cần Docker) | Coverage ≥ 80%, tests pass |
| 7 | `/review`* | Code review 5 trục | Feedback critical đã xử lý |
| 8 | `/scan`* | Quét bảo mật sau code | Không còn critical/high vuln |
| 9 | `/infra` | Docker hoá chạy local | `docker compose up` healthy |
| 10 | `/docs`* | Sinh tài liệu dự án | Docs đủ, README cập nhật |
| 11 | `/verify`* *(khuyến nghị mạnh)* | Kiểm từng acceptance criteria trên **đúng artifact sẽ ship** | 100% scenario có verify test pass |
| 12 | `/deploy` | Deploy **staging** (`STAGED`) — bước tự động cuối của kit | Promote production = thủ công, sau go/no-go của người |

<sub>* = bước optional, nhưng **đã chạy thì gate là blocking**. Bộ bắt buộc: `/spec` `/arch` `/plan` `/build` `/test` `/infra` `/deploy`. Làm production: khuyến nghị chạy đủ 12.</sub>

**Theo dõi tiến độ:** mở [plans/todo.md](plans/todo.md) bất cứ lúc nào — task xong được tick `- [x]`.

---

## Sai lầm hay gặp của người mới

1. **Nhảy thẳng vào `/build` khi chưa có spec/plan** → mất truy vết spec → code → test; kit sẽ yêu cầu quay lại đúng thứ tự.
2. **Duyệt spec qua loa ở Gate 1** → mọi bước sau xây trên yêu cầu sai; Gate 1 là gate rẻ nhất để sửa.
3. **Bỏ `/test` vì "unit test ở `/build` xanh rồi"** → `/build` chỉ test in-memory; `/test` mới kiểm với DB/dependency thật (bắt bug dialect, transaction, index).
4. **Chạy bước optional rồi bỏ qua gate đỏ của nó** → optional là *quyền không chạy*, không phải *quyền fail*: đã chạy thì gate blocking.
5. **Trả lời mơ hồ khi Claude hỏi ở `/spec`** → hỏi-không-đoán là cơ chế chống "spec bịa"; câu trả lời của bạn chính là spec.

## Tra cứu tiếp

| Cần gì | Đọc |
|---|---|
| Toàn cảnh pipeline, gates, agents | [`.claude/CLAUDE.md`](.claude/CLAUDE.md) |
| Bắt đầu bằng ngôn ngữ tự nhiên + chọn chế độ thực thi | [quick-start.md](quick-start.md) |
| Đổi stack (Node.js, PHP/Laravel, PostgreSQL, ELK…) | [.claude/PROJECT_PROFILE.md](.claude/PROJECT_PROFILE.md) + [`.claude/rules/overrides/`](.claude/rules/overrides/) |
| Dự án đã có code sẵn | [getting-started-brownfield.md](getting-started-brownfield.md) |
