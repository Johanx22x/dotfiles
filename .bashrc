#
# ~/.bashrc
#


# If not running interactively, don't do anything
[[ $- != *i* ]] && return

alias neo='neofetch --backend ascii --source ~/ascii/nier.txt'
alias clock='tty-clock -c'
alias vi='nvim'
alias ls='exa --icons'
PS1='[\u@\h \W]\$ '
export PATH=~/go/bin:$PATH

#ADD OpenCV in PKG_CONFIG
PKG_CONFIG_PATH=/usr/local/lib/pkgconfig:
export PKG_CONFIG_PATH

# >>> conda initialize >>>
# !! Contents within this block are managed by 'conda init' !!
# __conda_setup="$('/home/johan/anaconda3/bin/conda' 'shell.bash' 'hook' 2> /dev/null)"
# if [ $? -eq 0 ]; then
#     eval "$__conda_setup"
# else
#     if [ -f "/home/johan/anaconda3/etc/profile.d/conda.sh" ]; then
#         . "/home/johan/anaconda3/etc/profile.d/conda.sh"
#     else
#         export PATH="/home/johan/anaconda3/bin:$PATH"
#     fi
# fi
# unset __conda_setup
# <<< conda initialize <<<

. "$HOME/.cargo/env"

