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
        Link = "$HOME\AppData\Local\nvim"
        Target = Join-Path $root "nvim"
    },
    @{
        Link = $PROFILE
        Target = Join-Path $root "Microsoft.PowerShell_profile.ps1"
    }
)

foreach ($item in $links) {
    $parent = Split-Path $item.Link

    if (-not (Test-Path $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }

    if (Test-Path $item.Link) {
        Remove-Item $item.Link -Force
    }

    New-Item -ItemType SymbolicLink -Path $item.Link -Target $item.Target -Force | Out-Null

    Write-Host "Created: $($item.Link) -> $($item.Target)"
}
