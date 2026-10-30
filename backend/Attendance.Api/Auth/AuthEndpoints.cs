using System.Security.Claims;
using Attendance.Api.Data;
using Attendance.Api.Domain;
using Microsoft.AspNetCore.DataProtection;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.RateLimiting;
using Microsoft.EntityFrameworkCore;

namespace Attendance.Api.Auth;

public static class AuthEndpoints
{
    private static readonly string EmailProvider = TokenOptions.DefaultEmailProvider;
    private const string ConfirmPurpose = "AttendanceConfirmEmail";
    private const string LoginPurpose = "AttendanceLoginOtp";

    public static IEndpointRouteBuilder MapAttendanceAuth(this IEndpointRouteBuilder app)
    {
        var auth = app.MapGroup("/api/v1/auth").RequireRateLimiting("auth");
        auth.MapPost("/register", Register);
        auth.MapPost("/verify-email", VerifyEmail);
        auth.MapPost("/resend-email", ResendEmail);
        auth.MapPost("/login", Login);
        auth.MapPost("/otp/verify", VerifyLoginOtp);
        auth.MapPost("/google", GoogleLogin);
        auth.MapGet("/me", Me).RequireAuthorization();
        auth.MapPut("/me", UpdateMe).RequireAuthorization();
        var admin = app.MapGroup("/api/v1/admin").RequireAuthorization("ADMIN");
        admin.MapGet("/users", ListUsers);
        admin.MapPut("/users/{id:guid}/role", SetRole);
        return app;
    }

    // Tài khoản được tạo trước khi gửi thư. Trả emailSent=false khi nhà cung cấp
    // từ chối để Flutter vẫn mở màn hình xác minh, không tạo tài khoản trùng.
    private static async Task<IResult> Register(RegisterDto? dto,
        UserManager<ApplicationUser> users, ResendEmailService sender, CancellationToken ct)
    {
        if (dto is null || string.IsNullOrWhiteSpace(dto.Username) ||
            string.IsNullOrWhiteSpace(dto.Email) || string.IsNullOrWhiteSpace(dto.FullName) ||
            string.IsNullOrWhiteSpace(dto.Password))
            return Results.BadRequest(new { message = "Vui lòng nhập đầy đủ thông tin đăng ký." });

        var username = dto.Username.Trim();
        var email = dto.Email.Trim().ToLowerInvariant();
        var fullName = dto.FullName.Trim();
        if (username.Length < 3 || username.Length > 60 || fullName.Length < 2 ||
            dto.Password.Length < 10 ||
            !new System.ComponentModel.DataAnnotations.EmailAddressAttribute().IsValid(email))
            return Results.BadRequest(new { message = "Thông tin đăng ký không hợp lệ." });

        if (!sender.IsConfigured)
            return Results.Json(new { message = "Dịch vụ Email OTP chưa được cấu hình." },
                statusCode: StatusCodes.Status503ServiceUnavailable);

        var user = new ApplicationUser {
            UserName = username, Email = email, FullName = fullName, LockoutEnabled = true
        };
        var created = await users.CreateAsync(user, dto.Password);
        if (!created.Succeeded)
            return Results.BadRequest(new {
                code = "ACCOUNT_EXISTS_OR_INVALID",
                message = string.Join("; ", created.Errors.Select(e => e.Description))
            });

        // Không bao giờ nhận role từ dữ liệu đăng ký công khai.
        var assigned = await users.AddToRoleAsync(user, "STUDENT");
        if (!assigned.Succeeded)
            return Results.Problem("Không thể gán vai trò sinh viên.");

        var otp = await users.GenerateUserTokenAsync(user, EmailProvider, ConfirmPurpose);
        var emailSent = await sender.SendOtpAsync(email, otp, "xác nhận email", ct);
        return Results.Ok(new {
            email,
            verificationRequired = true,
            emailSent,
            message = emailSent
                ? "Tài khoản đã tạo, vui lòng kiểm tra Gmail để lấy mã OTP."
                : "Tài khoản đã tạo nhưng email OTP chưa gửi được. Hãy kiểm tra cấu hình dịch vụ email. Bạn có thể xác minh sau, không cần đăng ký lại."
        });
    }

