using System.Security.Claims;
using Attendance.Api.Data;
using Attendance.Api.Domain;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;

namespace Attendance.Api.Academics;

// Part 4: Real PostgreSQL/EF Core APIs. Every mutation checks the caller's JWT role
// and ownership/teaching assignment; client-side role controls are never trusted.
public static class AcademicEndpoints
{
    private static Guid? Caller(ClaimsPrincipal user) =>
        Guid.TryParse(user.FindFirst("sub")?.Value, out var id) ? id : null;

    private static bool Admin(ClaimsPrincipal user) => user.IsInRole("ADMIN");
    private static bool Staff(ClaimsPrincipal user) => Admin(user) || user.IsInRole("LECTURER");

    private static async Task<bool> CanTeach(AttendanceDbContext db, ClaimsPrincipal user,
        Guid classId, CancellationToken ct)
    {
        if (Admin(user)) return true;
        var id = Caller(user);
        return id.HasValue && user.IsInRole("LECTURER") &&
            await db.TeachingAssignments.AnyAsync(x => x.ClassSectionId == classId && x.LecturerId == id.Value, ct);
    }

    private static async Task<bool> CanViewClass(AttendanceDbContext db, ClaimsPrincipal user,
        Guid classId, CancellationToken ct)
    {
        if (await CanTeach(db, user, classId, ct)) return true;
        var id = Caller(user);
        return id.HasValue && await db.Enrollments.AnyAsync(
            x => x.ClassSectionId == classId && x.StudentId == id.Value, ct);
    }

    private static IResult Bad(string message) => Results.BadRequest(new { message });
    private static IResult Missing() => Results.NotFound(new { message = "Không tìm thấy dữ liệu." });

