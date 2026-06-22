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

    # A release archive can contain the same filename in more than one font
    # variant directory. Once Windows loads the first copy it can lock that
    # file, so do not attempt to overwrite an existing user-font file.
    if (Test-Path $target) {
        Log ("User font file already present: {0}" -f $fontFileName)
    }
    else {
        Copy-Item $Path $target -Force
    }

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

function Get-WindowsTerminalSchemeFromKittyConfig {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if (-not (Test-Path $Path)) {
        throw ("Kitty configuration file does not exist: {0}" -f $Path)
    }

    $contents = Get-Content -Path $Path -Raw

    function Get-Color {
        param([string]$Name)

        $match = [regex]::Match($contents, ("(?m)^\s*{0}\s+(#[0-9a-fA-F]{{6}})" -f [regex]::Escape($Name)))

        if (-not $match.Success) {
            throw ("Missing color '{0}' in {1}" -f $Name, $Path)
        }

        return $match.Groups[1].Value
    }

    return [pscustomobject][ordered]@{
        name                = "Tokyo Night"
        background          = Get-Color "background"
        foreground          = Get-Color "foreground"
        selectionBackground = Get-Color "selection_background"
        cursorColor         = Get-Color "cursor"
        black               = Get-Color "color0"
        red                 = Get-Color "color1"
        green               = Get-Color "color2"
        yellow              = Get-Color "color3"
        blue                = Get-Color "color4"
        purple              = Get-Color "color5"
        cyan                = Get-Color "color6"
        white               = Get-Color "color7"
        brightBlack         = Get-Color "color8"
        brightRed           = Get-Color "color9"
        brightGreen         = Get-Color "color10"
        brightYellow        = Get-Color "color11"
        brightBlue          = Get-Color "color12"
        brightPurple        = Get-Color "color13"
        brightCyan          = Get-Color "color14"
        brightWhite         = Get-Color "color15"
    }
}

