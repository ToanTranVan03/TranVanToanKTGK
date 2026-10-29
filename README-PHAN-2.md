# PHẦN 2 — Backend ASP.NET Core 10 + PostgreSQL + EF Core + Docker

**Tên project Flutter:** `TranVanToanKTGK` (package `tran_van_toan_ktgk`)

## Đã được thêm vào ZIP

- Backend **ASP.NET Core 10 Minimal API** ở `backend/Attendance.Api`.
- **Entity Framework Core 10 + Npgsql/PostgreSQL**, `AttendanceDbContext` và các bảng chính cho tài khoản, vai trò Identity, môn học, lớp học, phòng học, ghi danh, phiên điểm danh, kết quả, đơn nghỉ, QR/face/BLE/AI metadata.
- Khởi tạo sẵn **ASP.NET Core Identity** cho giai đoạn đăng nhập/OTP tiếp theo, **chưa mở** endpoint đăng ký/đăng nhập.
- API `GET /health` (kiểm tra web process) và `GET /api/v1/system/status` (kiểm tra PostgreSQL).
- `Dockerfile`, `docker-compose.yml`, script setup migration và script kiểm tra API trên Internet.
- Flutter có nút **Kiểm tra kết nối Backend** trên màn hình chính: dùng Dio gọi REST API thật sau khi đã cấu hình HTTPS.

**CHƯA triển khai Internet:** cần tài khoản Render/VPS của nhóm, cấu hình secret/DB và hostname HTTPS do nhà cung cấp cấp. Không có API thật khi chưa deploy. Backend không được coi là đã deploy chỉ vì ZIP đã có Dockerfile.

## SỬA LỖI Migration Build failed (bản cập nhật 29/10/2026)

Nếu gặp `Build started... Build failed` ở lệnh tạo migration, hãy chạy **script mới**:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\start-backend.ps1
```

Script sẽ build C# công khai trước, sau đó sử dụng local `dotnet-ef 10.0.13` và `--no-build` để tạo migration. Không phụ thuộc vào phiên bản global `dotnet-ef` trên máy.

Nếu vẫn lỗi, xem dòng `error CSxxxx` hoặc `NUxxxx` sau lệnh `dotnet build` và chạy riêng:

```powershell
dotnet build .\backend\Attendance.Api\Attendance.Api.csproj --configuration Debug --verbosity normal
dotnet tool run dotnet-ef -- --version
```

Không xóa `.env`, không xóa Docker volumes và không chạy `dotnet ef database drop`. File `.env` có mật khẩu riêng ở máy bạn, cần giữ nguyên.

Các PackageReference .NET 10 được cập nhật về bản đã phát hành ngày 13/10/2026; `System.Security.Cryptography.Pkcs` được ghim `10.0.13` để khắc phục CVE-2026-70162 và CVE-2026-84008. Sau khi sửa cần chạy `dotnet restore` lại để NuGet cập nhật.

## A. Chạy Backend bằng Docker trên máy phát triển (Windows)

Yêu cầu: **.NET 10 SDK** và **Docker Desktop** (đã mở), PowerShell. Lệnh từ thư mục `D:\TranVanToanKTGK`:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\start-backend.ps1
```

Script sẽ:
1. Tạo `.env` với mật khẩu PostgreSQL ngẫu nhiên nếu chưa có.
2. `dotnet restore` và cài `dotnet-ef` nếu cần.
3. Tạo Entity Framework migration đầu tiên trong `backend/Attendance.Api/Data/Migrations/` (khi chưa có).
4. `dotnet build` backend để phát hiện lỗi.
5. `docker compose up -d --build` cho PostgreSQL và API.

Kiểm tra:

```powershell
docker compose ps
docker compose logs --tail=100 api
```

Có thể kiểm tra backend locally bằng trình duyệt máy phát triển hoặc PowerShell nhưng **không đặt URL nội bộ này vào Flutter**; theo yêu cầu dự án, app di động chỉ dùng API được deploy HTTPS trên Internet. Nếu muốn, bạn có thể kiểm tra API ở máy dev qua `http://127.0.0.1:8080/health` chỉ để gỡ lỗi máy chủ, không dùng làm endpoint cho ứng dụng. Nếu yêu cầu của giảng viên cấm localhost ngay cả bước kiểm tra thì bỏ qua bước kiểm tra này, dùng URL sau khi deploy.

### Để chuẩn bị deploy

Sau khi script sinh migration, **commit toàn bộ thư mục `backend/Attendance.Api/Data/Migrations/` lên GitHub** cùng project. Migration phải là thành phần của bản deploy; không tạo migration mới ngẫu nhiên trên mỗi server.

**Không dùng** `EnsureCreated()` kết hợp với EF Core migrations và không dùng `EnsureDeleted()` trên dữ liệu thực tế.

