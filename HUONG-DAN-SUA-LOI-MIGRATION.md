# Sửa lỗi EF Migration — 29/10/2026

Flutter của bạn đã `flutter analyze` thành công và `flutter test` đã pass 3/3. **Không cần cài lại Flutter**.

## Làm ngay

1. Sao lưu project cũ.
2. Giải nén ZIP này và thay các file trong thư mục `D:\\TranVanToanKTGK`. Không xóa `.env` đã tạo, không ghi đè mật khẩu.
3. Mở PowerShell ở `D:\\TranVanToanKTGK` và chạy:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\start-backend.ps1
```

Bản mới có local `dotnet-ef` được ghim 10.0.13, build Backend rõ ràng rồi sinh migration với `--no-build`. Mã Backend và Flutter trước đó được giữ nguyên; chỉ bổ sung điều chỉnh .NET packages, script và hướng dẫn.

## Nếu vẫn lỗi

```powershell
dotnet build .\backend\Attendance.Api\Attendance.Api.csproj -c Debug -v normal
dotnet tool run dotnet-ef -- --version
```

Gửi các dòng `error ...` và khoảng 15 dòng trước/sau. **Không gửi file `.env` hoặc mật khẩu PostgreSQL.**

## Xác nhận kết quả

Chạy:

```powershell
docker compose ps
docker compose logs --tail=40 api
```

Chỉ khi API/DB chạy và được triển khai HTTPS công khai thì mới sử dụng được từ Flutter theo yêu cầu thầy.
