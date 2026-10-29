using System.Globalization;
using System.Security.Claims;
using System.Security.Cryptography;
using System.Text;
using Attendance.Api.Data;
using Attendance.Api.Domain;
using Microsoft.EntityFrameworkCore;

namespace Attendance.Api.Advanced;

/// <summary>
/// Part 5.1: short-lived signed QR and server-authorized GPS check-in.
/// Does not trust student identity, classroom coordinates, or session IDs from a QR alone.
/// </summary>
public static class AdvancedAttendanceEndpoints
{
    private static Guid? Caller(ClaimsPrincipal user) =>
        Guid.TryParse(user.FindFirst("sub")?.Value, out var id) ? id : null;

    private static IResult Bad(string message) => Results.BadRequest(new { message });
    private static IResult Missing() => Results.NotFound(new { message = "Không tìm thấy phiên điểm danh." });

    public static IEndpointRouteBuilder MapAdvancedAttendanceEndpoints(this IEndpointRouteBuilder app)
    {
        var group = app.MapGroup("/api/v1/advanced-attendance").RequireAuthorization();

        // Only assigned lecturer or admin may display the QR for a live session.
        group.MapGet("/sessions/{sessionId:guid}/qr", async (
            Guid sessionId, AttendanceDbContext db, ClaimsPrincipal user,
            IConfiguration config, CancellationToken ct) =>
        {
            var uid = Caller(user);
            if (!uid.HasValue) return Results.Unauthorized();
            if (!await db.Users.AnyAsync(x => x.Id == uid.Value && x.IsActive && x.EmailConfirmed, ct))
                return Results.Forbid();
            var session = await db.AttendanceSessions.AsNoTracking()
                .FirstOrDefaultAsync(x => x.Id == sessionId, ct);
            if (session is null) return Missing();

            var admin = user.IsInRole("ADMIN");
            var lecturer = user.IsInRole("LECTURER") &&
                await db.TeachingAssignments.AnyAsync(x =>
                    x.ClassSectionId == session.ClassSectionId && x.LecturerId == uid.Value, ct);
            if (!admin && !lecturer) return Results.Forbid();

            var now = DateTime.UtcNow;
            if (session.Status != "OPEN" || now < session.StartsAtUtc || now > session.EndsAtUtc)
                return Bad("Phiên chưa mở, đã đóng hoặc nằm ngoài giờ điểm danh.");

            var section = await db.ClassSections.AsNoTracking()
                .FirstOrDefaultAsync(x => x.Id == session.ClassSectionId, ct);
            if (section?.ClassroomId is null) return Bad("Lớp chưa được gán phòng học có GPS.");
            var room = await db.Classrooms.AsNoTracking()
                .FirstOrDefaultAsync(x => x.Id == section.ClassroomId.Value, ct);
            if (room is null) return Bad("Không tìm thấy phòng học.");

            var signingKey = config["Qr:SigningKey"];
            if (string.IsNullOrWhiteSpace(signingKey) || Encoding.UTF8.GetByteCount(signingKey) < 32)
                return Results.Json(new { message = "Chưa cấu hình Qr__SigningKey (ít nhất 32 byte)." },
                    statusCode: StatusCodes.Status503ServiceUnavailable);

            var expiry = DateTimeOffset.UtcNow.AddSeconds(60);
            var token = MakeToken(sessionId, expiry.ToUnixTimeSeconds(), signingKey);
            return Results.Ok(new
            {
                qrToken = token,
                expiresAtUtc = expiry.UtcDateTime,
                sessionId,
                roomName = room.Name,
                radiusMeters = room.RadiusMeters
            });
        });

        // Student submits QR token + current device GPS. All authorization happens on server.
        group.MapPost("/check-in", async (
            CheckInRequest body, AttendanceDbContext db, ClaimsPrincipal user,
            IConfiguration config, CancellationToken ct) =>
        {
            if (!user.IsInRole("STUDENT")) return Results.Forbid();
            var studentId = Caller(user);
            if (!studentId.HasValue) return Results.Unauthorized();
            if (!await db.Users.AnyAsync(x => x.Id == studentId.Value && x.IsActive && x.EmailConfirmed, ct))
                return Results.Forbid();

            if (string.IsNullOrWhiteSpace(body.QrToken) || body.QrToken.Length > 512 ||
                !double.IsFinite(body.Latitude) || body.Latitude is < -90 or > 90 ||
                !double.IsFinite(body.Longitude) || body.Longitude is < -180 or > 180 ||
                !double.IsFinite(body.AccuracyMeters) || body.AccuracyMeters is < 0 or > 100)
                return Bad("Mã QR hoặc vị trí không hợp lệ; yêu cầu GPS chính xác trong 100 mét.");

            var signingKey = config["Qr:SigningKey"];
            if (string.IsNullOrWhiteSpace(signingKey) || Encoding.UTF8.GetByteCount(signingKey) < 32)
                return Results.Json(new { message = "Máy chủ chưa cấu hình xác thực QR." },
                    statusCode: StatusCodes.Status503ServiceUnavailable);
            if (!TryVerifyToken(body.QrToken, signingKey, out var sessionId))
                return Bad("Mã QR không hợp lệ hoặc đã hết hạn. Hãy quét mã mới.");

            var session = await db.AttendanceSessions.AsNoTracking()
                .FirstOrDefaultAsync(x => x.Id == sessionId, ct);
            if (session is null) return Missing();
            var now = DateTime.UtcNow;
            if (session.Status != "OPEN" || now < session.StartsAtUtc || now > session.EndsAtUtc)
                return Bad("Phiên điểm danh chưa mở, đã đóng hoặc ngoài giờ.");
            if (!await db.Enrollments.AnyAsync(x =>
                x.ClassSectionId == session.ClassSectionId && x.StudentId == studentId.Value, ct))
                return Results.Forbid();

            var section = await db.ClassSections.AsNoTracking()
                .FirstOrDefaultAsync(x => x.Id == session.ClassSectionId, ct);
            if (section?.ClassroomId is null) return Bad("Lớp chưa gán phòng học GPS.");
            var room = await db.Classrooms.AsNoTracking()
                .FirstOrDefaultAsync(x => x.Id == section.ClassroomId.Value, ct);
            if (room is null || !double.IsFinite(room.Latitude) || !double.IsFinite(room.Longitude)
                || !double.IsFinite(room.RadiusMeters) || room.RadiusMeters <= 0)
                return Bad("Phòng học chưa cấu hình GPS hợp lệ.");

            var distance = DistanceMeters(body.Latitude, body.Longitude, room.Latitude, room.Longitude);
            if (distance > room.RadiusMeters)
                return Bad($"Bạn đang cách phòng khoảng {Math.Round(distance)} m, vượt bán kính {room.RadiusMeters:0} m.");

            if (await db.AttendanceRecords.AnyAsync(x =>
                x.AttendanceSessionId == sessionId && x.StudentId == studentId.Value, ct))
                return Results.Conflict(new { message = "Sinh viên đã có kết quả điểm danh cho phiên này." });

            db.AttendanceRecords.Add(new AttendanceRecord
            {
                AttendanceSessionId = sessionId,
                StudentId = studentId.Value,
                Status = "PRESENT",
                Method = "QR_GPS",
                CheckedAtUtc = now
            });
            // Deliberately avoid storing raw latitude / longitude in persistent evidence.
            db.AttendanceAttempts.Add(new AttendanceAttempt
            {
                AttendanceSessionId = sessionId,
                StudentId = studentId.Value,
                Result = "ACCEPTED",
                EvidenceJson = System.Text.Json.JsonSerializer.Serialize(new
                {
                    method = "QR_GPS", distanceMeters = Math.Round(distance, 1),
                    accuracyMeters = Math.Round(body.AccuracyMeters, 1)
                })
            });
            try { await db.SaveChangesAsync(ct); }
            catch (DbUpdateException)
            {
                // May be a concurrent duplicate insert; do not reveal database details.
                return Results.Conflict(new { message = "Không thể ghi kết quả; hãy tải lại để kiểm tra điểm danh trùng." });
            }
            return Results.Ok(new
            {
                message = "Điểm danh QR + GPS thành công.",
                status = "PRESENT", method = "QR_GPS", distanceMeters = Math.Round(distance, 1)
            });
        });
        return app;
    }

