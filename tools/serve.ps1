# Serves the folder that contains muzik.pak over the local Wi-Fi network so the
# iPhone can download it in Safari (Files app). No cable needed.
# Usage:  powershell -ExecutionPolicy Bypass -File .\serve.ps1
param(
    [string]$Folder = $PSScriptRoot,
    [int]$Port = 8000
)

$pak = Join-Path $Folder 'muzik.pak'
if (-not (Test-Path -LiteralPath $pak)) {
    Write-Error "muzik.pak bulunamadi: $pak  (once restore-pak.ps1 calistir)"
    exit 1
}

$ips = Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
    Where-Object { $_.IPAddress -notlike '127.*' -and $_.IPAddress -notlike '169.254.*' } |
    Select-Object -ExpandProperty IPAddress

Write-Host ""
Write-Host "Telefon ve bu PC ayni Wi-Fi'de olmali."
Write-Host "iPhone Safari'de su adresi ac ve muzik.pak'i indir:"
foreach ($ip in $ips) {
    Write-Host "    http://${ip}:${Port}/muzik.pak"
}
Write-Host ""
Write-Host "Durdurmak icin Ctrl+C."
Write-Host ""

python -m http.server $Port --bind 0.0.0.0 --directory $Folder
