[[ $- != *i* ]] && return

# Cursor shape
printf '\e[34 q'

# Prompt
if command -v starship >/dev/null 2>&1; then
  eval "$(starship init bash)"
fi

# Directory jumping
if command -v zoxide >/dev/null 2>&1; then
  eval "$(zoxide init bash)"
fi

# Environment
export CLAUDE_CODE_MAX_OUTPUT_TOKENS=64000
export EDITOR=micro

if [ -d "$HOME/.android/bin" ]; then
  export PATH="$HOME/.android/bin:$PATH"
fi

if [ -d "$HOME/.local/share/pi-node" ]; then
  node_bin="$(find "$HOME/.local/share/pi-node" -maxdepth 1 -type d -name 'node-*' | sort | tail -n 1)/bin"
  [ ! -d "$node_bin" ] || export PATH="$node_bin:$PATH"
fi

if [ -d "$HOME/.lmstudio/bin" ]; then
  export PATH="$PATH:$HOME/.lmstudio/bin"
fi

# Short aliases
alias nrs='sudo nixos-rebuild switch --flake .#nixbox'
alias l='eza -al --icons'
alias rebuild='sudo nixos-rebuild switch --flake "$HOME/Documents/nixos#nixbox"'
alias m='udisksctl mount -b '
alias ad='asciidoctor -a source-highlighter=rouge '
alias battery='acpi --battery --details'
alias bigFiles='du -ahx . | sort -h | nl'
alias cmatrix='cmatrix -bu 6'
alias cpufreq='watch grep "cpu MHz" /proc/cpuinfo'
alias fingerprint='sudo fprintd-enroll "$(whoami)"'
alias gpg-check='gpg --keyserver-options auto-key-retrieve --verify'
alias gpg-retrieve='gpg --keyserver-options auto-key-retrieve --receive-keys'
alias grep='grep --color=auto'
alias gs='git status'
alias journalInfo='journalctl -p 3 -xb'
alias mnt='udisksctl mount -b '
alias partuuid='ls -l /dev/disk/by-partuuid'
alias polkitStatus='pgrep -af polkit'
alias sf='sudo systemctl --failed'
alias ss='sudo systemctl start'
alias st='sudo systemctl status'
alias userlist='cut -d: -f1 /etc/passwd'
alias wget='wget -c'

# Btrfs
alias bbalance='sudo btrfs balance start /'
alias bbalanceStatus='sudo btrfs balance status /'
alias bdefrag='sudo btrfs filesystem defragment -r /'
alias bfree='sudo btrfs filesystem usage /'
alias bscrub='sudo btrfs scrub start /'
alias bscrubStatus='sudo btrfs scrub status /'

# Archive extractor
ex() {
  if [ -f "$1" ]; then
    case "$1" in
      *.tar.bz2) tar xjf "$1" ;;
      *.tar.gz) tar xzf "$1" ;;
      *.bz2) bunzip2 "$1" ;;
      *.rar) unrar x "$1" ;;
      *.gz) gunzip "$1" ;;
      *.tar) tar xf "$1" ;;
      *.tbz2) tar xjf "$1" ;;
      *.tgz) tar xzf "$1" ;;
      *.zip) unzip "$1" ;;
      *.Z) uncompress "$1" ;;
      *.7z) 7z x "$1" ;;
      *.deb) ar x "$1" ;;
      *.tar.xz) tar xf "$1" ;;
      *.tar.zst) unzstd "$1" ;;
      *) echo "'$1' cannot be extracted via ex()" ;;
    esac
  else
    echo "'$1' is not a valid file"
  fi
}


# Pi
export PATH="$HOME/.local/bin:$PATH"

# Qt 6 theme integration (qt6ct)
export QT_QPA_PLATFORMTHEME=qt6ct
