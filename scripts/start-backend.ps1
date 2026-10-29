$ErrorActionPreference = 'Stop'
Set-Location (Resolve-Path (Join-Path $PSScriptRoot '..'))

if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
  throw 'Chua cai Docker Desktop. Cai Docker Desktop va mo Docker engine.'
}
if (-not (Test-Path .env)) {
  $bytes = New-Object byte[] 32
  $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
  try { $rng.GetBytes($bytes) } finally { $rng.Dispose() }
  $password = -join ($bytes | ForEach-Object { $_.ToString('x2') })
  "POSTGRES_PASSWORD=$password" | Set-Content -Path .env -Encoding ascii
  Write-Host 'Da tao file .env voi mat khau PostgreSQL ngau nhien.'
}
& "$PSScriptRoot/setup-backend.ps1"
if ($LASTEXITCODE -ne 0) { throw 'Setup Backend that bai' }

docker compose up -d --build
if ($LASTEXITCODE -ne 0) { throw 'Docker Compose that bai' }
Write-Host 'Docker Backend da duoc khoi dong. Kiem tra docker compose ps.'
Write-Host 'Chay tren may dev: docker compose logs --tail=100 api'
Write-Host 'LUU Y: Flutter phai ket noi API sau khi deploy HTTPS len Internet.'
