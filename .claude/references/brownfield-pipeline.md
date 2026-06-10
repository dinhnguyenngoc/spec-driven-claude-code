# Brownfield Pipeline — Quick Reference

> Tra cứu nhanh thứ tự lệnh cho Phase A (discovery) và 5 luồng Phase B (task lặp lại).
> Chi tiết kỷ luật: [`../rules/brownfield.md`](../rules/brownfield.md) · Mode/Profile: [`../CLAUDE.md`](../CLAUDE.md) §Project Mode & Profile.

---

## Mẹo nhớ — 1 spine + 5 entry

**Spine chung** của các luồng phát triển (B1/B2/B5):

```
/build → /test → /review → /verify → /deploy
```

Mỗi luồng B chỉ khác ở **cửa vào spine**. Memorize spine 1 lần, nhớ cửa vào cho từng luồng.

---

## Cây quyết định

| Tình huống | Luồng |
|-----------|-------|
| Nhận repo legacy lần đầu | **Phase A** |
| Thêm tính năng MỚI | **B1** |
| Sửa tính năng ĐÃ CÓ | **B2** |
| Bug phát hiện lúc dev (chưa release) | **B3** |
| Lỗi trên production đang LIVE | **B4** |
| Đổi / nâng cấp kiến trúc / công nghệ | **B5** |
| Nâng cấp dependency/runtime (.NET bump, vá CVE) — behavior giữ nguyên | **B5-lite** — ADR nhẹ, không cần strangler-fig; **full regression bắt buộc** (blast radius = cả app) |
| Trả nợ kỹ thuật / refactor không đổi behavior | **`/simplify`** (kênh riêng — characterization test làm lưới "behavior unchanged") |
| Gỡ bỏ / deprecate tính năng | **B2 + ADR** (breaking by design — deprecation window + migration path, per backward-compat rule) |

---

## Phase A — Discovery (MỘT lần khi nhận repo, READ-ONLY với source)

```
/discover  →  /spec (reverse)  →  /arch (reverse)  →  /infra (reverse-bootstrap)
              [/scan khuyến nghị, độc lập — trước lần deploy đầu]
```

**Output:**
- `Project Profile` (mode + DB + observability + structure) trong [`CLAUDE.md`](../CLAUDE.md)
- `specs/SPEC.md` baseline (as-is user stories)
- `architecture/` baseline (kiến trúc thật + ADR inferred)
- `docker/Dockerfile` + `docker-compose.yml` + `.dockerignore` + `.env.example` (infra khớp code thực tế, chạy được local)

**Boundary:** read-only với `src/`/`web/` source code. Phase A có thể tạo file mới trong `docker/`, `specs/`, `architecture/`, `docs/` (artifact documentation/setup, không phải code business logic). Mọi thay đổi **code business** thuộc Phase B.

**Tại sao `/verify` và `/deploy` KHÔNG thuộc Phase A:**
- `/verify` và `/deploy` là **execution command** — touch runtime state (test artifact thật, promote ra production), không sinh baseline documentation.
- Brownfield project theo định nghĩa **đã có production hiện hành** — không cần "first deploy" như greenfield. Production deploy mới = touch production state → thuộc Phase B per-change.
- `/infra` REVERSE-BOOTSTRAP **đã đủ** để spin up local dev environment (`docker compose up -d`); không cần `/deploy` để "thấy app chạy".

---

## Phase B — 5 luồng

### B1 — Tính năng MỚI trên legacy

```
/spec(delta) → /arch(conformance) → /plan → [/secure] → /build → /test → /review → [/scan] → /verify → /deploy
```

- `/spec(delta)`: chỉ đặc tả tính năng mới, reference story cũ — KHÔNG viết lại.
- `/arch(conformance)`: mặc định **no-op**; ADR nhẹ chỉ nếu có quyết định nhỏ mới.
- `/build`: TDD bình thường (code mới); characterization test **chỉ khi** đụng vùng legacy chưa test.
- Tính năng mới mở **surface ngoài** (payment, SSO, webhook, URL-fetch) → **nên chạy `/secure`** — surface mới chính là ứng viên "Highest-Risk Active Surface" (Phase 3.5).

### B2 — Sửa tính năng ĐÃ CÓ

```
[characterization test TRƯỚC]  →  /spec(delta) → /arch(conformance) → /plan → /build → /test(backward-compat) → /review → /verify → /deploy
```

- **Khác B1**: bắt buộc viết characterization test chụp behavior hiện tại (PASS) trước khi đụng code.
- `/test`: thêm test backward-compat — contract/data/API cũ không đổi.

### B3 — Fix bug (dev-time, chưa release)

```
/fix-issue → /test → /review → /verify → /deploy
```

- Bỏ qua `/spec`/`/arch`/`/plan` — không có yêu cầu nghiệp vụ mới.
- `/fix-issue`: reproduce → regression test (fail trước fix) → root cause → fix.

### B4 — Hotfix (production đang LIVE)

