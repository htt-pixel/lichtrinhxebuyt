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

## Dữ liệu 25 tuyến, giá vé, đặt chỗ (v3)
Chạy lần lượt trong SQL Editor: `schema.sql` → `schema_v2.sql` → `schema_v3.sql` → `seed_1_routes_stops_buses.sql` → `seed_2_trips_a.sql` → `seed_3_trips_b.sql`.
- `seed_1` **xoá toàn bộ** tuyến, điểm dừng, xe, chuyến và đặt chỗ cũ trước khi nạp dữ liệu mẫu.
- 20 tuyến dừng cố định (giá 6.000–7.000 đ/lượt) và 5 tuyến **xe đón dọc đường** (DD1–DD5): giá = 8.000 đ + 1.500 đ/km, làm tròn 500 đ, tính từ điểm đón (chọn trên bản đồ) đến điểm trả.
- Giờ tới từng điểm dừng tính từ cột `offset_min`. Độ trễ (`delay_min`) cao hơn ở giờ cao điểm 6:30–8:30 và 16:30–18:30. Tài xế và admin cập nhật độ trễ thực tế.
- Địa danh là thật nhưng tọa độ xấp xỉ, trạm trung gian (tên "Trạm 05-03") nội suy theo đường thẳng, giá và lịch chạy là mẫu. Cần thay bằng dữ liệu chính thức khi vận hành.
- Giá vé và kiểm tra chỗ trống được tính ở server (trigger), người dùng không sửa được. Chưa tích hợp cổng thanh toán: chuyển khoản/ví điện tử chỉ ghi nhận hình thức, admin đánh dấu "Đã thanh toán".
- Muốn sinh lại dữ liệu: `python3 generate_seed.py`.

## Đặt chỗ không cần tài khoản/email (v4) và 50 tuyến
Thứ tự chạy mới: `schema.sql` → `schema_v2.sql` → `schema_v3.sql` → `schema_v4.sql` → `seed_1_routes_stops_buses.sql` → `seed_2_trips_a.sql` → `seed_3_trips_b.sql` → `seed_4_trips_c.sql` → `seed_5_trips_d.sql` (thay cho thứ tự ở mục v3).
- Khách không đăng nhập nhập họ tên + số điện thoại, nhận **mã đặt chỗ 8 ký tự**. Nút "Tra cứu vé" cho xem hoặc huỷ vé bằng mã + số điện thoại. Họ tên và số điện thoại được nhớ trên thiết bị (localStorage) nếu khách chọn.
- Khách vãng lai chỉ **thêm** được đặt chỗ, không đọc được bảng. Thông tin cá nhân chỉ admin xem (tab "Đặt chỗ"). Mỗi số điện thoại giới hạn 5 vé chưa thanh toán trong 24 giờ.
- Khi mở công khai nên bật CAPTCHA (Supabase: Authentication → Attack Protection) hoặc đặt rate limit ở tầng ngoài, vì ai cũng gửi được đặt chỗ ảo.
- Dữ liệu mẫu giờ có 50 tuyến (40 dừng cố định, 10 xe đón dọc đường). Danh sách tuyến có bộ lọc loại xe và đếm số tuyến.
