#!/usr/bin/env bash
set -euo pipefail

LOCAL_BIN="${HOME}/.local/bin"
NVIM_DST="${HOME}/.config/nvim"

remove_if_symlink() {
  local path="$1"
  if [ -L "$path" ]; then
    echo "unlink: $path"
    rm -f "$path"
  else
    echo "skip (no es symlink): $path"
  fi
}

echo "[*] Quitando symlinks..."
remove_if_symlink "${HOME}/.zshrc"
remove_if_symlink "${HOME}/.tmux.conf"
remove_if_symlink "${LOCAL_BIN}/tmux-cht.sh"
remove_if_symlink "${LOCAL_BIN}/tmux-sessionizer"
[ -L "$NVIM_DST" ] && rm -f "$NVIM_DST" || echo "skip (no es symlink): $NVIM_DST"

echo "[*] Eliminando instalaciones de usuario (nvm, pyenv, oh-my-zsh, starship)..."
rm -rf "${HOME}/.nvm"
rm -rf "${HOME}/.pyenv"
rm -rf "${HOME}/.oh-my-zsh"
rm -f  "${LOCAL_BIN}/starship"
rm -f  "${HOME}/.config/starship.toml" || true

echo "[*] Cambiando shell por defecto a bash antes de purgar zsh..."
if command -v chsh >/dev/null 2>&1; then
  chsh -s /bin/bash "$USER" || true
fi

echo "[*] Purga de paquetes instalados con apt..."
sudo apt-get remove --purge -y \
  fzf tmux neovim zsh \
  build-essential gcc g++ clang make pkg-config \
  libssl-dev zlib1g-dev libbz2-dev libreadline-dev libsqlite3-dev \
  llvm libncursesw5-dev xz-utils tk-dev libxml2-dev libxmlsec1-dev \
  libffi-dev liblzma-dev || true

sudo apt-get autoremove -y || true
sudo apt-get autoclean -y || true

echo "[✓] Desinstalación completada."
