<#
.SYNOPSIS
    Anna's Booktable  -  Environment Verification (standalone)
    Run anytime to check the health of the entire dev environment.
#>

param(
    [string]$ProjectRoot = "D:\Dev\AnnaBooktable"
)

$ErrorActionPreference = "SilentlyContinue"

# Load lib if available, otherwise inline minimal helpers
$libPath = Join-Path $PSScriptRoot "Lib_Common.ps1"
if (Test-Path $libPath) { . $libPath }

$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" +
            [System.Environment]::GetEnvironmentVariable("Path","User")

$total = 0; $passed = 0; $failed = @()

function Check {
    param([string]$Section, [string]$Name, [bool]$Ok, [string]$Detail)
    $script:total++
    if ($Ok) {
        $script:passed++
        Write-Host "  [OK] $Name  -  $Detail" -ForegroundColor Green
    } else {
        $script:failed += "$Section/$Name"
        Write-Host "  [FAIL] $Name  -  $Detail" -ForegroundColor Red
    }
}

function Section { param([string]$Title) Write-Host "`n  -- $Title --" -ForegroundColor DarkCyan }

function TestCmd {
    param([string]$Cmd)
    $null -ne (Get-Command $Cmd -ErrorAction SilentlyContinue)
}

function GetVer {
    param([string]$Cmd, [string]$Args = "--version")
    try { $out = & $Cmd $Args 2>&1 | Select-Object -First 1; return $out.ToString().Trim() }
    catch { return $null }
}

# ============================================================

Write-Host ""
Write-Host "+==============================================================+" -ForegroundColor Cyan
Write-Host "|            Environment Verification Report                   |" -ForegroundColor Cyan
Write-Host "+==============================================================+" -ForegroundColor Cyan

# --- Windows Features ---
Section "Windows Features"
foreach ($f in @(
    @{ Feature = "Microsoft-Windows-Subsystem-Linux"; Name = "WSL" },
    @{ Feature = "VirtualMachinePlatform";            Name = "Virtual Machine Platform" },
    @{ Feature = "Microsoft-Hyper-V-All";             Name = "Hyper-V" },
    @{ Feature = "Containers";                        Name = "Containers" }
)) {
    $state = (Get-WindowsOptionalFeature -Online -FeatureName $f.Feature -ErrorAction SilentlyContinue).State
    Check "WinFeature" $f.Name ($state -eq "Enabled") $(if ($state) { $state } else { "not available" })
}

# --- WSL2 ---
Section "WSL2 + Ubuntu Packages"
$distros = wsl --list --quiet 2>$null
Check "WSL" "Ubuntu distro" ($distros -match "Ubuntu") $(if ($distros -match "Ubuntu") { "installed" } else { "not found" })

if ($distros -match "Ubuntu") {
    $wslVersion = wsl --list --verbose 2>$null | Select-String "Ubuntu" | ForEach-Object { $_.ToString().Trim() }
    Check "WSL" "WSL version" ($wslVersion -match "2") "$wslVersion"

    $wslChecks = @(
        @{ Name = "gcc";     Cmd = "gcc --version 2>/dev/null | head -1" },
        @{ Name = "python3"; Cmd = "python3 --version 2>/dev/null" },
        @{ Name = "ffmpeg";  Cmd = "ffmpeg -version 2>/dev/null | head -1" },
        @{ Name = "git";     Cmd = "git --version 2>/dev/null" }
    )
    foreach ($c in $wslChecks) {
        $out = wsl --distribution Ubuntu -- bash -c $c.Cmd 2>$null | Select-Object -First 1
        Check "WSL" "WSL $($c.Name)" ($null -ne $out -and $out.Length -gt 0) $(if ($out) { $out.Trim() } else { "not found" })
    }
}

# --- CLI Tools ---
Section "CLI Tools (Windows)"
$cliTools = @(
    @{ Name = "Git";              Cmd = "git";    Args = "--version" },
    @{ Name = ".NET SDK";         Cmd = "dotnet"; Args = "--version" },
    @{ Name = "Node.js";          Cmd = "node";   Args = "--version" },
    @{ Name = "npm";              Cmd = "npm";    Args = "--version" },
    @{ Name = "Docker";           Cmd = "docker"; Args = "--version" },
    @{ Name = "Docker Compose";   Cmd = "docker"; Args = "compose version" },
    @{ Name = "GitHub CLI";       Cmd = "gh";     Args = "--version" },
    @{ Name = "Azure CLI";        Cmd = "az";     Args = "version" },
    @{ Name = "VS Code";          Cmd = "code";   Args = "--version" }
)
foreach ($t in $cliTools) {
    $ver = GetVer $t.Cmd $t.Args
    Check "CLI" $t.Name ($null -ne $ver) $(if ($ver) { $ver } else { "NOT FOUND" })
}

# --- .NET Global Tools ---
Section ".NET Global Tools"
foreach ($t in @("dotnet-ef", "dotnet-aspnet-codegenerator")) {
    $found = dotnet tool list --global 2>$null | Select-String $t
    Check "DotNet" $t ($null -ne $found) $(if ($found) { "installed" } else { "not found" })
}

# --- Docker ---
Section "Docker"
$dockerRunning = docker info 2>$null
Check "Docker" "Docker daemon" ($null -ne $dockerRunning) $(if ($dockerRunning) { "running" } else { "NOT RUNNING" })