    // Signed payload: AT5.<sessionGuid:N>.<expiresUnixSeconds>.<HMAC-SHA256-base64url>
    private static string MakeToken(Guid sessionId, long expires, string secret)
    {
        var data = $"AT5.{sessionId:N}.{expires.ToString(CultureInfo.InvariantCulture)}";
        var mac = HMACSHA256.HashData(Encoding.UTF8.GetBytes(secret), Encoding.UTF8.GetBytes(data));
        return $"{data}.{Convert.ToBase64String(mac).TrimEnd('=').Replace('+', '-').Replace('/', '_')}";
    }

    private static bool TryVerifyToken(string token, string secret, out Guid sessionId)
    {
        sessionId = Guid.Empty;
        var parts = token.Split('.');
        if (parts.Length != 4 || parts[0] != "AT5" ||
            !Guid.TryParseExact(parts[1], "N", out var candidate) ||
            !long.TryParse(parts[2], NumberStyles.None, CultureInfo.InvariantCulture, out var expiry))
            return false;

        var now = DateTimeOffset.UtcNow.ToUnixTimeSeconds();
        if (expiry <= now || expiry > now + 90) return false;
        var expected = MakeToken(candidate, expiry, secret);
        var expectedMac = Encoding.UTF8.GetBytes(expected.Split('.')[3]);
        var givenMac = Encoding.UTF8.GetBytes(parts[3]);
        if (expectedMac.Length != givenMac.Length ||
            !CryptographicOperations.FixedTimeEquals(expectedMac, givenMac)) return false;
        sessionId = candidate;
        return true;
    }

    private static double DistanceMeters(double lat1, double lon1, double lat2, double lon2)
    {
        const double r = 6371000;
        static double Rad(double degrees) => degrees * Math.PI / 180;
        var phi1 = Rad(lat1); var phi2 = Rad(lat2);
        var dphi = Rad(lat2 - lat1); var dlambda = Rad(lon2 - lon1);
        var a = Math.Pow(Math.Sin(dphi / 2), 2) +
                Math.Cos(phi1) * Math.Cos(phi2) * Math.Pow(Math.Sin(dlambda / 2), 2);
        return 2 * r * Math.Asin(Math.Min(1, Math.Sqrt(a)));
    }

    public sealed record CheckInRequest(string QrToken, double Latitude, double Longitude, double AccuracyMeters);
}
