# PROJECT_PROFILE — user-owned (kit upgrade KHÔNG đụng file này)

> **File này thuộc tầng CONFIG của kit layering** (xem `CLAUDE.md` §Kit Layering): schema do kit định nghĩa (`CLAUDE.md` §Project Mode & Profile), **nội dung do repo của bạn sở hữu**. Nội dung được nạp vào context mỗi phiên (import trong `CLAUDE.md`) — giữ file gọn. Khi kit nâng version, file này được giữ nguyên.
>
> **Cách dùng theo tình huống:**
> - **Repo ĐÃ có code (brownfield — mặc định của kit):** chạy `/discover` — lệnh khảo sát repo và tự sinh/cập nhật block dưới bằng giá trị thật (kèm red-flags).
> - **Repo mới tinh (chưa có business code):** đổi `Mode: greenfield` + khai stack sẽ dùng. Lưu ý: routing đối chiếu Mode với hiện trạng repo — lệch sẽ cảnh báo và đề nghị sửa Mode giúp bạn (chỉ sửa sau khi bạn đồng ý).

## Project Profile

> Block mặc định do kit ship — **placeholder theo base stack**, chưa mô tả repo nào. `/discover` (brownfield) hoặc bạn (greenfield) thay bằng giá trị thật.

- **Mode:** brownfield
- **Core:** C# 12 + ASP.NET Core 8 + EF Core 8 — base stack (no override)
- **Database:** SQL Server → base `rules/database.md` (no override)
- **Observability:** Serilog + Prometheus + Grafana → base `rules/monitoring.md` (no override)
- **Structure:** Clean Architecture (Api → Core ← Infrastructure)
- **Frontend:** <none | khai nếu có>
- **Service id:** <chỉ multi-repo cần — single-repo bỏ trống>
- **Notes (red-flags từ /discover):** <brownfield: /discover điền — nợ test, khu vực rủi ro, điểm sáng>

### Giá trị hợp lệ & override kích hoạt (tham khảo khi điền)

| Trường | Base (mặc định — không cần override) | Khai khác → đọc kèm override |
|--------|--------------------------------------|------------------------------|
| Mode | `brownfield` — repo có code đang chạy/đã release → Phase A (`/discover` → `/spec` reverse → `/arch` reverse), luồng B1–B5, `rules/brownfield.md` active | `greenfield` — xây từ số 0 → pipeline 12 bước tuyến tính |
| Core | C# 12 + ASP.NET Core 8 + EF Core 8 | Node.js → `rules/overrides/lang-nodejs.md` + `framework-nodejs-web.md` + `test-nodejs.md` |
| Database | SQL Server 2022 | Oracle → `database-oracle.md` · MySQL → `database-mysql.md` · PostgreSQL → `database-postgres.md` · MongoDB → `database-mongodb.md` |
| Observability | Serilog + Prometheus + Grafana (+ Jaeger tracing) | ELK → `monitoring-elk.md` |
| Structure | Clean Architecture | N-tier · monolith — brownfield mô tả **as-is**, không "sửa" trong profile |
| Frontend | (không có) | Next.js 14 App Router (site SEO) · React + Vite SPA (admin/dashboard) → base `rules/frontend.md` |

> **Nguyên tắc override:** file override chỉ thay phần dialect/backend-specific; nguyên tắc agnostic của rule base (parametrized query, structured logging, correlation id…) **vẫn áp dụng** — xem `rules/tech-stack.md` §Core vs Peripheral. Precedence khi va chạm: `local/` > file này > kit base.
