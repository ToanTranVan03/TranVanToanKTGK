using System.Net.Http.Headers;
using System.Net.Http.Json;

namespace Attendance.Api.Auth;

// Render Free blocks outbound SMTP ports. Use the Resend HTTPS API instead.
public sealed class ResendEmailService(HttpClient http, IConfiguration config)
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
            return response.IsSuccessStatusCode;
        }
        catch (HttpRequestException) { return false; }
        catch (TaskCanceledException) { return false; }
    }
}
