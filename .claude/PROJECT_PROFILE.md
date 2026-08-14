# PROJECT_PROFILE — user-owned (kit upgrade KHÔNG đụng file này)

> **File này thuộc tầng CONFIG của kit layering** (xem `CLAUDE.md` §Kit Layering): schema do kit định nghĩa (`CLAUDE.md` §Project Mode & Profile), **nội dung do repo của bạn sở hữu**. Nội dung được nạp vào context mỗi phiên (import trong `CLAUDE.md`) — giữ file gọn. Khi kit nâng version, file này được giữ nguyên.
>
> **Cách dùng theo tình huống:**
> - **Repo ĐÃ có code (brownfield — mặc định của kit):** chạy `/discover` — lệnh khảo sát repo và tự sinh/cập nhật block dưới bằng giá trị thật (kèm red-flags).
> - **Repo mới tinh (chưa có business code):** đổi `Mode: greenfield` + khai stack sẽ dùng. Lưu ý: routing đối chiếu Mode với hiện trạng repo — lệch sẽ cảnh báo và đề nghị sửa Mode giúp bạn (chỉ sửa sau khi bạn đồng ý).
> - **Sản phẩm NHIỀU repo (workspace):** đặt kit ở thư mục cha (`myproject/.claude`), KHÔNG copy kit vào từng repo. Chạy `/discover` tại thư mục cha — Phase 0 phát hiện các repo con, hỏi xác nhận rồi tự sinh **workspace profile** (`Mode: workspace` + `Repos:` registry) cho file này, đồng thời sinh per-repo profile (schema block dưới) bên trong từng repo con. Chi tiết: `CLAUDE.md` §Workspace Mode.

## Project Profile

> **Chưa gắn với dự án nào** — đây là trạng thái mặc định của kit khi vừa đem vào repo. Repo có code sẵn → chạy `/discover` (tự khảo sát và điền toàn bộ block này bằng giá trị thật + red-flags). Repo mới tinh → đổi `Mode: greenfield` và khai stack dự định. Sản phẩm nhiều repo → xem tình huống workspace ở đầu file.

- **Mode:** brownfield   <!-- mặc định của kit — ca phổ biến nhất là đem kit vào repo sẵn có; xây từ số 0 → đổi `greenfield` -->
- **Output Language:** Vietnamese   <!-- ngôn ngữ prose/artifact + hội thoại; code & identifier luôn English (CLAUDE.md §Output Language). Đổi sang tên tiếng Anh của ngôn ngữ bạn muốn, vd `English`, `Japanese` -->
- **Core:** <chưa khai — C# 12 + ASP.NET Core 8 + EF Core 8 (base) | Node.js | PHP + Laravel — xem bảng dưới>
- **Database:** <chưa khai — SQL Server (base) | Oracle | MySQL | PostgreSQL | MongoDB — xem bảng dưới>
- **Observability:** <chưa khai — Serilog/Prometheus/Grafana (base) | ELK — xem bảng dưới>
- **Structure:** <chưa khai — Clean Architecture | N-tier | monolith; brownfield: mô tả as-is, không "sửa" trong profile>
- **Frontend:** <nếu có — Next.js 14 (site SEO) | React + Vite SPA (admin) | Blade/Livewire/Inertia (Laravel) | …>
- **Service id:** <chỉ sản phẩm multi-repo — key duy nhất cho /discover-system; single-repo → bỏ trống>
- **Notes:** <red-flags/blockers — /discover điền cho brownfield; greenfield có thể bỏ trống>

### Giá trị hợp lệ & override kích hoạt (tham khảo khi điền)

| Trường | Base (mặc định — không cần override) | Khai khác → đọc kèm override |
|--------|--------------------------------------|------------------------------|
| Mode | `brownfield` — repo có code đang chạy/đã release → Phase A (`/discover` → `/spec` reverse → `/arch` reverse), luồng B1–B5, `rules/brownfield.md` active | `greenfield` — xây từ số 0 → pipeline 12 bước tuyến tính · `workspace` — CHỈ dùng cho profile ở thư mục cha của sản phẩm multi-repo (meta-mode, kèm `Repos:` registry) → `CLAUDE.md` §Workspace Mode; repo thường KHÔNG dùng giá trị này |
| Output Language | `Vietnamese` — cũng là mặc định khi thiếu field (backward-compat: repo cấu hình trước khi field ra đời không bị đổi ngôn ngữ giữa dự án) | Tên tiếng Anh của ngôn ngữ bất kỳ (`English`, `Japanese`…) — `English` → mọi thứ English, quy tắc trộn ngôn ngữ tự triệt tiêu. Workspace: 1 sản phẩm = 1 ngôn ngữ, `/discover` hỏi 1 lần và ghi đồng nhất mọi profile |
| Core | C# 12 + ASP.NET Core 8 + EF Core 8 | Node.js → `rules/overrides/lang-nodejs.md` + `framework-nodejs-web.md` + `test-nodejs.md` · PHP → `rules/overrides/lang-php.md` + `framework-php-laravel.md` + `test-php.md` · **Repo đa-stack** → khai TẤT CẢ kèm scope path, stack chủ đạo trước (vd `C# (src/) + Python (tools/etl/)`) — override áp theo vùng, không chọn-một-bỏ-một; 2 framework cùng ngôn ngữ → as-is + red-flag `dual framework` + OQ |
| Database | SQL Server 2022 | Oracle → `database-oracle.md` · MySQL → `database-mysql.md` · PostgreSQL → `database-postgres.md` · MongoDB → `database-mongodb.md` |
| Observability | Serilog + Prometheus + Grafana (+ Jaeger tracing) | ELK → `monitoring-elk.md` |
| Structure | Clean Architecture | N-tier · monolith — brownfield mô tả **as-is**, không "sửa" trong profile |
| Frontend | (không có) | Next.js 14 App Router (site SEO) · React + Vite SPA (admin/dashboard) → base `rules/frontend.md` · Blade/Livewire/Inertia (Laravel server-rendered) → `framework-php-laravel.md` §K, brownfield giữ as-is |

> **Nguyên tắc override:** file override chỉ thay phần dialect/backend-specific; nguyên tắc agnostic của rule base (parametrized query, structured logging, correlation id…) **vẫn áp dụng** — xem `rules/tech-stack.md` §Core vs Peripheral. Precedence khi va chạm: `local/` > file này > kit base.
