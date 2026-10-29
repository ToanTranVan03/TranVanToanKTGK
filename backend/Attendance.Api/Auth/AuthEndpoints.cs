using System.Security.Claims;
using Attendance.Api.Domain;
using Microsoft.AspNetCore.DataProtection;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.RateLimiting;

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
        auth.MapGet("/me", Me).RequireAuthorization();

        var admin = app.MapGroup("/api/v1/admin").RequireAuthorization("ADMIN");
        admin.MapGet("/users", ListUsers);
        admin.MapPut("/users/{id:guid}/role", SetRole);
        return app;
    }

    private static async Task<IResult> Register(RegisterDto dto,
        UserManager<ApplicationUser> users, ResendEmailService sender, CancellationToken ct)
    {
        if (!sender.IsConfigured)
            return Results.Problem("Dịch vụ email chưa cấu hình.", statusCode: 503);
        var name = dto.Username.Trim();
        var email = dto.Email.Trim().ToLowerInvariant();
        if (name.Length < 3 || name.Length > 60 || dto.FullName.Trim().Length < 2 ||
            !email.Contains('@') || dto.Password.Length < 10)
            return Results.BadRequest(new { message = "Thông tin đăng ký không hợp lệ; mật khẩu tối thiểu 10 ký tự." });
        var user = new ApplicationUser { UserName = name, Email = email, FullName = dto.FullName.Trim(), LockoutEnabled = true };
        var result = await users.CreateAsync(user, dto.Password);
        if (!result.Succeeded)
            return Results.BadRequest(new { message = string.Join("; ", result.Errors.Select(x => x.Description)) });
        await users.AddToRoleAsync(user, "STUDENT"); // Never accept a role from registration input.
        var code = await users.GenerateUserTokenAsync(user, EmailProvider, ConfirmPurpose);
        var sent = await sender.SendOtpAsync(email, code, "xác nhận email", ct);
        return sent
            ? Results.Ok(new { message = "Đã gửi mã OTP xác nhận email.", email })
            : Results.Json(new { message = "Tạo tài khoản thành công nhưng chưa gửi được email. Kiểm tra cấu hình và dùng Gửi lại OTP." }, statusCode: 503);
    }

    private static async Task<IResult> VerifyEmail(EmailOtpDto dto,
        UserManager<ApplicationUser> users)
    {
        var user = await users.FindByEmailAsync(dto.Email.Trim());
        if (user is null) return Results.BadRequest(new { message = "Mã OTP hoặc email không hợp lệ." });
        if (user.EmailConfirmed) return Results.Ok(new { message = "Email đã xác nhận." });
        var valid = await users.VerifyUserTokenAsync(user, EmailProvider, ConfirmPurpose, dto.Code.Trim());
        if (!valid) return Results.BadRequest(new { message = "Mã OTP không hợp lệ hoặc hết hạn." });
        user.EmailConfirmed = true;
        var updated = await users.UpdateAsync(user);
        return updated.Succeeded ? Results.Ok(new { message = "Đã xác nhận email. Bạn có thể đăng nhập." })
            : Results.Problem("Không thể xác nhận email.");
    }

    private static async Task<IResult> ResendEmail(EmailDto dto,
        UserManager<ApplicationUser> users, ResendEmailService sender, CancellationToken ct)
    {
        var user = await users.FindByEmailAsync(dto.Email.Trim());
        if (user is not null && !user.EmailConfirmed && sender.IsConfigured)
        {
            var code = await users.GenerateUserTokenAsync(user, EmailProvider, ConfirmPurpose);
            await sender.SendOtpAsync(user.Email!, code, "xác nhận email", ct);
        }
        // Do not reveal whether an email exists.
        return Results.Ok(new { message = "Nếu tài khoản tồn tại và chưa xác nhận, email OTP sẽ được gửi." });
    }

    private static async Task<IResult> Login(LoginDto dto,
        UserManager<ApplicationUser> users, IDataProtectionProvider protection,
        ResendEmailService sender, CancellationToken ct)
    {
        if (!sender.IsConfigured)
            return Results.Problem("Dịch vụ email chưa cấu hình.", statusCode: 503);
        var user = await users.FindByNameAsync(dto.Username.Trim());
        if (user is null || !user.IsActive || await users.IsLockedOutAsync(user))
            return Results.Unauthorized();
        if (!await users.CheckPasswordAsync(user, dto.Password))
        {
            await users.AccessFailedAsync(user);
            return Results.Unauthorized();
        }
        if (!user.EmailConfirmed)
            return Results.BadRequest(new { message = "Tài khoản chưa xác nhận email." });
        var code = await users.GenerateUserTokenAsync(user, EmailProvider, LoginPurpose);
        if (!await sender.SendOtpAsync(user.Email!, code, "đăng nhập", ct))
            return Results.Problem("Không gửi được OTP. Kiểm tra nhà cung cấp email.", statusCode: 503);
        var ticket = protection.CreateProtector("Attendance.LoginTicket.v1")
            .ToTimeLimitedDataProtector().Protect(user.Id.ToString(), TimeSpan.FromMinutes(5));
        return Results.Ok(new { otpRequired = true, ticket, emailHint = MaskEmail(user.Email!) });
    }

    private static async Task<IResult> VerifyLoginOtp(VerifyLoginDto dto,
        UserManager<ApplicationUser> users, IDataProtectionProvider protection,
        JwtTokenService tokens)
    {
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
        // Invalidates the OTP code for reuse by rotating the user's security stamp.
        await users.UpdateSecurityStampAsync(user);
        return Results.Ok(await tokens.CreateAsync(user, users));
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

    private static async Task<IResult> SetRole(Guid id, RoleDto dto,
        ClaimsPrincipal principal, UserManager<ApplicationUser> users)
    {
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
}
