# BusLine — Lịch trình xe buýt

Web tĩnh (HTML + JS thuần) chạy trên GitHub Pages, dữ liệu nằm ở Supabase.

## 1. Tạo cơ sở dữ liệu
1. Tạo project tại https://supabase.com.
2. Vào **SQL Editor**, dán toàn bộ `schema.sql` rồi chạy (có kèm dữ liệu mẫu tuyến 01).
3. Vào **Authentication → Users**, tạo một tài khoản (email + mật khẩu).
4. Cấp quyền admin bằng cách chạy (đổi email):
   ```sql
   update auth.users
   set raw_app_meta_data = coalesce(raw_app_meta_data,'{}'::jsonb) || '{"role":"admin"}'::jsonb
   where email = 'ban@example.com';
   ```
   Đăng xuất rồi đăng nhập lại để quyền có hiệu lực.

## 2. Điền khoá kết nối
Vào **Project Settings → API**, lấy **Project URL** và khoá **anon public**. Dán vào hai hằng số đầu phần `<script>` trong `index.html`.

Chỉ dùng khoá `anon`. Tuyệt đối không đưa khoá `service_role` vào repo. Việc ghi dữ liệu được bảo vệ bằng RLS, không phải bằng việc giấu khoá.

## 3. Đưa lên GitHub Pages
1. Tạo repo, đẩy `index.html`, `schema.sql`, `README.md` lên nhánh `main`.
2. **Settings → Pages → Deploy from a branch → main / (root)**.
3. Mở `https://<tên-bạn>.github.io/<tên-repo>/`. Quản trị ở `.../#admin` sau khi đăng nhập.

## Ghi chú
- Giờ luôn tính theo `Asia/Ho_Chi_Minh`.
- Bảng giờ tự cập nhật khi bảng `trips` thay đổi (Realtime).
- Trong Supabase, nếu muốn thêm domain GitHub Pages vào danh sách cho phép, vào **Authentication → URL Configuration**.
