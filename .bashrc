# If not running interactively, don't do anything
[[ $- != *i* ]] && return

alias ls='ls --color=auto'
alias grep='grep --color=auto'
bp () {
     printf "Bat 0: %s \n" "$(cat /sys/class/power_supply/BAT0/capacity)"
     printf "Bat 1: %s \n" "$(cat /sys/class/power_supply/BAT1/capacity)"
}
export PATH="$HOME/.local/bin:$PATH"

#Time & Date Formatting
HISTTIMEFORMAT="%F %T "

HISTSIZE=2000
HISTFILESIZE=2000

set -o vi

# Colors
ylw="\[\e[33m\]"
clr="\[\e[0m\]"
pur="\[\e[38;2;180;100;255m\]"
blu="\[\e[38;2;122;162;247m\]"
orn="\[\e[38;2;224;175;104m\]"
grn="\[\e[38;2;158;206;104m\]"
lav="\[\e[38;2;187;154;247m\]"
cyn="\[\e[38;2;125;207;255m\]"
bgrn="\[\e[38;2;159;224;68m\]"
born="\[\e[38;2;250;186;74m\]"
bblu="\[\e[38;2;141;176;255m\]"

export LS_COLORS="$LS_COLORS:di=38;5;111:ln=38;5;183:ex=38;5;121:*.tar=38;5;180:bd=38;5;215:cd=38;5;111:so=38;5;159:pi=38;5;215"

# Display current Git branch in the Bash prompt
function git_branch() {
    if git rev-parse --is-inside-work-tree &>/dev/null; then
        printf "%s" "($(git symbolic-ref --short HEAD 2>/dev/null))"
    fi
}

# Set the prompt
function bash_prompt() {
    PS1="${grn}\u@\h ${blu}\w${lav}\$(git_branch)${orn} \$ ${clr}"
    #PS1="${blu}\$(git_branch)${pur} \W${grn} \$ ${clr}"
}

bash_prompt

eval "$(direnv hook bash)"