function Set-WindowsTerminalSettings {
    $source = Join-Path $scriptDir "settings.json"
    $kittyConfigSource = Join-Path $root "kitty\kitty.conf"

    if (-not (Test-Path $source)) {
        throw ("Windows Terminal settings file does not exist: {0}" -f $source)
    }

    # Keep Kitty as the single palette source of truth for both terminals.
    $terminalScheme = Get-WindowsTerminalSchemeFromKittyConfig -Path $kittyConfigSource

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
        Log ("DryRun: Would apply the Windows Terminal palette from {0}" -f $kittyConfigSource)
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

    $settings = Get-Content -Path $source -Raw | ConvertFrom-Json
    $settings.schemes = @($terminalScheme)

    foreach ($profile in $settings.profiles.list) {
        if ($profile.name -in @("PowerShell", "Windows PowerShell")) {
            $profile | Add-Member -NotePropertyName "colorScheme" -NotePropertyValue "Tokyo Night" -Force
            $profile | Add-Member -NotePropertyName "font" -NotePropertyValue ([pscustomobject]@{ face = "JetBrainsMono Nerd Font Mono" }) -Force
            if ($profile.PSObject.Properties["lineHeight"]) {
                $profile.PSObject.Properties.Remove("lineHeight")
            }
            $profile | Add-Member -NotePropertyName "padding" -NotePropertyValue "8, 12, 8, 12" -Force
        }
    }

    $settings | ConvertTo-Json -Depth 20 | Set-Content -Path $target -Encoding utf8
    Log "Windows Terminal settings installed with the Tokyo Night palette and JetBrainsMono Nerd Font Mono"
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

function Ensure-JetBrainsMonoNerdFont {
    Log "Ensuring JetBrainsMono Nerd Font Mono"

    if (Test-FontInstalled -FontNamePattern "*JetBrainsMono*Nerd*Font*Mono*") {
        Log "JetBrainsMono Nerd Font Mono already installed"
        return
    }

    if ($DryRun) {
        Log "DryRun: Would download and install the latest JetBrainsMono Nerd Font Mono release"
        return
    }

    $release = Invoke-RestMethod -Uri "https://api.github.com/repos/ryanoasis/nerd-fonts/releases/latest" -Headers @{ "User-Agent" = "dotfiles-bootstrap" }
    $asset = $release.assets |
        Where-Object { $_.name -eq "JetBrainsMono.zip" } |
        Select-Object -First 1

    if (-not $asset) {
        throw "The latest Nerd Fonts release does not contain JetBrainsMono.zip"
    }

    $archive = Join-Path $env:TEMP $asset.name
    $extractDir = Join-Path $env:TEMP ("JetBrainsMonoNerdFont-{0}" -f [guid]::NewGuid())

    try {
        Log ("Downloading JetBrainsMono Nerd Font Mono {0}" -f $release.tag_name)
        Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $archive
        Expand-Archive -Path $archive -DestinationPath $extractDir -Force

        $fontFiles = Get-ChildItem -Path $extractDir -Recurse -File -Filter "JetBrainsMonoNerdFontMono-*.ttf"

        if ($fontFiles.Count -eq 0) {
            throw "The JetBrains Mono Nerd Font archive did not contain any Mono TrueType font files"
        }

        foreach ($font in $fontFiles) {
            Install-UserFontFile -Path $font.FullName
        }
    }
    finally {
        Remove-Item -LiteralPath $archive -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $extractDir -Recurse -Force -ErrorAction SilentlyContinue
    }

    if (-not (Test-FontInstalled -FontNamePattern "*JetBrainsMono*Nerd*Font*Mono*")) {
        throw "JetBrainsMono Nerd Font Mono was copied but Windows did not register it"
    }

    Log "JetBrainsMono Nerd Font Mono installation complete"
}

function Ensure-PowerShellFormatter {
    Log "Ensuring PowerShell formatter: PSScriptAnalyzer"

    $moduleName = "PSScriptAnalyzer"

    if ($DryRun) {
        if (Get-Module -ListAvailable -Name $moduleName) {
            Log "DryRun: PSScriptAnalyzer already installed"
        }
        else {
            Log "DryRun: Would install PSScriptAnalyzer for CurrentUser"
        }

        return
    }

    if (Get-Module -ListAvailable -Name $moduleName) {
        Log "PSScriptAnalyzer already installed"
        return
    }

    if (-not (Get-PackageProvider -Name NuGet -ErrorAction SilentlyContinue)) {
        Log "Installing NuGet package provider"
        Install-PackageProvider -Name NuGet -Scope CurrentUser -Force | Out-Null
    }

    $repo = Get-PSRepository -Name PSGallery -ErrorAction SilentlyContinue

    if (-not $repo) {
        Log "Registering PSGallery"
        Register-PSRepository -Default
    }

    Set-PSRepository -Name PSGallery -InstallationPolicy Trusted

    Install-Module `
        -Name $moduleName `
        -Scope CurrentUser `
        -Force `
        -AllowClobber

    Log "PSScriptAnalyzer installed"
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
    "OpenAI.Codex",
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
Ensure-JetBrainsMonoNerdFont
Set-WindowsTerminalSettings
Ensure-PowerShellFormatter

# --- SYMLINKS ---
$documents = [Environment]::GetFolderPath("MyDocuments")
$profileSource = Join-Path $scriptDir "Microsoft.PowerShell_profile.ps1"

$links = @(
    @{
        Path   = Join-Path $HOME "AppData\Local\nvim"
        Target = Join-Path $root "nvim"
    },
    @{
        Path   = Join-Path $documents "PowerShell\Microsoft.PowerShell_profile.ps1"
        Target = $profileSource
    },
    @{
        Path   = Join-Path $documents "WindowsPowerShell\Microsoft.PowerShell_profile.ps1"
        Target = $profileSource
    }
)

foreach ($link in $links) {
    New-SafeDotfileLink -Path $link.Path -Target $link.Target
}

# --- SCOOP + TREE-SITTER ---
Ensure-Scoop
Ensure-ScoopPackage -Name "tree-sitter"

Configure-Git

Log "Bootstrap complete"
