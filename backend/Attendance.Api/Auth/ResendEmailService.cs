using System.Net.Http.Headers;
using System.Net.Http.Json;

namespace Attendance.Api.Auth;

// Render Free blocks outbound SMTP ports. Use the Resend HTTPS API instead.
public sealed class ResendEmailService(HttpClient http, IConfiguration config, ILogger<ResendEmailService> logger)
{
    public bool IsConfigured => !string.IsNullOrWhiteSpace(config["Email:ResendApiKey"])
        && !string.IsNullOrWhiteSpace(config["Email:From"]);

    public async Task<bool> SendOtpAsync(string email, string code, string context, CancellationToken ct)
    {
        if (!IsConfigured) return false;
        using var request = new HttpRequestMessage(HttpMethod.Post, "https://api.resend.com/emails");
        request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", config["Email:ResendApiKey"]);
        request.Content = JsonContent.Create(new
        {
            from = config["Email:From"],
            to = new[] { email },
            subject = $"Student Attendance - mã OTP {context}",
            text = $"Mã OTP của bạn: {code}. Mã dùng trong thời gian ngắn. Không chia sẻ mã này với bất kỳ ai. Nếu không yêu cầu, hãy bỏ qua email."
        });
        try
        {
            using var response = await http.SendAsync(request, ct);
            if (!response.IsSuccessStatusCode)
                logger.LogWarning("Resend không chấp nhận yêu cầu gửi OTP, HTTP {StatusCode}. Kiểm tra domain/email nhận trên Resend.",
                    (int)response.StatusCode);
            return response.IsSuccessStatusCode;
        }
        catch (HttpRequestException ex)
        {
            logger.LogWarning("Lỗi kết nối HTTPS tới Resend: {ErrorType}", ex.GetType().Name);
            return false;
        }
        catch (TaskCanceledException)
        {
            logger.LogWarning("Gửi Resend hết thời gian chờ.");
            return false;
        }
    }
}
