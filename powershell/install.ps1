param(
    [switch]$DryRun,
    [switch]$AdminPhase
)

$ErrorActionPreference = "Stop"

# Script is expected at: dotfiles\powershell\install.ps1
# Repo root is expected at: dotfiles
# Dotfile links use junctions/hardlinks so they work even when Windows file symlinks are restricted
$scriptDir = $PSScriptRoot
$root = Split-Path $scriptDir -Parent

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

function Test-DeveloperModeEnabled {
    $key = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock"

    if (-not (Test-Path $key)) {
        return $false
    }

    $value = Get-ItemProperty -Path $key -Name "AllowDevelopmentWithoutDevLicense" -ErrorAction SilentlyContinue
    return ($null -ne $value -and $value.AllowDevelopmentWithoutDevLicense -eq 1)
}

function Enable-DeveloperMode {
    Log "Checking Windows Developer Mode"

    if (Test-DeveloperModeEnabled) {
        Log "Windows Developer Mode already enabled"
        return
    }

    if (-not (Test-Admin)) {
        throw "Developer Mode enable requires Administrator"
    }

    Log "Enabling Windows Developer Mode"

    if ($DryRun) {
        Log "DryRun: Would enable Windows Developer Mode"
        return
    }

    $key = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock"

    if (-not (Test-Path $key)) {
        New-Item -Path $key -Force | Out-Null
    }

    New-ItemProperty -Path $key -Name "AllowDevelopmentWithoutDevLicense" -Value 1 -PropertyType DWORD -Force | Out-Null
    New-ItemProperty -Path $key -Name "AllowAllTrustedApps" -Value 1 -PropertyType DWORD -Force | Out-Null

    Log "Windows Developer Mode registry flags enabled"
}

function Test-SameVolume {
    param(
        [Parameter(Mandatory = $true)]
        [string]$PathA,

        [Parameter(Mandatory = $true)]
        [string]$PathB
    )

    $rootA = [System.IO.Path]::GetPathRoot([System.IO.Path]::GetFullPath($PathA))
    $rootB = [System.IO.Path]::GetPathRoot([System.IO.Path]::GetFullPath($PathB))

    return ($rootA -ieq $rootB)
}

function Test-ReparsePointTarget {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [string]$Target
    )

    $item = Get-Item $Path -Force -ErrorAction SilentlyContinue

    if (-not $item) {
        return $false
    }

    if ($item.LinkType -ne "SymbolicLink" -and $item.LinkType -ne "Junction") {
        return $false
    }

    $actualTarget = $item.Target

    if ($actualTarget -is [array]) {
        $actualTarget = $actualTarget[0]
    }

    if ([string]::IsNullOrWhiteSpace($actualTarget)) {
        return $false
    }

    try {
        $actualFull = [System.IO.Path]::GetFullPath($actualTarget)
        $targetFull = [System.IO.Path]::GetFullPath($Target)
        return ($actualFull -ieq $targetFull)
    }
    catch {
        return $false
    }
}

function New-SafeDotfileLink {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [string]$Target
    )

    $Path = [System.IO.Path]::GetFullPath($Path)
    $Target = [System.IO.Path]::GetFullPath($Target)

    if (-not (Test-Path $Target)) {
        throw ("Link target does not exist: {0}" -f $Target)
    }

    $targetItem = Get-Item $Target -Force
    $targetIsDirectory = $targetItem.PSIsContainer

    if (Test-Path $Path) {
        $existingItem = Get-Item $Path -Force -ErrorAction SilentlyContinue

        if ($existingItem -and (Test-ReparsePointTarget -Path $Path -Target $Target)) {
            Log ("OK unchanged: {0}" -f $Path)
            return
        }

        Log ("Removing existing item: {0}" -f $Path)

        if (-not $DryRun) {
            if ($existingItem -and ($existingItem.Attributes -band [System.IO.FileAttributes]::ReparsePoint)) {
                # Important: do not use -Recurse on a junction/symlink. Remove only the link itself.
                Remove-Item $Path -Force
            }
            else {
                Remove-Item $Path -Force -Recurse
            }
        }
    }

    $parent = Split-Path $Path -Parent

    if ($parent -and -not (Test-Path $parent)) {
        Log ("Creating directory: {0}" -f $parent)

        if (-not $DryRun) {
            New-Item -ItemType Directory -Path $parent -Force | Out-Null
        }
    }

    if ($targetIsDirectory) {
        # Directory symlinks require Developer Mode/admin. Junctions do not, and they work well for local dotfile dirs.
        Log ("Linking directory junction: {0} -> {1}" -f $Path, $Target)

        if (-not $DryRun) {
            New-Item -ItemType Junction -Path $Path -Target $Target -Force | Out-Null
        }

        return
    }

    if (Test-SameVolume -PathA $Path -PathB $Target) {
        # File symlinks require Developer Mode/admin. Hard links do not, as long as both files are on the same volume.
        Log ("Linking file hardlink: {0} -> {1}" -f $Path, $Target)

        if (-not $DryRun) {
            New-Item -ItemType HardLink -Path $Path -Target $Target -Force | Out-Null
        }

        return
    }

    # Cross-volume file hard links are impossible. Copy instead of failing the whole bootstrap.
    Log ("Copying file because hard links require the same drive: {0} -> {1}" -f $Target, $Path)

    if (-not $DryRun) {
        Copy-Item $Target $Path -Force
    }
}

