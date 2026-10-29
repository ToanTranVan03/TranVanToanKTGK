
using System.Security.Claims;
using System.Security.Cryptography;
using System.Text;
using Attendance.Api.Domain;
using Microsoft.AspNetCore.Identity;

namespace Attendance.Api.Auth;

public static class FaceLoginEndpoints
{
    private const string Provider = "AttendanceFaceLogin";
    private const string TokenName = "DeviceCredential";

    public sealed record FaceSignInDto(
        string? Username,
        string? Secret
    );

    public static IEndpointRouteBuilder MapFaceLoginEndpoints(
        this IEndpointRouteBuilder app)
    {
        var group = app.MapGroup("/api/v1/auth/face")
            .RequireRateLimiting("auth");

        group.MapPost("/enroll", Enroll)
            .RequireAuthorization();

        group.MapPost("/sign-in", SignIn);

        group.MapPost("/revoke", Revoke)
            .RequireAuthorization();

        return app;
    }

    // Chỉ tài khoản đã đăng nhập bằng OTP mới được
    // đăng ký thiết bị dùng Face Unlock.
    private static async Task<IResult> Enroll(
        ClaimsPrincipal principal,
        UserManager<ApplicationUser> users)
    {
        var userId = principal.FindFirstValue("sub");

        if (!Guid.TryParse(userId, out var id))
        {
            return Results.Unauthorized();
        }

        var user = await users.FindByIdAsync(id.ToString());

        if (user is null ||
            !user.IsActive ||
            !user.EmailConfirmed)
        {
            return Results.Unauthorized();
        }

        // Khóa ngẫu nhiên dùng cho một thiết bị.
        var secret = Convert.ToBase64String(
            RandomNumberGenerator.GetBytes(48)
        );

        var hash = Convert.ToHexString(
            SHA256.HashData(
                Encoding.UTF8.GetBytes(secret)
            )
        );

        // Thiết bị phải kích hoạt lại sau 7 ngày.
        var expires = DateTimeOffset.UtcNow
            .AddDays(7)
            .ToUnixTimeSeconds();

        // Chỉ lưu hash vào AspNetUserTokens.
        var saved = await users.SetAuthenticationTokenAsync(
            user,
            Provider,
            TokenName,
            $"{expires}|{hash}"
        );

        if (!saved.Succeeded)
        {
            return Results.Problem(
                "Không lưu được thông tin đăng nhập khuôn mặt."
            );
        }

        return Results.Ok(new
        {
            username = user.UserName,
            secret,
            expiresAtUtc = DateTimeOffset
                .FromUnixTimeSeconds(expires)
                .UtcDateTime
        });
    }

    private static async Task<IResult> SignIn(
        FaceSignInDto? dto,
        UserManager<ApplicationUser> users,
        JwtTokenService jwt)
    {
        if (dto is null ||
            string.IsNullOrWhiteSpace(dto.Username) ||
            string.IsNullOrWhiteSpace(dto.Secret) ||
            dto.Secret.Length > 200)
        {
            return Results.Unauthorized();
        }

        var user = await users.FindByNameAsync(
            dto.Username.Trim()
        );

        if (user is null ||
            !user.IsActive ||
            !user.EmailConfirmed ||
            await users.IsLockedOutAsync(user))
        {
            return Results.Unauthorized();
        }

        var stored = await users.GetAuthenticationTokenAsync(
            user,
            Provider,
            TokenName
        );

        if (string.IsNullOrWhiteSpace(stored))
        {
            return Results.Unauthorized();
        }

        var pieces = stored.Split('|', 2);

        if (pieces.Length != 2 ||
            !long.TryParse(pieces[0], out var expires) ||
            expires <= DateTimeOffset.UtcNow.ToUnixTimeSeconds())
        {
            return Results.Unauthorized();
        }

        var actualHash = Convert.ToHexString(
            SHA256.HashData(
                Encoding.UTF8.GetBytes(dto.Secret)
            )
        );

        // So sánh hash trong thời gian cố định.
        var expectedBytes = Encoding.ASCII.GetBytes(pieces[1]);
        var actualBytes = Encoding.ASCII.GetBytes(actualHash);

        if (!CryptographicOperations.FixedTimeEquals(
                expectedBytes,
                actualBytes))
        {
            return Results.Unauthorized();
        }

        var result = await jwt.CreateAsync(user, users);

        return Results.Ok(result);
    }

    private static async Task<IResult> Revoke(
        ClaimsPrincipal principal,
        UserManager<ApplicationUser> users)
    {
        var userId = principal.FindFirstValue("sub");

        if (!Guid.TryParse(userId, out var id))
        {
            return Results.Unauthorized();
        }

        var user = await users.FindByIdAsync(id.ToString());

        if (user is null)
        {
            return Results.Unauthorized();
        }

        var result = await users.RemoveAuthenticationTokenAsync(
            user,
            Provider,
            TokenName
        );

        return result.Succeeded
            ? Results.Ok(new
            {
                message = "Đã tắt đăng nhập khuôn mặt."
            })
            : Results.Problem("Không thể thu hồi thiết bị.");
    }
}
