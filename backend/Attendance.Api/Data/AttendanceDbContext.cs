using Attendance.Api.Domain;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Identity.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore;

namespace Attendance.Api.Data;

public sealed class AttendanceDbContext
    : IdentityDbContext<ApplicationUser, IdentityRole<Guid>, Guid>
{
    public AttendanceDbContext(DbContextOptions<AttendanceDbContext> options)
        : base(options) { }

    public DbSet<Course> Courses => Set<Course>();
    public DbSet<Classroom> Classrooms => Set<Classroom>();
    public DbSet<ClassSection> ClassSections => Set<ClassSection>();
    public DbSet<Enrollment> Enrollments => Set<Enrollment>();
    public DbSet<TeachingAssignment> TeachingAssignments => Set<TeachingAssignment>();
    public DbSet<AttendanceSession> AttendanceSessions => Set<AttendanceSession>();
    public DbSet<AttendanceRecord> AttendanceRecords => Set<AttendanceRecord>();
    public DbSet<AttendanceAttempt> AttendanceAttempts => Set<AttendanceAttempt>();
    public DbSet<LeaveRequest> LeaveRequests => Set<LeaveRequest>();
    public DbSet<ExternalIdentity> ExternalIdentities => Set<ExternalIdentity>();
    public DbSet<FaceTemplate> FaceTemplates => Set<FaceTemplate>();
    public DbSet<Beacon> Beacons => Set<Beacon>();
    public DbSet<RiskAssessment> RiskAssessments => Set<RiskAssessment>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        base.OnModelCreating(modelBuilder);

        modelBuilder.Entity<ApplicationUser>(e =>
        {
            e.ToTable("users");
            e.Property(x => x.FullName).HasMaxLength(200).IsRequired();
            e.Property(x => x.StudentCode).HasMaxLength(30);
            e.HasIndex(x => x.StudentCode).IsUnique();
        });

        modelBuilder.Entity<Course>(e =>
        {
            e.ToTable("courses");
            e.HasKey(x => x.Id);
            e.Property(x => x.Code).HasMaxLength(30).IsRequired();
            e.Property(x => x.Name).HasMaxLength(200).IsRequired();
            e.HasIndex(x => x.Code).IsUnique();
        });

        modelBuilder.Entity<Classroom>(e =>
        {
            e.ToTable("classrooms");
            e.HasKey(x => x.Id);
            e.Property(x => x.Name).HasMaxLength(150).IsRequired();
            e.HasIndex(x => x.Name).IsUnique();
        });

        modelBuilder.Entity<ClassSection>(e =>
        {
            e.ToTable("class_sections");
            e.HasKey(x => x.Id);
            e.Property(x => x.ClassCode).HasMaxLength(40).IsRequired();
            e.Property(x => x.Semester).HasMaxLength(30).IsRequired();
            e.HasIndex(x => new { x.ClassCode, x.Semester }).IsUnique();
            e.HasOne<Course>().WithMany().HasForeignKey(x => x.CourseId)
                .OnDelete(DeleteBehavior.Restrict);
            e.HasOne<Classroom>().WithMany().HasForeignKey(x => x.ClassroomId)
                .OnDelete(DeleteBehavior.Restrict);
        });

        modelBuilder.Entity<Enrollment>(e =>
        {
            e.ToTable("class_enrollments");
            e.HasKey(x => new { x.ClassSectionId, x.StudentId });
            e.HasOne<ClassSection>().WithMany().HasForeignKey(x => x.ClassSectionId)
                .OnDelete(DeleteBehavior.Restrict);
            e.HasOne<ApplicationUser>().WithMany().HasForeignKey(x => x.StudentId)
                .OnDelete(DeleteBehavior.Restrict);
        });

        modelBuilder.Entity<TeachingAssignment>(e =>
        {
            e.ToTable("teaching_assignments");
            e.HasKey(x => new { x.ClassSectionId, x.LecturerId });
            e.HasOne<ClassSection>().WithMany().HasForeignKey(x => x.ClassSectionId)
                .OnDelete(DeleteBehavior.Restrict);
            e.HasOne<ApplicationUser>().WithMany().HasForeignKey(x => x.LecturerId)
                .OnDelete(DeleteBehavior.Restrict);
        });

        modelBuilder.Entity<AttendanceSession>(e =>
        {
            e.ToTable("attendance_sessions");
            e.HasKey(x => x.Id);
            e.Property(x => x.Status).HasMaxLength(20).IsRequired();
            e.Property(x => x.QrSecretRef).HasMaxLength(200);
            e.HasIndex(x => new { x.ClassSectionId, x.StartsAtUtc });
            e.HasOne<ClassSection>().WithMany().HasForeignKey(x => x.ClassSectionId)
                .OnDelete(DeleteBehavior.Restrict);
        });

        modelBuilder.Entity<AttendanceRecord>(e =>
        {
            e.ToTable("attendance_records");
            e.HasKey(x => x.Id);
            e.Property(x => x.Status).HasMaxLength(20).IsRequired();
            e.Property(x => x.Method).HasMaxLength(30);
            e.HasIndex(x => new { x.AttendanceSessionId, x.StudentId }).IsUnique();
            e.HasOne<AttendanceSession>().WithMany().HasForeignKey(x => x.AttendanceSessionId)
                .OnDelete(DeleteBehavior.Restrict);
            e.HasOne<ApplicationUser>().WithMany().HasForeignKey(x => x.StudentId)
                .OnDelete(DeleteBehavior.Restrict);
        });

        modelBuilder.Entity<AttendanceAttempt>(e =>
        {
            e.ToTable("attendance_attempts");
            e.HasKey(x => x.Id);
            e.Property(x => x.Result).HasMaxLength(30).IsRequired();
            e.Property(x => x.EvidenceJson).HasColumnType("jsonb");
            e.HasIndex(x => new { x.StudentId, x.CreatedAtUtc });
            e.HasOne<AttendanceSession>().WithMany().HasForeignKey(x => x.AttendanceSessionId)
                .OnDelete(DeleteBehavior.Restrict);
            e.HasOne<ApplicationUser>().WithMany().HasForeignKey(x => x.StudentId)
                .OnDelete(DeleteBehavior.Restrict);
        });

        modelBuilder.Entity<LeaveRequest>(e =>
        {
            e.ToTable("leave_requests");
            e.HasKey(x => x.Id);
            e.Property(x => x.Reason).HasMaxLength(2000).IsRequired();
            e.Property(x => x.Status).HasMaxLength(20).IsRequired();
            e.Property(x => x.AttachmentRef).HasMaxLength(500);
            e.HasIndex(x => new { x.AttendanceSessionId, x.StudentId }).IsUnique();
            e.HasOne<AttendanceSession>().WithMany().HasForeignKey(x => x.AttendanceSessionId)
                .OnDelete(DeleteBehavior.Restrict);
            e.HasOne<ApplicationUser>().WithMany().HasForeignKey(x => x.StudentId)
                .OnDelete(DeleteBehavior.Restrict);
        });

        modelBuilder.Entity<ExternalIdentity>(e =>
        {
            e.ToTable("external_identities");
            e.HasKey(x => x.Id);
            e.Property(x => x.Provider).HasMaxLength(50).IsRequired();
            e.Property(x => x.ProviderSubject).HasMaxLength(255).IsRequired();
            e.HasIndex(x => new { x.Provider, x.ProviderSubject }).IsUnique();
            e.HasOne<ApplicationUser>().WithMany().HasForeignKey(x => x.UserId)
                .OnDelete(DeleteBehavior.Restrict);
        });

        modelBuilder.Entity<FaceTemplate>(e =>
        {
            e.ToTable("face_templates");
            e.HasKey(x => x.Id);
            e.Property(x => x.EncryptedTemplateRef).HasMaxLength(500).IsRequired();
            e.Property(x => x.ModelVersion).HasMaxLength(80).IsRequired();
            e.HasOne<ApplicationUser>().WithMany().HasForeignKey(x => x.UserId)
                .OnDelete(DeleteBehavior.Restrict);
        });

        modelBuilder.Entity<Beacon>(e =>
        {
            e.ToTable("beacons");
            e.HasKey(x => x.Id);
            e.Property(x => x.BeaconCode).HasMaxLength(100).IsRequired();
            e.Property(x => x.SecretRef).HasMaxLength(200);
            e.HasIndex(x => x.BeaconCode).IsUnique();
            e.HasOne<Classroom>().WithMany().HasForeignKey(x => x.ClassroomId)
                .OnDelete(DeleteBehavior.Restrict);
        });

        modelBuilder.Entity<RiskAssessment>(e =>
        {
            e.ToTable("risk_assessments");
            e.HasKey(x => x.Id);
            e.Property(x => x.RiskLevel).HasMaxLength(20).IsRequired();
            e.HasIndex(x => new { x.StudentId, x.ClassSectionId, x.EvaluatedAtUtc });
            e.HasOne<ApplicationUser>().WithMany().HasForeignKey(x => x.StudentId)
                .OnDelete(DeleteBehavior.Restrict);
            e.HasOne<ClassSection>().WithMany().HasForeignKey(x => x.ClassSectionId)
                .OnDelete(DeleteBehavior.Restrict);
        });
    }
}