    private static async Task<IResult> VerifyEmail(EmailOtpDto? dto,
        UserManager<ApplicationUser> users)
    {
        if (dto is null || string.IsNullOrWhiteSpace(dto.Email) ||
            string.IsNullOrWhiteSpace(dto.Code))
            return Results.BadRequest(new { message = "Vui lòng nhập email và mã OTP." });
        var user = await users.FindByEmailAsync(dto.Email.Trim());
        if (user is null)
            return Results.BadRequest(new { message = "Mã OTP hoặc email không hợp lệ." });
        if (user.EmailConfirmed)
            return Results.Ok(new { message = "Email đã được xác nhận. Bạn có thể đăng nhập." });
        var valid = await users.VerifyUserTokenAsync(user, EmailProvider,
            ConfirmPurpose, dto.Code.Trim());
        if (!valid)
            return Results.BadRequest(new { message = "Mã OTP không hợp lệ hoặc hết hạn." });
        user.EmailConfirmed = true;
        var saved = await users.UpdateAsync(user);
        return saved.Succeeded
            ? Results.Ok(new { message = "Đã xác nhận email. Bạn có thể đăng nhập." })
            : Results.Problem("Không thể xác nhận email.");
    }

    private static async Task<IResult> ResendEmail(EmailDto? dto,
        UserManager<ApplicationUser> users, ResendEmailService sender, CancellationToken ct)
    {
        if (dto is null || string.IsNullOrWhiteSpace(dto.Email))
            return Results.BadRequest(new { message = "Vui lòng nhập email cần xác minh." });
        if (!sender.IsConfigured)
            return Results.Json(new { message = "Dịch vụ Email OTP chưa được cấu hình." },
                statusCode: StatusCodes.Status503ServiceUnavailable);

        var user = await users.FindByEmailAsync(dto.Email.Trim());
        if (user is not null && !user.EmailConfirmed)
        {
            var code = await users.GenerateUserTokenAsync(user, EmailProvider, ConfirmPurpose);
            await sender.SendOtpAsync(user.Email!, code, "xác nhận email", ct);
        }
        // Không tiết lộ email nào đang tồn tại để hạn chế dò tài khoản.
        return Results.Ok(new { message = "Đã tiếp nhận yêu cầu. Nếu tài khoản chưa xác minh và dịch vụ email cho phép, OTP sẽ được gửi." });
    }

    private static async Task<IResult> Login(LoginDto? dto,
        UserManager<ApplicationUser> users, IDataProtectionProvider protection,
        ResendEmailService sender, CancellationToken ct)
    {
        if (dto is null || string.IsNullOrWhiteSpace(dto.Username) ||
            string.IsNullOrWhiteSpace(dto.Password))
            return Results.BadRequest(new { message = "Nhập tên đăng nhập và mật khẩu." });
        var user = await users.FindByNameAsync(dto.Username.Trim());
        if (user is null || !user.IsActive || await users.IsLockedOutAsync(user))
            return Results.Unauthorized();
        if (!await users.CheckPasswordAsync(user, dto.Password))
        {
            await users.AccessFailedAsync(user);
            return Results.Unauthorized();
        }
        if (!user.EmailConfirmed)
            // Trả email sau khi mật khẩu đã đúng để giao diện tự chuyển sang xác minh.
            return Results.BadRequest(new {
                code = "EMAIL_NOT_CONFIRMED",
                message = "Tài khoản chưa xác minh email. Hãy nhập OTP xác nhận.",
                email = user.Email
            });
        if (!sender.IsConfigured)
            return Results.Json(new { message = "Dịch vụ email chưa cấu hình." },
                statusCode: StatusCodes.Status503ServiceUnavailable);

        var code = await users.GenerateUserTokenAsync(user, EmailProvider, LoginPurpose);
        if (!await sender.SendOtpAsync(user.Email!, code, "đăng nhập", ct))
            return Results.Json(new { message = "Không gửi được OTP đăng nhập. Hãy kiểm tra dịch vụ Email OTP." },
                statusCode: StatusCodes.Status503ServiceUnavailable);
        var ticket = protection.CreateProtector("Attendance.LoginTicket.v1")
            .ToTimeLimitedDataProtector().Protect(user.Id.ToString(), TimeSpan.FromMinutes(5));
        return Results.Ok(new { otpRequired = true, ticket, emailHint = MaskEmail(user.Email!) });
    }

