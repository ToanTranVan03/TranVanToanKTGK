# Render deployment (manual account setup required)

1. Push the project to your own GitHub repository. Generate the first migration using `scripts/setup-backend.ps1` and COMMIT `backend/Attendance.Api/Data/Migrations` before deploying.
2. Create **Render Postgres**. Use the same region as your Web Service. Choose a plan suitable for persistent data; do not store essential class data in ephemeral free databases.
3. Create Render **Web Service**, runtime **Docker**, repository root directory `backend/Attendance.Api`, Dockerfile path `Dockerfile` (relative to root directory).
4. Set environment variables in the Render dashboard:
   - `ConnectionStrings__Default=Host=<internal-db-host>;Port=5432;Database=<db-name>;Username=<db-user>;Password=<db-password>;SSL Mode=Require`
   - `Database__ApplyMigrationsOnStartup=true`
   - `ASPNETCORE_ENVIRONMENT=Production`
   - Render provides `PORT`, honored by Program.cs.
5. Set Health Check Path `/health`.
6. After deploy, open `https://<your-service>.onrender.com/api/v1/system/status`; it should return `databaseConnected: true`. Use *your actual assigned domain*; the URL here is a placeholder.
7. In Android Studio Run > Edit Configurations, add additional run args:
   `--dart-define=API_BASE_URL=https://<your-service>.onrender.com/api/v1`
8. Re-run Flutter and tap 'Kiểm tra kết nối'.

Security: Render TLS terminates inbound HTTPS; do not put DB credentials into Flutter. Internal Render Postgres host should only be visible to API. Do not make raw PostgreSQL port publicly accessible.

See official docs: https://render.com/docs/web-services and https://render.com/docs/postgresql-creating-connecting
