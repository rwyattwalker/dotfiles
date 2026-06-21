param(
    [switch]$DryRun,
    [switch]$AdminPhase
)

$ErrorActionPreference = "Stop"
$root = $PSScriptRoot

function Log {
    param([string]$Message)
    Write-Host ("[{0}] {1}" -f (Get-Date -Format "HH:mm:ss"), $Message)
}

function Test-Admin {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Run {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Command,

        [string[]]$ArgumentList = @()
    )

    Log ("Running: {0} {1}" -f $Command, ($ArgumentList -join " "))

    if ($DryRun) {
        return
    }

    & $Command @ArgumentList

    if ($LASTEXITCODE -ne 0) {
        throw ("Command failed with exit code {0}: {1} {2}" -f $LASTEXITCODE, $Command, ($ArgumentList -join " "))
    }
}

function New-SafeSymlink {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [string]$Target
    )

    $Target = [System.IO.Path]::GetFullPath($Target)

    if (-not (Test-Path $Target)) {
        throw ("Symlink target does not exist: {0}" -f $Target)
    }

    if (Test-Path $Path) {
        $item = Get-Item $Path -Force -ErrorAction SilentlyContinue

        if ($item -and $item.LinkType -eq "SymbolicLink") {
            $currentTarget = [System.IO.Path]::GetFullPath($item.Target)

            if ($currentTarget -eq $Target) {
                Log ("OK unchanged: {0}" -f $Path)
                return
            }

            Log ("Updating symlink: {0}" -f $Path)
        }
        else {
            Log ("Removing existing item: {0}" -f $Path)
        }

        if (-not $DryRun) {
            Remove-Item $Path -Force -Recurse
        }
    }

    $parent = Split-Path $Path -Parent

    if ($parent -and -not (Test-Path $parent)) {
        Log ("Creating directory: {0}" -f $parent)

        if (-not $DryRun) {
            New-Item -ItemType Directory -Path $parent -Force | Out-Null
        }
    }

    Log ("Linking: {0} -> {1}" -f $Path, $Target)

    if (-not $DryRun) {
        try {
            New-Item -ItemType SymbolicLink -Path $Path -Target $Target -Force | Out-Null
        }
        catch {
            $msg = @()
            $msg += "Failed to create symlink:"
            $msg += ""
            $msg += ("  {0} -> {1}" -f $Path, $Target)
            $msg += ""
            $msg += "Enable Windows Developer Mode or run this script as Administrator."
            $msg += ("Original error: {0}" -f $_)
            throw ($msg -join [Environment]::NewLine)
        }
    }
}

function Test-WingetPackageInstalled {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Id
    )

    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        throw "winget is not installed or not available on PATH"
    }

    winget list --id $Id -e --accept-source-agreements | Out-Null
    return ($LASTEXITCODE -eq 0)
}

function Ensure-WingetPackage {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Id
    )

    Log ("Ensuring winget package: {0}" -f $Id)

    if ($DryRun) {
        return
    }

    if (Test-WingetPackageInstalled -Id $Id) {
        Log ("Already installed: {0}" -f $Id)
        return
    }

    Run "winget" @(
        "install",
        "--id", $Id,
        "-e",
        "--silent",
        "--accept-source-agreements",
        "--accept-package-agreements"
    )
}

function Get-VsWherePath {
    $paths = @(
        "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe",
        "$env:ProgramFiles\Microsoft Visual Studio\Installer\vswhere.exe"
    )

    foreach ($path in $paths) {
        if (Test-Path $path) {
            return $path
        }
    }

    return $null
}

function Test-MsvcInstalled {
    if (Get-Command cl.exe -ErrorAction SilentlyContinue) {
        return $true
    }

    $vswhere = Get-VsWherePath

    if (-not $vswhere) {
        return $false
    }

    $installPath = & $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath

    if ([string]::IsNullOrWhiteSpace($installPath)) {
        return $false
    }

    return $true
}

