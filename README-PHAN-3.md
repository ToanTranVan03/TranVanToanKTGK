# Phần 3 — Đăng ký, Email OTP, JWT, phân quyền

> Bản mã nguồn mở rộng cho `TranVanToanKTGK`. Merge lên project hiện tại, không xóa thư mục cũ. **Giữ nguyên `backend/Attendance.Api/Data/Migrations/` đã sinh trên máy bạn**: ZIP xây dựng từ bản upload giai đoạn trước có thể không chứa migration đã sinh sau khi bạn chạy `dotnet ef`.

## Chức năng đã code

- Đăng ký sinh viên bằng Email; tài khoản chưa xác nhận không được đăng nhập.
- Xác nhận Email qua mã OTP từ ASP.NET Core Identity Token Provider.
- Đăng nhập `username + password` -> gửi mã Email OTP -> xác nhận -> cấp JWT trong 2 giờ.
- Role ADMIN, LECTURER, STUDENT, Admin có API quản lý role và màn hình phân quyền.
- Flutter: đăng ký, login, OTP, dashboard 3 vai trò, lưu Access Token bằng Secure Storage, đăng xuất.
- API quan trọng: `POST /api/v1/auth/register`, `/auth/verify-email`, `/auth/resend-email`, `/auth/login`, `/auth/otp/verify`; `GET /api/v1/auth/me`; `GET /api/v1/admin/users`; `PUT /api/v1/admin/users/{id}/role`.
- Chống brute force bước đầu bằng rate limiter và Identity lockout, không cho đăng ký tự chọn role.

**Chưa có:** Google/Microsoft OAuth, SMS OTP, refresh token, biometric face login, CRUD lớp/điểm danh. Dashboard hiện mô tả chức năng, không phải CRUD thật.

## Không dùng SMTP trên Render Free

Render Free chặn outbound SMTP (25/465/587). Email OTP trong source gửi bằng **Resend HTTPS API** qua cổng 443.

1. Đăng ký Resend tại https://resend.com/ , lấy API key (không chia sẻ). Xác minh domain của bạn để gửi cho mọi email. Khi chỉ thử, `onboarding@resend.dev` thường chỉ gửi được tới email của tài khoản Resend, không phải mọi địa chỉ sinh viên.
2. Render Web Service -> Environment, **giữ nguyên** ba biến từ Phần 2 và bổ sung:

| Key | Value (ví dụ) |
| --- | --- |
| `Jwt__Key` | Chuỗi ngẫu nhiên dài ít nhất 32 byte, **bí mật** |
| `Jwt__Issuer` | `TranVanToanKTGK-API` |
| `Jwt__Audience` | `TranVanToanKTGK-Mobile` |
| `Email__ResendApiKey` | API key Resend, bắt đầu bằng `re_` |
| `Email__From` | `Student Attendance <noreply@domain-da-verify.com>` |

Tùy chọn tạo tài khoản Admin đầu tiên (không đưa vào Github):

| Key | Value |
| --- | --- |
| `BootstrapAdmin__Email` | Email admin nhận OTP được |
| `BootstrapAdmin__Username` | Tên đăng nhập admin |
| `BootstrapAdmin__Password` | Mật khẩu admin mạnh, chỉ nhập trong Render |

Sinh `Jwt__Key` trong PowerShell (chỉ sao chép kết quả vào Render, không push vào Git):

```powershell
$bytes = New-Object byte[] 48
[System.Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($bytes)
[Convert]::ToBase64String($bytes)
```

**Giữ ConnectionStrings__Default** là giá trị kết nối PostgreSQL hiện tại trên Render. Không đưa connection string vào GitHub.

> Render Free có thể mất hơn 50 giây khi khởi động lại; Dio đã được tăng receiveTimeout để không báo lỗi ngay lúc cold start.

## Merge dự án và push

1. Sao lưu `D:\TranVanToanKTGK`. Giải nén ZIP **đè các file trùng tên**, tuyệt đối **không xóa thư mục cũ trước**, vì cần giữ `Data/Migrations`, `.git` và `.env` riêng của bạn.
2. Xác nhận `backend/Attendance.Api/Data/Migrations/` có migration `InitialSchema` từ Phần 2.
3. Terminal Android Studio:

```powershell
cd D:\TranVanToanKTGK
flutter pub get
flutter analyze
flutter test
dotnet build .\backend\Attendance.Api\Attendance.Api.csproj
git status --short
```

4. Đảm bảo `.env` không có trong git status, rồi:

```powershell
git add .
git commit -m "Part 3 email OTP and RBAC"
git push origin main
```

5. Trên Render cập nhật Environment vars phía trên, chọn **Save, deploy**. Khi nhận commit mới, Render sẽ tự build lại backend. Nếu deploy thất bại, xem **dòng lỗi đầu tiên** trong Logs.
6. Kiểm tra:

```
https://tranvantoanktgk-api.onrender.com/health
https://tranvantoanktgk-api.onrender.com/api/v1/system/status
```

7. Với Pixel 8, dừng bản Flutter hiện tại rồi chạy:

```powershell
flutter run -d emulator-5554 --dart-define=API_BASE_URL=https://tranvantoanktgk-api.onrender.com/api/v1/
```

Dùng ID trong `flutter devices` nếu không phải `emulator-5554`.

## Kịch bản demo

- Đăng ký username mới, email có thể nhận từ Resend, password tối thiểu 10 ký tự theo chính sách Identity (chữ hoa, chữ thường, số, ký tự đặc biệt).
- Nhập OTP xác nhận email; đăng nhập username + password; nhận OTP thứ hai; nhập OTP để vào Dashboard Sinh viên.
- Với tài khoản Admin tạo từ Environment, đăng nhập -> OTP -> Quản lý phân quyền -> đổi role người dùng sang giảng viên.
- Đăng xuất và đăng nhập lại tài khoản giảng viên để kiểm tra dashboard riêng.

> OTP phát sinh theo cơ chế ASP.NET Identity có thời gian hiệu lực ngắn, không lưu mã thô trong DB. Khóa mã hóa ticket xác minh OTP dùng DataProtection của instance hiện tại; sau restart của Render Free, các ticket OTP đang chờ có thể mất hiệu lực: hãy đăng nhập lại. Bản học phần chưa phải triển khai production đầy đủ (cần thêm refresh token, key ring bền vững, kiểm toán, captcha, giám sát, chính sách dữ liệu và xử lý race OTP).

## Gỡ lỗi

- Render không Start / lỗi `Jwt__Key`: thêm ba biến JWT, key đủ mạnh và deploy lại.
- HTTP 503 khi đăng ký/login: chưa cấu hình Resend hoặc API gửi email lỗi.
- Không nhận OTP: kiểm tra email, mục Domains/Logs tại Resend, sender phải được xác minh.
- HTTP 401 tại `/auth/me`: token hết hạn, đăng nhập lại.
- App còn hiện giao diện cũ: Stop và chạy lại `flutter run` với `--dart-define`, không chỉ Hot Reload.
- Không thấy migration: nhớ giữ thư mục `backend/Attendance.Api/Data/Migrations` của project đang chạy trên máy; không ghi đè cả repo bằng cách xóa cũ.
