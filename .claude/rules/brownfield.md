# Brownfield Rules — Làm việc trên Legacy Code

> **Tóm tắt:** Bộ kỷ luật **bắt buộc khi sửa code đang chạy / đã release** (`Project Profile → Mode: brownfield`). Ràng buộc số một đổi từ *"tôi xây gì"* (greenfield) sang **"tôi phải KHÔNG phá gì"** — nên mọi nguyên tắc dưới đây xoay quanh việc **dựng lưới an toàn trước khi đụng code**. **Greenfield bỏ qua toàn bộ file này.**
>
> Nguồn nguyên lý: Michael Feathers — *Working Effectively with Legacy Code* (characterization test, seams) + strangler-fig pattern.

---

## Định nghĩa

**Legacy code** = code đang chạy / đã release nhưng **thiếu test, spec, hoặc tài liệu** mô tả ý định. Vấn đề cốt lõi không phải "code cũ" mà là **thiếu lưới an toàn để thay đổi tự tin**.

---

## 4 nguyên tắc cốt lõi

### 1. Measure vs Verify — phân biệt rõ

**Nghĩa là:** cùng một lệnh có thể đang *đo hiện trạng* (measure) hoặc *kiểm đúng yêu cầu* (verify) — chỉ "verify" mới cần spec. Phân biệt để không đi kiểm "đúng/sai" khi còn chưa có spec định nghĩa "đúng" là gì.

| Hoạt động | Cần spec? | Thuộc giai đoạn |
|-----------|:---------:|-----------------|
| **Measure** — đo hiện trạng (coverage hiện có, suite pass?, complexity, vuln) | ❌ Không | Discovery (read-only) |
| **Verify** — kiểm behavior khớp acceptance criteria | ✅ Có | Per-change (sau khi có spec) |

> **Hệ quả:** bước nào dính acceptance criteria (`/test` verify, `/review` trục Correctness) **không thể đứng trước reverse-`/spec`** — chưa có spec thì chưa có "đúng" để kiểm. Discovery chỉ *measure*; *verify* để per-change.

### 2. Upfront vs Per-change — không làm hàng loạt trước

**Nghĩa là:** việc *một lần* (bản đồ code, baseline) làm ở Discovery; việc *theo từng thay đổi* chỉ làm cho **đúng vùng đang đụng** — không retrofit cả repo.

| Làm 1 lần upfront (Discovery) | Làm per-change (luồng B) |
|-------------------------------|--------------------------|
| Bản đồ codebase (`/discover`) | Characterization test cho **đúng vùng sắp đụng** |
| Baseline spec/arch (reverse) | Full `/review` Five-Axis cho **slice mình sửa** |
| Health snapshot nhẹ + red-flag | `/test` verify cho thay đổi cụ thể |

> Đừng viết characterization test cho cả codebase, đừng review toàn repo — chỉ cho vùng thay đổi chạm tới.
>
> **VIẾT theo delta — CHẠY toàn bộ:** quy tắc trên chỉ giới hạn phần *viết mới* (test, characterization, review effort); còn suite/verify-suite **đã automated** thì CHẠY full mỗi vòng — regression net xanh mới chứng minh phần không đổi không bị ảnh hưởng. Bảng tra `/test` · `/review` · `/verify` + cây quyết định 9 tình huống: [`../references/brownfield-pipeline.md`](../references/brownfield-pipeline.md) §Scope per-change.

### 3. Backward compatibility mặc định

**Nghĩa là:** mặc định **không phá** thứ mà client / dữ liệu / hệ thống tích hợp đang dựa vào.

- API contract, response shape, DB schema, event/message format, public behavior **không được phá** trừ khi có ADR + migration plan.
- Thay đổi phá vỡ (breaking change) → bump major version + deprecation window + migration path.
- Mọi PR brownfield phải trả lời được: *"thay đổi này có phá client/data/integration đang chạy không?"*

### 4. ADR mới mới được đổi kiến trúc

**Nghĩa là:** chỉ đổi kiến trúc khi có **ADR** (Architecture Decision Record — bản ghi quyết định kiến trúc) — không "tiện tay" đổi khi đang làm việc khác.

- Luồng phát triển / sửa tính năng (B1, B2): **giữ nguyên kiến trúc** — `/arch` ở chế độ conformance-gate.
- Chỉ luồng nâng cấp (B5) được đổi kiến trúc, **bắt buộc ADR** (kèm v2-trigger) + migration plan.
- Không "tiện tay" đổi pattern/structure khi đang làm việc khác.

---

## Characterization Test — kỹ thuật trung tâm