    public static IEndpointRouteBuilder MapAcademicEndpoints(this IEndpointRouteBuilder app)
    {
        var a = app.MapGroup("/api/v1/academics").RequireAuthorization();
        // A previously issued JWT must not keep a deactivated account active.
        a.AddEndpointFilter(async (context, next) =>
        {
            var id = Caller(context.HttpContext.User);
            if (!id.HasValue) return Results.Unauthorized();
            var db = context.HttpContext.RequestServices.GetRequiredService<AttendanceDbContext>();
            if (!await db.Users.AnyAsync(x => x.Id == id.Value && x.IsActive && x.EmailConfirmed,
                    context.HttpContext.RequestAborted))
                return Results.Forbid();
            return await next(context);
        });

        // Courses, no new migration (tables already created in Part 2).
        a.MapGet("/courses", async (AttendanceDbContext db, CancellationToken ct) =>
            Results.Ok(await db.Courses.AsNoTracking().OrderBy(x => x.Code)
                .Select(x => new { x.Id, x.Code, x.Name, x.Credits }).ToListAsync(ct)));

        a.MapPost("/courses", async (CourseInput body, AttendanceDbContext db, CancellationToken ct) =>
        {
            if (string.IsNullOrWhiteSpace(body.Code) || string.IsNullOrWhiteSpace(body.Name) ||
                body.Code.Trim().Length > 30 || body.Name.Trim().Length > 200 || body.Credits is < 1 or > 20)
                return Bad("Mã môn, tên môn và số tín chỉ (1–20) phải hợp lệ.");
            var code = body.Code.Trim().ToUpperInvariant();
            if (await db.Courses.AnyAsync(x => x.Code == code, ct)) return Results.Conflict(new { message = "Mã môn đã tồn tại." });
            var value = new Course { Code = code, Name = body.Name.Trim(), Credits = body.Credits };
            db.Courses.Add(value); await db.SaveChangesAsync(ct);
            return Results.Ok(new { value.Id });
        }).RequireAuthorization("ADMIN");

        a.MapPut("/courses/{id:guid}", async (Guid id, CourseInput body, AttendanceDbContext db, CancellationToken ct) =>
        {
            var value = await db.Courses.FindAsync([id], ct);
            if (value is null) return Missing();
            if (string.IsNullOrWhiteSpace(body.Code) || string.IsNullOrWhiteSpace(body.Name) ||
                body.Code.Trim().Length > 30 || body.Name.Trim().Length > 200 || body.Credits is < 1 or > 20)
                return Bad("Thông tin môn học không hợp lệ.");
            var code = body.Code.Trim().ToUpperInvariant();
            if (await db.Courses.AnyAsync(x => x.Id != id && x.Code == code, ct)) return Results.Conflict(new { message = "Mã môn đã tồn tại." });
            value.Code = code; value.Name = body.Name.Trim(); value.Credits = body.Credits;
            await db.SaveChangesAsync(ct); return Results.Ok(new { message = "Đã cập nhật môn học." });
        }).RequireAuthorization("ADMIN");

        a.MapDelete("/courses/{id:guid}", async (Guid id, AttendanceDbContext db, CancellationToken ct) =>
        {
            var value = await db.Courses.FindAsync([id], ct);
            if (value is null) return Missing();
            if (await db.ClassSections.AnyAsync(x => x.CourseId == id, ct))
                return Results.Conflict(new { message = "Môn đã có lớp; hãy xử lý các lớp trước." });
            db.Courses.Remove(value); await db.SaveChangesAsync(ct); return Results.NoContent();
        }).RequireAuthorization("ADMIN");

        // Classrooms.
        a.MapGet("/rooms", async (AttendanceDbContext db, CancellationToken ct) =>
            Results.Ok(await db.Classrooms.AsNoTracking().OrderBy(x => x.Name).ToListAsync(ct)));
        a.MapPost("/rooms", async (RoomInput body, AttendanceDbContext db, CancellationToken ct) =>
        {
            if (!ValidRoom(body)) return Bad("Phòng hoặc tọa độ không hợp lệ.");
            var name = body.Name.Trim();
            if (await db.Classrooms.AnyAsync(x => x.Name == name, ct)) return Results.Conflict(new { message = "Phòng đã tồn tại." });
            var room = new Classroom { Name = name, Latitude = body.Latitude, Longitude = body.Longitude,
                RadiusMeters = body.RadiusMeters };
            db.Classrooms.Add(room); await db.SaveChangesAsync(ct); return Results.Ok(new { room.Id });
        }).RequireAuthorization("ADMIN");
        a.MapPut("/rooms/{id:guid}", async (Guid id, RoomInput body, AttendanceDbContext db, CancellationToken ct) =>
        {
            var room = await db.Classrooms.FindAsync([id], ct);
            if (room is null) return Missing();
            if (!ValidRoom(body)) return Bad("Phòng hoặc tọa độ không hợp lệ.");
            var name = body.Name.Trim();
            if (await db.Classrooms.AnyAsync(x => x.Id != id && x.Name == name, ct))
                return Results.Conflict(new { message = "Phòng đã tồn tại." });
            room.Name = name; room.Latitude = body.Latitude; room.Longitude = body.Longitude;
            room.RadiusMeters = body.RadiusMeters; await db.SaveChangesAsync(ct);
            return Results.Ok(new { message = "Đã cập nhật phòng." });
        }).RequireAuthorization("ADMIN");
        a.MapDelete("/rooms/{id:guid}", async (Guid id, AttendanceDbContext db, CancellationToken ct) =>
        {
            var room = await db.Classrooms.FindAsync([id], ct);
            if (room is null) return Missing();
            if (await db.ClassSections.AnyAsync(x => x.ClassroomId == id, ct) ||
                await db.Beacons.AnyAsync(x => x.ClassroomId == id, ct))
                return Results.Conflict(new { message = "Phòng đang được sử dụng." });
            db.Classrooms.Remove(room); await db.SaveChangesAsync(ct); return Results.NoContent();
        }).RequireAuthorization("ADMIN");

        // Class list is scoped on server, not only UI.
        a.MapGet("/classes", async (AttendanceDbContext db, ClaimsPrincipal user, CancellationToken ct) =>
        {
            var query = db.ClassSections.AsNoTracking();
            if (!Admin(user))
            {
                var id = Caller(user);
                if (!id.HasValue) return Results.Unauthorized();
                if (user.IsInRole("LECTURER"))
                    query = query.Where(c => db.TeachingAssignments.Any(x => x.ClassSectionId == c.Id && x.LecturerId == id.Value));
                else
                    query = query.Where(c => db.Enrollments.Any(x => x.ClassSectionId == c.Id && x.StudentId == id.Value));
            }
            var result = await (from c in query
                join course in db.Courses on c.CourseId equals course.Id
                join room in db.Classrooms on c.ClassroomId equals (Guid?)room.Id into rooms
                from room in rooms.DefaultIfEmpty()
                orderby c.Semester descending, c.ClassCode
                select new { c.Id, c.CourseId, CourseName = course.Name, c.ClassCode, c.Semester,
                    c.ClassroomId, RoomName = room == null ? "" : room.Name,
                    StudentCount = db.Enrollments.Count(e => e.ClassSectionId == c.Id) }).ToListAsync(ct);
            return Results.Ok(result);
        });

        a.MapPost("/classes", async (ClassInput body, AttendanceDbContext db, CancellationToken ct) =>
        {
            if (!ValidClass(body)) return Bad("Thông tin lớp không hợp lệ.");
            if (!await db.Courses.AnyAsync(x => x.Id == body.CourseId, ct)) return Bad("Môn học không tồn tại.");
            if (body.ClassroomId.HasValue && !await db.Classrooms.AnyAsync(x => x.Id == body.ClassroomId, ct)) return Bad("Phòng không tồn tại.");
            var code = body.ClassCode.Trim().ToUpperInvariant();
            var semester = body.Semester.Trim();
            if (await db.ClassSections.AnyAsync(x => x.ClassCode == code && x.Semester == semester, ct))
                return Results.Conflict(new { message = "Lớp đã tồn tại trong học kỳ." });
            var value = new ClassSection { ClassCode = code, Semester = semester,
                CourseId = body.CourseId, ClassroomId = body.ClassroomId };
            db.ClassSections.Add(value); await db.SaveChangesAsync(ct); return Results.Ok(new { value.Id });
        }).RequireAuthorization("ADMIN");

        a.MapPut("/classes/{id:guid}", async (Guid id, ClassInput body, AttendanceDbContext db, CancellationToken ct) =>
        {
            var value = await db.ClassSections.FindAsync([id], ct);
            if (value is null) return Missing();
            if (!ValidClass(body)) return Bad("Thông tin lớp không hợp lệ.");
            if (!await db.Courses.AnyAsync(x => x.Id == body.CourseId, ct)) return Bad("Môn học không tồn tại.");
            if (body.ClassroomId.HasValue && !await db.Classrooms.AnyAsync(x => x.Id == body.ClassroomId, ct)) return Bad("Phòng không tồn tại.");
            var code = body.ClassCode.Trim().ToUpperInvariant();
            var semester = body.Semester.Trim();
            if (await db.ClassSections.AnyAsync(x => x.Id != id && x.ClassCode == code && x.Semester == semester, ct))
                return Results.Conflict(new { message = "Lớp đã tồn tại trong học kỳ." });
            value.CourseId = body.CourseId; value.ClassroomId = body.ClassroomId;
            value.ClassCode = code; value.Semester = semester;
            await db.SaveChangesAsync(ct); return Results.Ok(new { message = "Đã cập nhật lớp." });
        }).RequireAuthorization("ADMIN");
        a.MapDelete("/classes/{id:guid}", async (Guid id, AttendanceDbContext db, CancellationToken ct) =>
        {
            var value = await db.ClassSections.FindAsync([id], ct);
            if (value is null) return Missing();
            if (await db.Enrollments.AnyAsync(x => x.ClassSectionId == id, ct) ||
                await db.TeachingAssignments.AnyAsync(x => x.ClassSectionId == id, ct) ||
                await db.AttendanceSessions.AnyAsync(x => x.ClassSectionId == id, ct))
                return Results.Conflict(new { message = "Lớp đã có sinh viên/giảng viên/phiên điểm danh." });
            db.ClassSections.Remove(value); await db.SaveChangesAsync(ct); return Results.NoContent();
        }).RequireAuthorization("ADMIN");

        // Student management: soft-deactivate accounts to preserve historical attendance.
        a.MapGet("/students", async (AttendanceDbContext db, CancellationToken ct) =>
        {
            var students = await (from u in db.Users.AsNoTracking()
                join ur in db.UserRoles on u.Id equals ur.UserId
                join r in db.Roles on ur.RoleId equals r.Id
                where r.Name == "STUDENT"
                orderby u.FullName
                select new { u.Id, u.UserName, u.FullName, u.Email, u.StudentCode,
                    u.IsActive, u.EmailConfirmed }).ToListAsync(ct);
            return Results.Ok(students);
        }).RequireAuthorization("ADMIN");
        // Exact username lookup for an assigned lecturer adding a student to a class.
        a.MapGet("/students/lookup", async (string username, AttendanceDbContext db, ClaimsPrincipal user,
            CancellationToken ct) =>
        {
            if (!Staff(user)) return Results.Forbid();
            if (string.IsNullOrWhiteSpace(username) || username.Trim().Length > 256)
                return Bad("Nhập tên đăng nhập sinh viên.");
            var name = username.Trim();
            var student = await (from u in db.Users.AsNoTracking()
                join ur in db.UserRoles on u.Id equals ur.UserId
                join r in db.Roles on ur.RoleId equals r.Id
                where r.Name == "STUDENT" && u.UserName == name && u.IsActive
                select new { u.Id, u.FullName, u.UserName, u.StudentCode }).FirstOrDefaultAsync(ct);
            return student is null ? Missing() : Results.Ok(student);
        }).RequireAuthorization("STAFF");
        a.MapPut("/students/{id:guid}", async (Guid id, StudentInput body,
            AttendanceDbContext db, UserManager<ApplicationUser> manager, CancellationToken ct) =>
        {
            var student = await manager.FindByIdAsync(id.ToString());
            if (student is null || !await manager.IsInRoleAsync(student, "STUDENT")) return Missing();
            if (string.IsNullOrWhiteSpace(body.FullName) || body.FullName.Trim().Length > 200 ||
                (body.StudentCode?.Trim().Length ?? 0) > 30) return Bad("Tên hoặc mã sinh viên không hợp lệ.");
            var code = string.IsNullOrWhiteSpace(body.StudentCode) ? null : body.StudentCode.Trim();
            if (code is not null && await db.Users.AnyAsync(x => x.Id != id && x.StudentCode == code, ct))
                return Results.Conflict(new { message = "Mã sinh viên đã tồn tại." });
            student.FullName = body.FullName.Trim(); student.StudentCode = code; student.IsActive = body.IsActive;
            var result = await manager.UpdateAsync(student);
            return result.Succeeded ? Results.Ok(new { message = "Đã cập nhật sinh viên." }) :
                Bad(string.Join("; ", result.Errors.Select(x => x.Description)));
        }).RequireAuthorization("ADMIN");
        a.MapDelete("/students/{id:guid}", async (Guid id,
            UserManager<ApplicationUser> manager) =>
        {
            var student = await manager.FindByIdAsync(id.ToString());
            if (student is null || !await manager.IsInRoleAsync(student, "STUDENT")) return Missing();
            student.IsActive = false;
            var result = await manager.UpdateAsync(student);
            return result.Succeeded ? Results.Ok(new { message = "Đã vô hiệu hóa tài khoản sinh viên; giữ lịch sử điểm danh." }) :
                Bad("Không thể vô hiệu hóa sinh viên.");
        }).RequireAuthorization("ADMIN");

        // Class roster and lecturer assignment.
        a.MapGet("/classes/{classId:guid}/students", async (Guid classId, AttendanceDbContext db,
            ClaimsPrincipal user, CancellationToken ct) =>
        {
            if (!await CanTeach(db, user, classId, ct)) return Results.Forbid();
            var data = await (from e in db.Enrollments.AsNoTracking()
                join s in db.Users on e.StudentId equals s.Id
                where e.ClassSectionId == classId
                orderby s.FullName
                select new { s.Id, s.FullName, s.UserName, s.Email, s.StudentCode, e.JoinedAtUtc }).ToListAsync(ct);
            return Results.Ok(data);
        });
        a.MapPost("/classes/{classId:guid}/students", async (Guid classId, EnrollInput body,
            AttendanceDbContext db, ClaimsPrincipal user, UserManager<ApplicationUser> manager, CancellationToken ct) =>
        {
            if (!await CanTeach(db, user, classId, ct)) return Results.Forbid();
            if (!await db.ClassSections.AnyAsync(x => x.Id == classId, ct)) return Missing();
            var student = await manager.FindByIdAsync(body.StudentId.ToString());
            if (student is null || !student.IsActive || !await manager.IsInRoleAsync(student, "STUDENT"))
                return Bad("Tài khoản không phải sinh viên đang hoạt động.");
            if (await db.Enrollments.AnyAsync(x => x.ClassSectionId == classId && x.StudentId == body.StudentId, ct))
                return Results.Conflict(new { message = "Sinh viên đã thuộc lớp." });
            db.Enrollments.Add(new Enrollment { ClassSectionId = classId, StudentId = body.StudentId });
            await db.SaveChangesAsync(ct); return Results.Ok(new { message = "Đã thêm sinh viên vào lớp." });
        });
        a.MapDelete("/classes/{classId:guid}/students/{studentId:guid}", async (Guid classId,
            Guid studentId, AttendanceDbContext db, ClaimsPrincipal user, CancellationToken ct) =>
        {
            if (!await CanTeach(db, user, classId, ct)) return Results.Forbid();
            var enrollment = await db.Enrollments.FindAsync([classId, studentId], ct);
            if (enrollment is null) return Missing();
            if (await db.AttendanceSessions.AnyAsync(s => s.ClassSectionId == classId &&
                (db.AttendanceRecords.Any(r => r.AttendanceSessionId == s.Id && r.StudentId == studentId) ||
                 db.LeaveRequests.Any(l => l.AttendanceSessionId == s.Id && l.StudentId == studentId)), ct))
                return Results.Conflict(new { message = "Sinh viên đã có lịch sử điểm danh/đơn nghỉ." });
            db.Enrollments.Remove(enrollment); await db.SaveChangesAsync(ct); return Results.NoContent();
        });

        a.MapGet("/lecturers", async (AttendanceDbContext db, CancellationToken ct) =>
        {
            var result = await (from u in db.Users.AsNoTracking()
                join ur in db.UserRoles on u.Id equals ur.UserId
                join r in db.Roles on ur.RoleId equals r.Id
                where r.Name == "LECTURER" && u.IsActive
                orderby u.FullName
                select new { u.Id, u.FullName, u.UserName, u.Email }).ToListAsync(ct);
            return Results.Ok(result);
        }).RequireAuthorization("ADMIN");
        a.MapGet("/classes/{classId:guid}/lecturers", async (Guid classId,
            AttendanceDbContext db, ClaimsPrincipal user, CancellationToken ct) =>
        {
            if (!await CanViewClass(db, user, classId, ct)) return Results.Forbid();
            var data = await (from t in db.TeachingAssignments.AsNoTracking()
                join l in db.Users on t.LecturerId equals l.Id
                where t.ClassSectionId == classId
                select new { l.Id, l.FullName, l.UserName }).ToListAsync(ct);
            return Results.Ok(data);
        });
        a.MapPost("/classes/{classId:guid}/lecturers", async (Guid classId, LecturerInput body,
            AttendanceDbContext db, UserManager<ApplicationUser> manager, CancellationToken ct) =>
        {
            if (!await db.ClassSections.AnyAsync(x => x.Id == classId, ct)) return Missing();
            var teacher = await manager.FindByIdAsync(body.LecturerId.ToString());
            if (teacher is null || !teacher.IsActive || !await manager.IsInRoleAsync(teacher, "LECTURER"))
                return Bad("Tài khoản không phải giảng viên đang hoạt động.");
            if (await db.TeachingAssignments.AnyAsync(x => x.ClassSectionId == classId && x.LecturerId == body.LecturerId, ct))
                return Results.Conflict(new { message = "Giảng viên đã được phân công." });
            db.TeachingAssignments.Add(new TeachingAssignment { ClassSectionId = classId, LecturerId = body.LecturerId });
            await db.SaveChangesAsync(ct); return Results.Ok(new { message = "Đã phân công giảng viên." });
        }).RequireAuthorization("ADMIN");
        a.MapDelete("/classes/{classId:guid}/lecturers/{lecturerId:guid}", async (Guid classId, Guid lecturerId,
            AttendanceDbContext db, CancellationToken ct) =>
        {
            var x = await db.TeachingAssignments.FindAsync([classId, lecturerId], ct);
            if (x is null) return Missing();
            db.TeachingAssignments.Remove(x); await db.SaveChangesAsync(ct); return Results.NoContent();
        }).RequireAuthorization("ADMIN");

        // Sessions: lecturer may only manage own classes, student only sees enrolled classes.
        a.MapGet("/classes/{classId:guid}/sessions", async (Guid classId,
            AttendanceDbContext db, ClaimsPrincipal user, CancellationToken ct) =>
        {
            if (!await CanViewClass(db, user, classId, ct)) return Results.Forbid();
            var data = await db.AttendanceSessions.AsNoTracking().Where(x => x.ClassSectionId == classId)
                .OrderByDescending(x => x.StartsAtUtc)
                .Select(x => new { x.Id, x.ClassSectionId, x.StartsAtUtc, x.EndsAtUtc, x.Status,
                    PresentCount = db.AttendanceRecords.Count(r => r.AttendanceSessionId == x.Id && r.Status == "PRESENT") })
                .ToListAsync(ct);
            return Results.Ok(data);
        });
        a.MapPost("/classes/{classId:guid}/sessions", async (Guid classId, SessionInput body,
            AttendanceDbContext db, ClaimsPrincipal user, CancellationToken ct) =>
        {
            if (!await CanTeach(db, user, classId, ct)) return Results.Forbid();
            if (!await db.ClassSections.AnyAsync(x => x.Id == classId, ct)) return Missing();
            if (!ValidSession(body)) return Bad("Thời gian hoặc trạng thái phiên điểm danh không hợp lệ.");
            var session = new AttendanceSession { ClassSectionId = classId,
                StartsAtUtc = body.StartsAtUtc.ToUniversalTime(), EndsAtUtc = body.EndsAtUtc.ToUniversalTime(),
                Status = body.Status.ToUpperInvariant() };
            db.AttendanceSessions.Add(session); await db.SaveChangesAsync(ct); return Results.Ok(new { session.Id });
        });
        a.MapPut("/sessions/{id:guid}", async (Guid id, SessionInput body,
            AttendanceDbContext db, ClaimsPrincipal user, CancellationToken ct) =>
        {
            var session = await db.AttendanceSessions.FindAsync([id], ct);
            if (session is null) return Missing();
            if (!await CanTeach(db, user, session.ClassSectionId, ct)) return Results.Forbid();
            if (!ValidSession(body)) return Bad("Thời gian hoặc trạng thái phiên không hợp lệ.");
            session.StartsAtUtc = body.StartsAtUtc.ToUniversalTime();
            session.EndsAtUtc = body.EndsAtUtc.ToUniversalTime();
            session.Status = body.Status.ToUpperInvariant();
            await db.SaveChangesAsync(ct); return Results.Ok(new { message = "Đã cập nhật phiên điểm danh." });
        });
        a.MapDelete("/sessions/{id:guid}", async (Guid id, AttendanceDbContext db,
            ClaimsPrincipal user, CancellationToken ct) =>
        {
            var session = await db.AttendanceSessions.FindAsync([id], ct);
            if (session is null) return Missing();
            if (!await CanTeach(db, user, session.ClassSectionId, ct)) return Results.Forbid();
            if (await db.AttendanceRecords.AnyAsync(x => x.AttendanceSessionId == id, ct) ||
                await db.AttendanceAttempts.AnyAsync(x => x.AttendanceSessionId == id, ct) ||
                await db.LeaveRequests.AnyAsync(x => x.AttendanceSessionId == id, ct))
                return Results.Conflict(new { message = "Phiên đã có điểm danh/đơn xin nghỉ; không thể xóa." });
            db.AttendanceSessions.Remove(session); await db.SaveChangesAsync(ct); return Results.NoContent();
        });
        a.MapGet("/sessions/{id:guid}/attendance", async (Guid id,
            AttendanceDbContext db, ClaimsPrincipal user, CancellationToken ct) =>
        {
            var session = await db.AttendanceSessions.AsNoTracking().FirstOrDefaultAsync(x => x.Id == id, ct);
            if (session is null) return Missing();
            if (!await CanViewClass(db, user, session.ClassSectionId, ct)) return Results.Forbid();
            var query = db.AttendanceRecords.AsNoTracking().Where(x => x.AttendanceSessionId == id);
            if (!await CanTeach(db, user, session.ClassSectionId, ct))
            {
                var caller = Caller(user);
                if (!caller.HasValue) return Results.Unauthorized();
                query = query.Where(x => x.StudentId == caller.Value);
            }
            var result = await (from r in query
                join s in db.Users on r.StudentId equals s.Id
                select new { r.Id, r.StudentId, StudentName = s.FullName,
                    r.Status, r.Method, r.CheckedAtUtc }).ToListAsync(ct);
            return Results.Ok(result);
        });
        a.MapPut("/sessions/{id:guid}/attendance/{studentId:guid}", async (Guid id, Guid studentId,
            AttendanceStatusInput body, AttendanceDbContext db, ClaimsPrincipal user, CancellationToken ct) =>
        {
            var session = await db.AttendanceSessions.FindAsync([id], ct);
            if (session is null) return Missing();
            if (!await CanTeach(db, user, session.ClassSectionId, ct)) return Results.Forbid();
            var status = body.Status?.Trim().ToUpperInvariant();
            if (status is not ("PRESENT" or "ABSENT" or "LATE" or "EXCUSED")) return Bad("Trạng thái điểm danh không hợp lệ.");
            if (!await db.Enrollments.AnyAsync(x => x.ClassSectionId == session.ClassSectionId && x.StudentId == studentId, ct))
                return Bad("Sinh viên không thuộc lớp.");
            var record = await db.AttendanceRecords.FirstOrDefaultAsync(x => x.AttendanceSessionId == id && x.StudentId == studentId, ct);
            if (record is null)
            {
                record = new AttendanceRecord { AttendanceSessionId = id, StudentId = studentId };
                db.AttendanceRecords.Add(record);
            }
            record.Status = status; record.Method = "MANUAL";
            record.CheckedAtUtc = status is "PRESENT" or "LATE" ? DateTime.UtcNow : null;
            await db.SaveChangesAsync(ct); return Results.Ok(new { message = "Đã cập nhật điểm danh." });
        });
        a.MapPost("/sessions/{id:guid}/check-in", async (Guid id,
            AttendanceDbContext db, ClaimsPrincipal user, CancellationToken ct) =>
        {
            if (!user.IsInRole("STUDENT")) return Results.Forbid();
            var studentId = Caller(user);
            if (!studentId.HasValue) return Results.Unauthorized();
            var session = await db.AttendanceSessions.AsNoTracking().FirstOrDefaultAsync(x => x.Id == id, ct);
            if (session is null) return Missing();
            if (!await db.Enrollments.AnyAsync(x => x.ClassSectionId == session.ClassSectionId && x.StudentId == studentId.Value, ct))
                return Results.Forbid();
            var now = DateTime.UtcNow;
            if (session.Status != "OPEN" || now < session.StartsAtUtc || now > session.EndsAtUtc)
                return Bad("Buổi điểm danh chưa mở, đã đóng hoặc ngoài khung giờ.");
            if (await db.AttendanceRecords.AnyAsync(x => x.AttendanceSessionId == id && x.StudentId == studentId.Value, ct))
                return Results.Conflict(new { message = "Bạn đã có kết quả điểm danh; liên hệ giảng viên để điều chỉnh." });
            db.AttendanceRecords.Add(new AttendanceRecord { AttendanceSessionId = id, StudentId = studentId.Value,
                Status = "PRESENT", Method = "SELF_DEMO", CheckedAtUtc = now });
            await db.SaveChangesAsync(ct); return Results.Ok(new { message = "Đã điểm danh thử nghiệm Phần 4." });
        });

        // Leave requests: student CRUD their own PENDING request; assigned staff reviews.
        a.MapGet("/leave-requests", async (AttendanceDbContext db, ClaimsPrincipal user, CancellationToken ct) =>
        {
            var query = from l in db.LeaveRequests.AsNoTracking()
                join s in db.AttendanceSessions on l.AttendanceSessionId equals s.Id
                join c in db.ClassSections on s.ClassSectionId equals c.Id
                join u in db.Users on l.StudentId equals u.Id
                select new { l, s, c, u };
            if (!Admin(user))
            {
                var uid = Caller(user);
                if (!uid.HasValue) return Results.Unauthorized();
                if (user.IsInRole("LECTURER"))
                    query = query.Where(x => db.TeachingAssignments.Any(t => t.ClassSectionId == x.c.Id && t.LecturerId == uid.Value));
                else
                    query = query.Where(x => x.l.StudentId == uid.Value);
            }
            var result = await query.OrderByDescending(x => x.s.StartsAtUtc)
                .Select(x => new { x.l.Id, x.l.AttendanceSessionId, x.l.StudentId,
                    StudentName = x.u.FullName, x.c.ClassCode, x.s.StartsAtUtc,
                    x.l.Reason, x.l.Status }).ToListAsync(ct);
            return Results.Ok(result);
        });
        a.MapPost("/leave-requests", async (LeaveInput body,
            AttendanceDbContext db, ClaimsPrincipal user, CancellationToken ct) =>
        {
            if (!user.IsInRole("STUDENT")) return Results.Forbid();
            var id = Caller(user);
            if (!id.HasValue) return Results.Unauthorized();
            var session = await db.AttendanceSessions.FindAsync([body.AttendanceSessionId], ct);
            if (session is null) return Missing();
            if (!await db.Enrollments.AnyAsync(x => x.ClassSectionId == session.ClassSectionId && x.StudentId == id.Value, ct))
                return Results.Forbid();
            if (!ValidReason(body.Reason)) return Bad("Lý do phải có 5–2000 ký tự.");
            if (await db.LeaveRequests.AnyAsync(x => x.StudentId == id.Value && x.AttendanceSessionId == body.AttendanceSessionId, ct))
                return Results.Conflict(new { message = "Bạn đã gửi đơn cho buổi học này." });
            var leave = new LeaveRequest { AttendanceSessionId = body.AttendanceSessionId,
                StudentId = id.Value, Reason = body.Reason.Trim() };
            db.LeaveRequests.Add(leave); await db.SaveChangesAsync(ct); return Results.Ok(new { leave.Id });
        });
        a.MapPut("/leave-requests/{id:guid}", async (Guid id, LeaveReasonInput body,
            AttendanceDbContext db, ClaimsPrincipal user, CancellationToken ct) =>
        {
            var leave = await db.LeaveRequests.FindAsync([id], ct);
            if (leave is null) return Missing();
            if (Caller(user) != leave.StudentId || !user.IsInRole("STUDENT")) return Results.Forbid();
            if (leave.Status != "PENDING") return Bad("Đơn đã được duyệt/từ chối, không thể sửa.");
            if (!ValidReason(body.Reason)) return Bad("Lý do phải có 5–2000 ký tự.");
            leave.Reason = body.Reason.Trim(); await db.SaveChangesAsync(ct);
            return Results.Ok(new { message = "Đã cập nhật đơn." });
        });
        a.MapDelete("/leave-requests/{id:guid}", async (Guid id,
            AttendanceDbContext db, ClaimsPrincipal user, CancellationToken ct) =>
        {
            var leave = await db.LeaveRequests.FindAsync([id], ct);
            if (leave is null) return Missing();
            if (Caller(user) != leave.StudentId || !user.IsInRole("STUDENT")) return Results.Forbid();
            if (leave.Status != "PENDING") return Bad("Không thể xóa đơn đã xử lý.");
            db.LeaveRequests.Remove(leave); await db.SaveChangesAsync(ct); return Results.NoContent();
        });
        a.MapPut("/leave-requests/{id:guid}/decision", async (Guid id, LeaveDecisionInput body,
            AttendanceDbContext db, ClaimsPrincipal user, CancellationToken ct) =>
        {
            var leave = await db.LeaveRequests.FindAsync([id], ct);
            if (leave is null) return Missing();
            var session = await db.AttendanceSessions.FindAsync([leave.AttendanceSessionId], ct);
            if (session is null) return Missing();
            if (!Staff(user) || !await CanTeach(db, user, session.ClassSectionId, ct)) return Results.Forbid();
            var status = body.Status?.Trim().ToUpperInvariant();
            if (status is not ("APPROVED" or "REJECTED")) return Bad("Chỉ chọn APPROVED hoặc REJECTED.");
            if (leave.Status != "PENDING") return Results.Conflict(new { message = "Đơn đã xử lý." });
            leave.Status = status;
            if (status == "APPROVED")
            {
                var record = await db.AttendanceRecords.FirstOrDefaultAsync(x =>
                    x.AttendanceSessionId == session.Id && x.StudentId == leave.StudentId, ct);
                if (record is null)
                {
                    record = new AttendanceRecord { AttendanceSessionId = session.Id, StudentId = leave.StudentId };
                    db.AttendanceRecords.Add(record);
                }
                record.Status = "EXCUSED"; record.Method = "LEAVE"; record.CheckedAtUtc = null;
            }
            await db.SaveChangesAsync(ct);
            return Results.Ok(new { message = "Đã xử lý đơn xin nghỉ." });
        });

        return app;
    }

