# Set default editor
export EDITOR='nano'

# Not an interactive shell?
[[ $- == *i* ]] || return 0

# Enhanced history handling

if [ -n "$BASH_VERSION" ]
then
    bind '"\e[A": history-search-backward'
    bind '"\e[B": history-search-forward'
fi

if [ -n "$ZSH_VERSIONN" ]
then
    bindkey "^[[A" history-beginning-search-backward
    bindkey "^[[B" history-beginning-search-forward
fi
