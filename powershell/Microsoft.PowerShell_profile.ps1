oh-my-posh init pwsh --config 'https://github.com/JanDeDobbeleer/oh-my-posh/blob/main/themes/bubbles.omp.json' | Invoke-Expression

# Invoke fzf and change directory to the target
# Must have fzf installed - install by running: winget install --id=junegunn.fzf  -e
function cdf {
    $target = rg --files | fzf


    if ($target) {
        Set-Location (Split-Path $target -Parent)
    }
}

function Open-InitLua {
    Set-Location "C:\Users\$env:USERNAME\AppData\Local\nvim"
    nvim init.lua 
}

function Format-PSFile {
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    $resolvedPath = Resolve-Path $Path -ErrorAction Stop

    $script = Get-Content -LiteralPath $resolvedPath -Raw -ErrorAction Stop

    if ([string]::IsNullOrWhiteSpace($script)) {
        Write-Warning "File is empty or only whitespace: $resolvedPath"
        return
    }

    # Older PSScriptAnalyzer versions can fail if they can't infer line endings.
    if (-not ($script.EndsWith("`n"))) {
        $script += "`r`n"
    }

    try {
        $formatted = Invoke-Formatter -ScriptDefinition $script -ErrorAction Stop
    }
    catch {
        Write-Warning "Invoke-Formatter failed for: $resolvedPath"
        Write-Warning $_.Exception.Message
        return
    }

    Set-Content -LiteralPath $resolvedPath -Value $formatted -NoNewline
}

# Import the Chocolatey Profile that contains the necessary code to enable
# tab-completions to function for `choco`.
# Be aware that if you are missing these lines from your profile, tab completion
# for `choco` will not function.
# See https://ch0.co/tab-completion for details.
$ChocolateyProfile = "$env:ChocolateyInstall\helpers\chocolateyProfile.psm1"
if (Test-Path($ChocolateyProfile)) {
    Import-Module "$ChocolateyProfile"
}
