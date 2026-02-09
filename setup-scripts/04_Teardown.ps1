<#
.SYNOPSIS
    Anna's Booktable  -  Teardown / Reset
    Stops containers, removes volumes, and optionally deletes the project.

.PARAMETER Mode
    soft   -  Stop containers, keep data volumes (default)
    hard   -  Stop containers AND delete volumes (data loss!)
    nuke   -  Delete everything including project files (DESTRUCTIVE!)
#>

param(
    [ValidateSet("soft", "hard", "nuke")]
    [string]$Mode = "soft",
    [string]$ProjectRoot = "D:\Dev\AnnaBooktable"
)

function Write-Step { param($msg) Write-Host "`n>>> $msg" -ForegroundColor Cyan }
function Write-OK   { param($msg) Write-Host "  [OK] $msg" -ForegroundColor Green }
function Write-Warn { param($msg) Write-Host "  [WARN]  $msg" -ForegroundColor Yellow }

Write-Host ""
Write-Host "Mode: $Mode" -ForegroundColor $(if ($Mode -eq "nuke") { "Red" } elseif ($Mode -eq "hard") { "Yellow" } else { "Green" })

if ($Mode -eq "nuke") {
    Write-Host ""
    Write-Warn "THIS WILL DELETE THE ENTIRE PROJECT AND ALL DATA!"
    $confirm = Read-Host "Type 'DELETE' to confirm"
    if ($confirm -ne "DELETE") {
        Write-Host "Aborted." -ForegroundColor Gray
        exit
    }
}

# Stop containers
Write-Step "Stopping Docker containers"
if (Test-Path (Join-Path $ProjectRoot "docker-compose.yml")) {
    Set-Location $ProjectRoot
    docker compose down 2>$null
    Write-OK "Containers stopped"
} else {
    Write-Warn "docker-compose.yml not found"
}

# Remove volumes if hard/nuke
if ($Mode -in @("hard", "nuke")) {
    Write-Step "Removing Docker volumes"
    docker compose down -v 2>$null
    Write-OK "Volumes removed (all database data deleted)"
}

# Remove project if nuke
if ($Mode -eq "nuke") {
    Write-Step "Removing project directory"
    Set-Location $env:USERPROFILE
    if (Test-Path $ProjectRoot) {
        Remove-Item -Recurse -Force $ProjectRoot
        Write-OK "Project directory deleted: $ProjectRoot"
    }

    # Remove progress file
    $progressFile = "$env:USERPROFILE\.booktable_setup_progress"
    if (Test-Path $progressFile) {
        Remove-Item $progressFile -Force
        Write-OK "Setup progress file removed"
    }
}

# Reset just the setup progress (to re-run setup)
if ($Mode -eq "soft") {
    Write-Host ""
    $resetProgress = Read-Host "Reset setup progress tracker? This lets you re-run 00_Master_Setup.ps1 (y/N)"
    if ($resetProgress -eq "y") {
        $progressFile = "$env:USERPROFILE\.booktable_setup_progress"
        if (Test-Path $progressFile) {
            Remove-Item $progressFile -Force
            Write-OK "Progress reset  -  re-run 00_Master_Setup.ps1 to redo all steps"
        }
    }
}

Write-Host ""
Write-OK "Teardown complete ($Mode mode)"

if ($Mode -eq "soft") {
    Write-Host "  To restart: cd $ProjectRoot && docker compose up -d" -ForegroundColor Gray
}
if ($Mode -eq "hard") {
    Write-Host "  To rebuild with fresh data: cd $ProjectRoot && docker compose up -d" -ForegroundColor Gray
}
if ($Mode -eq "nuke") {
    Write-Host "  To start over: run 00_Master_Setup.ps1" -ForegroundColor Gray
}
Write-Host ""