    private static bool ValidRoom(RoomInput x) => !string.IsNullOrWhiteSpace(x.Name) &&
        x.Name.Trim().Length <= 150 && double.IsFinite(x.Latitude) &&
        double.IsFinite(x.Longitude) && double.IsFinite(x.RadiusMeters) &&
        x.Latitude is >= -90 and <= 90 && x.Longitude is >= -180 and <= 180 &&
        x.RadiusMeters is > 0 and <= 10000;
    private static bool ValidClass(ClassInput x) => !string.IsNullOrWhiteSpace(x.ClassCode) &&
        !string.IsNullOrWhiteSpace(x.Semester) && x.ClassCode.Trim().Length <= 40 &&
        x.Semester.Trim().Length <= 30 && x.CourseId != Guid.Empty;
    private static bool ValidSession(SessionInput x) => x.StartsAtUtc < x.EndsAtUtc &&
        x.Status?.ToUpperInvariant() is "DRAFT" or "OPEN" or "CLOSED" &&
        x.EndsAtUtc - x.StartsAtUtc <= TimeSpan.FromDays(2);
    private static bool ValidReason(string? x) => x is not null && x.Trim().Length is >= 5 and <= 2000;

    public sealed record CourseInput(string Code, string Name, int Credits);
    public sealed record RoomInput(string Name, double Latitude, double Longitude, double RadiusMeters);
    public sealed record ClassInput(Guid CourseId, Guid? ClassroomId, string ClassCode, string Semester);
    public sealed record StudentInput(string FullName, string? StudentCode, bool IsActive);
    public sealed record EnrollInput(Guid StudentId);
    public sealed record LecturerInput(Guid LecturerId);
    public sealed record SessionInput(DateTime StartsAtUtc, DateTime EndsAtUtc, string Status);
    public sealed record AttendanceStatusInput(string Status);
    public sealed record LeaveInput(Guid AttendanceSessionId, string Reason);
    public sealed record LeaveReasonInput(string Reason);
    public sealed record LeaveDecisionInput(string Status);
}
