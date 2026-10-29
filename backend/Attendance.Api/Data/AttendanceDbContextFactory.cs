using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Design;

namespace Attendance.Api.Data;

// Only for 'dotnet ef migrations add'; generating migrations never needs DB access.
public sealed class AttendanceDbContextFactory : IDesignTimeDbContextFactory<AttendanceDbContext>
{
    public AttendanceDbContext CreateDbContext(string[] args)
    {
        var connection = Environment.GetEnvironmentVariable("ConnectionStrings__Default")
            ?? "Host=design-time.invalid;Database=attendance;Username=placeholder;Password=placeholder";
        var options = new DbContextOptionsBuilder<AttendanceDbContext>()
            .UseNpgsql(connection).Options;
        return new AttendanceDbContext(options);
    }
}
