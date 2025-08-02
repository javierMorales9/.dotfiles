# ---------- Coloración de ls ----------
export LS_COLORS="rs=0:di=01;34:ln=01;36:mh=00:pi=40;33:so=01;35:do=01;35:bd=40;33;01:cd=40;33;01:or=40;31;01:mi=00:su=37;41:sg=30;43:ca=30;41:tw=30;42:ow=34;42:st=37;44:ex=01;32:*.tar=01;31:*.tgz=01;31:*.arc=01;31:*.arj=01;31:*.taz=01;31:*.lha=01;31:*.lz4=01;31:*.lzh=01;31:*.lzma=01;31:*.tlz=01;31:*.txz=01;31:*.tzo=01;31:*.t7z=01;31:*.zip=01;31:*.z=01;31:*.dz=01;31:*.gz=01;31:*.lrz=01;31:*.lz=01;31:*.lzo=01;31:*.xz=01;31:*.zst=01;31:*.tzst=01;31:*.bz2=01;31:*.bz=01;31:*.tbz=01;31:*.tbz2=01;31:*.tz=01;31:*.deb=01;31:*.rpm=01;31:*.jar=01;31:*.war=01;31:*.ear=01;31:*.sar=01;31:*.rar=01;31:*.alz=01;31:*.ace=01;31:*.zoo=01;31:*.cpio=01;31:*.7z=01;31:*.rz=01;31:*.cab=01;31:*.wim=01;31:*.swm=01;31:*.dwm=01;31:*.esd=01;31:*.jpg=01;35:*.jpeg=01;35:*.mjpg=01;35:*.mjpeg=01;35:*.gif=01;35:*.bmp=01;35:*.pbm=01;35:*.pgm=01;35:*.ppm=01;35:*.tga=01;35:*.xbm=01;35:*.xpm=01;35:*.tif=01;35:*.tiff=01;35:*.png=01;35:*.svg=01;35:*.svgz=01;35:*.mng=01;35:*.pcx=01;35:*.mov=01;35:*.mpg=01;35:*.mpeg=01;35:*.m2v=01;35:*.mkv=01;35:*.webm=01;35:*.ogm=01;35:*.mp4=01;35:*.m4v=01;35:*.mp4v=01;35:*.vob=01;35:*.qt=01;35:*.nuv=01;35:*.wmv=01;35:*.asf=01;35:*.rm=01;35:*.rmvb=01;35:*.flc=01;35:*.avi=01;35:*.fli=01;35:*.flv=01;35:*.gl=01;35:*.dl=01;35:*.xcf=01;35:*.xwd=01;35:*.yuv=01;35:*.cgm=01;35:*.emf=01;35:*.ogv=01;35:*.ogx=01;35:*.aac=00;36:*.au=00;36:*.flac=00;36:*.m4a=00;36:*.mid=00;36:*.midi=00;36:*.mka=00;36:*.mp3=00;36:*.mpc=00;36:*.ogg=00;36:*.ra=00;36:*.wav=00;36:*.oga=00;36:*.opus=00;36:*.spx=00;36:*.xspf=00;36:"

# ---------- XDG ----------
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"

# ---------- oh-my-zsh ----------
export ZSH="$HOME/.oh-my-zsh"
plugins=(
  git
  zsh-syntax-highlighting
  zsh-autosuggestions
  poetry
)
[[ -s "$ZSH/oh-my-zsh.sh" ]] && source "$ZSH/oh-my-zsh.sh"

# ---------- fzf keybindings/completion (Ubuntu) ----------
[[ -f /usr/share/doc/fzf/examples/key-bindings.zsh ]] && source /usr/share/doc/fzf/examples/key-bindings.zsh
[[ -f /usr/share/doc/fzf/examples/completion.zsh    ]] && source /usr/share/doc/fzf/examples/completion.zsh

# ---------- PATH ----------
typeset -U path PATH
path+=("$HOME/bin" "$HOME/.local/bin" "$HOME/.local/share/ponyup/bin" "$HOME/.pulumi/bin" "$HOME/personal/sumneko/bin" "/usr/local/go/bin" "$HOME/go/bin")
export PATH

# ---------- WSL helpers ----------
if [[ -n "$WT_SESSION" ]] && grep -qiE 'microsoft|wsl' /proc/sys/kernel/osrelease 2>/dev/null; then
  chpwd() {
    emulate -L zsh
    echo -en '\e]9;9;"'
    wslpath -w "$PWD" | tr -d '\n'
    echo -en '"\x07'
  }
fi

# ---------- Starship prompt ----------
if command -v starship >/dev/null 2>&1; then
  eval "$(starship init zsh)"
fi

# ---------- Aliases ----------
alias vim='nvim'
alias python='python3'
alias pv='pipenv'
alias stdocker='sudo service docker start'

alias ga='git add .'
alias gbD='git branch -D'
alias gbu='git branch --unset-upstream'
alias gb='git branch'
alias gc='git add .; git commit -m '
alias gcam='git commit -am'
alias gcm='git commit -m'
alias gca='git commit --amend --no-edit'
alias gco='git checkout'
alias gd='git diff'
alias gfa='git fetch --all -prune'
alias gl='git pull'
alias gp='git push'
alias gpup='git push -u origin '
alias gst='git status -s'
alias glog='git --no-pager log --oneline -10'
alias grst='git reset --hard HEAD'
alias gm='git merge'
alias gdif='git --no-pager diff'
alias gdifl='gdif HEAD~1 HEAD'
alias grt='git reset --hard HEAD'

# ---------- tmux keybinding ----------
bindkey -s '^f' "tmux-sessionizer\n"

# ---------- PNPM (si lo tienes instalado) ----------
export PNPM_HOME="$HOME/.local/share/pnpm"
case ":$PATH:" in
  *":$PNPM_HOME:"*) ;;
  *) export PATH="$PNPM_HOME:$PATH" ;;
esac

# ---------- Conda (si está instalado) ----------
if [[ -x "$HOME/miniconda3/bin/conda" ]]; then
  __conda_setup="$("$HOME/miniconda3/bin/conda" 'shell.zsh' 'hook' 2> /dev/null)"
  if [[ $? -eq 0 ]]; then
    eval "$__conda_setup"
  elif [[ -f "$HOME/miniconda3/etc/profile.d/conda.sh" ]]; then
    . "$HOME/miniconda3/etc/profile.d/conda.sh"
  else
    export PATH="$HOME/miniconda3/bin:$PATH"
  fi
  unset __conda_setup
fi

# ---------- rbenv (si está instalado) ----------
if command -v rbenv >/dev/null 2>&1; then
  export PATH="$HOME/.rbenv/bin:$PATH"
  eval "$(rbenv init - zsh)"
fi

# ---------- nvm ----------
export NVM_DIR="$HOME/.nvm"
[[ -s "$NVM_DIR/nvm.sh" ]] && . "$NVM_DIR/nvm.sh"

# ---------- pyenv ----------
export PYENV_ROOT="$HOME/.pyenv"
if [[ -d "$PYENV_ROOT" ]]; then
  export PATH="$PYENV_ROOT/bin:$PATH"
  if command -v pyenv >/dev/null 2>&1; then
    eval "$(pyenv init - zsh)"
  fi
fi

# ---------- WebStorm (WSL) ----------
if grep -qiE 'microsoft|wsl' /proc/sys/kernel/osrelease 2>/dev/null; then
  alias webstorm='/mnt/c/Program\ Files/JetBrains/WebStorm\ 2022.1.4/bin/webstorm64.exe'
fi
