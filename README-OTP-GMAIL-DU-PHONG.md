# BỔ SUNG GMAIL OTP (GIỮ NGUYÊN RESEND) – TranVanToanKTGK

## Mục tiêu

- **Không xóa, không thay đổi Resend đang dùng.** Resend vẫn là phương án dự phòng.
- Khi cấu hình đủ `Email__AppsScriptUrl` và `Email__AppsScriptSecret`, Backend **ưu tiên Gmail qua Google Apps Script** để gửi OTP đăng ký, xác nhận email, gửi lại OTP và đăng nhập. Nếu Gmail thất bại, Backend **thử Resend**.
- **Không sửa Flutter, Identity, PostgreSQL, các API hoặc QR/GPS.** Mã OTP vẫn do ASP.NET Core Identity tạo và kiểm tra ở máy chủ.
- Đây là kênh gửi dùng cho đồ án/demo với giới hạn số người nhận của Gmail; không phải nền tảng email sản xuất quy mô lớn.

## 1. Giải nén

ZIP có thư mục `TranVanToanKTGK` ở cấp đầu. **Giải nén vào `D:\`**, chọn ghi đè một file:

`D:\TranVanToanKTGK\backend\Attendance.Api\Auth\ResendEmailService.cs`

File mới để **sao chép vào Google Apps Script**, không chạy trực tiếp trong Flutter/.NET:

`D:\TranVanToanKTGK\scripts\otp-google-apps-script\Code.gs`

Không chỉnh sửa `.env`, `AuthEndpoints.cs`, `AuthSetup.cs`, `Program.cs`, hay database.

## 2. Tạo Google Apps Script

1. Vào https://script.google.com/ và đăng nhập Gmail muốn dùng để **gửi** OTP.
2. Tạo **New project**. Mở file `Code.gs` trên máy tính rồi **copy toàn bộ nội dung** dán vào `Code.gs` trong trình duyệt Apps Script.
3. Bấm **Save**. Đặt tên project, ví dụ `TranVanToanKTGK OTP`.
4. Tạo **bí mật chia sẻ ngẫu nhiên** (PowerShell):

   ```powershell
   $bytes = New-Object byte[] 48
   $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
   $rng.GetBytes($bytes)
   $rng.Dispose()
   [Convert]::ToBase64String($bytes) | Set-Clipboard
   ```

   Giá trị bí mật đã được sao chép vào Clipboard. **Không gửi bí mật cho người khác, không lưu trong GitHub.**
5. Trong Apps Script → **Project Settings** (biểu tượng bánh răng) → **Script Properties** → **Add script property**:

   | Property | Value |
   |---|---|
   | `SHARED_SECRET` | Dán giá trị bí mật từ Clipboard |

6. Trong editor chọn hàm **`authorizeMail`** rồi bấm **Run** một lần; cấp quyền MailApp gửi email cho Gmail của bạn. Có thể hiện thông báo xác minh quyền truy cập của Google nếu script tự tạo chưa được xác minh; chỉ cấp quyền cho **script chính bạn vừa tạo**.
7. Chọn **Deploy → New deployment → Select type: Web app**; cấu hình:

   - **Execute as:** Me
   - **Who has access:** Anyone
   - Bấm **Deploy**, hoàn tất các bước xác nhận quyền của Google.

8. **Copy Web app URL** có dạng:

   `https://script.google.com/macros/s/xxxxxxxxxxxxxxxx/exec`

   **Không dùng URL `/dev`, không dùng đường dẫn trang editor, không thêm token vào URL.** Nếu Google không cho chọn Anyone (ví dụ giới hạn tài khoản tổ chức), phải dùng Gmail cá nhân hoặc phương án khác.

## 3. Cấu hình Render (giữ nguyên các biến Resend)

Render → `tranvantoanktgk-api` → **Environment**:

| KEY | VALUE |
|---|---|
| `Email__AppsScriptUrl` | **Web app URL** ở bước 2, kết thúc `/exec` |
| `Email__AppsScriptSecret` | **Cùng bí mật** đã đặt vào `SHARED_SECRET` của Apps Script |

**Giữ nguyên `Email__ResendApiKey` và `Email__From`.** Nếu Gmail gửi được, Backend không gọi Resend. Nếu Gmail không gửi được, Backend thử Resend. Nếu xóa cả hai biến Apps Script, Backend vẫn gửi bằng Resend như cũ.

