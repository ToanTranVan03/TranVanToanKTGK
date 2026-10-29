# TranVanToanKTGK — Student Attendance App

Flutter/Dart Android + ASP.NET Core 10 Web API + PostgreSQL/EF Core + Docker.

**Phần 1**: Giao diện chào mừng, đăng nhập mẫu, Riverpod, GoRouter, Dio, Widget tests.
**Phần 2**: Backend + schema EF Core + Docker + status API + màn hình Flutter kiểm tra kết nối API HTTPS.

## Xem hướng dẫn Phần 2

Mở **[README-PHAN-2.md](README-PHAN-2.md)**. Hướng dẫn chi tiết lệnh PowerShell, Docker, migration và deploy nằm trong đó.

## Chạy Flutter

```powershell
flutter pub get
flutter analyze
flutter test
flutter run
```

Khi đã deploy Backend HTTPS thực:

```powershell
flutter run --dart-define=API_BASE_URL=https://<your-real-service>.onrender.com/api/v1
```

Lưu ý: URL chỉ là ví dụ, ứng dụng không sử dụng localhost làm API. Không đưa mật khẩu Database vào Flutter. `login_page.dart` vẫn là biểu mẫu mẫu; đăng nhập thật sẽ được xây dựng ở Phần 3.
