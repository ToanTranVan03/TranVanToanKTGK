# SỬA ĐĂNG KÝ / ĐĂNG NHẬP / XÁC MINH EMAIL — 29/10/2026

Bản vá này chỉ gồm 6 file Backend và Flutter trong thư mục `TranVanToanKTGK`.
Giải nén ZIP vào `D:\`, chọn Replace files. Giữ nguyên `.env`, `.git`, PostgreSQL và toàn bộ Phần 4.

Đã xử lý:
- Khi tài khoản đã tạo nhưng Resend không gửi được OTP, Flutter vẫn chuyển tới màn hình xác minh; Backend trả `emailSent=false` thay vì 503 gây nhầm.
- Màn hình đăng ký thêm nút "Đã đăng ký nhưng chưa nhận OTP? Xác minh email".
- Sau khi đăng nhập đúng mật khẩu nhưng chưa xác minh Gmail, Flutter tự chuyển tới màn hình OTP; cũng có nút gửi lại OTP trong trang đăng nhập.
- Bổ sung kiểm tra request rỗng cho các API đăng nhập/xác minh/gửi lại OTP, tránh lỗi 500.
- Backend chỉ ghi mã trạng thái lỗi từ Resend vào log (không ghi OTP/API key).

Lưu ý bắt buộc:
- `Email__From=onboarding@resend.dev` chỉ gửi email thử nghiệm tới địa chỉ chủ tài khoản Resend. Muốn gửi OTP đến nhiều Gmail khác nhau, phải xác minh domain trên Resend và dùng `Email__From` thuộc domain đó. Không có sửa code nào vượt qua hạn chế nhà cung cấp.
- Các tài khoản đã tạo nhưng chưa xác minh KHÔNG đăng ký lại; vào đăng nhập > "Chưa xác nhận Gmail? Gửi lại mã OTP", nhập Gmail và xác minh.
- Mật khẩu đã nhập lúc đăng ký không thể xem lại. Bản vá KHÔNG thêm chức năng đặt lại mật khẩu.

Kiểm tra:
```
cd D:\TranVanToanKTGK
dotnet build .\backend\Attendance.Api\Attendance.Api.csproj
flutter analyze
flutter test
git status --short
git diff --check
```
Nếu đều thành công, chỉ commit những file cần sửa (đừng commit .env):
```
git add backend/Attendance.Api/Auth/AuthEndpoints.cs backend/Attendance.Api/Auth/ResendEmailService.cs lib/features/auth/data/auth_api.dart lib/features/auth/presentation/pages/login_page.dart lib/features/auth/presentation/pages/register_page.dart lib/features/auth/presentation/pages/otp_page.dart
git diff --cached --name-only
git commit -m "Fix registration login email verification recovery"
git push origin main
```
Render: Deploy latest commit, kiểm tra Live. Flutter: Stop rồi Run, dùng --dart-define API_BASE_URL đúng.

Không thể chạy Flutter/.NET tests trong môi trường tạo gói; cần chạy trên máy Windows trước deploy.
