using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;

namespace Attendance.Api.Auth;

/// <summary>
/// OTP delivery with backward compatibility:
/// - Google Apps Script (Gmail) is preferred when both Apps Script settings exist.
/// - Existing Resend HTTPS API remains as a fallback.
/// - If Gmail is not configured, the old Resend-only behavior is preserved.
/// All OTP generation and verification stays in AuthEndpoints / ASP.NET Identity.
/// </summary>
public sealed class ResendEmailService(
    HttpClient http,
    IConfiguration config,
    ILogger<ResendEmailService> logger)
{
    private bool GmailConfigured =>
        !string.IsNullOrWhiteSpace(config["Email:AppsScriptUrl"]) &&
        !string.IsNullOrWhiteSpace(config["Email:AppsScriptSecret"]);

    private bool ResendConfigured =>
        !string.IsNullOrWhiteSpace(config["Email:ResendApiKey"]) &&
        !string.IsNullOrWhiteSpace(config["Email:From"]);

    // AuthEndpoints already checks this property before registration/login.
    public bool IsConfigured => GmailConfigured || ResendConfigured;

    public async Task<bool> SendOtpAsync(
        string email, string code, string context, CancellationToken ct)
    {
        // Gmail handles all recipients when configured; no DNS/domain required.
        if (GmailConfigured &&
            await SendViaAppsScriptAsync(email, code, context, ct))
        {
            return true;
        }

        // Keep the previously working provider intact as backup.
        if (ResendConfigured &&
            await SendViaResendAsync(email, code, context, ct))
        {
            return true;
        }

        logger.LogWarning("OTP was not accepted by any configured email provider.");
        return false;
    }

    private async Task<bool> SendViaAppsScriptAsync(
        string email, string code, string context, CancellationToken ct)
    {
        var rawUrl = config["Email:AppsScriptUrl"];
        if (!Uri.TryCreate(rawUrl, UriKind.Absolute, out var endpoint) ||
            endpoint.Scheme != Uri.UriSchemeHttps ||
            !string.Equals(endpoint.Host, "script.google.com",
                StringComparison.OrdinalIgnoreCase) ||
            !endpoint.AbsolutePath.StartsWith("/macros/s/", StringComparison.Ordinal) ||
            !endpoint.AbsolutePath.EndsWith("/exec", StringComparison.Ordinal))
        {
            logger.LogWarning("Email Apps Script URL is not a valid Google /exec web app URL.");
            return false;
        }

        // Never put the secret, recipient or OTP in the URL or logs.
        using var request = new HttpRequestMessage(HttpMethod.Post, endpoint)
        {
            Content = JsonContent.Create(new
            {
                secret = config["Email:AppsScriptSecret"],
                to = email,
                code,
                purpose = context
            })
        };

        try
        {
            // Apps Script ContentService normally redirects the JSON result to
            // script.googleusercontent.com. HttpClient follows that redirect.
            using var response = await http.SendAsync(request, ct);
            if (!response.IsSuccessStatusCode)
            {
                logger.LogWarning(
                    "Google Apps Script OTP endpoint returned HTTP {StatusCode}.",
                    (int)response.StatusCode);
                return false;
            }

            await using var body = await response.Content.ReadAsStreamAsync(ct);
            using var json = await JsonDocument.ParseAsync(body, cancellationToken: ct);
            var sent = json.RootElement.ValueKind == JsonValueKind.Object &&
                       json.RootElement.TryGetProperty("ok", out var value) &&
                       value.ValueKind == JsonValueKind.True;

            if (!sent)
            {
                logger.LogWarning(
                    "Google Apps Script returned an unsuccessful OTP response. " +
                    "Check deployment access, script properties and Gmail quota.");
            }
            return sent;
        }
        catch (HttpRequestException ex)
        {
            logger.LogWarning("Google Apps Script HTTPS error: {Type}.",
                ex.GetType().Name);
            return false;
        }
        catch (TaskCanceledException) when (!ct.IsCancellationRequested)
        {
            logger.LogWarning("Google Apps Script email request timed out.");
            return false;
        }
        catch (JsonException)
        {
            logger.LogWarning("Google Apps Script did not return JSON. " +
                "Check the /exec deployment and access settings.");
            return false;
        }
    }

    private async Task<bool> SendViaResendAsync(
        string email, string code, string context, CancellationToken ct)
    {
        using var request = new HttpRequestMessage(
            HttpMethod.Post, "https://api.resend.com/emails");
        request.Headers.Authorization = new AuthenticationHeaderValue(
            "Bearer", config["Email:ResendApiKey"]);
        request.Content = JsonContent.Create(new
        {
            from = config["Email:From"],
            to = new[] { email },
            subject = $"Student Attendance - mã OTP {context}",
            text = $"Mã OTP của bạn: {code}. Mã dùng trong thời gian ngắn. " +
                   "Không chia sẻ mã này với bất kỳ ai. " +
                   "Nếu bạn không yêu cầu, hãy bỏ qua email."
        });

        try
        {
            using var response = await http.SendAsync(request, ct);
            if (!response.IsSuccessStatusCode)
            {
                logger.LogWarning("Resend rejected the OTP email, HTTP {StatusCode}.",
                    (int)response.StatusCode);
            }
            return response.IsSuccessStatusCode;
        }
        catch (HttpRequestException ex)
        {
            logger.LogWarning("Resend HTTPS error: {Type}.", ex.GetType().Name);
            return false;
        }
        catch (TaskCanceledException) when (!ct.IsCancellationRequested)
        {
            logger.LogWarning("Resend email request timed out.");
            return false;
        }
    }
}
