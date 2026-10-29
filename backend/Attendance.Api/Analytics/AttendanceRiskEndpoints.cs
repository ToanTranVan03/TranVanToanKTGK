
using System.Security.Claims;
using Attendance.Api.Data;
using Attendance.Api.Domain;
using Microsoft.EntityFrameworkCore;

namespace Attendance.Api.Analytics;

public static class AttendanceRiskEndpoints
{
    public static IEndpointRouteBuilder MapAttendanceRiskEndpoints(
        this IEndpointRouteBuilder app)
    {
        var group = app.MapGroup("/api/v1/analytics")
            .RequireAuthorization();

        group.MapGet("/attendance-risk", GetAttendanceRisk)
            .WithName("GetAttendanceRisk")
            .WithTags("Phan 7 - Canh bao chuyen can");

        return app;
    }

    private static async Task<IResult> GetAttendanceRisk(
        AttendanceDbContext db,
        ClaimsPrincipal user,
        CancellationToken ct)
    {
        var claim = user.FindFirst("sub")?.Value;

        if (!Guid.TryParse(claim, out var callerId))
        {
            return Results.Unauthorized();
        }

        var isAdmin = user.IsInRole("ADMIN");
        var isLecturer = user.IsInRole("LECTURER");
        var isStudent = user.IsInRole("STUDENT");

        if (!isAdmin && !isLecturer && !isStudent)
        {
            return Results.Forbid();
        }

        var active = await db.Users.AnyAsync(
            x => x.Id == callerId &&
                 x.IsActive &&
                 x.EmailConfirmed,
            ct
        );

        if (!active)
        {
            return Results.Forbid();
        }

        IQueryable<ClassSection> classQuery =
            db.ClassSections.AsNoTracking();

        if (!isAdmin)
        {
            if (isLecturer)
            {
                classQuery = classQuery.Where(c =>
                    db.TeachingAssignments.Any(t =>
                        t.ClassSectionId == c.Id &&
                        t.LecturerId == callerId
                    )
                );
            }
            else
            {
                classQuery = classQuery.Where(c =>
                    db.Enrollments.Any(e =>
                        e.ClassSectionId == c.Id &&
                        e.StudentId == callerId
                    )
                );
            }
        }

        var classes = await (
            from c in classQuery
            join course in db.Courses.AsNoTracking()
                on c.CourseId equals course.Id
            select new
            {
                c.Id,
                c.ClassCode,
                CourseName = course.Name
            }
        ).ToListAsync(ct);

        var classIds = classes.Select(c => c.Id).ToArray();

        if (classIds.Length == 0)
        {
            return Results.Ok(Array.Empty<object>());
        }

        var enrollments = await (
            from e in db.Enrollments.AsNoTracking()
            join student in db.Users.AsNoTracking()
                on e.StudentId equals student.Id
            where classIds.Contains(e.ClassSectionId)
                && (!isStudent || isAdmin || isLecturer ||
                    e.StudentId == callerId)
            select new
            {
                e.ClassSectionId,
                e.StudentId,
                student.FullName,
                student.StudentCode
            }
        ).ToListAsync(ct);

        // Chi tinh nhung buoi da ket thuc.
        // Phien DRAFT khong duoc dua vao thong ke.
        var now = DateTime.UtcNow;

        var sessions = await db.AttendanceSessions
            .AsNoTracking()
            .Where(s =>
                classIds.Contains(s.ClassSectionId) &&
                s.EndsAtUtc <= now &&
                s.Status != "DRAFT"
            )
            .Select(s => new
            {
                s.Id,
                s.ClassSectionId
            })
            .ToListAsync(ct);

        var sessionIds = sessions.Select(s => s.Id).ToArray();

        var records = await db.AttendanceRecords
            .AsNoTracking()
            .Where(r =>
                sessionIds.Contains(r.AttendanceSessionId) &&
                (!isStudent || isAdmin || isLecturer ||
                    r.StudentId == callerId)
            )
            .Select(r => new
            {
                r.StudentId,
                r.AttendanceSessionId,
                r.Status
            })
            .ToListAsync(ct);

        var reports = enrollments.Select(e =>
        {
            var classroom = classes.First(c =>
                c.Id == e.ClassSectionId);

            var classSessionIds = sessions
                .Where(s => s.ClassSectionId == e.ClassSectionId)
                .Select(s => s.Id)
                .ToHashSet();

            var ownRecords = records
                .Where(r =>
                    r.StudentId == e.StudentId &&
                    classSessionIds.Contains(r.AttendanceSessionId))
                .ToList();

            var present = ownRecords.Count(r =>
                r.Status == "PRESENT");

            var late = ownRecords.Count(r =>
                r.Status == "LATE");

            var absent = ownRecords.Count(r =>
                r.Status == "ABSENT");

            var excused = ownRecords.Count(r =>
                r.Status == "EXCUSED");

            // Buoi duoc duyet nghi phep khong tru chuyen can.
            // Buoi chua cham khong tu dong tinh la vang.
            var assessed = present + late + absent;

            var attended = present + late;

            var rate = assessed == 0
                ? 0.0
                : Math.Round(
                    attended * 100.0 / assessed,
                    1
                );

            string level;
            string message;

            if (assessed < 3)
            {
                level = "INSUFFICIENT";
                message = "Chua du 3 luot diem danh de "
                    + "dua ra canh bao dang tin cay.";
            }
            else if (rate < 70)
            {
                level = "HIGH";
                message = "Nguy co chuyen can cao. "
                    + "Can chu dong lien he giang vien.";
            }
            else if (rate < 85)
            {
                level = "MEDIUM";
                message = "Can chu y chuyen can va "
                    + "han che vang hoc.";
            }
            else
            {
                level = "LOW";
                message = "Chuyen can hien dang on dinh.";
            }

            return new
            {
                classId = e.ClassSectionId,
                classroom.ClassCode,
                classroom.CourseName,
                studentId = e.StudentId,
                studentName = e.FullName,
                studentCode = e.StudentCode,
                completedSessions = classSessionIds.Count,
                recordedSessions = ownRecords.Count,
                unrecordedSessions = Math.Max(
                    0,
                    classSessionIds.Count - ownRecords.Count
                ),
                assessedSessions = assessed,
                present,
                late,
                absent,
                excused,
                attendanceRate = rate,
                riskLevel = level,
                message
            };
        })
        .OrderBy(r => r.riskLevel switch
        {
            "HIGH" => 0,
            "MEDIUM" => 1,
            "LOW" => 2,
            _ => 3
        })
        .ThenBy(r => r.ClassCode)
        .ThenBy(r => r.studentName)
        .ToList();

        return Results.Ok(reports);
    }
}
