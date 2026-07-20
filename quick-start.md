# Quick-start — Dùng kit Spec-driven Development với Claude Code

> Dành cho teammate lần đầu dùng kit. Đọc 5 phút là bắt đầu được. Tài liệu đầy đủ: [`.claude/CLAUDE.md`](.claude/CLAUDE.md).

## Kit này là gì?

Một bộ "harness" SDLC cho Claude Code: **12 lệnh pipeline** (`/spec` → `/arch` → `/plan` → `/secure` → `/build` → `/test` → `/review` → `/scan` → `/infra` → `/docs` → `/verify` → `/deploy`) + 7 lệnh hỗ trợ, mỗi lệnh do một **agent chuyên trách** đảm nhiệm và kết thúc bằng một **Quality Gate**. Mục tiêu: output tái lập được, có truy vết spec → code → test → deploy, không phụ thuộc trí nhớ của người chạy.

## Cách bắt đầu — KHÔNG cần nhớ lệnh nào

Mở Claude Code trong repo và **mô tả việc bạn muốn làm bằng câu thường**:

> *"Tôi muốn thêm tính năng đăng nhập Google vào repo này"*

Claude sẽ trả lời theo format 3 phần (đã cấu hình sẵn trong kit — §Natural-Language Task Routing):

1. **Mode** — repo này là greenfield hay brownfield, kèm căn cứ (nếu Project Profile lệch hiện trạng, Claude cảnh báo trước).
2. **Luồng** — tên luồng bạn sẽ đi (greenfield 12 bước, hoặc B1–B5…).
3. **Checklist lệnh theo thứ tự** + các kỷ luật then chốt của luồng đó.

Sau đó Claude hỏi bạn chọn **chế độ thực thi**:

| Chế độ | Cách hoạt động | Hợp với |
|--------|----------------|---------|
| **User-driven** | Bạn tự gõ từng lệnh trong checklist, tự duyệt từng gate | Muốn kiểm soát chặt, đang học kit |
| **Claude-driven** | Claude chạy tuần tự các lệnh, **dừng ở mỗi Quality Gate** chờ bạn duyệt | Đã quen kit, muốn nhanh |

> Bất kể chế độ nào, các điểm cần **sign-off của con người** (duyệt spec ở Gate 1, verdict của review, promote production) **luôn dừng chờ bạn**.

## Câu mẫu → luồng (cây quyết định rút gọn)

| Bạn nói | Luồng | Kỷ luật then chốt |
|---------|-------|-------------------|
| "Nhận repo legacy này lần đầu" | **Phase A** | Read-only: `/discover` → `/spec`(reverse) → `/arch`(reverse) → `/infra`(reverse-bootstrap) |
| "Sản phẩm microservices nhiều repo" | **Multi-repo** | Per repo chạy Phase A; rồi `/discover-system` 1 lần trong workspace → bản đồ hệ thống (một chiều). Xem [`brownfield-pipeline`](.claude/references/brownfield-pipeline.md) + [`microservices-multirepo`](.claude/references/microservices-multirepo.md) |
| "Thêm tính năng MỚI" | **B1** | Spec chỉ phần delta; mở surface ngoài (payment/SSO/webhook) → nên chạy `/secure` |
| "Sửa tính năng ĐÃ CÓ" | **B2** | **Characterization test TRƯỚC khi sửa** (chụp behavior hiện tại, PASS) |
| "Fix bug" (chưa release) | **B3** | `/fix-issue`: regression test fail-trước-fix, root cause `file:line` |
| "Sự cố trên production" | **B4** | `/hotfix`: câu hỏi đầu tiên là *rollback hay fix-forward*, re-verify trước redeploy |
| "Nâng cấp kiến trúc / công nghệ" | **B5** | ADR bắt buộc + strangler-fig, không big-bang rewrite |
| "Bump dependency / vá CVE" | **B5-lite** | ADR nhẹ; **full regression bắt buộc** |
| "Dọn nợ kỹ thuật / refactor" | **`/simplify`** | Không đổi behavior; characterization làm lưới |
| "Tính năng X có chưa? / Y đang cấu hình ra sao? / Tính năng export CSV được thêm ở version nào, gồm những scenario gì?" (hỏi hiện trạng — không phải yêu cầu sửa) | **`/inspect`** | Read-only, 3 tầng bằng chứng (records → code → live), KHÔNG route vào B-flow, không hỏi chế độ thực thi. Lịch sử version tính năng đọc từ `specs/SPEC.md` §Revision History; version phát hành từ `CHANGELOG.md` + `RELEASE_NOTES` |

Bảng đầy đủ + thứ tự lệnh từng luồng: [`.claude/references/brownfield-pipeline.md`](.claude/references/brownfield-pipeline.md).

## 3 quy tắc vàng (mọi luồng)

1. **Không skip gate đang BLOCKING** — gate optional (`/secure`, `/review`, `/scan`, `/verify`) có thể bỏ qua, nhưng **đã chạy thì phải pass** mới đi tiếp.
2. **`plans/todo.md` là sự thật** — task xong phải tick `- [x]` trước khi báo done; chưa tick = chưa xong.
3. **Hỏi, không đoán** — yêu cầu thiếu/mơ hồ thì Claude sẽ hỏi lại hoặc ghi thành Assumption chờ bạn confirm; đừng ngại trả lời, đó là cách spec không bị "đoán bừa".

## Tham số optional hay dùng (biết để dùng khi cần)

Hầu hết việc mô tả bằng câu thường là đủ, nhưng 2 lệnh có tham số đáng nhớ:

| Lệnh | Mặc định | Bật thêm khi cần |
|------|----------|------------------|
| `/spec` | Sản phẩm UI: **ASCII wireframes sinh sẵn** | `--prototype` (hoặc nói *"kèm prototype"*) → thêm clickable HTML prototype cho stakeholder duyệt click-through |
| `/arch` | Component stack loại trừ → **1 Rejection ADR gộp bảng** | `--adr=per-component` (hoặc *"ADR riêng từng component"*) → mỗi component loại trừ 1 ADR đầy đủ (audit/compliance) |

## Scope khi làm brownfield — câu hỏi hay gặp nhất

**"`/test`, `/review`, `/verify` chạy trên toàn bộ source hay chỉ phần tôi sửa?"**

→ **VIẾT theo delta, CHẠY toàn bộ**: test mới chỉ viết cho vùng thay đổi (+ characterization vùng đụng), nhưng suite đã có thì chạy full mỗi vòng — suite cũ xanh mới chứng minh phần không đổi không bị ảnh hưởng. `/review` chỉ review diff. Chi tiết: [`brownfield-pipeline.md` §Scope per-change](.claude/references/brownfield-pipeline.md).

## Tra cứu sâu hơn

| Cần gì | Đọc |
|--------|-----|
| Toàn cảnh pipeline, gates, agents | [`.claude/CLAUDE.md`](.claude/CLAUDE.md) |
| Thứ tự lệnh từng luồng brownfield | [`.claude/references/brownfield-pipeline.md`](.claude/references/brownfield-pipeline.md) |
| Kỷ luật legacy (characterization, backward-compat) | [`.claude/rules/brownfield.md`](.claude/rules/brownfield.md) |
| Chi tiết 1 lệnh bất kỳ | `.claude/commands/<lệnh>.md` |
