<#
.SYNOPSIS
    Shared utilities for Anna's Booktable setup scripts.
    Dot-source this file: . .\Lib_Common.ps1
#>

# ============================================================
# Constants
# ============================================================
$script:ProgressFile  = Join-Path $env:USERPROFILE ".booktable_setup_progress"
$script:LogFile       = Join-Path $env:USERPROFILE ".booktable_setup.log"
$script:EnvFile       = Join-Path $env:USERPROFILE ".booktable.env"  # secrets go here, never in scripts
$script:ProjectRoot   = if ($ProjectRoot) { $ProjectRoot } else { "D:\Dev\AnnaBooktable" }

# ============================================================
# Logging  -  every action is logged to file + console
# ============================================================
function Write-Log {
    param(
        [string]$Message,
        [ValidateSet("INFO","WARN","ERROR","OK","SKIP","STEP","PROMPT")]
        [string]$Level = "INFO"
    )
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $line = "[$ts] [$Level] $Message"
    $line | Out-File -Append -FilePath $script:LogFile -Encoding utf8

    switch ($Level) {
        "STEP"   { Write-Host "`n>>> $Message" -ForegroundColor Cyan }
        "OK"     { Write-Host "  [OK] $Message" -ForegroundColor Green }
        "SKIP"   { Write-Host "  [SKIP]  $Message" -ForegroundColor DarkGray }
        "WARN"   { Write-Host "  [WARN]  $Message" -ForegroundColor Yellow }
        "ERROR"  { Write-Host "  [FAIL] $Message" -ForegroundColor Red }
        "PROMPT" { Write-Host "  [?] $Message" -ForegroundColor Magenta }
        default  { Write-Host "    $Message" -ForegroundColor Gray }
    }
}

# ============================================================
# Idempotent progress tracking  -  survives reboots
# ============================================================
function Get-CompletedSteps {
    if (Test-Path $script:ProgressFile) {
        return @(Get-Content $script:ProgressFile -ErrorAction SilentlyContinue | Where-Object { $_ -match '\S' })
    }
    return @()
}

function Set-StepComplete {
    param([string]$StepName)
    if (-not (Test-StepComplete $StepName)) {
        $StepName | Out-File -Append -FilePath $script:ProgressFile -Encoding utf8
        Write-Log "Progress saved: $StepName" "INFO"
    }
}

function Test-StepComplete {
    param([string]$StepName)
    return (Get-CompletedSteps) -contains $StepName
}

function Reset-AllProgress {
    if (Test-Path $script:ProgressFile) { Remove-Item $script:ProgressFile -Force }
    Write-Log "All progress reset." "WARN"
}

# ============================================================
# Fail-fast: abort on unexpected errors
# ============================================================
function Assert-Success {
    param([string]$Action, [int]$ExitCode = $LASTEXITCODE)
    if ($ExitCode -ne 0) {
        Write-Log "FAILED: $Action (exit code $ExitCode)" "ERROR"
        Write-Log "Check log: $($script:LogFile)" "ERROR"
        throw "Setup aborted: $Action failed."
    }
}

# ============================================================
# Command / binary detection
# ============================================================
function Test-CommandExists {
    param([string]$Command)
    $null -ne (Get-Command $Command -ErrorAction SilentlyContinue)
}

function Get-CommandVersion {
    param([string]$Command, [string]$Args = "--version")
    try {
        $out = & $Command $Args 2>&1 | Select-Object -First 1
        return $out.ToString().Trim()
    } catch {
        return $null
    }
}

# ============================================================
# Refresh PATH without restarting shell
# ============================================================
function Refresh-Path {
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" +
                [System.Environment]::GetEnvironmentVariable("Path","User")
}

# ============================================================
# Safe prompt  -  never modifies system without consent
# ============================================================
function Request-Consent {
    param([string]$Question, [bool]$DefaultYes = $true)
    $default = if ($DefaultYes) { "Y/n" } else { "y/N" }
    Write-Log $Question "PROMPT"
    $answer = Read-Host "  $Question ($default)"

    if ([string]::IsNullOrWhiteSpace($answer)) {
        return $DefaultYes
    }
    return $answer.Trim().ToLower() -eq "y"
}

