# TRAN VAN TOAN KTGK — PHAN 4 (CRUD QL DIEM DANH)

Day la **ban bo sung vao project dang chay**, KHONG PHAI project Flutter moi.
Code giu nguyen Phan 3 (Email OTP/JWT/Resend) va ket noi thang Render PostgreSQL.

## 1. Copy dung thu muc

ZIP co thu muc goc `TranVanToanKTGK/`.
- Neu dung Windows Explorer: giai nen vao `D:\`, cho phep **Replace files**.
- Hoac PowerShell: `Expand-Archive -Path "<duong-dan-toi-ZIP>" -DestinationPath "D:\" -Force`
- Khong giai nen vao `D:\TranVanToanKTGK` neu Windows se tao thu muc long `TranVanToanKTGK\TranVanToanKTGK`.
- Khong xoa `.git`, `.env`, `backend/Attendance.Api/Data/Migrations`, database Render hay code Phan 3.
- Neu co thay doi source chua commit, sao luu / git commit truoc khi giai nen.

## 2. Những file được đưa vào

| File | Mục đích |
| --- | --- |
| `backend/Attendance.Api/Academics/AcademicEndpoints.cs` | API CRUD, kiểm tra vai trò và quyền trên lớp |
| `backend/Attendance.Api/Program.cs` | Đăng ký `MapAcademicEndpoints` và policy `STAFF` |
| `lib/features/academics/data/academic_api.dart` | Client Dio cho CRUD |
| `lib/features/academics/presentation/pages/academic_pages.dart` | UI quản lý môn, phòng, lớp, SV, buổi học, điểm danh, đơn nghỉ |
| `lib/app/router/app_router.dart` | Đường dẫn màn hình và bảo vệ phiên đăng nhập |
| `lib/features/dashboards/presentation/pages/dashboard_page.dart` | Menu chức năng thật theo vai trò |
| `README-PHAN-4.md` | Hướng dẫn này |

**Không cần migration mới:** Domain entities và `AttendanceDbContext` của Phần 2 đã có bảng.

## 3. Lệnh kiểm tra trên Android Studio Terminal

```powershell
cd D:\TranVanToanKTGK
dotnet build .\backend\Attendance.Api\Attendance.Api.csproj
flutter pub get
flutter analyze
flutter test
```

Nếu dotnet/flutter có lỗi, **không push GitHub** cho tới khi xử lý xong.

## 4. Push/deploy

```powershell
git status --short
git diff --check
git add backend/Attendance.Api/Program.cs backend/Attendance.Api/Academics/AcademicEndpoints.cs lib/app/router/app_router.dart lib/features/dashboards/presentation/pages/dashboard_page.dart lib/features/academics/data/academic_api.dart lib/features/academics/presentation/pages/academic_pages.dart README-PHAN-4.md
git diff --cached --name-only
git commit -m "Part 4 academic CRUD attendance and leave management"
git push origin main
```

Vào Render > `tranvantoanktgk-api` > Deploy latest commit (nếu Auto Deploy chưa tự chạy).
Kiểm tra Render Live và endpoint `GET /health` = `Healthy`.

Khởi động lại Flutter (không chỉ hot reload):

```powershell
flutter run --dart-define=API_BASE_URL=https://tranvantoanktgk-api.onrender.com/api/v1/
```

Nếu muốn bấm nút ▶ trên Android Studio, đặt Additional run args:

```
--dart-define=API_BASE_URL=https://tranvantoanktgk-api.onrender.com/api/v1/
```

## 5. Thao tác kiểm thử đúng thứ tự

1. Đăng nhập **ADMIN**. Nếu chưa có admin, đặt ba Render Environment keys `BootstrapAdmin__Username`, `BootstrapAdmin__Email`, `BootstrapAdmin__Password` bằng giá trị riêng (KHÔNG đưa mật khẩu vào GitHub), deploy lại rồi đăng nhập. Chức năng bootstrap ở Phần 3 đã hỗ trợ.
2. Admin mở **Môn học** > thêm môn, sửa, xem, xóa khi chưa có lớp.
3. Admin mở **Phòng học** > thêm phòng với tọa độ; sửa/xóa khi chưa dùng.
4. Admin mở **Lớp học** > tạo lớp, chọn môn/phòng; vào chi tiết > phân công giảng viên và thêm SV bằng username chính xác. Sinh viên cần đăng ký Email OTP trước.
5. Admin mở **Phân quyền** và chuyển tài khoản giảng viên sang `LECTURER`. Giảng viên phải **đăng xuất, đăng nhập lại** để JWT có vai trò mới.
6. Giảng viên đăng nhập > **Lớp giảng dạy** > mở lớp > **Các buổi điểm danh** > tạo phiên `OPEN` trong thời gian hiện tại.
7. Sinh viên thuộc lớp đăng nhập > **Lớp học và điểm danh** > chọn lớp/phiên > **Điểm danh thử nghiệm** (thao tác thủ công chỉ dành cho Phần 4).
8. Giảng viên mở kết quả để cập nhật `PRESENT`, `LATE`, `ABSENT`, `EXCUSED`.
9. Sinh viên vào **Đơn xin nghỉ** > gửi đơn, sửa/thu hồi khi `PENDING`; giảng viên duyệt/từ chối, học viên xem kết quả. Đơn được duyệt tạo/cập nhật trạng thái `EXCUSED`.

## 6. Phạm vi / lưu ý

- Chỉ tài khoản đã xác nhận Email OTP và còn hoạt động mới được sử dụng API Phần 4.
- API kiểm tra JWT, vai trò, quyền phụ trách lớp, thành viên của lớp. Không dùng UI làm lớp bảo mật duy nhất.
- Xóa lớp/môn/phiên khi đã có dữ liệu liên quan bị chặn để giữ toàn vẹn CSDL.
- Xóa SV qua quản trị là **vô hiệu hóa tài khoản**, không xóa điểm danh lịch sử.
- Đăng ký học viên thông qua Phần 3, quản lý hồ sơ và xếp lớp qua Phần 4.
- **Điểm danh SELF_DEMO chưa có chống gian lận**, chỉ phục vụ kiểm thử CRUD. Phần sau phải bắt buộc quét QR, GPS hoặc cơ chế xác thực tương đương trước khi chấm công chính thức.
- Phần 4 chưa triển khai nhận diện khuôn mặt, định vị GPS, quét QR, BLE, AI.
- Bản ZIP được tạo bằng kiểm tra tĩnh trong môi trường không có .NET SDK và Flutter SDK; bắt buộc chạy `dotnet build`, `flutter analyze`, `flutter test` trên máy Windows của bạn để xác nhận.
