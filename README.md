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

## Bản đồ và tài khoản người dùng (v2)
- Chạy thêm `schema_v2.sql` sau `schema.sql`. File này tạo bảng `profiles`, tự tạo hồ sơ khi có người đăng ký, và cho tài xế đổi trạng thái chuyến của xe mình.
- Bản đồ dùng Leaflet + OpenStreetMap, đường đi lấy từ máy chủ demo OSRM (nếu lỗi sẽ vẽ đường thẳng nối các điểm dừng). Khi chạy thật nên thay bằng dịch vụ định tuyến riêng.
- Đăng ký công khai chỉ tạo vai trò **khách hàng** hoặc **tài xế**. Quyền admin và việc gán xe cho tài xế chỉ admin làm được (tab "Người dùng" trong trang quản trị).
- Để đăng ký không cần xác nhận email khi thử nghiệm: Authentication → Providers → Email → tắt "Confirm email". Khi chạy thật nên bật lại.
- Thêm domain GitHub Pages vào Authentication → URL Configuration → Site URL để link xác nhận email trỏ đúng.
