#
# ~/.bashrc
#

# Process no more commands if non-interactive shell:
[[ $- != *i* ]] && return

########################################
# Prompt

# Function to rebuild the shell prompt:
function _bash_prompt {
    local pwdmaxlen=25
    # Indicate that there has been dir truncation
    local trunc_symbol=".."
    local dir=${PWD##*/}
    pwdmaxlen=$(( ( pwdmaxlen < ${#dir} ) ? ${#dir} : pwdmaxlen ))
    NEW_PWD=${PWD/#$HOME/\~}
    local pwdoffset=$(( ${#NEW_PWD} - pwdmaxlen ))
    if [ ${pwdoffset} -gt "0" ]
    then
        NEW_PWD=${NEW_PWD:$pwdoffset:$pwdmaxlen}
        NEW_PWD=${trunc_symbol}/${NEW_PWD#*/}
    fi

    case $TERM in
     xterm*|rxvt*)
         local TITLEBAR='\[\033]0;\u:${NEW_PWD}\007\]'
         ;;
     *)
         local TITLEBAR=""
         ;;
    esac
    local NONE="\[\033[0m\]"    # unsets color to term's fg color

    # regular colors
    local K="\[\033[0;30m\]"    # black
    local R="\[\033[0;31m\]"    # red
    local G="\[\033[0;32m\]"    # green
    local Y="\[\033[0;33m\]"    # yellow
    local B="\[\033[0;34m\]"    # blue
    local M="\[\033[0;35m\]"    # magenta
    local C="\[\033[0;36m\]"    # cyan
    local W="\[\033[0;37m\]"    # white

    # emphasized (bolded) colors
    local EMK="\[\033[1;30m\]"
    local EMR="\[\033[1;31m\]"
    local EMG="\[\033[1;32m\]"
    local EMY="\[\033[1;33m\]"
    local EMB="\[\033[1;34m\]"
    local EMM="\[\033[1;35m\]"
    local EMC="\[\033[1;36m\]"
    local EMW="\[\033[1;37m\]"

    # background colors
    local BGK="\[\033[40m\]"
    local BGR="\[\033[41m\]"
    local BGG="\[\033[42m\]"
    local BGY="\[\033[43m\]"
    local BGB="\[\033[44m\]"
    local BGM="\[\033[45m\]"
    local BGC="\[\033[46m\]"
    local BGW="\[\033[47m\]"

    local UC=$W                 # user's color
    [ $UID -eq "0" ] && UC=$R   # root's color

    if [ -z "${VIRTUAL_ENV}" ]; then
        # without colors: PS1="[\u@\h \${NEW_PWD}]\\$ "
        # extra backslash in front of \$ to make bash colorize the prompt
        PS1="${TITLEBAR}${EMK}[${UC}\u${EMK}@${UC}\h ${EMB}\${NEW_PWD}${EMK}]${UC}\\$ ${NONE}"
    else
        # For pythonistas
        PS1="${TITLEBAR}${EMK}[${UC}(`basename ${VIRTUAL_ENV}`)${EMK} ${EMB}\${NEW_PWD}${EMK}]${UC}\\$ ${NONE}"
    fi
}
_bash_prompt # Execute it immediately...

########################################
# Aliases

if [ ${TERM} != "dumb" ]; then
    # Directory listing shortcuts and color
    if [ -x /usr/bin/dircolors ]; then
        eval $( dircolors -b | sed -r "1s/';\$/${ADD_LS_COLORS}';/" )
        unset ADD_LS_COLORS
        alias ls='ls --group-directories-first --human-readable -v --color=always'
    else
        alias ls='ls --group-directories-first --human-readable -v '
    fi

    # Pacman color
    if [ -x /usr/bin/pacman-color ]; then
        alias pacman='pacman-color'
    fi

    alias diff='colordiff'
    alias grep='grep --color'
    alias egrep='egrep --color'
    alias fgrep='fgrep --color'
fi

alias la='ls --almost-all'
alias ll='ls -l'
alias lq='ls --quote-name'
alias lr='ls --recursive'
alias lrt='ls --reverse -lt'

# Application/convenience shortcuts:
alias j='jobs -l'
alias df='df --human-readable'
alias du='du --human-readable'
alias mkdir='mkdir --parents'
alias nano='nano --autoindent --nohelp --nowrap'
alias tree='tree --dirsfirst -v'
alias usage='du --summarize -k * | sort --numeric-sort'
alias whois='whois -H'

# File operation safety measure:
alias cp='cp -i'
alias mv='mv -i'
alias rm='rm -i'

# Microsoft DOS commands:
alias cls='clear'
alias del='rm'
alias dir='ls'
alias edit=${EDITOR}
alias md='mkdir'
alias rd='rmdir'

# Typographical errors:
alias cd..='cd ..'

########################################
# History

# Settings for bash history:
export HISTIGNORE='&:cd:[bf]g:exit:clear:cls:ls:ll:la:reset'
export HISTSIZE=10000
export HISTFILESIZE=10000
export HISTCONTROL='ignorespace:erasedups'

########################################
# Shell Options

shopt -sq autocd
shopt -sq cdspell
shopt -sq checkwinsize
shopt -sq cmdhist
shopt -sq dotglob
shopt -sq expand_aliases
shopt -sq histappend
shopt -sq hostcomplete
shopt -sq no_empty_cmd_completion
shopt -sq nocaseglob

########################################
# Input Options

# Prevent use of software flow control keys:
/bin/stty start undef # Usually ^S by default.
/bin/stty stop  undef # Usually ^Q by default.

########################################
# Limits

# Limit number of processes (Protection against fork bombs).
#ulimit -u 5000

########################################
# Pager Settings

# Specify options for the less pager:
export LESS='-MQRSi -#5'

# Use lesspipe to make less more friendly for non-text input files:
[ -x '/usr/bin/lesspipe.sh' ] && eval "$(SHELL=/bin/bash lesspipe.sh)"
[ -x '/usr/bin/lesspipe' ] && eval "$(SHELL=/bin/bash lesspipe)"

# Less Colors for Man Pages
# http://linuxtidbits.wordpress.com/2009/03/23/less-colors-for-man-pages/
export LESS_TERMCAP_mb=$'\E[01;31m'       # begin blinking
export LESS_TERMCAP_md=$'\E[01;38;5;74m'  # begin bold
export LESS_TERMCAP_me=$'\E[0m'           # end mode
export LESS_TERMCAP_se=$'\E[0m'           # end standout-mode
export LESS_TERMCAP_so=$'\E[38;5;246m'    # begin standout-mode - info box
export LESS_TERMCAP_ue=$'\E[0m'           # end underline
export LESS_TERMCAP_us=$'\E[04;38;5;146m' # begin underline

PROMPT_COMMAND=_bash_prompt

# virtualenv wrapper
export WORKON_HOME=${HOME}/Snakepit
if [ -f /usr/local/bin/virtualenvwrapper.sh ]; then
    source /usr/local/bin/virtualenvwrapper.sh
elif [ -f /usr/bin/virtualenvwrapper.sh ]; then
    source /usr/bin/virtualenvwrapper.sh
fi
