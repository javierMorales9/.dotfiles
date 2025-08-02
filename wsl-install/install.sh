#!/usr/bin/env bash
#
# ATENCION: No esta probada porque no tenia una clean wsl a mano y
# me daba un perezote brutal probarlo.
# Si algo no te va, pregunta a este chat:
# https://chatgpt.com/c/688e9c23-00d4-8331-b618-bddff5fe2bb1
#
set -euo pipefail

# ========= Config básica =========
SCRIPT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="${HOME}/.dotfiles"
NVIM_SRC="${DOTFILES_DIR}/nvim/.config/nvim"
LOCAL_BIN="${HOME}/.local/bin"

ZSHRC_SRC="${SCRIPT_DIR}/.zshrc"       # tu .zshrc dentro de wsl-install
TMUXCONF_SRC="${SCRIPT_DIR}/.tmux.conf" # tu .tmux.conf dentro de wsl-install
TMUX_CHT_SRC="${SCRIPT_DIR}/tmux-cht.sh"
TMUX_SESS_SRC="${SCRIPT_DIR}/tmux-sessionizer"

timestamp() { date +"%Y%m%d-%H%M%S"; }

backup_if_regular() {
  local target="$1"
  if [ -e "$target" ] && [ ! -L "$target" ]; then
    mv -v "$target" "${target}.bak.$(timestamp)"
  fi
}

link() {
  local src="$1" dst="$2"
  mkdir -p "$(dirname "$dst")"
  backup_if_regular "$dst"
  ln -sfn "$src" "$dst"
  echo "symlink: $dst -> $src"
}

ensure_exec() { chmod +x "$1" 2>/dev/null || true; }

# ========= Paquetes del sistema =========
echo "[*] Actualizando APT e instalando paquetes base..."
sudo apt-get update -y
sudo apt-get install -y \
  git curl zsh fzf tmux neovim \
  build-essential gcc g++ clang make pkg-config \
  libssl-dev zlib1g-dev libbz2-dev libreadline-dev libsqlite3-dev \
  llvm libncursesw5-dev xz-utils tk-dev libxml2-dev libxmlsec1-dev \
  libffi-dev liblzma-dev ca-certificates

# ========= Starship en ~/.local/bin =========
if ! command -v starship >/dev/null 2>&1; then
  echo "[*] Instalando starship en ${LOCAL_BIN}..."
  mkdir -p "$LOCAL_BIN"
  curl -fsSL https://starship.rs/install.sh | bash -s -- -y -b "$LOCAL_BIN"
else
  echo "[=] starship ya instalado."
fi

# ========= NVM + Node LTS =========
if [ ! -d "${HOME}/.nvm" ]; then
  echo "[*] Instalando nvm..."
  curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
fi
export NVM_DIR="$HOME/.nvm"
# shellcheck disable=SC1091
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
nvm install --lts
nvm alias default 'lts/*'
nvm use default
echo "[=] Node: $(node -v), npm: $(npm -v)"

# ========= pyenv + último Python 3.x =========
if [ ! -d "${HOME}/.pyenv" ]; then
  echo "[*] Instalando pyenv..."
  git clone https://github.com/pyenv/pyenv.git "${HOME}/.pyenv"
fi
export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init -)"

LATEST_PY="$(pyenv install -l | sed 's/^[[:space:]]*//' | grep -E '^3\.[0-9]+\.[0-9]+$' | tail -1)"
echo "[*] Instalando Python ${LATEST_PY} con pyenv..."
pyenv install -s "${LATEST_PY}"
pyenv global "${LATEST_PY}"
hash -r
echo "[=] Python: $(python -V)"

# ========= oh-my-zsh + plugins =========
if [ ! -d "${HOME}/.oh-my-zsh" ]; then
  echo "[*] Instalando oh-my-zsh..."
  export RUNZSH=no
  export KEEP_ZSHRC=yes
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
else
  echo "[=] oh-my-zsh ya instalado."
fi
ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
mkdir -p "$ZSH_CUSTOM/plugins"
[ -d "${ZSH_CUSTOM}/plugins/zsh-syntax-highlighting" ] || \
  git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "${ZSH_CUSTOM}/plugins/zsh-syntax-highlighting"
[ -d "${ZSH_CUSTOM}/plugins/zsh-autosuggestions" ] || \
  git clone https://github.com/zsh-users/zsh-autosuggestions.git "${ZSH_CUSTOM}/plugins/zsh-autosuggestions"

# ========= Symlinks =========
echo "[*] Symlink de .zshrc y .tmux.conf..."
link "$ZSHRC_SRC"    "${HOME}/.zshrc"       # si quieres ~/.zshr, dímelo y cambio esto
link "$TMUXCONF_SRC" "${HOME}/.tmux.conf"

echo "[*] Symlink de configuración de Neovim..."
link "$NVIM_SRC" "${HOME}/.config/nvim"

echo "[*] Symlinks de utilidades tmux en ${LOCAL_BIN}..."
mkdir -p "$LOCAL_BIN"
link "$TMUX_CHT_SRC"  "${LOCAL_BIN}/tmux-cht.sh"
link "$TMUX_SESS_SRC" "${LOCAL_BIN}/tmux-sessionizer"
ensure_exec "${LOCAL_BIN}/tmux-cht.sh"
ensure_exec "${LOCAL_BIN}/tmux-sessionizer"

# ========= zsh como shell por defecto =========
if [ "${SHELL:-}" != "$(command -v zsh)" ]; then
  echo "[*] Estableciendo zsh como shell por defecto..."
  chsh -s "$(command -v zsh)" "$USER" || true
fi

echo
echo "[✓] Instalación completada. Abre una nueva terminal (o 'exec zsh') para aplicar todo."
