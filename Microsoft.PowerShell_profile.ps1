oh-my-posh init pwsh --config 'https://github.com/JanDeDobbeleer/oh-my-posh/blob/main/themes/bubblesline.omp.json' | Invoke-Expression
#Set-PSReadLineKeyHandler -Key Tab -Function AcceptNextSuggestionWord
#Set-PSReadLineKeyHandler -Key 'Shift+Tab' -Function MenuComplete

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

# Import the Chocolatey Profile that contains the necessary code to enable
# tab-completions to function for `choco`.
# Be aware that if you are missing these lines from your profile, tab completion
# for `choco` will not function.
# See https://ch0.co/tab-completion for details.
$ChocolateyProfile = "$env:ChocolateyInstall\helpers\chocolateyProfile.psm1"
if (Test-Path($ChocolateyProfile)) {
  Import-Module "$ChocolateyProfile"
}
