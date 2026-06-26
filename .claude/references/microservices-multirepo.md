# Microservices Multi-Repo — Quick Lookup

> Cách dùng kit cho một sản phẩm microservices gồm **nhiều repo** (mỗi repo = 1 service / bounded context). Bổ sung cho pipeline per-repo, KHÔNG thay thế nó. Kỷ luật legacy per-service vẫn theo [`../rules/brownfield.md`](../rules/brownfield.md).

## Nguyên tắc cốt lõi

- **Đơn vị pipeline = 1 repo / 1 service.** Mỗi service chạy pipeline riêng (Project Profile riêng, stack riêng qua `overrides/*`, test riêng, deploy riêng). KHÔNG gộp N repo vào một lần chạy `/discover` — `Project Profile` đơn-giá-trị không biểu diễn được N stack.
- **System layer = tài liệu hiểu hệ thống, MỘT CHIỀU.** `/discover-system` đọc output per-repo → dựng bản đồ toàn hệ thống. Per-repo **không** phụ thuộc runtime vào system layer.
- **An toàn liên-service = backward-compat discipline** (repo-local), KHÔNG phải runtime dependency lên system layer. Xem [`../rules/brownfield.md`](../rules/brownfield.md).

## Hai pattern bố trí repo

| Pattern | Khi nào | `/discover-system` đọc gì |
|---|---|---|
| **A. Workspace** | Tất cả repo clone cạnh nhau dưới 1 thư mục cha | Đọc artifact per-repo trong các subfolder |
| **B. Repo riêng** (phổ biến) | Mỗi service repo độc lập | Tạo **workspace tạm** (clone tất cả về 1 cha) rồi chạy như A |

> Cả 2 đều quy về: có **một workspace** chứa các repo cạnh nhau để `/discover-system` đọc.

## Flow — một chiều ↑

```
1. Tạo workspace: clone tất cả service repo dưới 1 thư mục cha.

2. [per-repo, song song]  mỗi repo Phase A:
   /discover → /spec(reverse) → /arch(reverse)
   → CODEBASE_MAP · SPEC(@US) · ARCHITECTURE + openapi + §Service Contracts

3. [workspace, 1 lần]  /discover-system
   → architecture/system/ (catalog · context · container · journeys · contract catalog · traceability)
   → commit vào platform repo (documentation, dùng chung)

4. [per-repo, mỗi feature]  Phase B brownfield (B1–B5) ĐỘC LẬP per service.
   An toàn liên-service = backward-compat. KHÔNG đọc ngược system layer trong việc thường ngày.
```

## Precondition của `/discover-system`

Phase A per-repo phải xong cho **từng** service: mỗi repo có `docs/CODEBASE_MAP.md` + `specs/SPEC.md` (có `@US`) + `architecture/ARCHITECTURE.md` kèm **§Service Contracts** (bảng exposed/consumed — xem [`../commands/arch.md`](../commands/arch.md) §3.2) + khai `Service id` trong Project Profile. Thiếu repo nào → catalog gắn `⚠️ incomplete`, không bịa.

## Vai trò mỗi artifact system layer

| File | Nội dung |
|---|---|
| `service-catalog.md` | Bảng service: `id · repo · trách nhiệm · stack · owner · last-synced` |
| `system-context.md` | C4 L1 — ranh giới sản phẩm + actor + tất cả service |
| `container.md` | C4 L2 — service + bus + gateway + cạnh `ai↔ai` (ghép từ §Service Contracts) |
| `journeys/*.md` | Sequence xuyên service + `@SYS-US` (đánh dấu `inferred` nếu suy từ event/async) |
| `contracts/event-catalog.md` | `topic · schema · producer · consumers` + REST cross-service |
| `traceability.md` | `@SYS-US → {service:@US}` |

## Nâng cao (để sau — opt-in, KHÔNG cần cho bản đầu)

- **Auto contract-break detection:** `/test`/`/review` của service cross-check contract nó *consume* với openapi của partner (đọc 1 file contract, không phải cả system layer); hoặc consumer-driven contract testing (Pact-style).
- **Blast-radius khi B5 breaking change:** đọc thủ công `container.md` để biết ai *consume* contract sắp phá → lập migration plan.
- **Cross-service E2E:** 1 repo `e2e` riêng giữ journey xuyên service (mặc định: mỗi service test độc lập).
- **Downward sync:** submodule / sync slice system layer vào từng repo nếu sau này muốn per-repo tham chiếu tự động.

## Greenfield multi-service (ngược chiều — ghi chú)

Thiết kế N service **từ đầu** = **system-first**: spec/arch ở tầng hệ thống (phân rã sản phẩm → service + contract) TRƯỚC, rồi mới per-service. Đảo thứ tự so với reverse ở trên. Kit hiện tối ưu cho **brownfield/reverse**; greenfield multi-service làm thủ công theo nguyên tắc này.

## See also

- [`../commands/discover-system.md`](../commands/discover-system.md) — lệnh dựng system layer
- [`../commands/arch.md`](../commands/arch.md) §3.2 Service Contracts — keystone input
- [`brownfield-pipeline.md`](brownfield-pipeline.md) — pipeline per-repo (Phase A + B)
- [`../rules/brownfield.md`](../rules/brownfield.md) — backward-compat discipline (an toàn liên-service)
