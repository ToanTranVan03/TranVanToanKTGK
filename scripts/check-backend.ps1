param([Parameter(Mandatory = $true)][string]$ApiOrigin)
$uri = [Uri]$ApiOrigin
if ($uri.Scheme -ne 'https') { throw 'API phai su dung HTTPS cong khai.' }
$endpoint = $ApiOrigin.TrimEnd('/') + '/api/v1/system/status'
Write-Host "GET $endpoint"
Invoke-RestMethod -Method Get -Uri $endpoint -TimeoutSec 25 | Format-List