# ============================================================
# WinGet install with version verification
# ============================================================
function Install-WithWinget {
    param(
        [string]$PackageId,
        [string]$DisplayName,
        [string]$VerifyCommand = "",
        [string]$VerifyArgs = "--version"
    )

    # 1. Check if already installed via version command
    if ($VerifyCommand -and (Test-CommandExists $VerifyCommand)) {
        $ver = Get-CommandVersion $VerifyCommand $VerifyArgs
        if ($ver) {
            Write-Log "$DisplayName already installed: $ver" "SKIP"
            return $true
        }
    }

    # 2. Install via winget
    Write-Log "Installing $DisplayName ($PackageId)..." "INFO"
    $output = winget install --id $PackageId `
        --accept-package-agreements --accept-source-agreements `
        --disable-interactivity --silent 2>&1 | Out-String

    Write-Log "winget output: $($output.Trim())" "INFO"

    # 3. Refresh PATH and verify
    Refresh-Path

    if ($VerifyCommand) {
        # Give installer a moment to finalize
        Start-Sleep -Seconds 2
        Refresh-Path

        $ver = Get-CommandVersion $VerifyCommand $VerifyArgs
        if ($ver) {
            Write-Log "$DisplayName installed and verified: $ver" "OK"
            return $true
        } else {
            # Winget may report success for already-installed packages
            if ($output -match "already installed" -or $output -match "No available upgrade") {
                Write-Log "$DisplayName reported as already installed by winget (CLI not in PATH yet  -  may need shell restart)" "WARN"
                return $true
            }
            Write-Log "$DisplayName installed but '$VerifyCommand $VerifyArgs' not found in PATH. May need shell restart." "WARN"
            return $false
        }
    }

    # No verify command  -  trust winget exit
    if ($output -match "Successfully installed" -or $output -match "already installed" -or $output -match "No available upgrade") {
        Write-Log "$DisplayName installed (no verify command)" "OK"
        return $true
    }

    Write-Log "$DisplayName installation uncertain  -  check manually" "WARN"
    return $false
}

# ============================================================
# Windows Feature toggle (idempotent)
# ============================================================
function Enable-WindowsFeatureSafe {
    param(
        [string]$FeatureName,
        [string]$DisplayName,
        [bool]$Required = $true
    )

    try {
        $state = (Get-WindowsOptionalFeature -Online -FeatureName $FeatureName -ErrorAction Stop).State
    } catch {
        if ($Required) {
            Write-Log "$DisplayName  -  feature not found on this OS edition" "ERROR"
            return @{ Changed = $false; Error = $true }
        }
        Write-Log "$DisplayName  -  not available on this edition (non-critical)" "WARN"
        return @{ Changed = $false; Error = $false }
    }

    if ($state -eq "Enabled") {
        Write-Log "$DisplayName already enabled" "SKIP"
        return @{ Changed = $false; Error = $false }
    }

    Write-Log "Enabling $DisplayName..." "INFO"
    try {
        $result = Enable-WindowsOptionalFeature -Online -FeatureName $FeatureName -NoRestart -All -WarningAction SilentlyContinue -ErrorAction Stop
        Write-Log "$DisplayName enabled (reboot may be needed)" "OK"
        return @{ Changed = $true; Error = $false; NeedsReboot = ($result.RestartNeeded -eq $true) }
    } catch {
        if ($Required) {
            Write-Log "$DisplayName  -  FAILED to enable: $_" "ERROR"
            return @{ Changed = $false; Error = $true }
        }
        Write-Log "$DisplayName  -  could not enable (non-critical): $_" "WARN"
        return @{ Changed = $false; Error = $false }
    }
}

# ============================================================
# Banner
# ============================================================
function Write-Banner {
    Write-Host ""
    Write-Host "+==============================================================+" -ForegroundColor Magenta
    Write-Host "|          Anna's Booktable  -  Dev Environment Setup           |" -ForegroundColor Magenta
    Write-Host "|          Windows 11 Enterprise * .NET 8 * React * Docker    |" -ForegroundColor Magenta
    Write-Host "+==============================================================+" -ForegroundColor Magenta
    Write-Host "  Log file: $($script:LogFile)" -ForegroundColor DarkGray
    Write-Host ""
}
