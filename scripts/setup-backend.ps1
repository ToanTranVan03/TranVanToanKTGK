$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
Push-Location $root
try {
  if (-not (Get-Command dotnet -ErrorAction SilentlyContinue)) {
    throw 'Khong tim thay .NET SDK. Can cai .NET 10 SDK.'
  }

  $project = 'backend/Attendance.Api/Attendance.Api.csproj'
  $target = 'backend/Attendance.Api/Data/Migrations'

  Write-Host '=== .NET SDK ===' -ForegroundColor Cyan
  dotnet --version
  if ($LASTEXITCODE -ne 0) { throw 'Khong doc duoc phien ban dotnet' }

  Write-Host '=== Restore Backend ===' -ForegroundColor Cyan
  dotnet restore $project
  if ($LASTEXITCODE -ne 0) { throw 'dotnet restore that bai' }

  Write-Host '=== Restore EF Core CLI dung phien ban cua project (10.0.13) ===' -ForegroundColor Cyan
  dotnet tool restore
  if ($LASTEXITCODE -ne 0) { throw 'dotnet tool restore that bai' }
  dotnet tool run dotnet-ef -- --version
  if ($LASTEXITCODE -ne 0) { throw 'Khong chay duoc EF Core CLI' }

  # IMPORTANT: Build explicitly before migrations so the real C# compiler errors
  # are visible. EF Core's internal 'Build failed' is often too generic.
  Write-Host '=== Build Backend (hien thi loi C# neu co) ===' -ForegroundColor Cyan
  dotnet build $project --configuration Debug --no-restore --verbosity minimal
  if ($LASTEXITCODE -ne 0) {
    Write-Host 'Backend build failed. Chay lenh sau va gui toan bo loi CSxxxx/NUxxxx:' -ForegroundColor Yellow
    Write-Host "dotnet build $project --configuration Debug --verbosity normal"
    throw 'Backend chua build thanh cong; khong tao migration'
  }

  if (-not (Test-Path $target) -or -not (Get-ChildItem $target -Filter '*_InitialSchema.cs' -ErrorAction SilentlyContinue)) {
    Write-Host '=== Tao Migration InitialSchema (su dung assembly da build) ===' -ForegroundColor Cyan
    dotnet tool run dotnet-ef -- migrations add InitialSchema --project $project --startup-project $project --output-dir Data/Migrations --configuration Debug --no-build --verbose
    if ($LASTEXITCODE -ne 0) {
      throw 'Tao migration that bai; xem cac dong loi chi tiet phia tren'
    }
  } else {
    Write-Host 'InitialSchema da ton tai. Khong tao trung.' -ForegroundColor Green
  }

  Write-Host '=== Build Release de kiem tra Docker/Deploy ===' -ForegroundColor Cyan
  dotnet build $project --configuration Release --no-restore --verbosity minimal
  if ($LASTEXITCODE -ne 0) { throw 'Build Release that bai' }

  Write-Host 'DA HOAN TAT: Backend build va migration da duoc tao.' -ForegroundColor Green
} finally {
  Pop-Location
}