function Ensure-VisualStudioBuildTools {
    Log "Checking for MSVC Build Tools"

    if (Test-MsvcInstalled) {
        Log "MSVC Build Tools already installed"
        return
    }

    if (-not (Test-Admin)) {
        throw "Visual Studio Build Tools installation requires Administrator"
    }

    Log "MSVC not found. Installing Visual Studio Build Tools."

    $vsInstaller = Join-Path $env:TEMP "vs_buildtools.exe"

    if (-not $DryRun) {
        Invoke-WebRequest -Uri "https://aka.ms/vs/17/release/vs_BuildTools.exe" -OutFile $vsInstaller

        Run $vsInstaller @(
            "--wait",
            "--norestart",
            "--nocache",
            "--add", "Microsoft.VisualStudio.Workload.VCTools",
            "--add", "Microsoft.VisualStudio.Component.Windows11SDK.22621",
            "--includeRecommended"
        )
    }

    Log "Build Tools installation complete. Reboot may be required."
}

function Ensure-Scoop {
    if (Get-Command scoop -ErrorAction SilentlyContinue) {
        Log "Scoop already installed"
        return
    }

    if (Test-Admin) {
        throw "Scoop should not be installed from an Administrator shell"
    }

    Log "Installing Scoop"

    if ($DryRun) {
        return
    }

    Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
    Invoke-RestMethod -Uri "https://get.scoop.sh" | Invoke-Expression
}

function Configure-Git {
    if($DryRun){
        Log "DryRun: Would write git config"
    }
    else {
        Log "Writig git configuration"
        git config --global user.name "Wyatt Walker"
        git config --global user.email "wyatt@wwalker.me"
        git config --global credential.helper manager
        git config --global pull.rebase true
    }
}

function Invoke-AdminPhase {
    if ($DryRun) {
        if (Test-MsvcInstalled) {
            Log "DryRun: MSVC Build Tools already installed"
        }
        else {
            Log "DryRun: would relaunch as Administrator for MSVC Build Tools"
        }

        return
    }

    if (Test-MsvcInstalled) {
        Log "MSVC Build Tools already installed"
        return
    }

    Log "MSVC Build Tools missing. Relaunching admin phase."

    $argList = @(
        "-NoProfile",
        "-ExecutionPolicy", "Bypass",
        "-File", $PSCommandPath,
        "-AdminPhase"
    )

    Start-Process -FilePath "powershell" -ArgumentList $argList -Verb RunAs -Wait
}

# ---------------- ADMIN PHASE ----------------

if ($AdminPhase) {
    Log "Admin phase started"

    if (-not (Test-Admin)) {
        throw "Admin phase was started without Administrator privileges"
    }

    Ensure-VisualStudioBuildTools

    Log "Admin phase complete"
    exit 0
}

# ---------------- NORMAL USER PHASE ----------------

Log ("Bootstrap started DryRun={0}" -f $DryRun)
Log ("Repo root: {0}" -f $root)

if (Test-Admin) {
    throw "Run this script from normal PowerShell, not Administrator. It will request admin only when needed."
}

# --- SYMLINKS ---
$links = @(
    @{
        Path = Join-Path $HOME "AppData\Local\nvim"
        Target = Join-Path $root "nvim"
    },
    @{
        Path = $PROFILE
        Target = Join-Path $root "Microsoft.PowerShell_profile.ps1"
    }
)

foreach ($link in $links) {
    New-SafeSymlink -Path $link.Path -Target $link.Target
}

# --- WINGET PACKAGES ---
$packages = @(
    "WireGuard.WireGuard",
    "Mozilla.Firefox",
    "Valve.Steam",
    "Bitwarden.Bitwarden",
    "Git.Git",
    "Neovim.Neovim",
    "JanDeDobbeleer.OhMyPosh",
    "Seafile.Seafile"
)

foreach ($pkg in $packages) {
    Ensure-WingetPackage -Id $pkg
}

# --- SCOOP + TREE-SITTER ---
Ensure-Scoop

if (Get-Command scoop -ErrorAction SilentlyContinue) {
    Run "scoop" @("install", "tree-sitter")
}
else {
    Log "Scoop unavailable. Skipping tree-sitter."
}

# --- OH MY POSH FONT ---
Log "Installing Meslo font"

if (Get-Command oh-my-posh -ErrorAction SilentlyContinue) {
    try {
        Run "oh-my-posh" @("font", "install", "meslo")
    }
    catch {
        Log ("Font install failed: {0}" -f $_)
    }
}
else {
    Log "oh-my-posh unavailable. Skipping font install."
}

Configure-Git

# --- ADMIN-ONLY MSVC PHASE ---
Invoke-AdminPhase

Log "Bootstrap complete"