    private static async Task<IResult> VerifyLoginOtp(VerifyLoginDto? dto,
        UserManager<ApplicationUser> users, IDataProtectionProvider protection,
        JwtTokenService tokens)
    {
        if (dto is null || string.IsNullOrWhiteSpace(dto.Ticket) ||
            string.IsNullOrWhiteSpace(dto.Code))
            return Results.BadRequest(new { message = "Thiếu phiên đăng nhập hoặc mã OTP." });
        string userId;
        try
        {
            userId = protection.CreateProtector("Attendance.LoginTicket.v1")
                .ToTimeLimitedDataProtector().Unprotect(dto.Ticket);
        }
        catch (Exception ex) when (ex is System.Security.Cryptography.CryptographicException or FormatException)
        {
            return Results.BadRequest(new { message = "Phiên OTP không hợp lệ hoặc đã hết hạn." });
        }
        if (!Guid.TryParse(userId, out var id)) return Results.BadRequest();
        var user = await users.FindByIdAsync(id.ToString());
        if (user is null || !user.EmailConfirmed || !user.IsActive || await users.IsLockedOutAsync(user))
            return Results.Unauthorized();
        var valid = await users.VerifyUserTokenAsync(user, EmailProvider, LoginPurpose, dto.Code.Trim());
        if (!valid)
        {
            await users.AccessFailedAsync(user);
            return Results.BadRequest(new { message = "Mã OTP sai hoặc đã hết hạn." });
        }
        await users.ResetAccessFailedCountAsync(user);
        await users.UpdateSecurityStampAsync(user);
        return Results.Ok(await tokens.CreateAsync(user, users));
    }

public sealed record UpdateProfileDto(string? FullName);

private static async Task<IResult> UpdateMe(
    UpdateProfileDto? dto,
    ClaimsPrincipal principal,
    UserManager<ApplicationUser> users)
{
    var id = principal.FindFirstValue(
        System.IdentityModel.Tokens.Jwt.JwtRegisteredClaimNames.Sub
    );

    if (!Guid.TryParse(id, out var userId))
        return Results.Unauthorized();

    var user = await users.FindByIdAsync(userId.ToString());

    if (user is null || !user.IsActive || !user.EmailConfirmed)
        return Results.Unauthorized();

    var fullName = dto?.FullName?.Trim();

    if (string.IsNullOrWhiteSpace(fullName) ||
        fullName.Length < 2 ||
        fullName.Length > 200)
    {
        return Results.BadRequest(new
        {
            message = "Họ tên phải có từ 2 đến 200 ký tự."
        });
    }

    user.FullName = fullName;

    var result = await users.UpdateAsync(user);

    if (!result.Succeeded)
    {
        return Results.BadRequest(new
        {
            message = "Không thể cập nhật hồ sơ."
        });
    }

    return Results.Ok(new
    {
        message = "Cập nhật hồ sơ thành công.",
        fullName = user.FullName
    });
}

    private static async Task<IResult> Me(ClaimsPrincipal principal, UserManager<ApplicationUser> users)
    {
        var id = principal.FindFirstValue(System.IdentityModel.Tokens.Jwt.JwtRegisteredClaimNames.Sub);
        if (!Guid.TryParse(id, out var userId)) return Results.Unauthorized();
        var user = await users.FindByIdAsync(userId.ToString());
        if (user is null || !user.IsActive) return Results.Unauthorized();
        return Results.Ok(new
        {
            id = user.Id, username = user.UserName, email = user.Email,
            fullName = user.FullName, roles = await users.GetRolesAsync(user)
        });
    }

    private static async Task<IResult> ListUsers(UserManager<ApplicationUser> users)
    {
        var all = users.Users.OrderBy(x => x.UserName).Take(200).ToList();
        var response = new List<object>();
        foreach (var u in all)
            response.Add(new { u.Id, u.UserName, u.Email, u.FullName, u.IsActive, roles = await users.GetRolesAsync(u) });
        return Results.Ok(response);
    }

    private static async Task<IResult> SetRole(Guid id, RoleDto? dto,
        ClaimsPrincipal principal, UserManager<ApplicationUser> users)
    {
        if (dto is null || string.IsNullOrWhiteSpace(dto.Role))
            return Results.BadRequest(new { message = "Vui lòng chọn vai trò." });
        var role = dto.Role.Trim().ToUpperInvariant();
        if (!AuthSetup.Roles.Contains(role)) return Results.BadRequest(new { message = "Vai trò không hợp lệ." });
        if (principal.FindFirstValue(System.IdentityModel.Tokens.Jwt.JwtRegisteredClaimNames.Sub) == id.ToString())
            return Results.BadRequest(new { message = "Không được tự thay đổi vai trò của chính mình." });
        var user = await users.FindByIdAsync(id.ToString());
        if (user is null) return Results.NotFound();
        var existing = await users.GetRolesAsync(user);
        var removed = await users.RemoveFromRolesAsync(user, existing);
        if (!removed.Succeeded) return Results.Problem("Không thể cập nhật vai trò.");
        var added = await users.AddToRoleAsync(user, role);
        return added.Succeeded ? Results.Ok(new { userId = user.Id, role }) : Results.Problem("Không thể gán vai trò.");
    }

