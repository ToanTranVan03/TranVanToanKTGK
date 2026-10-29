using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Text;
using Attendance.Api.Domain;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Identity;
using Microsoft.Extensions.Options;
using Microsoft.IdentityModel.Tokens;

namespace Attendance.Api.Auth;

public static class AuthSetup
{
    public static readonly string[] Roles = ["ADMIN", "LECTURER", "STUDENT"];

    public static IServiceCollection AddAttendanceAuthentication(this IServiceCollection services, IConfiguration configuration)
    {
        var key = configuration["Jwt:Key"];
        if (string.IsNullOrEmpty(key) || Encoding.UTF8.GetByteCount(key) < 32)
            throw new InvalidOperationException("Jwt__Key must contain at least 32 UTF-8 bytes. Set a random secret in Render Environment.");
        var issuer = configuration["Jwt:Issuer"];
        var audience = configuration["Jwt:Audience"];
        if (string.IsNullOrWhiteSpace(issuer) || string.IsNullOrWhiteSpace(audience))
            throw new InvalidOperationException("Jwt__Issuer and Jwt__Audience are required.");

        services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
            .AddJwtBearer(options =>
            {
                options.MapInboundClaims = false;
                options.TokenValidationParameters = new TokenValidationParameters
                {
                    ValidateIssuerSigningKey = true,
                    IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(key)),
                    ValidateIssuer = true,
                    ValidIssuer = issuer,
                    ValidateAudience = true,
                    ValidAudience = audience,
                    ValidateLifetime = true,
                    ClockSkew = TimeSpan.FromSeconds(30),
                    NameClaimType = JwtRegisteredClaimNames.Sub,
                    RoleClaimType = "role",
                };
            });
        services.AddAuthorization();
        services.AddDataProtection();
        services.AddHttpClient<ResendEmailService>();
        services.AddScoped<JwtTokenService>();
        return services;
    }

    public static async Task SeedAuthRolesAsync(IServiceProvider serviceProvider, IConfiguration configuration)
    {
        var roles = serviceProvider.GetRequiredService<RoleManager<IdentityRole<Guid>>>();
        foreach (var name in Roles)
        {
            if (!await roles.RoleExistsAsync(name))
            {
                var result = await roles.CreateAsync(new IdentityRole<Guid>(name));
                if (!result.Succeeded) throw new InvalidOperationException("Cannot create identity roles.");
            }
        }

        var email = configuration["BootstrapAdmin:Email"];
        var password = configuration["BootstrapAdmin:Password"];
        var username = configuration["BootstrapAdmin:Username"];
        if (string.IsNullOrWhiteSpace(email) || string.IsNullOrWhiteSpace(password)) return;
        if (string.IsNullOrWhiteSpace(username)) username = "admin";

        var users = serviceProvider.GetRequiredService<UserManager<ApplicationUser>>();
        var admin = await users.FindByEmailAsync(email);
        if (admin is null)
        {
            admin = new ApplicationUser
            {
                UserName = username,
                Email = email,
                EmailConfirmed = true,
                FullName = "Quản trị hệ thống",
                IsActive = true,
                LockoutEnabled = true,
            };
            var created = await users.CreateAsync(admin, password);
            if (!created.Succeeded) throw new InvalidOperationException("Cannot bootstrap admin. Check username, email and password policy.");
        }
        if (!await users.IsInRoleAsync(admin, "ADMIN"))
        {
            var assigned = await users.AddToRoleAsync(admin, "ADMIN");
            if (!assigned.Succeeded) throw new InvalidOperationException("Cannot assign admin role.");
        }
    }
}

public sealed class JwtTokenService(IConfiguration configuration)
{
    public async Task<object> CreateAsync(ApplicationUser user, UserManager<ApplicationUser> users)
    {
        var roleNames = await users.GetRolesAsync(user);
        var expires = DateTime.UtcNow.AddHours(2);
        var claims = new List<Claim>
        {
            new(JwtRegisteredClaimNames.Sub, user.Id.ToString()),
            new(JwtRegisteredClaimNames.Jti, Guid.NewGuid().ToString()),
            new(JwtRegisteredClaimNames.Email, user.Email ?? ""),
        };
        claims.AddRange(roleNames.Select(role => new Claim("role", role)));
        var signingKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(configuration["Jwt:Key"]!));
        var jwt = new JwtSecurityToken(
            issuer: configuration["Jwt:Issuer"], audience: configuration["Jwt:Audience"],
            claims: claims, expires: expires,
            signingCredentials: new SigningCredentials(signingKey, SecurityAlgorithms.HmacSha256));
        return new
        {
            accessToken = new JwtSecurityTokenHandler().WriteToken(jwt),
            expiresAtUtc = expires,
            user = new
            {
                id = user.Id,
                username = user.UserName,
                email = user.Email,
                fullName = user.FullName,
                role = roleNames.Contains("ADMIN") ? "ADMIN"
                    : roleNames.Contains("LECTURER") ? "LECTURER"
                    : "STUDENT",
            }
        };
    }
}
