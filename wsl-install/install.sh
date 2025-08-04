#!/usr/bin/env bash
#
# Instalador para WSL Ubuntu con Neovim >= 0.10 desde tarball oficial en /opt.
# Mantiene tu estructura de dotfiles y utilidades.
#
# Requisitos: sudo, conexión a internet.
# Idempotente: reintentar es seguro (usa ln -sfn, backups y checks).
#
set -euo pipefail

# ========= Config =========
SCRIPT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="${HOME}/.dotfiles"
NVIM_SRC="${DOTFILES_DIR}/nvim/.config/nvim"
LOCAL_BIN="${HOME}/.local/bin"

ZSHRC_SRC="${SCRIPT_DIR}/.zshrc"
TMUXCONF_SRC="${SCRIPT_DIR}/.tmux.conf"
TMUX_CHT_SRC="${SCRIPT_DIR}/tmux-cht.sh"
TMUX_SESS_SRC="${SCRIPT_DIR}/tmux-sessionizer"

NVIM_TARBALL_URL="https://github.com/neovim/neovim/releases/latest/download/nvim-linux-x86_64.tar.gz"
NVIM_OPT_DIR="/opt"
NVIM_SYMLINK_DIR="${NVIM_OPT_DIR}/nvim"                # symlink estable -> /opt/nvim-<vers>
NVIM_USR_BIN="/usr/local/bin/nvim"                     # symlink del ejecutable
NVIM_TMP_DIR="${NVIM_OPT_DIR}/nvim-linux-x86_64"       # carpeta temporal tras extraer

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

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || { echo "[-] Necesitas '$1' para continuar." >&2; exit 1; }
}

# ========= Detecta WSL (solo a título informativo) =========
if grep -qiE "microsoft|wsl" /proc/version 2>/dev/null; then
  echo "[=] WSL detectado."
fi

# ========= Paquetes del sistema (sin 'neovim') =========
echo "[*] Actualizando APT e instalando paquetes base..."
sudo apt-get update -y
sudo apt-get install -y \
  git curl zsh fzf tmux unzip \
  software-properties-common ca-certificates gnupg \
  ripgrep fd-find \
  build-essential gcc g++ clang make pkg-config \
  libssl-dev zlib1g-dev libbz2-dev libreadline-dev libsqlite3-dev \
  llvm libncursesw5-dev xz-utils tk-dev libxml2-dev libxmlsec1-dev \
  libffi-dev liblzma-dev

# Alias 'fd' para 'fdfind' en Ubuntu
mkdir -p "$LOCAL_BIN"
if ! command -v fd >/dev/null 2>&1; then
  ln -sfn "$(command -v fdfind)" "${LOCAL_BIN}/fd" || true
fi

# ========= Neovim desde tarball oficial en /opt =========
install_neovim_tarball() {
  echo "[*] Instalando Neovim >= 0.10 desde tarball en ${NVIM_OPT_DIR}..."
  require_cmd curl
  tmp_tar="/tmp/nvim-linux-x86_64.tar.gz"
  curl -fL "$NVIM_TARBALL_URL" -o "$tmp_tar"

  # Limpia directorio temporal previo y extrae en /opt
  sudo rm -rf "${NVIM_TMP_DIR}"
  sudo tar -C "${NVIM_OPT_DIR}" -xzf "$tmp_tar"

  # Detecta versión real desde el binario extraído
  if [ ! -x "${NVIM_TMP_DIR}/bin/nvim" ]; then
    echo "[-] No se encontró ${NVIM_TMP_DIR}/bin/nvim tras extraer." >&2
    exit 1
  fi
  NVIM_VER_RAW="$("${NVIM_TMP_DIR}/bin/nvim" -v | awk 'NR==1{print $2}')"
  NVIM_VER="${NVIM_VER_RAW#v}"  # quita 'v' inicial si existe
  if [[ -z "$NVIM_VER" ]]; then
    echo "[-] No pude detectar la versión de Neovim." >&2
    exit 1
  fi

  # Mueve a carpeta versionada y crea symlinks estables
  local target_dir="${NVIM_OPT_DIR}/nvim-${NVIM_VER}"
  sudo rm -rf "$target_dir"
  sudo mv "${NVIM_TMP_DIR}" "$target_dir"

  # /opt/nvim -> /opt/nvim-<vers>
  sudo ln -sfn "$target_dir" "${NVIM_SYMLINK_DIR}"
  # /usr/local/bin/nvim -> /opt/nvim/bin/nvim
  sudo ln -sfn "${NVIM_SYMLINK_DIR}/bin/nvim" "${NVIM_USR_BIN}"

  # Comprueba versión mínima 0.10
  if ! "${NVIM_USR_BIN}" --version | awk '
    NR==1{
      ver=$2; sub(/^v/,"",ver);
      n=split(ver,a,".");
      major=a[1]+0; minor=a[2]+0;
      if (major>0 || minor>=10) exit 0; else exit 1
    }'
  then
    echo "[-] Neovim instalado es < 0.10. Revisa el tarball usado." >&2
    exit 1
  fi

  echo "[=] Neovim ${NVIM_VER} instalado."
}