if ($dockerRunning) {
    # Test container capability
    $testOut = docker run --rm hello-world 2>&1 | Out-String
    Check "Docker" "Test container" ($testOut -match "Hello from Docker") $(if ($testOut -match "Hello from Docker") { "hello-world OK" } else { "failed" })

    # Project containers
    $containers = @("booktable-postgres", "booktable-redis", "booktable-elasticsearch", "booktable-rabbitmq", "booktable-seq")
    foreach ($c in $containers) {
        $status = docker inspect --format='{{.State.Status}}' $c 2>$null
        Check "Docker" $c ($status -eq "running") $(if ($status) { $status } else { "not found" })
    }

    # DB seed data
    $slots = docker exec booktable-postgres psql -U booktable_admin -d booktable -t -c "SELECT COUNT(*) FROM time_slots;" 2>$null
    if ($slots) {
        $count = $slots.Trim()
        Check "Docker" "DB seed data" ([int]$count -gt 0) "$count time slots"
    }
}

# --- VS Code Extensions ---
Section "VS Code Extensions"
if (TestCmd "code") {
    $installed = code --list-extensions 2>$null

    $keyExt = @(
        @{ Id = "vscodevim.vim";                          Name = "Vim Emulation" },
        @{ Id = "GitHub.copilot";                         Name = "GitHub Copilot" },
        @{ Id = "GitHub.copilot-chat";                    Name = "Copilot Chat" },
        @{ Id = "ms-vscode-remote.remote-wsl";            Name = "Remote - WSL" },
        @{ Id = "ms-vscode-remote.remote-ssh";            Name = "Remote - SSH" },
        @{ Id = "ms-vscode-remote.remote-containers";     Name = "Dev Containers" },
        @{ Id = "ms-dotnettools.csdevkit";                Name = "C# Dev Kit" },
        @{ Id = "ms-python.python";                       Name = "Python" },
        @{ Id = "eamodio.gitlens";                        Name = "GitLens" }
    )
    foreach ($e in $keyExt) {
        Check "VSCode" $e.Name ($installed -contains $e.Id) $(if ($installed -contains $e.Id) { "installed" } else { "MISSING" })
    }
} else {
    Write-Host "  [SKIP]  VS Code CLI not available  -  skipping" -ForegroundColor DarkGray
}

# --- GitHub Auth ---
Section "Authentication Status"
if (TestCmd "gh") {
    $ghAuth = gh auth status 2>&1 | Out-String
    Check "Auth" "GitHub CLI" ($ghAuth -match "Logged in") $(if ($ghAuth -match "Logged in") { "authenticated" } else { "not logged in -> gh auth login" })
}

$sshKey = Test-Path "$env:USERPROFILE\.ssh\id_ed25519.pub"
Check "Auth" "SSH key (ed25519)" $sshKey $(if ($sshKey) { "exists" } else { "not found -> ssh-keygen -t ed25519" })

# --- Project Structure ---
Section "Project Structure"
$criticalFiles = @(
    "AnnaBooktable.sln",
    "docker-compose.yml",
    "db/init/01_schema.sql",
    "src/Gateway/AnnaBooktable.Gateway.csproj",
    "src/Services/InventoryService/AnnaBooktable.InventoryService.csproj",
    "src/diner-app/package.json",
    "src/restaurant-portal/package.json"
)
foreach ($f in $criticalFiles) {
    $exists = Test-Path (Join-Path $ProjectRoot $f)
    Check "Project" ($f -replace ".*[\\/]","") $exists $(if ($exists) { "exists" } else { "MISSING" })
}

# --- Build ---
Section "Build"
$slnPath = Join-Path $ProjectRoot "AnnaBooktable.sln"
if (Test-Path $slnPath) {
    Push-Location $ProjectRoot
    $buildOut = dotnet build --no-restore --verbosity quiet 2>&1 | Out-String
    $buildOk = $LASTEXITCODE -eq 0
    Pop-Location
    Check "Build" ".NET solution" $buildOk $(if ($buildOk) { "compiles" } else { "BUILD FAILED" })
}

# ============================================================
# Summary
# ============================================================
$pct = if ($total -gt 0) { [math]::Round(($passed / $total) * 100) } else { 0 }
$color = if ($pct -eq 100) { "Green" } elseif ($pct -ge 80) { "Yellow" } else { "Red" }

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Result: $passed / $total checks passed ($pct%)" -ForegroundColor $color

if ($failed.Count -gt 0) {
    Write-Host ""
    Write-Host "  Failed checks:" -ForegroundColor Red
    foreach ($f in $failed) { Write-Host "    * $f" -ForegroundColor Red }
}

Write-Host ""
if ($pct -eq 100) {
    Write-Host "  (!) Everything looks great! Ready to develop." -ForegroundColor Green
} else {
    Write-Host "  Manual next steps:" -ForegroundColor Yellow
    Write-Host "    * Install Visual Studio 2022 Enterprise (+ VsVim, Copilot extensions)" -ForegroundColor Gray
    Write-Host "    * gh auth login            (GitHub CLI authentication)" -ForegroundColor Gray
    Write-Host "    * claude login             (Claude Code authentication)" -ForegroundColor Gray
    Write-Host "    * az login                 (Azure CLI authentication)" -ForegroundColor Gray
    Write-Host "    * ssh-keygen -t ed25519    (generate SSH key)" -ForegroundColor Gray
    Write-Host "    * gh ssh-key add ~/.ssh/id_ed25519.pub  (add to GitHub)" -ForegroundColor Gray
}
Write-Host ""
