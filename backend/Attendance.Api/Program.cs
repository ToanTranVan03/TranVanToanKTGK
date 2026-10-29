using Attendance.Api.Auth;
using Attendance.Api.Academics;
using Attendance.Api.Advanced;
using Attendance.Api.Data;
using Microsoft.AspNetCore.RateLimiting;
using System.Threading.RateLimiting;
using Attendance.Api.Domain;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;

var builder = WebApplication.CreateBuilder(args);

// Render supplies PORT; Docker Compose uses ASPNETCORE_URLS=...:8080.
if (int.TryParse(Environment.GetEnvironmentVariable("PORT"), out var port))
{
    builder.WebHost.UseUrls($"http://0.0.0.0:{port}");
}

var connectionString = builder.Configuration.GetConnectionString("Default");
if (string.IsNullOrWhiteSpace(connectionString))
{
    throw new InvalidOperationException(
        "Missing ConnectionStrings__Default. See .env.example / README-PHAN-2.md.");
}

builder.Services.AddDbContext<AttendanceDbContext>(options =>
    options.UseNpgsql(connectionString));

// Identity authentication, email OTP and role-based permissions.
builder.Services.AddIdentityCore<ApplicationUser>(options =>
    {
        options.User.RequireUniqueEmail = true;
        options.Password.RequiredLength = 10;
        options.Password.RequireDigit = true;
        options.Password.RequireLowercase = true;
        options.Password.RequireUppercase = true;
        options.Password.RequireNonAlphanumeric = true;
        options.Lockout.DefaultLockoutTimeSpan = TimeSpan.FromMinutes(15);
        options.Lockout.AllowedForNewUsers = true;
        options.Lockout.MaxFailedAccessAttempts = 5;
    })
    .AddRoles<IdentityRole<Guid>>()
    .AddEntityFrameworkStores<AttendanceDbContext>()
    .AddDefaultTokenProviders();

builder.Services.AddAttendanceAuthentication(builder.Configuration);
builder.Services.AddAuthorizationBuilder()
    .AddPolicy("ADMIN", p => p.RequireRole("ADMIN"))
    .AddPolicy("STAFF", p => p.RequireRole("ADMIN", "LECTURER"));
builder.Services.AddRateLimiter(options =>
{
    options.RejectionStatusCode = StatusCodes.Status429TooManyRequests;
    options.AddFixedWindowLimiter("auth", limiter =>
    {
        limiter.PermitLimit = 12;
        limiter.Window = TimeSpan.FromMinutes(1);
        limiter.QueueLimit = 0;
        limiter.AutoReplenishment = true;
    });
});

builder.Services.AddHealthChecks();

var app = builder.Build();

if (app.Configuration.GetValue<bool>("Database:ApplyMigrationsOnStartup"))
{
    using var scope = app.Services.CreateScope();
    var db = scope.ServiceProvider.GetRequiredService<AttendanceDbContext>();
    var migrations = db.Database.GetMigrations().ToArray();
    if (migrations.Length == 0)
    {
        throw new InvalidOperationException(
            "No EF Core migrations found. Run scripts/setup-backend.ps1 before deploy.");
    }
    await db.Database.MigrateAsync();
}

using (var scope = app.Services.CreateScope())
{
    await AuthSetup.SeedAuthRolesAsync(scope.ServiceProvider, app.Configuration);
}

app.UseRouting();
app.UseRateLimiter();
app.UseAuthentication();
app.UseAuthorization();
app.MapAttendanceAuth();
app.MapAcademicEndpoints();
app.MapAdvancedAttendanceEndpoints();
app.MapHealthChecks("/health");

app.MapGet("/api/v1/system/status", async (
    AttendanceDbContext db, CancellationToken cancellationToken) =>
{
    bool databaseConnected;
    try
    {
        databaseConnected = await db.Database.CanConnectAsync(cancellationToken);
    }
    catch (Exception)
    {
        // Never disclose database connection details to anonymous callers.
        databaseConnected = false;
    }

    var response = new
    {
        application = "Student Attendance API",
        apiVersion = "v1",
        serverTimeUtc = DateTime.UtcNow,
        databaseConnected,
    };
    return databaseConnected ? Results.Ok(response) : Results.Json(
        response, statusCode: StatusCodes.Status503ServiceUnavailable);
})
.WithName("SystemStatus");

app.Run();

// Enables WebApplicationFactory integration tests in later stages.
public partial class Program { }