# Desinstala neovim de APT si está para evitar sombras en /usr/bin
if dpkg -s neovim >/dev/null 2>&1; then
  echo "[*] Quitando neovim de APT para evitar conflictos..."
  sudo apt-get remove -y neovim || true
  sudo apt-get autoremove -y || true
fi

install_neovim_tarball

# ========= Starship en ~/.local/bin =========
if ! command -v starship >/dev/null 2>&1; then
  echo "[*] Instalando starship en ${LOCAL_BIN}..."
  mkdir -p "$LOCAL_BIN"
  curl -fsSL https://starship.rs/install.sh | sh -s -- -y -b "$LOCAL_BIN"
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
eval "$("$PYENV_ROOT/bin/pyenv" init -)"

LATEST_PY="$("$PYENV_ROOT/bin/pyenv" install -l | sed 's/^[[:space:]]*//' | grep -E '^3\.[0-9]+\.[0-9]+$' | tail -1)"
echo "[*] Instalando Python ${LATEST_PY} con pyenv..."
"$PYENV_ROOT/bin/pyenv" install -s "${LATEST_PY}"
"$PYENV_ROOT/bin/pyenv" global "${LATEST_PY}"
hash -r
echo "[=] Python: $(python -V)"
python -m pip install --user --upgrade pip pynvim >/dev/null 2>&1 || true

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
link "$ZSHRC_SRC"    "${HOME}/.zshrc"
link "$TMUXCONF_SRC" "${HOME}/.tmux.conf"

echo "[*] Symlink de configuración de Neovim..."
link "$NVIM_SRC" "${HOME}/.config/nvim"

echo "[*] Symlinks de utilidades tmux en ${LOCAL_BIN}..."
mkdir -p "$LOCAL_BIN"
link "$TMUX_CHT_SRC"  "${LOCAL_BIN}/tmux-cht.sh"
link "$TMUX_SESS_SRC" "${LOCAL_BIN}/tmux-sessionizer"
ensure_exec "${LOCAL_BIN}/tmux-cht.sh"
ensure_exec "${LOCAL_BIN}/tmux-sessionizer"

# ========= Asegura PATHs útiles =========
# /usr/local/bin suele preceder a /usr/bin por defecto; añadimos ~/.local/bin si falta
if ! grep -q 'export PATH="$HOME/.local/bin:$PATH"' "${HOME}/.zshrc" 2>/dev/null; then
  echo 'export PATH="$HOME/.local/bin:$PATH"' >> "${HOME}/.zshrc"
fi

# ========= zsh como shell por defecto =========
if [ "${SHELL:-}" != "$(command -v zsh)" ]; then
  echo "[*] Estableciendo zsh como shell por defecto..."
  chsh -s "$(command -v zsh)" "$USER" || true
fi

# ========= Resumen =========
echo
echo "========== RESUMEN =========="
echo "[=] nvim: $(command -v nvim)"
nvim --version | head -n1
echo "[=] Node: $(node -v)"
echo "[=] Python: $(python -V | awk '{print $2}')"
echo "[=] Starship: $(command -v starship >/dev/null && starship --version | head -n1 || echo 'no instalado')"
echo "[=] zsh: $(zsh --version | awk '{print $1, $2}')"
echo "[=] fzf: $(fzf --version | head -n1)"
echo "[=] ripgrep: $(rg --version | head -n1)"
echo
echo "[✓] Instalación completada. Abre una nueva terminal (o 'exec zsh')."
echo "    Dentro de Neovim, ejecuta ':checkhealth' y ':Lazy sync' si usas lazy.nvim."