function Install-PowerShellTheme {
    $themeSource = Join-Path $scriptDir "theme.omp.json"

    if (-not (Test-Path $themeSource)) {
        $themeSource = Get-ChildItem $scriptDir -Filter "*.omp.json" -File -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty FullName
    }

    if (-not $themeSource) {
        Log ("No Oh My Posh theme found next to install.ps1. Expected theme.omp.json or *.omp.json in {0}" -f $scriptDir)
        return
    }

    $themeTargetDir = Join-Path $env:LOCALAPPDATA "oh-my-posh"
    $themeTarget = Join-Path $themeTargetDir "theme.omp.json"

    Log ("Installing Oh My Posh theme: {0} -> {1}" -f $themeSource, $themeTarget)

    if ($DryRun) {
        Log "DryRun: Would copy Oh My Posh theme"
        return
    }

    if (-not (Test-Path $themeTargetDir)) {
        New-Item -ItemType Directory -Path $themeTargetDir -Force | Out-Null
    }

    Copy-Item $themeSource $themeTarget -Force
}

function Install-UserFontFile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if (-not (Test-Path $Path)) {
        throw ("Font file does not exist: {0}" -f $Path)
    }

    $fontsDir = Join-Path $env:LOCALAPPDATA "Microsoft\Windows\Fonts"
    $fontFileName = Split-Path $Path -Leaf
    $target = Join-Path $fontsDir $fontFileName

    Log ("Installing user font: {0}" -f $fontFileName)

    if ($DryRun) {
        Log ("DryRun: Would copy font to {0}" -f $target)
        return
    }

    if (-not (Test-Path $fontsDir)) {
        New-Item -ItemType Directory -Path $fontsDir -Force | Out-Null
    }

    Copy-Item $Path $target -Force

    # Register the copied font for the current user. Windows accepts a per-user font registry entry here.
    $fontRegKey = "HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts"
    if (-not (Test-Path $fontRegKey)) {
        New-Item -Path $fontRegKey -Force | Out-Null
    }

    $ext = [System.IO.Path]::GetExtension($fontFileName).ToLowerInvariant()
    $fontType = if ($ext -eq ".otf") { "OpenType" } else { "TrueType" }
    $regName = "{0} ({1})" -f ([System.IO.Path]::GetFileNameWithoutExtension($fontFileName)), $fontType

    New-ItemProperty -Path $fontRegKey -Name $regName -Value $target -PropertyType String -Force | Out-Null
}

function Install-LocalFonts {
    $fontDirs = @(
        $scriptDir,
        (Join-Path $scriptDir "fonts")
    )

    $fontFiles = @()

    foreach ($dir in $fontDirs) {
        if (Test-Path $dir) {
            $fontFiles += Get-ChildItem $dir -Filter "*.ttf" -File -ErrorAction SilentlyContinue
            $fontFiles += Get-ChildItem $dir -Filter "*.otf" -File -ErrorAction SilentlyContinue
        }
    }

    $fontFiles = $fontFiles | Sort-Object FullName -Unique

    if ($fontFiles.Count -eq 0) {
        Log "No local font files found."
        Log "Your Windows Terminal settings use: AdwaitaMono Nerd Font"
        Log ("Put the AdwaitaMono Nerd Font .ttf/.otf files in {0} or {1}" -f $scriptDir, (Join-Path $scriptDir "fonts"))
        return
    }

    foreach ($font in $fontFiles) {
        Install-UserFontFile -Path $font.FullName
    }

    Log "Local font installation complete"
}

