export ZSH="/usr/share/oh-my-zsh"
ZSH_THEME="robbyrussell"

plugins=(git fzf extract)

source "$ZSH/oh-my-zsh.sh"

alias make="make -j$(nproc)"
alias ninja="ninja -j$(nproc)"
alias n="ninja"
alias c="clear"
alias rmpkg="sudo pacman -Rsn"
alias cleanch="sudo pacman -Scc"
alias fixpacman="sudo rm /var/lib/pacman/db.lck"
alias update="sudo pacman -Syu"
alias apt="man pacman"
alias apt-get="man pacman"
alias please="sudo"
alias tb="nc termbin.com 9999"
alias cleanup="sudo pacman -Rsn $(pacman -Qtdq)"
alias jctl="journalctl -p 3 -xb"
alias rip="expac --timefmt='%Y-%m-%d %T' '%l\t%n %v' | sort | tail -200 | nl"
