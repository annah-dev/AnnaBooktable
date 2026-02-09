<#
.SYNOPSIS
    Anna's Booktable  -  START HERE
    On first run: copies all scripts from OneDrive to C:\Setup (local).
    Then prints the exact commands to run. Makes no system changes.
#>

$LocalSetupDir = "C:\Setup"
$ScriptFiles = @(
    "Lib_Common.ps1",
    "START_HERE.ps1",
    "00_Master_Setup.ps1",
    "01_Scaffold_Project.ps1",
    "02_Setup_Docker.ps1",
    "03_Verify_Environment.ps1",
    "04_Teardown.ps1",
    "05_Dev_Helpers.ps1"
)

# ============================================================
# Detect if running from OneDrive (or any non-local location)
# ============================================================
$runningFrom = $PSScriptRoot
$isLocal = $runningFrom -eq $LocalSetupDir

if (-not $isLocal) {
    Write-Host ""
    Write-Host "+======================================================================+" -ForegroundColor Cyan
    Write-Host "|          Installing scripts to $LocalSetupDir                       |" -ForegroundColor Cyan
    Write-Host "+======================================================================+" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  Source: $runningFrom" -ForegroundColor DarkGray
    Write-Host "  Target: $LocalSetupDir" -ForegroundColor DarkGray
    Write-Host ""

    # Create local folder
    if (-not (Test-Path $LocalSetupDir)) {
        New-Item -ItemType Directory -Path $LocalSetupDir -Force | Out-Null
        Write-Host "  [OK] Created $LocalSetupDir" -ForegroundColor Green
    }

    # Copy each script
    $copied = 0
    $skipped = 0
    foreach ($file in $ScriptFiles) {
        $src = Join-Path $runningFrom $file
        $dst = Join-Path $LocalSetupDir $file

        if (-not (Test-Path $src)) {
            Write-Host "  [WARN]  $file  -  not found in source folder, skipping" -ForegroundColor Yellow
            continue
        }

        # Compare: only copy if source is newer or destination doesn't exist
        if (Test-Path $dst) {
            $srcTime = (Get-Item $src).LastWriteTime
            $dstTime = (Get-Item $dst).LastWriteTime
            if ($srcTime -le $dstTime) {
                Write-Host "  [SKIP]  $file  -  already up to date" -ForegroundColor DarkGray
                $skipped++
                continue
            }
        }

        Copy-Item -Path $src -Destination $dst -Force
        Unblock-File -Path $dst -ErrorAction SilentlyContinue
        Write-Host "  [OK] $file  -  copied" -ForegroundColor Green
        $copied++
    }

    Write-Host ""
    Write-Host "  Copied: $copied   Up to date: $skipped" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  ===============================================================" -ForegroundColor Cyan
    Write-Host "  Scripts installed to $LocalSetupDir" -ForegroundColor Green
    Write-Host "  All commands below use the LOCAL copy (not OneDrive)." -ForegroundColor Green
    Write-Host "  ===============================================================" -ForegroundColor Cyan

    $sd = $LocalSetupDir
} else {
    $sd = $LocalSetupDir
}

# ============================================================
# Unblock all scripts in local folder
# ============================================================
Get-ChildItem -Path $sd -Filter "*.ps1" -ErrorAction SilentlyContinue | ForEach-Object {
    Unblock-File -Path $_.FullName -ErrorAction SilentlyContinue
}

# ============================================================
# Check if running as Administrator
# ============================================================
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator
)

# ============================================================
# Show progress if available
# ============================================================
$progressFile = Join-Path $env:USERPROFILE ".booktable_setup_progress"
$completedCount = 0
if (Test-Path $progressFile) {
    $completedCount = @(Get-Content $progressFile | Where-Object { $_ -match '\S' }).Count
}

# ============================================================
# Print commands
# ============================================================
Write-Host ""
Write-Host "+======================================================================+" -ForegroundColor Cyan
Write-Host "|             Anna's Booktable  -  Dev Environment Setup                |" -ForegroundColor Cyan
Write-Host "+======================================================================+" -ForegroundColor Cyan
Write-Host ""

if (-not $isAdmin) {
    Write-Host "  [WARN]  You are NOT running as Administrator." -ForegroundColor Yellow
    Write-Host "  Right-click PowerShell -> 'Run as Administrator', then re-run." -ForegroundColor Yellow
    Write-Host ""
}

