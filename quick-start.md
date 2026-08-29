# Quick-start — Dùng kit SpecGate

> Dành cho người lần đầu dùng kit — kể cả khi bạn không trực tiếp viết code. Đọc 5 phút là bắt đầu được.
> Muốn checklist **từng bước theo tình trạng dự án** thay vì mô tả bằng ngôn ngữ tự nhiên? → [getting-started-brownfield.md](getting-started-brownfield.md) (cho repo có code sẵn) · [getting-started-greenfield.md](getting-started-greenfield.md) (xây dự án từ số 0).
>
> **Cần có trước:** thư mục `.claude/` của kit đã nằm trong thư mục gốc dự án (chưa có thì xem cách lấy kit ở [README_VN.md](README_VN.md) §Bắt đầu nhanh) · Docker đang chạy nếu bạn đi tới bước `/test` trở đi (từ `/spec` đến `/build` thì không cần).

## Kit này là gì?

SpecGate là bộ quy trình phát triển phần mềm (SDLC) dành cho Claude Code: thay vì bảo AI "làm giúp tôi" rồi nhận về một mớ code, bạn đi qua **12 bước** theo thứ tự, từ viết yêu cầu đến đưa lên máy chủ thử nghiệm (staging).

Mỗi bước do một **agent chuyên trách** đảm nhiệm — agent là Claude được gắn sẵn một vai, ví dụ chuyên viên phân tích nghiệp vụ, kiến trúc, lập trình, kiểm thử — và kết thúc bằng một **cổng kiểm soát chất lượng (Quality Gate)**: bước sau chỉ bắt đầu khi bạn duyệt kết quả bước trước.

12 bước theo thứ tự: `/spec → /arch → /plan → /secure → /build → /test → /review → /scan → /infra → /docs → /verify → /deploy`, kèm 8 lệnh hỗ trợ. Tóm lại: **AI làm, bạn kiểm soát từng giai đoạn.**

## Cách bắt đầu — KHÔNG cần nhớ lệnh nào

Mở Claude Code trong repo (thư mục dự án của bạn) và **mô tả việc bạn muốn làm bằng câu thường**. Chọn câu gần nhất với tình huống của bạn:

- **Dự án mới, chưa có code:** *"`Tôi muốn xây website LinkVault — quản lý bookmark cá nhân: đăng ký tài khoản, lưu bookmark (URL, tiêu đề, tag), tìm kiếm, đánh dấu yêu thích.`"* (bản mô tả đầy đủ có sẵn ở [`examples/linkvault-brief.txt`](examples/linkvault-brief.txt))
- **Vừa nhận source code, chưa biết gì về nó:** *"`Tôi mới nhận source code của dự án này, giúp tôi nắm hiện trạng trước khi sửa gì.`"*
- **Đã có code, thêm tính năng mới:** *"`Tôi muốn thêm tính năng đăng nhập Google vào dự án này.`"*
- **Đã có code, sửa tính năng đang chạy:** *"`Tôi muốn sửa quy tắc đặt lại mật khẩu: link hết hạn sau 30 phút thay vì 24 giờ.`"*

Claude sẽ trả lời theo format 3 phần (kit đã cấu hình sẵn):

1. **Mode** — repo này là **greenfield** (dự án xây từ số 0) hay **brownfield** (dự án đã có code đang chạy), kèm căn cứ.
2. **Luồng** — tên luồng bạn sẽ đi: greenfield 12 bước, hoặc B1–B5 (tên các luồng làm việc trên dự án đã có code — B1 thêm tính năng · B2 sửa tính năng đã có · B3 sửa bug chưa phát hành · B4 xử lý sự cố production · B5 nâng cấp kiến trúc).
3. **Checklist lệnh theo thứ tự** + các nguyên tắc quan trọng phải tuân thủ trong luồng đó.

Sau đó Claude hỏi bạn chọn **chế độ thực thi**:

| Chế độ | Cách hoạt động | Hợp với |
|--------|----------------|---------|
| **User-driven** *(khuyến nghị lần đầu)* | Bạn tự gõ từng lệnh trong checklist, tự duyệt từng cổng | Muốn kiểm soát chặt, đang học kit |
| **Claude-driven** | Claude chạy tuần tự các lệnh, **dừng ở mỗi cổng** chờ bạn duyệt | Đã quen kit, muốn nhanh |

> Bất kể chế độ nào, các điểm cần **con người ký duyệt** (duyệt spec — bản đặc tả yêu cầu — ở Gate 1, kết luận của bước review, đưa bản build lên môi trường thật) **luôn dừng chờ bạn**.

Ví dụ: chọn **User-driven** rồi gõ `/spec <mô tả yêu cầu>` — Claude sẽ hỏi vài câu làm rõ, rồi viết tập tin `specs/SPEC.md` để bạn đọc và duyệt trước khi sang bước sau. **Duyệt bằng cách trả lời ngay trong chat** (ví dụ: *"đồng ý, tiếp tục"*) — hoặc nêu chỗ muốn chỉnh, Claude sửa xong sẽ trình lại.

Cứ thế đi hết checklist: duyệt xong bước này thì gõ lệnh kế tiếp. Bước cuối `/deploy` chỉ đưa bản build lên máy chủ thử nghiệm (staging) — đưa lên môi trường thật là việc người quyết định và làm tay.

Ngoài 12 bước pipeline còn **8 lệnh hỗ trợ** hay cần: `/inspect` (hỏi hiện trạng, không sửa gì) · `/debug` (tìm nguyên nhân lỗi) · `/simplify` (dọn code cho gọn, không đổi hành vi) · `/fix-issue` (sửa bug khi chưa phát hành) · `/hotfix` (xử lý sự cố đang chạy) · `/discover` (khảo sát dự án có sẵn) · `/discover-system` (bản đồ hệ thống nhiều repo) · `/export-docs` (xuất PRD/SDD chuẩn công ty) — mô tả từng lệnh trong [README_VN.md](README_VN.md).

## 3 quy tắc vàng (mọi luồng)

1. **Không bỏ qua cổng đang chặn (blocking)** — các cổng tùy chọn (optional: `/secure`, `/review`, `/scan`, `/docs`, `/verify`) có thể không chạy, nhưng **đã chạy thì phải pass** mới đi tiếp.
2. **Tập tin `plans/todo.md`** (do bước `/plan` sinh ra) **là sự thật** — mỗi task làm xong phải được tick `- [x]`: Claude tự tick sau khi hoàn thành, bạn kiểm lại; chưa tick nghĩa là chưa xong.
3. **Hỏi, không đoán** — yêu cầu thiếu/mơ hồ thì Claude sẽ hỏi lại hoặc ghi lại thành giả định (Assumption) chờ bạn xác nhận; đừng ngại trả lời, đó là cách spec không bị "đoán bừa".

## Tra cứu sâu hơn

| Cần gì | Đọc |
|--------|-----|
| Toàn cảnh pipeline, các cổng, các agent | [`.claude/CLAUDE.md`](.claude/CLAUDE.md) *(tiếng Anh)* |
| Thứ tự lệnh từng luồng brownfield (bảng đầy đủ) | [`.claude/references/brownfield-pipeline.md`](.claude/references/brownfield-pipeline.md) *(tiếng Anh)* |
| Kỷ luật legacy (characterization, backward-compat) | [`.claude/rules/brownfield.md`](.claude/rules/brownfield.md) *(tiếng Anh)* |
| Chi tiết + tham số optional của 1 lệnh bất kỳ | `.claude/commands/<lệnh>.md` *(tiếng Anh)* |
