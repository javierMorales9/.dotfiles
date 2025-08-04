#!/usr/bin/env bash
set -euo pipefail

# Flags
DRY_RUN=0
ASSUME_YES=0
KEEP_APT=0

while (( "$#" )); do
  case "$1" in
    --dry-run) DRY_RUN=1; shift ;;
    -y|--yes) ASSUME_YES=1; shift ;;
    --keep-apt) KEEP_APT=1; shift ;;
    -h|--help)
      cat <<'EOF'
Uso: wsl-uninstall.sh [opciones]

Opciones:
  --dry-run     Muestra lo que haría, sin borrar nada.
  -y, --yes     No pedir confirmaciones (modo no interactivo).
  --keep-apt    Conserva los paquetes APT (no los purga).
  -h, --help    Esta ayuda.

Esta uninstall revierte lo instalado por el script de install:
- Neovim (tarball en /opt/nvim-<vers>, symlink /opt/nvim y /usr/local/bin/nvim)
- Symlinks: ~/.zshrc, ~/.tmux.conf, ~/.config/nvim, ~/.local/bin/tmux-cht.sh, ~/.local/bin/tmux-sessionizer
- nvm + Node, pyenv + Python, oh-my-zsh, starship (+ ~/.config/starship.toml)
- Alias fd -> fdfind en ~/.local/bin/fd
- Línea PATH añadida al final de ~/.zshrc: export PATH="$HOME/.local/bin:$PATH"
- (Por defecto) purga los paquetes APT que instaló install, a menos que uses --keep-apt
EOF
      exit 0
      ;;
    *) echo "Opción no reconocida: $1" >&2; exit 1 ;;
  esac
done

confirm() {
  local msg="$1"
  if [ "$ASSUME_YES" -eq 1 ]; then return 0; fi
  read -r -p "$msg [y/N]: " ans
  [[ "$ans" == "y" || "$ans" == "Y" ]]
}

do_rm() {
  if [ "$DRY_RUN" -eq 1 ]; then
    echo "DRY-RUN rm -rf -- $*"
  else
    rm -rf -- "$@"
  fi
}

do_sudo_rm() {
  if [ "$DRY_RUN" -eq 1 ]; then
    echo "DRY-RUN sudo rm -rf -- $*"
  else
    sudo rm -rf -- "$@"
  fi
}

unlink_if_symlink() {
  local path="$1"
  if [ -L "$path" ]; then
    echo "unlink: $path"
    if [ "$DRY_RUN" -eq 0 ]; then rm -f "$path"; fi
  else
    echo "skip (no es symlink): $path"
  fi
}

# --- Paths usados por install ---
LOCAL_BIN="${HOME}/.local/bin"
NVIM_DST="${HOME}/.config/nvim"

echo "[*] Quitando symlinks de dotfiles y utilidades..."
unlink_if_symlink "${HOME}/.zshrc"
unlink_if_symlink "${HOME}/.tmux.conf"
unlink_if_symlink "${NVIM_DST}"
unlink_if_symlink "${LOCAL_BIN}/tmux-cht.sh"
unlink_if_symlink "${LOCAL_BIN}/tmux-sessionizer"

# alias 'fd' -> 'fdfind' que crea el install
if [ -L "${LOCAL_BIN}/fd" ]; then
  target="$(readlink -f "${LOCAL_BIN}/fd" || true)"
  if echo "$target" | grep -q "/fdfind$"; then
    echo "unlink: ${LOCAL_BIN}/fd"
    if [ "$DRY_RUN" -eq 0 ]; then rm -f "${LOCAL_BIN}/fd"; fi
  else
    echo "skip (fd no apunta a fdfind): ${LOCAL_BIN}/fd -> ${target}"
  fi
else
  echo "skip (no es symlink): ${LOCAL_BIN}/fd"
fi

echo "[*] Eliminando instalaciones de usuario (nvm, pyenv, oh-my-zsh, starship)..."
if confirm "¿Borrar ~/.nvm, ~/.pyenv, ~/.oh-my-zsh, ~/.local/bin/starship y ~/.config/starship.toml?"; then
  do_rm "${HOME}/.nvm"
  do_rm "${HOME}/.pyenv"
  do_rm "${HOME}/.oh-my-zsh"
  [ -f "${LOCAL_BIN}/starship" ] && do_rm "${LOCAL_BIN}/starship"
  [ -f "${HOME}/.config/starship.toml" ] && do_rm "${HOME}/.config/starship.toml"
