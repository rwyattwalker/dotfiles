$root = $PSScriptRoot

if (-not ([bool]([Security.Principal.WindowsPrincipal] `
        [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(`
        [Security.Principal.WindowsBuiltInRole] "Administrator")))
{
    Write-Host "Script must be run as Administrator"
    exit 1
}

$links = @(
    @{
        Link = "$HOME\AppData\Local\nvim\init.lua"
        Target = Join-Path $root "nvim\init.lua"
    },
    @{
        Link = "$HOME\.config\powershell\profile.ps1"
        Target = Join-Path $root "profile.ps1"
    }
)

# --- Function to create symlink safely ---
function New-SafeSymlink {
    param(
        [string]$Link,
        [string]$Target
    )

    Write-Host "`n🔗 Creating link:" -ForegroundColor Cyan
    Write-Host "Link:    $Link"
    Write-Host "Target:  $Target"

    # Make sure parent folder exists
    $parent = Split-Path $Link
    if (-not (Test-Path $parent)) {
        Write-Host "📁 Creating directory: $parent"
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }

    # Remove existing item if needed
    if (Test-Path $Link) {
        Write-Host "⚠️ Existing item found. Removing: $Link"
        Remove-Item -Force -Recurse $Link
    }

    # Determine type
    $isDir = (Test-Path $Target -PathType Container)

    if ($isDir) {
        New-Item -ItemType SymbolicLink -Path $Link -Target $Target | Out-Null
    } else {
        New-Item -ItemType SymbolicLink -Path $Link -Target $Target | Out-Null
    }

    Write-Host "✅ Symlink created."
}

# --- Create all links ---
foreach ($item in $links) {
    New-SafeSymlink -Link $item.Link -Target $item.Target
}

Write-Host "`n🎉 Done!"