> **Định nghĩa:** test chụp lại **behavior hiện tại của code** (không phải behavior *đúng* theo spec), làm lưới an toàn trước khi sửa. Cần vì legacy thường thiếu cả test lẫn spec — phải biết "code *đang* làm gì" mới phân biệt được thay đổi cố ý vs regression vô tình.

Khác với TDD greenfield:

| | TDD greenfield | Characterization (brownfield) |
|---|----------------|-------------------------------|
| Test viết để | mô tả behavior **mong muốn** | chụp behavior **đang có** (kể cả khi sai) |
| Trạng thái đầu | RED (fail, chưa có code) | GREEN (pass, code đã chạy) |
| Mục đích | dẫn dắt implement | phát hiện regression khi sửa |

### Quy trình khi sửa code legacy chưa có test

```
1. Viết characterization test chụp behavior HIỆN TẠI của vùng sắp sửa → chạy PASS (xác nhận lưới đúng)
2. Thực hiện thay đổi
3. Characterization test FAIL ở đúng chỗ behavior đổi → review: đổi này CÓ CHỦ ĐÍCH không?
   - Có chủ đích → cập nhật test theo behavior mới (đây là phần được phép đổi)
   - Ngoài ý muốn → đã bắt được regression, sửa lại
4. Behavior không định đổi → test vẫn PASS (lưới giữ nguyên)
```

### Seams (điểm cắt để test code khó test)

**Seam** = chỗ có thể thay đổi behavior mà **không sửa code tại đó**. Legacy thường có dependency cứng (new trực tiếp, static call, no DI) → cần seam để test được mà **không đổi behavior**:

- Tạo seam bằng: extract interface, virtual method, parameterize constructor.
- Ưu tiên seam ít rủi ro nhất; ghi lại nếu phải refactor để tạo seam — đây là **ngoại lệ duy nhất** của "no gratuitous refactor", và **phải có characterization test bao quanh trước**.

---

## Strangler-Fig — thay thế dần (cho B5)

**Strangler-fig** = thay thế **dần dần**, không viết lại một phát (big-bang):

1. Dựng implementation mới **song song** sau abstraction/interface.
2. Định tuyến một phần traffic/call qua bản mới (feature-flag).
3. Đo, mở rộng dần; bản cũ co lại tới khi bỏ được.
4. Backward-compat suốt quá trình — cache miss / path mới lỗi → fallthrough bản cũ.

> Ví dụ: `ICacheService` được thiết kế sẵn từ ngày đầu (ghi nhận bằng ADR khi chạy `/arch`) để sau này cắm Redis vào mà không đụng caller — đó là seam cho strangler-fig.

---

## No Gratuitous Refactor

Chỉ refactor **trong phạm vi đang đụng tới**, phục vụ thay đổi hiện tại:

- Không "dọn dẹp" code không liên quan trong cùng PR (làm vỡ review + tăng rủi ro regression).
- Tech debt phát hiện → ghi vào backlog (`/simplify` riêng), không gộp vào feature/fix.
- Ngoại lệ: refactor tạo-seam tối thiểu để test được code sắp sửa — phải có characterization test trước.

---

## Liên kết với Project Profile & commands

- **Project Profile** (trong `CLAUDE.md`) khai báo `Mode`, `Database`, `Observability`, `Structure`. Rule này chỉ active khi `Mode: brownfield`.
- Công nghệ ngoại vi khác mặc định (Oracle/MySQL/ELK…) → theo `rules/overrides/*` mà Profile khai báo.
- `/spec`, `/arch`, `/plan` đọc Mode để chuyển hành vi (xem §Brownfield Mode trong từng command).

### Vai trò `/arch` theo luồng (tóm tắt)

| Luồng | `/arch` mode | Mặc định |
|-------|-------------|----------|
| Discovery (Phase A) | **reverse** | mô tả as-is + ADR inferred |
| B1 feature mới / B2 sửa tính năng | **conformance-gate** | giữ nguyên kiến trúc |
| B5 nâng cấp | **redesign** | đổi có ADR + migration |

---

## Checklist brownfield (mọi luồng B)

- [ ] Đã có baseline `specs/` + `architecture/` (từ Discovery) để tham chiếu
- [ ] Vùng sắp sửa: nếu chưa có test → **viết characterization test trước** (chụp behavior hiện tại, PASS)
- [ ] Thay đổi **không phá** API/contract/schema/behavior đang chạy (hoặc có ADR + migration)
- [ ] `/arch` conformance-gate xác nhận **không cần đổi kiến trúc** (B1/B2), hoặc có ADR (B5)
- [ ] Không refactor code ngoài phạm vi đang đụng
- [ ] Test cũ vẫn PASS (regression net giữ nguyên) + test mới cho thay đổi
- [ ] `/verify` chứng minh trên artifact thật trước promote (Gate 11)