```
/hotfix  →  [Triage: rollback?]
         →  /fix-issue (root cause + regression test + fix)
         →  patch version + CHANGELOG + RELEASE_NOTES
         →  /verify (digest mới — chứng minh bản vá trên artifact thật)
         →  /deploy (rollback-ready)
         →  post-incident (runbook + test phòng ngừa vĩnh viễn)
```

- `/hotfix` là **thin orchestrator** — câu hỏi đầu: rollback hay fix-forward.
- Bản vá phải có version riêng + audit trail; re-verify trên digest mới trước redeploy.

### B5 — Nâng cấp kiến trúc / công nghệ

```
/arch(REDESIGN: proposal + ADR + migration + v2-trigger)
   → /plan(strangler-fig)
   → [/secure]
   → /build(incremental, feature-flag, backward-compat)
   → /test → /review → /scan → /verify → /deploy
```

- **Lần duy nhất `/arch` được chủ động đổi kiến trúc** — bắt buộc ADR (supersede ADR cũ nếu cần) + migration plan.
- Strangler-fig: không big-bang rewrite — dựng song song sau abstraction, feature-flag, mở rộng dần.
- Backward-compat suốt quá trình migration.
- Ví dụ: thêm Redis cache, migrate Oracle→PostgreSQL, đổi Serilog-file → ELK (cập nhật Project Profile + active override).

---

## Vai trò `/arch` theo luồng — bảng tra nhanh

| Luồng | Mode | Mặc định |
|-------|------|----------|
| Phase A | **reverse** | mô tả as-is + ADR inferred |
| B1 (mới), B2 (sửa) | **conformance-gate** | giữ nguyên kiến trúc; ADR chỉ khi có quyết định mới nhỏ |
| B5 (nâng cấp) | **redesign** | đổi kiểm soát + ADR (supersede) + migration |

---

## 2 kỷ luật brownfield xuyên MỌI luồng B

1. **Characterization test trước khi sửa** code legacy chưa có test (đặc biệt B2)
2. **Backward-compat mặc định** — không phá API/contract/data/schema đang chạy (phá vỡ → ADR + migration)

---

## Scope per-change — VIẾT theo delta, CHẠY toàn bộ

> Trả lời câu *"`/test`, `/review`, `/verify` thực hiện trên toàn bộ source hay chỉ phần thay đổi?"* — nguyên tắc gốc: [`../rules/brownfield.md`](../rules/brownfield.md) §Upfront-vs-Per-change. Phân biệt then chốt: **VIẾT (đắt) ≠ CHẠY (rẻ)**.

| Lệnh | VIẾT mới — CHỈ phần thay đổi | CHẠY — TOÀN BỘ những gì đã automated |
|------|------------------------------|----------------------------------------|
| `/test` | Test cho delta + characterization vùng đụng + backward-compat test cho contract kề cận | **Toàn bộ suite hiện có** — suite cũ xanh mới chứng minh "phần không đổi không bị ảnh hưởng" |
| `/review` | — | **Chỉ diff/slice của thay đổi** (Five-Axis trên phần sửa; trục Architecture đối chiếu conformance với baseline — KHÔNG re-review toàn repo) |
| `/verify` | Verify test cho scenario thay đổi/thêm (cập nhật VERIFY_MATRIX phần delta) | **Toàn bộ verify suite** (gồm zero-seed golden journey — lưới hệ thống rẻ nhất). Ngoại lệ duy nhất: **B4 hotfix** = scoped minimum (liveness + contract vùng bug + scenarios của story liên quan + test tái hiện incident) |

> Lưới lớn dần theo từng vòng B: vòng đầu sau Phase A build suite (ưu tiên golden journey + vùng sắp đụng), các vòng sau chỉ thêm delta. KHÔNG retrofit test toàn bộ upfront.

---

## Mapping lệnh → file lệnh

| Lệnh | File |
|------|------|
| `/discover` | [`../commands/discover.md`](../commands/discover.md) |
| `/spec` (reverse + delta) | [`../commands/spec.md`](../commands/spec.md) §Brownfield Mode |
| `/arch` (reverse + conformance + redesign) | [`../commands/arch.md`](../commands/arch.md) §Brownfield Mode |
| `/infra` (reverse-bootstrap + conformance-check) | [`../commands/infra.md`](../commands/infra.md) §Brownfield Mode |
| `/plan` (migration-aware) | [`../commands/plan.md`](../commands/plan.md) §Brownfield Mode |
| `/fix-issue` | [`../commands/fix-issue.md`](../commands/fix-issue.md) |
| `/hotfix` | [`../commands/hotfix.md`](../commands/hotfix.md) |
| `/verify` | [`../commands/verify.md`](../commands/verify.md) — Gate 11 **step optional · BLOCKING if run** (REQUIRED inside `/hotfix`) |
| Spine: `/build`, `/test`, `/review`, `/scan`, `/deploy` | dùng chung greenfield + brownfield |
