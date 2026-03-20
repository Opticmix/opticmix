# Clone opticmix umbrella repo with all submodules
# Usage: powershell -File scripts/clone.ps1

param(
    [string]$Destination = "opticmix"
)

Write-Host "Cloning opticmix umbrella repo..."
git clone --recurse-submodules https://github.com/Opticmix/opticmix.git $Destination

if ($LASTEXITCODE -eq 0) {
    Write-Host "`n[OK] Cloned to $Destination/" -ForegroundColor Green
    Write-Host "Submodules:"
    git -C $Destination submodule status
} else {
    Write-Host "`n[FAIL] Clone failed" -ForegroundColor Red
}