else
  echo "skip: instalaciones de usuario conservadas."
fi

echo "[*] Revirtiendo shell por defecto a bash (si procede)..."
if command -v chsh >/dev/null 2>&1; then
  if [ "$DRY_RUN" -eq 0 ]; then chsh -s /bin/bash "$USER" || true; fi
  echo "shell por defecto -> /bin/bash (si estaba en zsh)."
else
  echo "skip: 'chsh' no disponible."
fi

# --- Neovim instalado por tarball en /opt ---
echo "[*] Eliminando Neovim de /opt (tarball + symlinks)..."

# /usr/local/bin/nvim -> /opt/nvim/bin/nvim
if [ -L "/usr/local/bin/nvim" ]; then
  target="$(readlink -f /usr/local/bin/nvim || true)"
  if echo "$target" | grep -q "^/opt/nvim/bin/nvim$"; then
    echo "unlink: /usr/local/bin/nvim"
    if [ "$DRY_RUN" -eq 0 ]; then sudo rm -f /usr/local/bin/nvim; fi
  else
    echo "skip: /usr/local/bin/nvim apunta a ${target} (no lo toco)."
  fi
else
  echo "skip: /usr/local/bin/nvim no es symlink."
fi

# /opt/nvim (symlink estable)
if [ -L "/opt/nvim" ]; then
  echo "unlink: /opt/nvim"
  do_sudo_rm "/opt/nvim"
else
  echo "skip: /opt/nvim no es symlink."
fi

# /opt/nvim-* (carpetas versionadas)
if ls -d /opt/nvim-* >/dev/null 2>&1; then
  for d in /opt/nvim-*; do
    if [ -d "$d" ] && [ -x "$d/bin/nvim" ]; then
      echo "rm -rf: $d"
      do_sudo_rm "$d"
    fi
  done
else
  echo "skip: no hay /opt/nvim-*"
fi

# Por si quedó el layout antiguo /opt/nvim-linux-x86_64
if [ -d "/opt/nvim-linux-x86_64" ]; then
  echo "rm -rf: /opt/nvim-linux-x86_64"
  do_sudo_rm "/opt/nvim-linux-x86_64"
fi

# --- Línea PATH añadida por install ---
if [ -f "${HOME}/.zshrc" ] && [ ! -L "${HOME}/.zshrc" ]; then
  if grep -Fxq 'export PATH="$HOME/.local/bin:$PATH"' "${HOME}/.zshrc"; then
    echo "[*] Limpiando línea PATH añadida en ~/.zshrc"
    if [ "$DRY_RUN" -eq 1 ]; then
      echo "DRY-RUN sed -i '/^export PATH=\"\\$HOME\\/\\.local\\/bin:\\$PATH\"\$/d' ~/.zshrc"
    else
      sed -i '/^export PATH="\$HOME\/\.local\/bin:\$PATH"$/d' "${HOME}/.zshrc"
    fi
  else
    echo "skip: no encontré la línea PATH añadida por install en ~/.zshrc"
  fi
fi

# --- APT: purgar lo instalado por install (a menos que pidas conservar) ---
if [ "$KEEP_APT" -eq 1 ]; then
  echo "[*] Conservando paquetes APT (por --keep-apt)."
else
  echo "[*] Purga de paquetes APT instalados por install..."
  if confirm "¿Purgar toolchain(dev), zsh, tmux, fzf, ripgrep, fdfind y utilidades?"; then
    pkgs=(
      git curl zsh fzf tmux ripgrep fd-find unzip
      software-properties-common ca-certificates gnupg
      build-essential gcc g++ clang make pkg-config
      libssl-dev zlib1g-dev libbz2-dev libreadline-dev libsqlite3-dev
      llvm libncursesw5-dev xz-utils tk-dev libxml2-dev libxmlsec1-dev
      libffi-dev liblzma-dev
    )
    if [ "$DRY_RUN" -eq 1 ]; then
      echo "DRY-RUN sudo apt-get remove --purge -y ${pkgs[*]}"
      echo "DRY-RUN sudo apt-get autoremove -y"
      echo "DRY-RUN sudo apt-get autoclean -y"
    else
      sudo apt-get remove --purge -y "${pkgs[@]}" || true
      sudo apt-get autoremove -y || true
      sudo apt-get autoclean -y || true
    fi
  else
    echo "skip: purga APT cancelada."
  fi
fi

echo "[✓] Desinstalación completada."
echo "Sugerencia: abre una nueva terminal (o 'exec bash' / 'exec zsh')."