function Set-WindowsTerminalSettings {
    $source = Join-Path $scriptDir "settings.json"

    if (-not (Test-Path $source)) {
        throw ("Windows Terminal settings file does not exist: {0}" -f $source)
    }

    $possibleTargets = @(
        (Join-Path $env:LOCALAPPDATA "Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"),
        (Join-Path $env:LOCALAPPDATA "Packages\Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe\LocalState\settings.json"),
        (Join-Path $env:LOCALAPPDATA "Microsoft\Windows Terminal\settings.json")
    )

    $target = $null

    foreach ($path in $possibleTargets) {
        $parent = Split-Path $path -Parent

        if (Test-Path $parent) {
            $target = $path
            break
        }
    }

    if (-not $target) {
        $target = $possibleTargets[0]
    }

    $targetParent = Split-Path $target -Parent

    Log ("Setting Windows Terminal settings: {0} -> {1}" -f $source, $target)

    if ($DryRun) {
        Log "DryRun: Would copy Windows Terminal settings"
        return
    }

    if (-not (Test-Path $targetParent)) {
        New-Item -ItemType Directory -Path $targetParent -Force | Out-Null
    }

    if (Test-Path $target) {
        $backup = "{0}.backup-{1}" -f $target, (Get-Date -Format "yyyyMMdd-HHmmss")
        Copy-Item $target $backup -Force
        Log ("Backed up existing Windows Terminal settings: {0}" -f $backup)
    }

    Copy-Item $source $target -Force
    Log "Windows Terminal settings installed"
}

function Ensure-AdwaitaNerdFont {
    Log "Ensuring AdwaitaMono Nerd Font"

    if ($DryRun) {
        Log "DryRun: Would install AdwaitaMono Nerd Font through Scoop"
        return
    }

    if (-not (Get-Command scoop -ErrorAction SilentlyContinue)) {
        Log "Scoop unavailable. Skipping AdwaitaMono Nerd Font install."
        return
    }

    $fontAlreadyInstalled = Test-FontInstalled -FontNamePattern "*Adwaita*"

    if ($fontAlreadyInstalled) {
        Log "AdwaitaMono Nerd Font already installed"
        return
    }

    Run "scoop" @("bucket", "add", "nerd-fonts")

    $candidates = @(
        "AdwaitaMono-NF",
        "AdwaitaMono-NF-Mono",
        "AdwaitaMono-Nerd-Font",
        "AdwaitaMono"
    )

    foreach ($candidate in $candidates) {
        try {
            Log ("Trying font package: {0}" -f $candidate)
            Run "scoop" @("install", $candidate)

            if (Test-FontInstalled -FontNamePattern "*Adwaita*") {
                Log ("Installed AdwaitaMono Nerd Font using Scoop package: {0}" -f $candidate)
                return
            }
        }
        catch {
            Log ("Font package failed: {0}" -f $candidate)
        }
    }

    throw "Could not install AdwaitaMono Nerd Font from Scoop nerd-fonts bucket"
}