if ($completedCount -gt 0) {
    Write-Host "    # Progress: $completedCount step(s) already completed." -ForegroundColor DarkGray
    Write-Host "     (Setup will resume from where it left off.)" -ForegroundColor DarkGray
    Write-Host ""
}

Write-Host "  +----------------------------------------------------------------+" -ForegroundColor White
Write-Host "  |                    RUN THESE COMMANDS                          |" -ForegroundColor White
Write-Host "  |                                                                |" -ForegroundColor White
Write-Host "  |  Open PowerShell as Administrator, then copy-paste:            |" -ForegroundColor White
Write-Host "  +----------------------------------------------------------------+" -ForegroundColor White
Write-Host ""

Write-Host "  -- STEP 0: Unblock files & set execution policy --" -ForegroundColor DarkCyan
Write-Host ""
Write-Host "  Set-ExecutionPolicy Bypass -Scope Process -Force; Get-ChildItem '$sd\*.ps1' | Unblock-File" -ForegroundColor Green
Write-Host ""

Write-Host "  -- STEP 1: PLAN / DRY RUN (no changes, shows what will happen) --" -ForegroundColor DarkCyan
Write-Host ""
Write-Host "  & '$sd\00_Master_Setup.ps1' -DryRun" -ForegroundColor Green
Write-Host ""

Write-Host "  -- STEP 2: APPLY / EXECUTE (installs everything) --" -ForegroundColor DarkCyan
Write-Host ""
Write-Host "  & '$sd\00_Master_Setup.ps1'" -ForegroundColor Green
Write-Host ""

Write-Host "  -- STEP 3: RESUME AFTER REBOOT (same command  -  picks up where it left off) --" -ForegroundColor DarkCyan
Write-Host ""
Write-Host "  Set-ExecutionPolicy Bypass -Scope Process -Force" -ForegroundColor Green
Write-Host "  & '$sd\00_Master_Setup.ps1'" -ForegroundColor Green
Write-Host ""

Write-Host "  -- STEP 4: VERIFY / HEALTH CHECK (run anytime) --" -ForegroundColor DarkCyan
Write-Host ""
Write-Host "  & '$sd\03_Verify_Environment.ps1'" -ForegroundColor Green
Write-Host ""

Write-Host "  -- OTHER COMMANDS --" -ForegroundColor DarkCyan
Write-Host ""
Write-Host "  # Reset all progress and start fresh:" -ForegroundColor DarkGray
Write-Host "  & '$sd\00_Master_Setup.ps1' -Force" -ForegroundColor Gray
Write-Host ""
Write-Host "  # Re-sync scripts from OneDrive (if you updated them there):" -ForegroundColor DarkGray
Write-Host "  & '$runningFrom\START_HERE.ps1'" -ForegroundColor Gray
Write-Host ""
Write-Host "  # Tear down Docker containers (keep data):" -ForegroundColor DarkGray
Write-Host "  & '$sd\04_Teardown.ps1' -Mode soft" -ForegroundColor Gray
Write-Host ""
Write-Host "  # View setup log:" -ForegroundColor DarkGray
Write-Host "  Get-Content `"$env:USERPROFILE\.booktable_setup.log`" -Tail 50" -ForegroundColor Gray
Write-Host ""

Write-Host "  +----------------------------------------------------------------+" -ForegroundColor Yellow
Write-Host "  |  [WARN]  If a REBOOT is required:                                  |" -ForegroundColor Yellow
Write-Host "  |                                                                |" -ForegroundColor Yellow
Write-Host "  |  Reboot, then re-run the APPLY command:                        |" -ForegroundColor Yellow
Write-Host "  |                                                                |" -ForegroundColor Yellow
Write-Host "  |  Set-ExecutionPolicy Bypass -Scope Process -Force              |" -ForegroundColor Green
Write-Host "  |  & 'C:\Setup\00_Master_Setup.ps1'                             |" -ForegroundColor Green
Write-Host "  |                                                                |" -ForegroundColor Yellow
Write-Host "  +----------------------------------------------------------------+" -ForegroundColor Yellow
Write-Host ""

Write-Host "  Files in $sd`:" -ForegroundColor DarkGray
Get-ChildItem -Path $sd -Filter "*.ps1" -ErrorAction SilentlyContinue | ForEach-Object {
    Write-Host "      * $($_.Name)" -ForegroundColor DarkGray
}
Write-Host ""
