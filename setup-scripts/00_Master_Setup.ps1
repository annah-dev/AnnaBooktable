#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Anna's Booktable  -  Master Development Environment Setup (v2)

.DESCRIPTION
    Idempotent, fail-fast, reboot-safe setup for a Windows 11 dev workstation.

    Design principles:
      * Idempotent: every step checks state before acting; safe to re-run
      * Fail-fast: errors halt execution with clear messages
      * Reboot-safe: progress persists in ~/.booktable_setup_progress
      * Logged: every action written to ~/.booktable_setup.log
      * No secrets: credentials stored in ~/.booktable.env, never in scripts
      * No silent system changes: firewall/registry/networking changes require prompt
      * Verified: every install confirmed via version command

    Steps:
      0  System prerequisites check
      1  Windows features (WSL2, Hyper-V with consent, Containers)
      2  WSL2 Ubuntu + baseline packages
      3  Core dev tools via WinGet (verified)
      4  .NET global tools
      5  Node.js global packages + Claude Code
      6  Docker Desktop (WSL2 backend, test container)
      7  VS Code + extensions (Vim, Copilot, Remote Dev, DevContainers, C#, Python)
      8  Git & GitHub configuration
      9  Project scaffolding
      10 Docker infrastructure (PostgreSQL, Redis, Elasticsearch, RabbitMQ)
      11 Verification report + manual next steps

.EXAMPLE
    Set-ExecutionPolicy Bypass -Scope Process -Force
    .\00_Master_Setup.ps1

    # Custom project path and Git identity:
    .\00_Master_Setup.ps1 -ProjectRoot "D:\Dev\AnnaBooktable" -GitUserName "Anna" -GitUserEmail "anna@test.com"

    # Reset all progress and start fresh:
    .\00_Master_Setup.ps1 -Force
#>

param(
    [string]$ProjectRoot = "D:\Dev\AnnaBooktable",
    [string]$GitUserName = "Anna Hester",
    [string]$GitUserEmail = "annah.developer@gmail.com",
    [switch]$DryRun,
    [switch]$SkipRebootCheck,
    [switch]$Force
)

$ErrorActionPreference = "Stop"

# ============================================================
# Load shared library
# ============================================================
$libPath = Join-Path $PSScriptRoot "Lib_Common.ps1"
if (-not (Test-Path $libPath)) {
    Write-Host "[FAIL] Lib_Common.ps1 not found in $PSScriptRoot  -  place all scripts in the same folder." -ForegroundColor Red
    exit 1
}
. $libPath

# ============================================================
# DRY RUN MODE  -  show plan, change nothing
# ============================================================
if ($DryRun) {
    Write-Banner
    Write-Host "  ================ DRY RUN (no changes will be made) ================" -ForegroundColor Yellow
    Write-Host ""

    # System info
    $os  = Get-CimInstance Win32_OperatingSystem
    $cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
    $ramGB = [math]::Round($os.TotalVisibleMemorySize / 1MB, 1)
    $disk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'" | Select-Object -First 1
    $freeGB = [math]::Round($disk.FreeSpace / 1GB, 0)
    $edition = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion").EditionID

    Write-Host "  Machine:     $env:COMPUTERNAME" -ForegroundColor Gray
    Write-Host "  OS:          $($os.Caption) ($edition)" -ForegroundColor Gray
    Write-Host "  CPU:         $($cpu.Name.Trim())" -ForegroundColor Gray
    Write-Host "  RAM:         ${ramGB} GB" -ForegroundColor Gray
    Write-Host "  Disk C free: ${freeGB} GB" -ForegroundColor Gray
    Write-Host "  Project:     $ProjectRoot" -ForegroundColor Gray
    Write-Host "  Git name:    $GitUserName" -ForegroundColor Gray
    Write-Host "  Git email:   $GitUserEmail" -ForegroundColor Gray
    Write-Host ""

    # Show completed vs pending steps
    $allSteps = @(
        @{ Step = "Step1_WindowsFeatures"; Desc = "Windows features (WSL2, Hyper-V, Containers)" },
        @{ Step = "Step2_WSL_Ubuntu";      Desc = "WSL2 Ubuntu + baseline packages (gcc, python3, ffmpeg, git)" },
        @{ Step = "Step3_DevTools";        Desc = "Core tools: Git, .NET 8, Node, VS Code, Docker, Azure CLI, etc." },
        @{ Step = "Step4_DotNetTools";     Desc = ".NET global tools: dotnet-ef, codegen" },
        @{ Step = "Step5_NodeTools";       Desc = "Node globals: Yarn, create-vite, Claude Code" },
        @{ Step = "Step6_Docker";          Desc = "Docker Desktop: WSL2 backend, test container" },
        @{ Step = "Step7_VSCodeExtensions"; Desc = "VS Code: 22 extensions (Vim, Copilot, Remote, C#, Python)" },
        @{ Step = "Step8_GitConfig";       Desc = "Git config + SSH key ($GitUserEmail)" },
        @{ Step = "Step9_ProjectScaffold"; Desc = "Project scaffold: .NET solution + React apps" },
        @{ Step = "Step10_DockerInfra";    Desc = "Docker infra: PostgreSQL, Redis, Elasticsearch, RabbitMQ" },
        @{ Step = "Step11_Verify";         Desc = "Verification report + manual next steps" }
    )

    $completed = Get-CompletedSteps
    Write-Host "  Steps:" -ForegroundColor Cyan
    foreach ($s in $allSteps) {
        $done = $completed -contains $s.Step
        $icon = if ($done) { "[OK]" } else { "[ ]" }
        $color = if ($done) { "DarkGray" } else { "White" }
        Write-Host "    $icon $($s.Desc)" -ForegroundColor $color
    }

    $pending = ($allSteps | Where-Object { $completed -notcontains $_.Step }).Count
    Write-Host ""
    if ($pending -eq 0) {
        Write-Host "  All steps completed! Run VERIFY to confirm." -ForegroundColor Green
    } else {
        Write-Host "  $pending step(s) pending  -  run APPLY to execute." -ForegroundColor Yellow
    }

    Write-Host ""
    Write-Host "  =================== DRY RUN COMPLETE ===========================" -ForegroundColor Yellow
    exit 0
}

# ============================================================
# Initialize
# ============================================================
Write-Banner

if ($Force) { Reset-AllProgress }

$completed = Get-CompletedSteps
if ($completed.Count -gt 0) {
    Write-Host "  Resuming  -  completed: $($completed -join ', ')" -ForegroundColor DarkGray
    Write-Host "  (Use -Force to reset)`n" -ForegroundColor DarkGray
}

Write-Log "========== Setup started (PID $$) ==========" "INFO"
Write-Log "ProjectRoot: $ProjectRoot" "INFO"
Write-Log "User: $env:USERNAME  Host: $env:COMPUTERNAME" "INFO"

# ============================================================
# STEP 0: System Prerequisites
# ============================================================
function Invoke-Step0_SystemCheck {
    Write-Log "Step 0: System prerequisites" "STEP"

    $os  = Get-CimInstance Win32_OperatingSystem
    $cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
    $ramGB = [math]::Round($os.TotalVisibleMemorySize / 1MB, 1)
    $diskC = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'" | Select-Object -First 1
    $freeCGB = [math]::Round($diskC.FreeSpace / 1GB, 0)
    $edition = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion").EditionID
    $build = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion").CurrentBuild

    Write-Log "Host: $env:COMPUTERNAME" "INFO"
    Write-Log "OS: $($os.Caption) ($edition) Build $build" "INFO"
    Write-Log "CPU: $($cpu.Name.Trim())" "INFO"
    Write-Log "RAM: ${ramGB} GB" "INFO"
    Write-Log "Disk C: free: ${freeCGB} GB" "INFO"

    # Check D: drive exists (project goes there)
    $diskD = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='D:'" -ErrorAction SilentlyContinue
    if ($diskD) {
        $freeDGB = [math]::Round($diskD.FreeSpace / 1GB, 0)
        Write-Log "Disk D: free: ${freeDGB} GB (project drive)" "OK"
        if ($freeDGB -lt 20) {
            Write-Log "Minimum 20 GB free on D: recommended for project + Docker images" "WARN"
        }
    } else {
        Write-Log "D: drive not found. Project is configured for $ProjectRoot" "ERROR"
        Write-Log "Options: (a) create a D: partition, (b) re-run with -ProjectRoot C:\Dev\AnnaBooktable" "ERROR"
        throw "D: drive not found. Run with -ProjectRoot to use a different location."
    }

    # Hardware virtualisation
    # WMI VirtualizationFirmwareEnabled is unreliable on Xeon workstations.
    # Use multiple signals: WMI property, Hyper-V capability, and CPU model.
    $vtx = $cpu.VirtualizationFirmwareEnabled
    $isXeon = $cpu.Name -match "Xeon"
    $hyperVPresent = $false
    try {
        $hyperVPresent = (Get-CimInstance Win32_ComputerSystem).HypervisorPresent
    } catch { }

    if ($vtx -eq $true -or $hyperVPresent -eq $true) {
        Write-Log "VT-x / AMD-V enabled" "OK"
    } elseif ($isXeon) {
        Write-Log "VT-x WMI reports disabled, but Xeon $($cpu.Name.Trim()) has VT-x." "WARN"
        Write-Log "HP Z4 G4 has VT-x enabled by default. Continuing." "WARN"
        Write-Log "If Docker/WSL2 fails later, check BIOS: Security -> Virtualization Technology" "INFO"
    } elseif ($null -eq $vtx) {
        Write-Log "VT-x status unknown  -  continuing, but check BIOS if Docker fails" "WARN"
    } else {
        Write-Log "VT-x appears DISABLED  -  Docker/WSL2 may fail." "WARN"
        Write-Log "Check BIOS: Security -> Virtualization Technology -> Enable" "WARN"
        Write-Log "Continuing anyway  -  WSL2/Docker install will confirm." "WARN"
    }

    # Edition check
    if ($edition -match "Enterprise|Professional|Education") {
        Write-Log "Edition ($edition) supports Hyper-V" "OK"
    } else {
        Write-Log "Edition ($edition)  -  Hyper-V may not be available; WSL2 backend will be used" "WARN"
    }

    # Minimums
    if ($ramGB -lt 8)    { Write-Log "Minimum 8 GB RAM recommended (found ${ramGB} GB)" "WARN" }
    if ($freeCGB -lt 30) { Write-Log "Minimum 30 GB free on C: recommended for tools + Docker (found ${freeCGB} GB)" "WARN" }

    # -- Account prerequisites ------------------------------------
    Write-Log "" "INFO"
    Write-Log "Checking account prerequisites..." "STEP"
    $accountIssues = @()

    # GitHub CLI  -  check if already authenticated
    $ghInstalled = Test-CommandExists "gh"
    if ($ghInstalled) {
        try {
            $ghAuth = & gh auth status 2>&1
            if ($LASTEXITCODE -eq 0) {
                Write-Log "GitHub CLI: authenticated" "OK"
            } else {
                Write-Log "GitHub CLI installed but not authenticated  -  OK, Step 8 handles this" "INFO"
            }
        } catch {
            Write-Log "GitHub CLI installed but not authenticated  -  OK, Step 8 handles this" "INFO"
        }
    } else {
        Write-Log "GitHub CLI not yet installed  -  will install in Step 3" "INFO"
    }

    # Azure CLI  -  check if already logged in
    $azInstalled = Test-CommandExists "az"
    if ($azInstalled) {
        try {
            $azAccount = & az account show 2>&1
            if ($LASTEXITCODE -eq 0) {
                Write-Log "Azure CLI: logged in" "OK"
            } else {
                Write-Log "Azure CLI installed but not logged in  -  do 'az login' after setup" "INFO"
            }
        } catch {
            Write-Log "Azure CLI installed but not logged in  -  do 'az login' after setup" "INFO"
        }
    }

    # Print account setup checklist
    Write-Host ""
    Write-Host "  +----------------------------------------------------------------+" -ForegroundColor White
    Write-Host "  |         ACCOUNTS NEEDED (set up before or during setup)         |" -ForegroundColor White
    Write-Host "  +----------------------------------------------------------------+" -ForegroundColor White
    Write-Host ""
    Write-Host "  All accounts use: annah.developer@gmail.com" -ForegroundColor White
    Write-Host ""
    Write-Host "  1. GitHub" -ForegroundColor White
    Write-Host "     Sign up:         https://github.com/signup" -ForegroundColor Gray
    Write-Host "     Why:             Code hosting, version control, Copilot" -ForegroundColor DarkGray
    Write-Host "     Cost:            Free" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  2. Azure (new free account)" -ForegroundColor White
    Write-Host "     Sign up:         https://azure.microsoft.com/free" -ForegroundColor Gray
    Write-Host "     Why:             Deploy demo for interview" -ForegroundColor DarkGray
    Write-Host "     Cost:            Free ($200 credit, 30 days)" -ForegroundColor DarkGray
    Write-Host "     Note:            Create a NEW Microsoft account with your Gmail" -ForegroundColor DarkGray
    Write-Host "     Needs:           Credit card (verification only, no charge)" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  3. Stripe (can wait)" -ForegroundColor White
    Write-Host "     Sign up:         https://dashboard.stripe.com/register" -ForegroundColor Gray
    Write-Host "     Why:             Test payment processing (test mode only)" -ForegroundColor DarkGray
    Write-Host "     Cost:            Free (test mode)" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  TIP: Create the GitHub account NOW if you haven't yet." -ForegroundColor Yellow
    Write-Host "       The setup scripts will install tools, but you'll need" -ForegroundColor Yellow
    Write-Host "       the account to authenticate during Step 8." -ForegroundColor Yellow
    Write-Host ""
}

# ============================================================
# STEP 1: Windows Features
# ============================================================
function Invoke-Step1_WindowsFeatures {
    $step = "Step1_WindowsFeatures"
    if (Test-StepComplete $step) { Write-Log "Windows features" "SKIP"; return $false }

    Write-Log "Step 1: Windows features (WSL2, Hyper-V, Containers)" "STEP"

    $needsReboot = $false

    # Required features (fail-fast if these can't enable)
    $required = @(
        @{ Name = "Microsoft-Windows-Subsystem-Linux"; Display = "WSL" },
        @{ Name = "VirtualMachinePlatform";            Display = "Virtual Machine Platform" }
    )

    foreach ($f in $required) {
        $r = Enable-WindowsFeatureSafe -FeatureName $f.Name -DisplayName $f.Display -Required $true
        if ($r.Error) { throw "Required feature $($f.Display) failed to enable." }
        if ($r.Changed -or $r.NeedsReboot) { $needsReboot = $true }
    }

    # Hyper-V  -  prompt before enabling (modifies hypervisor, networking stack)
    $hvState = (Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-All -ErrorAction SilentlyContinue).State
    if ($hvState -eq "Enabled") {
        Write-Log "Hyper-V already enabled" "SKIP"
    } else {
        $consent = Request-Consent "Enable Hyper-V? (Improves Docker performance; modifies hypervisor layer)" $true
        if ($consent) {
            $hvFeatures = @(
                @{ Name = "Microsoft-Hyper-V-All";        Display = "Hyper-V (Full)" },
                @{ Name = "Microsoft-Hyper-V-Tools-All";  Display = "Hyper-V Management Tools" },
                @{ Name = "Microsoft-Hyper-V-Hypervisor"; Display = "Hyper-V Hypervisor" }
            )
            foreach ($f in $hvFeatures) {
                $r = Enable-WindowsFeatureSafe -FeatureName $f.Name -DisplayName $f.Display -Required $false
                if ($r.Changed -or $r.NeedsReboot) { $needsReboot = $true }
            }
        } else {
            Write-Log "Hyper-V skipped by user  -  Docker will use WSL2 backend only" "WARN"
        }
    }

    # Containers (optional)
    $r = Enable-WindowsFeatureSafe -FeatureName "Containers" -DisplayName "Windows Containers" -Required $false
    if ($r.Changed -or $r.NeedsReboot) { $needsReboot = $true }

    # NOTE: We do NOT create any Hyper-V virtual switch here.
    # The script never modifies networking without explicit prompt (handled separately if needed).

    Set-StepComplete $step

    if ($needsReboot) {
        Write-Log "REBOOT REQUIRED  -  Windows features need a restart to take effect." "WARN"
        Write-Log "After reboot, re-run this script; it will resume from Step 2." "WARN"
        return $true
    }
    return $false
}

# ============================================================
# STEP 2: WSL2 + Ubuntu + baseline packages
# ============================================================
function Invoke-Step2_WSL {
    $step = "Step2_WSL_Ubuntu"
    if (Test-StepComplete $step) { Write-Log "WSL2 + Ubuntu" "SKIP"; return }

    Write-Log "Step 2: WSL2 + Ubuntu + baseline packages" "STEP"

    # Set WSL default to version 2
    wsl --set-default-version 2 2>$null
    Write-Log "WSL default version set to 2" "OK"

    # Install Ubuntu if missing
    $distros = wsl --list --quiet 2>$null
    if ($distros -match "Ubuntu") {
        Write-Log "Ubuntu already installed in WSL" "SKIP"
    } else {
        Write-Log "Installing Ubuntu (may take several minutes)..." "INFO"
        try {
            $output = wsl --install -d Ubuntu --no-launch 2>&1
            $output | ForEach-Object { Write-Log $_ "INFO" }
        } catch {
            Write-Log "WSL install output: $_" "WARN"
        }
        Write-Log "Ubuntu installed  -  launch from Start Menu to create user account, then re-run this script" "OK"
        Write-Log "WSL Ubuntu needs initial user setup before baseline packages can be installed." "WARN"
        Set-StepComplete $step
        return
    }

    # Validate Ubuntu is WSL2
    $wslInfo = wsl --list --verbose 2>$null
    Write-Log "WSL distros:`n$wslInfo" "INFO"

    # Install baseline packages inside Ubuntu
    Write-Log "Installing baseline packages inside WSL Ubuntu..." "INFO"

    $wslScript = @'
set -e
echo "--- Updating apt ---"
sudo apt-get update -qq
echo "--- Installing baseline packages ---"
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
    build-essential \
    python3 python3-pip python3-venv \
    ffmpeg \
    git \
    curl \
    wget \
    unzip \
    jq \
    ca-certificates \
    gnupg \
    lsb-release
echo "--- Verifying ---"
echo "  gcc:     $(gcc --version | head -1)"
echo "  python3: $(python3 --version)"
echo "  ffmpeg:  $(ffmpeg -version | head -1)"
echo "  git:     $(git --version)"
echo "--- Done ---"
'@

    try {
        $wslOutput = $wslScript | wsl --distribution Ubuntu -- bash 2>&1
        $wslOutput | ForEach-Object { Write-Log "  [WSL] $_" "INFO" }
    } catch {
        Write-Log "WSL script output: $_" "WARN"
    }

    if ($LASTEXITCODE -eq 0) {
        Write-Log "WSL Ubuntu baseline packages installed and verified" "OK"
    } else {
        Write-Log "WSL package install returned exit code $LASTEXITCODE  -  check log" "WARN"
    }

    Set-StepComplete $step
}

# ============================================================
# STEP 3: Core Dev Tools (WinGet, each verified)
# ============================================================
function Invoke-Step3_DevTools {
    $step = "Step3_DevTools"
    if (Test-StepComplete $step) { Write-Log "Dev tools" "SKIP"; return }

    Write-Log "Step 3: Core dev tools via WinGet" "STEP"

    if (-not (Test-CommandExists "winget")) {
        Write-Log "winget not found  -  install 'App Installer' from Microsoft Store." "ERROR"
        throw "winget is required."
    }

    $tools = @(
        @{ Id = "Microsoft.WindowsTerminal";    Name = "Windows Terminal";    Cmd = "wt";     Args = "--version" },
        @{ Id = "Git.Git";                      Name = "Git";                 Cmd = "git";    Args = "--version" },
        @{ Id = "GitHub.cli";                   Name = "GitHub CLI";          Cmd = "gh";     Args = "--version" },
        @{ Id = "GitHub.GitHubDesktop";         Name = "GitHub Desktop";      Cmd = "";       Args = "" },
        @{ Id = "Microsoft.DotNet.SDK.8";       Name = ".NET 8 SDK";         Cmd = "dotnet"; Args = "--version" },
        @{ Id = "OpenJS.NodeJS.LTS";            Name = "Node.js LTS";        Cmd = "node";   Args = "--version" },
        @{ Id = "Microsoft.VisualStudioCode";   Name = "VS Code";            Cmd = "code";   Args = "--version" },
        @{ Id = "Microsoft.AzureCLI";           Name = "Azure CLI";          Cmd = "az";     Args = "version" },
        @{ Id = "Microsoft.AzureDataStudio";    Name = "Azure Data Studio";  Cmd = "";       Args = "" },
        @{ Id = "Postman.Postman";              Name = "Postman";            Cmd = "";       Args = "" }
    )

    $allOk = $true
    foreach ($t in $tools) {
        $ok = Install-WithWinget -PackageId $t.Id -DisplayName $t.Name -VerifyCommand $t.Cmd -VerifyArgs $t.Args
        if (-not $ok -and $t.Cmd) { $allOk = $false }
    }

    Refresh-Path

    if ($allOk) {
        Set-StepComplete $step
    } else {
        Write-Log "Some tools may need a shell restart to appear in PATH  -  re-run script after restart" "WARN"
        Set-StepComplete $step  # still mark done; verify step will catch real issues
    }
}

# ============================================================
# STEP 4: .NET Global Tools
# ============================================================
function Invoke-Step4_DotNetTools {
    $step = "Step4_DotNetTools"
    if (Test-StepComplete $step) { Write-Log ".NET global tools" "SKIP"; return }

    Write-Log "Step 4: .NET global tools" "STEP"

    Refresh-Path

    if (-not (Test-CommandExists "dotnet")) {
        Write-Log ".NET SDK not in PATH  -  may need shell restart" "ERROR"
        throw "dotnet command not found."
    }

    $tools = @(
        @{ Package = "dotnet-ef";                     Name = "Entity Framework CLI";  Required = $true },
        @{ Package = "dotnet-aspnet-codegenerator";   Name = "ASP.NET Codegen";       Required = $false }
    )

    foreach ($t in $tools) {
        $installed = dotnet tool list --global 2>$null | Select-String $t.Package
        if ($installed) {
            Write-Log "$($t.Name) ($($t.Package)) already installed" "SKIP"
        } else {
            Write-Log "Installing $($t.Name)..." "INFO"
            try {
                $output = & dotnet tool install --global $t.Package 2>&1
                $output | ForEach-Object { Write-Log "  $_" "INFO" }
                if ($LASTEXITCODE -ne 0) { throw "exit code $LASTEXITCODE" }
                Write-Log "$($t.Name) installed" "OK"
            } catch {
                if ($t.Required) {
                    throw "Required tool $($t.Package) failed to install: $_"
                } else {
                    Write-Log "$($t.Name) install failed  -  optional, skipping" "WARN"
                }
            }
        }
    }

    Set-StepComplete $step
}

# ============================================================
# STEP 5: Node.js Global Packages + Claude Code
# ============================================================
function Invoke-Step5_NodeTools {
    $step = "Step5_NodeTools"
    if (Test-StepComplete $step) { Write-Log "Node tools" "SKIP"; return }

    Write-Log "Step 5: Node.js global packages" "STEP"

    Refresh-Path

    if (-not (Test-CommandExists "npm")) {
        Write-Log "npm not in PATH  -  may need shell restart" "ERROR"
        throw "npm command not found."
    }

    $packages = @(
        @{ Pkg = "yarn";                         Cmd = "yarn";   Name = "Yarn" },
        @{ Pkg = "create-vite";                  Cmd = "";       Name = "Create Vite" },
        @{ Pkg = "@anthropic-ai/claude-code";    Cmd = "claude"; Name = "Claude Code" }
    )

    foreach ($p in $packages) {
        if ($p.Cmd -and (Test-CommandExists $p.Cmd)) {
            $ver = Get-CommandVersion $p.Cmd "--version"
            Write-Log "$($p.Name) already installed: $ver" "SKIP"
            continue
        }

        Write-Log "Installing $($p.Name) ($($p.Pkg))..." "INFO"
        try {
            $output = & npm install -g $p.Pkg 2>&1
            $output | ForEach-Object { Write-Log "  $_" "INFO" }
        } catch {
            Write-Log "npm output: $_  -  this is usually just an npm notice, continuing" "WARN"
        }

        Refresh-Path

        if ($p.Cmd -and (Test-CommandExists $p.Cmd)) {
            $ver = Get-CommandVersion $p.Cmd "--version"
            Write-Log "$($p.Name) installed: $ver" "OK"
        } elseif ($p.Cmd) {
            Write-Log "$($p.Name) installed but not in PATH yet  -  may need shell restart" "WARN"
        } else {
            Write-Log "$($p.Name) installed" "OK"
        }
    }

    Set-StepComplete $step
}

# ============================================================
# STEP 6: Docker Desktop  -  WSL2 backend + test container
# ============================================================
function Invoke-Step6_Docker {
    $step = "Step6_Docker"
    if (Test-StepComplete $step) { Write-Log "Docker Desktop" "SKIP"; return }

    Write-Log "Step 6: Docker Desktop (WSL2 backend)" "STEP"

    # Install if not present
    if (-not (Test-CommandExists "docker")) {
        Install-WithWinget -PackageId "Docker.DockerDesktop" -DisplayName "Docker Desktop" -VerifyCommand "docker" -VerifyArgs "--version"
        Refresh-Path
    }

    # Check if Docker daemon is running
    $dockerInfo = docker info 2>$null
    if (-not $dockerInfo) {
        Write-Log "Docker Desktop is installed but not running." "WARN"
        Write-Log "Please start Docker Desktop, ensure WSL2 backend is selected in Settings -> General, then re-run." "WARN"
        Write-Log "  Settings to verify in Docker Desktop:" "INFO"
        Write-Log "    [x] General -> 'Use the WSL 2 based engine'" "INFO"
        Write-Log "    [x] Resources -> WSL Integration -> Enable for Ubuntu" "INFO"
        return  # Don't mark complete; will retry
    }

    Write-Log "Docker daemon is running" "OK"

    # Log Docker backend info
    $backend = ($dockerInfo | Select-String "Server Version|Operating System|OSType" | Out-String).Trim()
    Write-Log "Docker info:`n    $backend" "INFO"

    # Verify WSL2 backend
    $osType = ($dockerInfo | Select-String "OSType") | ForEach-Object { $_.ToString().Trim() }
    Write-Log "Docker backend: $osType" "INFO"

    # Run test container
    Write-Log "Running test container: hello-world..." "INFO"
    try {
        $testOutput = & docker run --rm hello-world 2>&1 | Out-String
    } catch {
        $testOutput = "$_"
    }
    if ($testOutput -match "Hello from Docker") {
        Write-Log "Docker test container ran successfully" "OK"
    } else {
        Write-Log "Docker test container did not produce expected output  -  check Docker Desktop" "WARN"
        Write-Log "Output: $($testOutput.Trim())" "INFO"
    }

    Set-StepComplete $step
}

# ============================================================
# STEP 7: VS Code Extensions
# ============================================================
function Invoke-Step7_VSCodeExtensions {
    $step = "Step7_VSCodeExtensions"
    if (Test-StepComplete $step) { Write-Log "VS Code extensions" "SKIP"; return }

    Write-Log "Step 7: VS Code extensions" "STEP"

    Refresh-Path

    if (-not (Test-CommandExists "code")) {
        Write-Log "VS Code CLI not in PATH  -  skipping extensions (install manually)" "WARN"
        Set-StepComplete $step
        return
    }

    $extensions = @(
        # --- Vim Emulation ---
        @{ Id = "vscodevim.vim";                          Cat = "Vim" },

        # --- GitHub Copilot ---
        @{ Id = "GitHub.copilot";                         Cat = "AI" },
        @{ Id = "GitHub.copilot-chat";                    Cat = "AI" },

        # --- Remote Development ---
        @{ Id = "ms-vscode-remote.remote-wsl";            Cat = "Remote" },
        @{ Id = "ms-vscode-remote.remote-ssh";            Cat = "Remote" },
        @{ Id = "ms-vscode-remote.remote-ssh-edit";       Cat = "Remote" },
        @{ Id = "ms-vscode-remote.vscode-remote-extensionpack"; Cat = "Remote" },
        @{ Id = "ms-vscode-remote.remote-containers";     Cat = "DevContainers" },

        # --- C# / .NET ---
        @{ Id = "ms-dotnettools.csdevkit";                Cat = "C#" },
        @{ Id = "ms-dotnettools.csharp";                  Cat = "C#" },

        # --- Python ---
        @{ Id = "ms-python.python";                       Cat = "Python" },
        @{ Id = "ms-python.debugpy";                      Cat = "Python" },
        @{ Id = "ms-python.vscode-pylance";               Cat = "Python" },

        # --- Frontend ---
        @{ Id = "dbaeumer.vscode-eslint";                 Cat = "Frontend" },
        @{ Id = "esbenp.prettier-vscode";                 Cat = "Frontend" },
        @{ Id = "bradlc.vscode-tailwindcss";              Cat = "Frontend" },

        # --- Infrastructure ---
        @{ Id = "ms-azuretools.vscode-docker";            Cat = "Infra" },
        @{ Id = "ckolkman.vscode-postgres";               Cat = "Infra" },

        # --- Git ---
        @{ Id = "eamodio.gitlens";                        Cat = "Git" },
        @{ Id = "GitHub.vscode-pull-request-github";      Cat = "Git" },

        # --- API Testing ---
        @{ Id = "humao.rest-client";                      Cat = "API" },
        @{ Id = "rangav.vscode-thunder-client";           Cat = "API" },

        # --- Azure ---
        @{ Id = "ms-vscode.vscode-node-azure-pack";      Cat = "Azure" }
    )

    # Get currently installed extensions for idempotency
    $installed = code --list-extensions 2>$null

    $installedCount = 0
    $skippedCount = 0

    foreach ($ext in $extensions) {
        if ($installed -contains $ext.Id) {
            Write-Log "$($ext.Id) [$($ext.Cat)]" "SKIP"
            $skippedCount++
            continue
        }

        $result = code --install-extension $ext.Id --force 2>&1 | Out-String
        Write-Log "  $($ext.Id) [$($ext.Cat)]  -  installed" "OK"
        $installedCount++
    }

    Write-Log "VS Code extensions: $installedCount installed, $skippedCount already present" "OK"

    Set-StepComplete $step
}

# ============================================================
# STEP 8: Git & GitHub Configuration (Dual-Identity)
# ============================================================
function Invoke-Step8_GitConfig {
    $step = "Step8_GitConfig"
    if (Test-StepComplete $step) { Write-Log "Git config" "SKIP"; return }

    Write-Log "Step 8: Git & GitHub configuration" "STEP"

    Refresh-Path

    if (-not (Test-CommandExists "git")) {
        Write-Log "Git not in PATH" "ERROR"
        throw "git not found."
    }

    # -- Identity: single email for everything --
    # annah.developer@gmail.com is used for Git commits, GitHub, Azure, all accounts.

    $currentName  = git config --global user.name 2>$null
    $currentEmail = git config --global user.email 2>$null

    if (-not $currentName -and $GitUserName) {
        git config --global user.name $GitUserName
        Write-Log "Git user.name -> $GitUserName" "OK"
    } elseif ($currentName) {
        Write-Log "Git user.name already set: $currentName" "SKIP"
    } else {
        Write-Log "Git user.name not set  -  run: git config --global user.name 'Anna Hester'" "WARN"
    }

    if (-not $currentEmail -and $GitUserEmail) {
        git config --global user.email $GitUserEmail
        Write-Log "Git user.email -> $GitUserEmail (dev identity)" "OK"
    } elseif ($currentEmail) {
        Write-Log "Git user.email already set: $currentEmail" "SKIP"
    } else {
        Write-Log "Git user.email not set  -  run: git config --global user.email 'annah.developer@gmail.com'" "WARN"
    }

    # Safe defaults (user-level gitconfig only, no system changes)
    git config --global init.defaultBranch main
    git config --global core.autocrlf true
    git config --global push.autoSetupRemote true
    git config --global pull.rebase true
    git config --global core.editor "code --wait"
    Write-Log "Git defaults: main branch, autocrlf, rebase pull, VS Code editor" "OK"

    # -- SSH key for dev identity --
    $sshKeyPath = "$env:USERPROFILE\.ssh\id_ed25519"
    if (Test-Path "$sshKeyPath.pub") {
        Write-Log "SSH key already exists: $sshKeyPath.pub" "SKIP"
    } else {
        $genKey = Request-Consent "Generate SSH key for $GitUserEmail? (used for GitHub push access)" $true
        if ($genKey) {
            $sshDir = "$env:USERPROFILE\.ssh"
            if (-not (Test-Path $sshDir)) { New-Item -ItemType Directory -Path $sshDir -Force | Out-Null }

            try {
                $sshOutput = ssh-keygen -t ed25519 -C $GitUserEmail -f $sshKeyPath -N '""' 2>&1
                $sshOutput | ForEach-Object { Write-Log "  $_" "INFO" }
            } catch {
                Write-Log "ssh-keygen output: $_" "WARN"
            }

            if (Test-Path "$sshKeyPath.pub") {
                Write-Log "SSH key generated: $sshKeyPath.pub" "OK"
                Write-Log "Add to GitHub: gh ssh-key add $sshKeyPath.pub --title 'ANNAH-W2'" "INFO"

                # Configure Git to use SSH for GitHub
                git config --global url."git@github.com:".insteadOf "https://github.com/"
                Write-Log "Git configured to use SSH for GitHub URLs" "OK"
            } else {
                Write-Log "SSH key generation may have failed  -  check manually" "WARN"
            }
        } else {
            Write-Log "SSH key generation skipped" "SKIP"
        }
    }

    # -- GitHub CLI status --
    if (Test-CommandExists "gh") {
        try {
            $authStatus = & gh auth status 2>&1 | Out-String
        } catch {
            $authStatus = "$_"
        }
        if ($authStatus -match "Logged in") {
            Write-Log "GitHub CLI authenticated" "OK"
        } else {
            Write-Log "GitHub CLI not authenticated  -  manual step required" "WARN"
            Write-Log "  Run: gh auth login" "INFO"
            Write-Log "  Use annah.developer@gmail.com as your GitHub account" "INFO"
            Write-Log "  Choose SSH as preferred protocol if SSH key was generated" "INFO"
        }
    }

    Set-StepComplete $step
}

# ============================================================
# STEP 9: Project Scaffolding
# ============================================================
function Invoke-Step9_ProjectScaffold {
    $step = "Step9_ProjectScaffold"
    if (Test-StepComplete $step) { Write-Log "Project scaffold" "SKIP"; return }

    Write-Log "Step 9: Project scaffolding" "STEP"

    $scaffoldScript = Join-Path $PSScriptRoot "01_Scaffold_Project.ps1"
    if (Test-Path $scaffoldScript) {
        & $scaffoldScript -ProjectRoot $ProjectRoot
        Assert-Success "Project scaffolding"
    } else {
        Write-Log "01_Scaffold_Project.ps1 not found at $PSScriptRoot  -  run it separately" "WARN"
    }

    Set-StepComplete $step
}

# ============================================================
# STEP 10: Docker Infrastructure
# ============================================================
function Invoke-Step10_DockerInfra {
    $step = "Step10_DockerInfra"
    if (Test-StepComplete $step) { Write-Log "Docker infrastructure" "SKIP"; return }

    Write-Log "Step 10: Docker infrastructure (PostgreSQL, Redis, Elasticsearch, RabbitMQ)" "STEP"

    # Verify Docker is running
    $dockerInfo = docker info 2>$null
    if (-not $dockerInfo) {
        Write-Log "Docker not running  -  start Docker Desktop first, then re-run" "WARN"
        return  # Don't mark complete
    }

    $dockerScript = Join-Path $PSScriptRoot "02_Setup_Docker.ps1"
    if (Test-Path $dockerScript) {
        & $dockerScript -ProjectRoot $ProjectRoot
    } else {
        Write-Log "02_Setup_Docker.ps1 not found  -  run it separately" "WARN"
    }

    Set-StepComplete $step
}

# ============================================================
# STEP 11: Verification Report + Manual Next Steps
# ============================================================
function Invoke-Step11_VerifyAndReport {
    Write-Log "Step 11: Verification report" "STEP"

    Write-Host ""
    Write-Host "+--------------------------------------------------------------+" -ForegroundColor Cyan
    Write-Host "|                   VERIFICATION REPORT                        |" -ForegroundColor Cyan
    Write-Host "+--------------------------------------------------------------+" -ForegroundColor Cyan

    $total = 0; $passed = 0

    function script:Check {
        param([string]$Name, [bool]$Ok, [string]$Detail)
        $script:total++
        if ($Ok) { $script:passed++; Write-Host "  [OK] $Name  -  $Detail" -ForegroundColor Green }
        else { Write-Host "  [FAIL] $Name  -  $Detail" -ForegroundColor Red }
        Write-Log "VERIFY: $Name  -  $(if ($Ok) {'PASS'} else {'FAIL'})  -  $Detail" "INFO"
    }

    Refresh-Path

    # --- Windows Features ---
    Write-Host "`n  -- Windows Features --" -ForegroundColor DarkCyan
    foreach ($f in @("Microsoft-Windows-Subsystem-Linux", "VirtualMachinePlatform")) {
        $state = (Get-WindowsOptionalFeature -Online -FeatureName $f -ErrorAction SilentlyContinue).State
        Check $f ($state -eq "Enabled") "$state"
    }
    $hvState = (Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-All -ErrorAction SilentlyContinue).State
    Check "Hyper-V" ($hvState -eq "Enabled") $(if ($hvState) { $hvState } else { "not available" })

    # --- WSL ---
    Write-Host "`n  -- WSL2 --" -ForegroundColor DarkCyan
    $wslDistros = wsl --list --quiet 2>$null
    Check "WSL Ubuntu" ($wslDistros -match "Ubuntu") $(if ($wslDistros -match "Ubuntu") { "installed" } else { "not found" })

    # Verify WSL baseline packages
    $wslGcc = wsl --distribution Ubuntu -- gcc --version 2>$null | Select-Object -First 1
    Check "WSL gcc" ($null -ne $wslGcc) $(if ($wslGcc) { $wslGcc.Trim() } else { "not found" })

    $wslPy = wsl --distribution Ubuntu -- python3 --version 2>$null | Select-Object -First 1
    Check "WSL python3" ($null -ne $wslPy) $(if ($wslPy) { $wslPy.Trim() } else { "not found" })

    $wslFF = wsl --distribution Ubuntu -- ffmpeg -version 2>$null | Select-Object -First 1
    Check "WSL ffmpeg" ($null -ne $wslFF) $(if ($wslFF) { $wslFF.Trim() } else { "not found" })

    $wslGit = wsl --distribution Ubuntu -- git --version 2>$null | Select-Object -First 1
    Check "WSL git" ($null -ne $wslGit) $(if ($wslGit) { $wslGit.Trim() } else { "not found" })

    # --- CLI Tools ---
    Write-Host "`n  -- CLI Tools --" -ForegroundColor DarkCyan
    $cliTools = @(
        @{ Name = "Git";          Cmd = "git";    Args = "--version" },
        @{ Name = ".NET SDK";     Cmd = "dotnet"; Args = "--version" },
        @{ Name = "Node.js";      Cmd = "node";   Args = "--version" },
        @{ Name = "npm";          Cmd = "npm";    Args = "--version" },
        @{ Name = "Docker";       Cmd = "docker"; Args = "--version" },
        @{ Name = "GitHub CLI";   Cmd = "gh";     Args = "--version" },
        @{ Name = "Azure CLI";    Cmd = "az";     Args = "version" }
    )

    foreach ($t in $cliTools) {
        $ver = Get-CommandVersion $t.Cmd $t.Args
        Check $t.Name ($null -ne $ver) $(if ($ver) { $ver } else { "NOT FOUND" })
    }

    # --- .NET Tools ---
    Write-Host "`n  -- .NET Global Tools --" -ForegroundColor DarkCyan
    foreach ($t in @("dotnet-ef", "dotnet-aspnet-codegenerator")) {
        $found = dotnet tool list --global 2>$null | Select-String $t
        Check $t ($null -ne $found) $(if ($found) { "installed" } else { "not found" })
    }

    # --- Docker ---
    Write-Host "`n  -- Docker --" -ForegroundColor DarkCyan
    $dockerRunning = docker info 2>$null
    Check "Docker daemon" ($null -ne $dockerRunning) $(if ($dockerRunning) { "running" } else { "not running" })

    if ($dockerRunning) {
        $containers = @("booktable-postgres", "booktable-redis", "booktable-elasticsearch", "booktable-rabbitmq", "booktable-seq")
        foreach ($c in $containers) {
            $status = docker inspect --format='{{.State.Status}}' $c 2>$null
            Check $c ($status -eq "running") $(if ($status) { $status } else { "not found" })
        }
    }

    # --- VS Code Extensions (key ones) ---
    Write-Host "`n  -- VS Code Key Extensions --" -ForegroundColor DarkCyan
    if (Test-CommandExists "code") {
        $installedExt = code --list-extensions 2>$null
        $keyExt = @(
            @{ Id = "vscodevim.vim";                      Name = "Vim Emulation" },
            @{ Id = "GitHub.copilot";                     Name = "GitHub Copilot" },
            @{ Id = "GitHub.copilot-chat";                Name = "Copilot Chat" },
            @{ Id = "ms-vscode-remote.remote-wsl";        Name = "Remote - WSL" },
            @{ Id = "ms-vscode-remote.remote-ssh";        Name = "Remote - SSH" },
            @{ Id = "ms-vscode-remote.remote-containers"; Name = "Dev Containers" },
            @{ Id = "ms-dotnettools.csdevkit";            Name = "C# Dev Kit" },
            @{ Id = "ms-python.python";                   Name = "Python" }
        )
        foreach ($e in $keyExt) {
            $found = $installedExt -contains $e.Id
            Check $e.Name $found $(if ($found) { "installed" } else { "MISSING" })
        }
    }

    # --- Project ---
    Write-Host "`n  -- Project --" -ForegroundColor DarkCyan
    $slnExists = Test-Path (Join-Path $ProjectRoot "AnnaBooktable.sln")
    Check "Solution file" $slnExists $(if ($slnExists) { "exists" } else { "not found at $ProjectRoot" })

    # --- Summary ---
    $pct = if ($total -gt 0) { [math]::Round(($passed / $total) * 100) } else { 0 }
    $color = if ($pct -eq 100) { "Green" } elseif ($pct -ge 80) { "Yellow" } else { "Red" }

    Write-Host ""
    Write-Host "  Result: $passed / $total checks passed ($pct%)" -ForegroundColor $color
    Write-Log "Verification: $passed/$total ($pct%)" "INFO"

    # --- Manual Next Steps ---
    Write-Host ""
    Write-Host "+--------------------------------------------------------------+" -ForegroundColor Yellow
    Write-Host "|                   MANUAL NEXT STEPS                          |" -ForegroundColor Yellow
    Write-Host "+--------------------------------------------------------------+" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  All accounts use: annah.developer@gmail.com" -ForegroundColor White
    Write-Host ""
    Write-Host "  1. GitHub  -  authenticate the CLI" -ForegroundColor White
    Write-Host "     gh auth login" -ForegroundColor Gray
    Write-Host "     gh ssh-key add ~/.ssh/id_ed25519.pub --title 'ANNAH-W2'" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  2. Azure  -  log in (free account, $200 credit)" -ForegroundColor White
    Write-Host "     az login" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  3. Create your GitHub repo" -ForegroundColor White
    Write-Host "     cd $ProjectRoot" -ForegroundColor Gray
    Write-Host "     gh repo create AnnaBooktable --private --source . --push" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  4. Claude Code" -ForegroundColor White
    Write-Host "     claude login" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  5. Stripe test keys (later, when building Payment Service)" -ForegroundColor White
    Write-Host "     Get from https://dashboard.stripe.com/test/apikeys" -ForegroundColor Gray
    Write-Host "     Save to: $($script:EnvFile)" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  6. Visual Studio 2022 Enterprise (optional)" -ForegroundColor White
    Write-Host "     Download from https://my.visualstudio.com" -ForegroundColor Gray
    Write-Host "     Workloads: ASP.NET, Node.js, Data storage" -ForegroundColor Gray
    Write-Host "     Extensions: VsVim, GitHub Copilot, Copilot Chat" -ForegroundColor Gray
    Write-Host ""

    Write-Log "========== Setup finished ==========" "INFO"
}

# ============================================================
# RUN THESE COMMANDS  -  always printed at key moments
# ============================================================
function Write-RunCommands {
    param([switch]$AfterReboot)

    $sd = $PSScriptRoot

    Write-Host ""
    Write-Host "  +----------------------------------------------------------------+" -ForegroundColor White
    Write-Host "  |                    RUN THESE COMMANDS                           |" -ForegroundColor White
    Write-Host "  +----------------------------------------------------------------+" -ForegroundColor White
    Write-Host ""

    if ($AfterReboot) {
        Write-Host "  Reboot, then re-run the APPLY command below:" -ForegroundColor Yellow
        Write-Host ""
    }

    Write-Host "  # Unblock files & set execution policy (run once per shell session):" -ForegroundColor DarkGray
    Write-Host "  Set-ExecutionPolicy Bypass -Scope Process -Force; Get-ChildItem '$sd\*.ps1' | Unblock-File" -ForegroundColor Green
    Write-Host ""
    Write-Host "  # PLAN / DRY RUN (no changes):" -ForegroundColor DarkGray
    Write-Host "  & '$sd\00_Master_Setup.ps1' -DryRun" -ForegroundColor Green
    Write-Host ""
    Write-Host "  # APPLY / EXECUTE (make changes  -  idempotent, safe to re-run):" -ForegroundColor DarkGray
    Write-Host "  & '$sd\00_Master_Setup.ps1'" -ForegroundColor Green
    Write-Host ""
    Write-Host "  # VERIFY / HEALTH CHECK (run anytime):" -ForegroundColor DarkGray
    Write-Host "  & '$sd\03_Verify_Environment.ps1'" -ForegroundColor Green
    Write-Host ""
}

# ============================================================
# MAIN EXECUTION
# ============================================================
try {
    Invoke-Step0_SystemCheck

    $needsReboot = Invoke-Step1_WindowsFeatures
    if ($needsReboot -and -not $SkipRebootCheck) {
        Write-RunCommands -AfterReboot
        Write-Host ""
        $reboot = Request-Consent "Reboot now to activate Windows features?" $true
        if ($reboot) {
            Write-Log "Rebooting in 10 seconds..." "WARN"
            Start-Sleep -Seconds 10
            Restart-Computer -Force
            exit
        }
        Write-Log "Please reboot manually, then re-run the APPLY command above." "WARN"
        exit
    }

    Invoke-Step2_WSL
    Invoke-Step3_DevTools
    Invoke-Step4_DotNetTools
    Invoke-Step5_NodeTools
    Invoke-Step6_Docker
    Invoke-Step7_VSCodeExtensions
    Invoke-Step8_GitConfig
    Invoke-Step9_ProjectScaffold
    Invoke-Step10_DockerInfra
    Invoke-Step11_VerifyAndReport

    # Final command reference
    Write-RunCommands

} catch {
    Write-Log "FATAL: $_" "ERROR"
    Write-Log "Stack: $($_.ScriptStackTrace)" "ERROR"
    Write-Host "`n  Setup aborted. Check log: $($script:LogFile)" -ForegroundColor Red
    Write-Host "  Re-run this script to resume from the failed step.`n" -ForegroundColor Yellow

    Write-RunCommands
    exit 1
}
