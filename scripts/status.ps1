# Show status of all submodules
# Usage: powershell -File scripts/status.ps1

$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)

Write-Host "=== Opticmix Submodule Status ===" -ForegroundColor Cyan
Write-Host ""

$submodules = @("edge", "tracker", "touchfree", "re-docs", "claude-skills")

foreach ($sub in $submodules) {
    $path = Join-Path $root $sub
    if (Test-Path (Join-Path $path ".git")) {
        $branch = git -C $path rev-parse --abbrev-ref HEAD 2>$null
        $hash = git -C $path rev-parse --short HEAD 2>$null
        $dirty = git -C $path status --porcelain 2>$null
        $status = if ($dirty) { " [DIRTY]" } else { "" }
        Write-Host "  $sub`t$branch ($hash)$status" -ForegroundColor $(if ($dirty) { "Yellow" } else { "Green" })
    } else {
        Write-Host "  $sub`t[NOT INITIALIZED]" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "Run 'git submodule update --init --recursive' to initialize all." -ForegroundColor Gray
