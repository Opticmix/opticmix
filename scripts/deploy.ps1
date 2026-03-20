# Deploy edge components (DLL + Streamer) to TrackingSvc
# Must run as Administrator
# Usage: powershell -File scripts/deploy.ps1

param(
    [switch]$Restore  # Restore original DLL
)

$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$deployScript = Join-Path $root "edge\deploy\deploy_dll.ps1"

if (-not (Test-Path $deployScript)) {
    Write-Host "[ERROR] edge/deploy/deploy_dll.ps1 not found" -ForegroundColor Red
    Write-Host "Run 'git submodule update --init' first"
    exit 1
}

if ($Restore) {
    powershell -File $deployScript -Restore
} else {
    powershell -File $deployScript
}