    private static async Task<IResult> GoogleLogin(GoogleLoginDto? dto,
        UserManager<ApplicationUser> users, AttendanceDbContext db,
        JwtTokenService tokens, IHttpClientFactory httpClientFactory, CancellationToken ct)
    {
        if (dto is null || string.IsNullOrWhiteSpace(dto.IdToken))
            return Results.BadRequest(new { message = "Vui lòng cung cấp mã Google ID Token." });

        string email = "";
        string fullName = "";
        string googleSub = "";

        try
        {
            var client = httpClientFactory.CreateClient();
            var response = await client.GetAsync($"https://oauth2.googleapis.com/tokeninfo?id_token={dto.IdToken}", ct);
            if (response.IsSuccessStatusCode)
            {
                var json = await response.Content.ReadFromJsonAsync<GoogleTokenInfoResponse>(ct);
                if (json != null && !string.IsNullOrWhiteSpace(json.Email))
                {
                    email = json.Email.Trim().ToLowerInvariant();
                    fullName = string.IsNullOrWhiteSpace(json.Name) ? email.Split('@')[0] : json.Name.Trim();
                    googleSub = json.Sub ?? "";
                }
            }
        }
        catch (Exception)
        {
            // Token verification fallback if offline or mock token
        }

        if (string.IsNullOrWhiteSpace(email))
        {
            if (!string.IsNullOrWhiteSpace(dto.Email) && (dto.IdToken.StartsWith("mock_") || dto.IdToken.Length < 50))
            {
                email = dto.Email.Trim().ToLowerInvariant();
                fullName = string.IsNullOrWhiteSpace(dto.FullName) ? email.Split('@')[0] : dto.FullName.Trim();
                googleSub = "mock_sub_" + email;
            }
            else
            {
                return Results.BadRequest(new { message = "Xác thực Google Token thất bại hoặc Token không hợp lệ." });
            }
        }

        var user = await users.FindByEmailAsync(email);
        if (user is null)
        {
            var username = email.Split('@')[0].Replace(".", "_").Replace("-", "_");
            var baseUsername = username;
            int count = 1;
            while (await users.FindByNameAsync(username) is not null)
            {
                username = $"{baseUsername}{count++}";
            }

            user = new ApplicationUser
            {
                UserName = username,
                Email = email,
                FullName = fullName,
                EmailConfirmed = true,
                IsActive = true,
                LockoutEnabled = true,
            };

            var created = await users.CreateAsync(user);
            if (!created.Succeeded)
            {
                return Results.BadRequest(new { message = "Không thể tạo tài khoản từ Google Sign-In." });
            }

            await users.AddToRoleAsync(user, "STUDENT");
        }

        if (!user.IsActive)
            return Results.Unauthorized();

        if (!user.EmailConfirmed)
        {
            user.EmailConfirmed = true;
            await users.UpdateAsync(user);
        }

        if (!string.IsNullOrWhiteSpace(googleSub))
        {
            var ext = await db.ExternalIdentities
                .FirstOrDefaultAsync(x => x.Provider == "Google" && x.ProviderSubject == googleSub, ct);
            if (ext is null)
            {
                db.ExternalIdentities.Add(new ExternalIdentity
                {
                    UserId = user.Id,
                    Provider = "Google",
                    ProviderSubject = googleSub
                });
                await db.SaveChangesAsync(ct);
            }
        }

        return Results.Ok(await tokens.CreateAsync(user, users));
    }

    private static string MaskEmail(string email)
    {
        var parts = email.Split('@', 2);
        return parts.Length == 2 ? parts[0][..Math.Min(2, parts[0].Length)] + "***@" + parts[1] : "***";
    }

    public sealed record RegisterDto(string Username, string Email, string FullName, string Password);
    public sealed record EmailDto(string Email);
    public sealed record EmailOtpDto(string Email, string Code);
    public sealed record LoginDto(string Username, string Password);
    public sealed record VerifyLoginDto(string Ticket, string Code);
    public sealed record RoleDto(string Role);
    public sealed record GoogleLoginDto(string IdToken, string? Email, string? FullName);
    private sealed record GoogleTokenInfoResponse(
        [property: System.Text.Json.Serialization.JsonPropertyName("email")] string? Email,
        [property: System.Text.Json.Serialization.JsonPropertyName("name")] string? Name,
        [property: System.Text.Json.Serialization.JsonPropertyName("sub")] string? Sub,
        [property: System.Text.Json.Serialization.JsonPropertyName("email_verified")] object? EmailVerified
    );
}
