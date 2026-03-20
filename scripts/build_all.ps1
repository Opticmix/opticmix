# Build all components
# Usage: powershell -File scripts/build_all.ps1
# Requires: admin for deploy, vcvars64 for streamer

param(
    [switch]$EdgeOnly,
    [switch]$AeroMixOnly
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)

function Build-Edge {
    Write-Host "`n=== Building Edge (DLL + Streamer) ===" -ForegroundColor Cyan
    $buildScript = Join-Path $root "edge\build.ps1"
    if (Test-Path $buildScript) {
        powershell -File $buildScript
    } else {
        Write-Host "[SKIP] edge/build.ps1 not found" -ForegroundColor Yellow
    }
}

function Build-AeroMix {
    Write-Host "`n=== Building AeroMix Service ===" -ForegroundColor Cyan
    $csproj = Join-Path $root "touchfree\TF_Service_dotNet\TouchFree_Service\TouchFree_Service.csproj"
    if (Test-Path $csproj) {
        dotnet build -c Release $csproj
    } else {
        Write-Host "[SKIP] AeroMix csproj not found" -ForegroundColor Yellow
    }
}

if ($EdgeOnly) { Build-Edge; return }
if ($AeroMixOnly) { Build-AeroMix; return }

Build-Edge
Build-AeroMix

Write-Host "`n=== Build Complete ===" -ForegroundColor Green
