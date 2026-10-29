using Microsoft.AspNetCore.Identity;

namespace Attendance.Api.Domain;

// These models describe the core database. Business endpoints and authorization
// will be implemented in Parts 3-4; no public CRUD endpoints exist in Part 2.
public sealed class ApplicationUser : IdentityUser<Guid>
{
    public string FullName { get; set; } = string.Empty;
    public string? StudentCode { get; set; }
    public bool IsActive { get; set; } = true;
    public DateTime CreatedAtUtc { get; set; } = DateTime.UtcNow;
}

public sealed class Course
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public string Code { get; set; } = string.Empty;
    public string Name { get; set; } = string.Empty;
    public int Credits { get; set; }
}

public sealed class Classroom
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public string Name { get; set; } = string.Empty;
    public double Latitude { get; set; }
    public double Longitude { get; set; }
    public double RadiusMeters { get; set; } = 100;
}

public sealed class ClassSection
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public Guid CourseId { get; set; }
    public Guid? ClassroomId { get; set; }
    public string ClassCode { get; set; } = string.Empty;
    public string Semester { get; set; } = string.Empty;
}

public sealed class Enrollment
{
    public Guid ClassSectionId { get; set; }
    public Guid StudentId { get; set; }
    public DateTime JoinedAtUtc { get; set; } = DateTime.UtcNow;
}

public sealed class TeachingAssignment
{
    public Guid ClassSectionId { get; set; }
    public Guid LecturerId { get; set; }
}

public sealed class AttendanceSession
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public Guid ClassSectionId { get; set; }
    public DateTime StartsAtUtc { get; set; }
    public DateTime EndsAtUtc { get; set; }
    public string Status { get; set; } = "DRAFT";
    public string? QrSecretRef { get; set; }
}

public sealed class AttendanceRecord
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public Guid AttendanceSessionId { get; set; }
    public Guid StudentId { get; set; }
    public string Status { get; set; } = "ABSENT";
    public string? Method { get; set; }
    public DateTime? CheckedAtUtc { get; set; }
}

public sealed class AttendanceAttempt
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public Guid AttendanceSessionId { get; set; }
    public Guid StudentId { get; set; }
    public string Result { get; set; } = "PENDING";
    public string EvidenceJson { get; set; } = "{}";
    public DateTime CreatedAtUtc { get; set; } = DateTime.UtcNow;
}

public sealed class LeaveRequest
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public Guid AttendanceSessionId { get; set; }
    public Guid StudentId { get; set; }
    public string Reason { get; set; } = string.Empty;
    public string Status { get; set; } = "PENDING";
    public string? AttachmentRef { get; set; }
}

public sealed class ExternalIdentity
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public Guid UserId { get; set; }
    public string Provider { get; set; } = string.Empty;
    public string ProviderSubject { get; set; } = string.Empty;
}

public sealed class FaceTemplate
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public Guid UserId { get; set; }
    public string EncryptedTemplateRef { get; set; } = string.Empty;
    public string ModelVersion { get; set; } = string.Empty;
}

public sealed class Beacon
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public Guid ClassroomId { get; set; }
    public string BeaconCode { get; set; } = string.Empty;
    public string? SecretRef { get; set; }
    public bool IsActive { get; set; } = true;
}

public sealed class RiskAssessment
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public Guid StudentId { get; set; }
    public Guid ClassSectionId { get; set; }
    public double RiskScore { get; set; }
    public string RiskLevel { get; set; } = "LOW";
    public DateTime EvaluatedAtUtc { get; set; } = DateTime.UtcNow;
}
