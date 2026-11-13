# Finds the largest muzik.pak in the Recycle Bin and copies it next to this script.
# Usage:  powershell -ExecutionPolicy Bypass -File .\restore-pak.ps1
param(
    [string]$Destination = (Join-Path $PSScriptRoot "muzik.pak")
)

$recycle = Join-Path $env:SystemDrive '$Recycle.Bin'

Write-Host "Geri donusum kutusunda muzik.pak araniyor..."
$pak = Get-ChildItem -LiteralPath $recycle -Recurse -Force -Filter 'muzik.pak' -ErrorAction SilentlyContinue |
    Sort-Object Length -Descending |
    Select-Object -First 1

if (-not $pak) {
    Write-Error "muzik.pak geri donusum kutusunda bulunamadi."
    exit 1
}

$gb = [math]::Round($pak.Length / 1GB, 2)
Write-Host "Bulundu : $($pak.FullName)"
Write-Host "Boyut   : $gb GB"
Write-Host "Kopyalaniyor -> $Destination"

Copy-Item -LiteralPath $pak.FullName -Destination $Destination -Force
Write-Host "Tamam."