Bấm **Save, deploy** để Render tải cấu hình mới. Không đưa URL và secret vào mã nguồn, `appsettings.json`, ảnh chụp hoặc tài liệu GitHub. URL riêng lẻ không phải mật khẩu nhưng bạn vẫn nên giữ cùng secret.

## 4. Build và push code (trên Android Studio / PowerShell)

```powershell
cd D:\TranVanToanKTGK
dotnet build .\backend\Attendance.Api\Attendance.Api.csproj
flutter analyze
flutter test
git status --short
git add backend/Attendance.Api/Auth/ResendEmailService.cs scripts/otp-google-apps-script/Code.gs README-OTP-GMAIL-DU-PHONG.md
git diff --cached --name-only
git diff --cached --check
git commit -m "Add Gmail OTP delivery with Resend fallback"
git push origin main
```

Kiểm tra **không có secret, `.env`, mật khẩu** ở `git diff --cached` trước khi commit. Sau khi push, Render → **Manual Deploy → Deploy latest commit**; đảm bảo dịch vụ đã `Live` và dùng commit mới nhất. Bạn có thể thiết lập Environment trước hoặc sau khi push.

## 5. Kiểm thử không dùng Terminal gửi OTP

1. Trên Flutter chọn **Đăng nhập → Chưa xác nhận Gmail? Gửi lại mã OTP** và nhập email của tài khoản `vien` hoặc `xuyen` đã tạo (KHÔNG đăng ký trùng lần nữa).
2. Nhấn **Gửi lại OTP xác nhận**; kiểm tra Gmail nhận email từ Gmail đã chạy Apps Script (Hộp thư đến/Spam).
3. Nhập mã 6 số ở Flutter → xác minh. Đăng nhập bằng username và mật khẩu đã tạo, kiểm tra có nhận **OTP đăng nhập** qua Gmail không.
4. Để test đăng ký mới, dùng **email khác của bạn**, tạo username chưa dùng, thử đăng ký → OTP xác minh → đăng nhập → OTP đăng nhập.

Nếu email chưa đến:

- Apps Script → **Executions**: kiểm tra có lần chạy `doPost` không. Có lời gọi mà `MailApp` không gửi được thì kiểm tra **Script Properties, quyền gửi MailApp và Gmail quota**.
- Nếu **không có** lần chạy `doPost`: kiểm tra `Email__AppsScriptUrl`, `Email__AppsScriptSecret`, Render deploy và Web App **Who has access = Anyone**.
- Render → Logs: sẽ có cảnh báo tên nhà cung cấp và lỗi HTTP (không có mã OTP, email hoặc secret). Nếu Resend vẫn chưa xác minh domain và Gmail lỗi, OTP cũng sẽ không tới.
- Apps Script phản hồi `ok=true` nghĩa là **MailApp chấp nhận thao tác gửi**, chưa bảo đảm thư đã được Gmail phát vào Inbox; kiểm tra Spam và quota.
- Khi sửa `Code.gs` **sau deploy**, cần **Deploy → Manage deployments → Edit → New version → Deploy** để `/exec` sử dụng phiên bản mới.

## 6. Lưu ý bảo mật và giới hạn

- Apps Script được triển khai công khai (`Anyone`) để Backend Render gọi được, nhưng mỗi yêu cầu POST đều phải có `SHARED_SECRET` dài **ít nhất 32 ký tự**; secret chỉ ở Render Environment và Apps Script Script Properties.
- Ứng dụng **không cung cấp API công khai để gửi một email tùy ý**; email người nhận và mã OTP chỉ lấy từ luồng Authentication của Backend.
- Không sử dụng phương án gửi OTP về Telegram, hiển thị OTP trong app hay cho Admin xem OTP; như vậy mất mục đích xác thực email.
- Gmail cá nhân có quota gửi thư Apps Script (thường tối đa **100 người nhận/ngày**, có thể thay đổi). Giữ Rate Limiting hiện có cho API auth và **không bấm Gửi lại OTP liên tục**.
- Nếu gửi Gmail thành công nhưng phản hồi HTTP bị ngắt, Backend có thể thử Resend và dẫn đến hai email cùng mã. Đây là lỗi mạng có thể xảy ra khi dùng dự phòng; không chia sẻ OTP.
- Không cần DNS cho Gmail gửi qua Apps Script, nhưng dùng Gmail cá nhân với tài khoản của bạn để trình diễn, không triển khai sản xuất nhiều người.
- Tôi chưa chạy `dotnet build` trong môi trường đóng gói vì không có .NET SDK. **Bắt buộc kiểm tra build trên máy Windows của bạn trước khi push.**