function Test-FontInstalled {
    param(
        [Parameter(Mandatory = $true)]
        [string]$FontNamePattern
    )

    $fontRegistryPaths = @(
        "HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts",
        "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts"
    )

    foreach ($path in $fontRegistryPaths) {
        if (-not (Test-Path $path)) {
            continue
        }

        $fonts = Get-ItemProperty -Path $path

        foreach ($property in $fonts.PSObject.Properties) {
            if ($property.Name -like $FontNamePattern -or [string]$property.Value -like $FontNamePattern) {
                return $true
            }
        }
    }

    return $false
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

function Ensure-ScoopPackage {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    if (-not (Get-Command scoop -ErrorAction SilentlyContinue)) {
        Log ("Scoop unavailable. Skipping package: {0}" -f $Name)
        return
    }

    $installed = scoop list 2>$null | Select-String -Pattern ("^\s*{0}\s" -f [regex]::Escape($Name))

    if ($installed) {
        Log ("Scoop package already installed: {0}" -f $Name)
        return
    }

    Run "scoop" @("install", $Name)
}

function Configure-Git {
    if ($DryRun) {
        Log "DryRun: Would write git config"
        return
    }

    Log "Writing git configuration"
    git config --global user.name "Wyatt Walker"
    git config --global user.email "wyatt@wwalker.me"
    git config --global credential.helper manager
    git config --global pull.rebase true
}

function Invoke-AdminPhase {
    $needsDeveloperMode = -not (Test-DeveloperModeEnabled)
    $needsMsvc = -not (Test-MsvcInstalled)

    if ($DryRun) {
        if ($needsDeveloperMode) {
            Log "DryRun: would relaunch as Administrator to enable Developer Mode"
        }
        else {
            Log "DryRun: Developer Mode already enabled"
        }

        if ($needsMsvc) {
            Log "DryRun: would relaunch as Administrator for MSVC Build Tools"
        }
        else {
            Log "DryRun: MSVC Build Tools already installed"
        }

        return
    }

    if (-not $needsDeveloperMode -and -not $needsMsvc) {
        Log "Admin phase not needed"
        return
    }

    if ($needsDeveloperMode) {
        Log "Developer Mode missing. Relaunching admin phase."
    }

    if ($needsMsvc) {
        Log "MSVC Build Tools missing. Relaunching admin phase."
    }

    $argList = @(
        "-NoProfile",
        "-ExecutionPolicy", "Bypass",
        "-File", $PSCommandPath,
        "-AdminPhase"
    )

    Start-Process -FilePath "powershell" -ArgumentList $argList -Verb RunAs -Wait

    if (-not (Test-DeveloperModeEnabled)) {
        Log "Admin phase completed, but Windows Developer Mode still does not appear enabled. Continuing because dotfile links use junctions/hardlinks."
    }

    if (-not (Test-MsvcInstalled)) {
        throw "Admin phase completed, but MSVC Build Tools are still not installed"
    }

    Log "Admin phase verified"
}

# ---------------- ADMIN PHASE ----------------

if ($AdminPhase) {
    Log "Admin phase started"

    if (-not (Test-Admin)) {
        throw "Admin phase was started without Administrator privileges"
    }

    Enable-DeveloperMode
    Ensure-VisualStudioBuildTools

    Log "Admin phase complete"
    exit 0
}

# ---------------- NORMAL USER PHASE ----------------

Log ("Bootstrap started DryRun={0}" -f $DryRun)
Log ("Script dir: {0}" -f $scriptDir)
Log ("Repo root:  {0}" -f $root)

if (Test-Admin) {
    throw "Run this script from normal PowerShell, not Administrator. It will request admin only when needed."
}

# --- ADMIN-ONLY SETUP FIRST ---
Invoke-AdminPhase

# --- WINGET PACKAGES ---
$packages = @(
    "Microsoft.WindowsTerminal",
    "Microsoft.PowerShell",
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

# --- POWERSHELL / TERMINAL THEME + FONT ---
Install-PowerShellTheme
Install-LocalFonts
Set-WindowsTerminalSettings

# --- SYMLINKS ---
$documents = [Environment]::GetFolderPath("MyDocuments")
$profileSource = Join-Path $scriptDir "Microsoft.PowerShell_profile.ps1"

$links = @(
    @{
        Path = Join-Path $HOME "AppData\Local\nvim"
        Target = Join-Path $root "nvim"
    },
    @{
        Path = Join-Path $documents "PowerShell\Microsoft.PowerShell_profile.ps1"
        Target = $profileSource
    },
    @{
        Path = Join-Path $documents "WindowsPowerShell\Microsoft.PowerShell_profile.ps1"
        Target = $profileSource
    }
)

foreach ($link in $links) {
    New-SafeDotfileLink -Path $link.Path -Target $link.Target
}

# --- SCOOP + TREE-SITTER ---
Ensure-Scoop
Ensure-AdwaitaNerdFont
Ensure-ScoopPackage -Name "tree-sitter"

Configure-Git

Log "Bootstrap complete"
