Tôi muốn xây dựng sản phẩm "LinkVault" — Personal Bookmark Manager.

Requirements:
PRODUCT NAME: LinkVault
TAGLINE: Your personal bookmark manager — save, organize, find anything.

TARGET USER: Individual developer/knowledge worker muốn lưu trữ link có tổ chức,
             không muốn phụ thuộc vào browser bookmarks.

CORE FEATURES:

1. USER AUTHENTICATION
   - Đăng ký tài khoản bằng email + password
   - Đăng nhập, nhận JWT token
   - Mỗi user chỉ thấy bookmark của mình

2. BOOKMARK MANAGEMENT (CRUD)
   - Tạo bookmark: URL, title (auto-fetch từ URL nếu không nhập), description (optional)
   - Xem danh sách bookmark của mình (phân trang, 20/trang)
   - Sửa bookmark (title, description, tags)
   - Xóa bookmark
   - Đánh dấu bookmark là "favorite"

3. TAGS
   - Gán nhiều tags cho 1 bookmark (ví dụ: "python", "tutorial", "ai")
   - Xem tất cả tags của mình
   - Lọc bookmark theo tag

4. SEARCH
   - Tìm kiếm full-text trong title + description + URL
   - Kết hợp search + filter bookmark là “favorite” + filter tag

5. SIMPLE WEB UI
   - Trang đăng ký / đăng nhập
   - Dashboard: danh sách bookmark với search bar + tag filter
   - Form thêm/sửa bookmark
   - Responsive, dùng được trên mobile

NON-FUNCTIONAL REQUIREMENTS:
- API response time < 300ms cho 95th percentile
- Hỗ trợ 1 user concurrent (MVP — không cần scale)
- HTTPS không bắt buộc (local dev/demo)

OUT OF SCOPE (v1):
- Browser extension
- Import/export bookmarks
- Sharing bookmarks với người khác
- OAuth login (Google, GitHub)
- Email verification
- Mobile app