## B. Deploy Backend ra Internet qua Render (yêu cầu bắt buộc)

Xem hướng dẫn chi tiết trong `infra/render/README.md`.

1. Đẩy source, đặc biệt các file migration, lên GitHub.
2. Trên Render, tạo **PostgreSQL**, chọn region và tạo user/password riêng.
3. Tạo **Web Service** mới từ repo GitHub, chọn **Docker**, root directory `backend/Attendance.Api`, Dockerfile `Dockerfile`.
4. Khai báo Environment variables **ở Render**, KHÔNG ở Flutter:

| Key | Ví dụ mô tả |
|---|---|
| `ConnectionStrings__Default` | `Host=<render-private-db-host>;Port=5432;Database=<name>;Username=<user>;Password=<secret>;SSL Mode=Require` |
| `Database__ApplyMigrationsOnStartup` | `true` |
| `ASPNETCORE_ENVIRONMENT` | `Production` |

5. Health check: `/health`. Render cấp địa chỉ `https://<actual-service>.onrender.com`.
6. Kiểm tra `https://<actual-service>.onrender.com/api/v1/system/status`:

```json
{
  "application": "Student Attendance API",
  "apiVersion": "v1",
  "serverTimeUtc": "2026-10-29T03:00:00Z",
  "databaseConnected": true
}
```

Trên đây là **JSON minh họa**, thời gian thực lấy từ server. Nếu `databaseConnected=false`, cần xem logs và kiểm tra chuỗi kết nối.

### Chạy Flutter kết nối Backend public

Trong Android Studio Terminal:

```powershell
flutter pub get
flutter analyze
flutter test
flutter run --dart-define=API_BASE_URL=https://<actual-service>.onrender.com/api/v1
```

Hoặc ở Android Studio: `Run > Edit Configurations > Additional run args` điền cùng tham số `--dart-define=...`, rồi nhấn ▶ trên Pixel 8. Sau khi app chạy lại, bấm **Kiểm tra kết nối Backend**.

Không dùng URL ví dụ hoặc localhost / 10.0.2.2 trong cấu hình di động. Không commit mật khẩu `.env` hay connection string production.

## C. Tổ chức thư mục mới

```text
TranVanToanKTGK/
├─ android/                     Flutter Android (giữ nguyên Java)
├─ lib/                         Flutter đã có, thêm backend_status/
├─ test/                        Test trước đó và test card Backend
├─ backend/Attendance.Api/
│  ├─ Attendance.Api.csproj
│  ├─ Program.cs                /health, /api/v1/system/status
│  ├─ Domain/Entities.cs        Các entity cơ sở
│  ├─ Data/AttendanceDbContext.cs
│  ├─ Data/AttendanceDbContextFactory.cs
│  ├─ Dockerfile
│  └─ appsettings.json
├─ docker-compose.yml
├─ scripts/
│  ├─ setup-backend.ps1
│  ├─ start-backend.ps1
│  └─ check-backend.ps1
└─ infra/render/README.md
```

## D. Giới hạn của Phần 2 và Phần 3

- Phần 2 mới có **kiến trúc DB + health/status API**. Chưa có REST CRUD, JWT, đăng nhập thật, OTP, Google/Microsoft, phân quyền hay điểm danh; sẽ làm ở Phần 3/4.
- Các entity và khóa ngoại đã được chuẩn bị. Chưa có tài khoản, seed dữ liệu lớp hoặc thông tin nhạy cảm nào.
- Swagger chưa bổ sung; sẽ tạo API contract cho Auth/CRUD khi hoàn thiện giai đoạn tiếp theo.
- Quyền CORS không mở wildcard; ứng dụng Android native không yêu cầu CORS. Khi cần Web, sẽ cấu hình danh sách origin cụ thể.
- Trên Render, TLS được terminate tại reverse proxy. Docker Compose là môi trường dev, không phải bản triển khai HTTPS ra Internet.
- Không tự ý chạy các lệnh xoá database / volume khi có dữ liệu thật.

## E. Kiểm tra điều kiện đạt Phần 2

- `dotnet build backend/Attendance.Api/Attendance.Api.csproj` thành công.
- `docker compose ps` cho thấy API và PostgreSQL hoạt động.
- EF migration được tạo và áp dụng vào PostgreSQL.
- Trên HTTPS public: `/health` trả OK, `/api/v1/system/status` có `databaseConnected: true`.
- Flutter trên Pixel 8 nhấn `Kiểm tra kết nối Backend` hiển thị thành công.

Nếu chưa có URL Render/VPS thì Phần 2 mới xong **mã nguồn và cấu hình**, chưa hoàn tất yêu cầu deploy Internet.
