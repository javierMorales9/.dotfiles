#!/usr/bin/env bash
# =============================================================================
# install.sh – Bootstrap Ubuntu (idempotente, no interactivo)
# =============================================================================
# Qué hace:
#   • Asegura: zsh (default shell), ~/bin, ~/.config
#   • Instala base: git, curl, jq, ripgrep, fzf, tmux, postgresql-client,
#     build-essential + dependencias de pyenv, clang/clangd/lldb/lld
#   • Node LTS con nvm (default)
#   • Python 3.x más reciente con pyenv (global) + pipx + Poetry (via pipx)
#   • Neovim última estable en /opt/nvim + /usr/local/bin/nvim (o --system-nvim)
#   • WezTerm (apt si existe, si no .deb oficial)
#   • Instala oh-my-zsh + plugins (autosuggestions, syntax-highlighting)
#   • Crea symlinks:
#       ~/.config/nvim -> <REPO_ROOT>/nvim/.config/nvim
#       ~/.wezterm.lua -> <REPO_ROOT>/wezterm/.wezterm.lua
#       ~/.zshrc       -> <REPO_ROOT>/ubuntu-install/.zshrc   <<< CAMBIO
#       ~/.zshenv      -> <REPO_ROOT>/zsh/.zshenv             (si existe)
#
# Uso:
#   chmod +x install.sh
#   ./install.sh [--repo-root PATH] [--system-nvim] [--system-python] [--skip-wezterm]
# =============================================================================

set -euo pipefail

# ----------------------------- Flags -----------------------------------------
REPO_ROOT=""
USE_SYSTEM_NVIM="false"
USE_SYSTEM_PYTHON="false"
SKIP_WEZTERM="false"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo-root) REPO_ROOT="$2"; shift 2 ;;
    --system-nvim) USE_SYSTEM_NVIM="true"; shift ;;
    --system-python) USE_SYSTEM_PYTHON="true"; shift ;;
    --skip-wezterm) SKIP_WEZTERM="true"; shift ;;
    *) echo "Flag desconocida: $1" >&2; exit 1 ;;
  esac
done

# ----------------------------- Helpers ---------------------------------------
log()  { printf "\033[1;34m[INFO]\033[0m %s\n" "$*"; }
ok()   { printf "\033[1;32m[ OK ]\033[0m %s\n" "$*"; }
warn() { printf "\033[1;33m[WARN]\033[0m %s\n" "$*"; }
err()  { printf "\033[1;31m[ERR ]\033[0m %s\n" "$*" >&2; }

need_cmd() { command -v "$1" >/dev/null 2>&1; }
need_sudo() {
  if [[ $EUID -ne 0 ]]; then
    if need_cmd sudo; then sudo -v; else err "Necesito sudo"; exit 1; fi
  fi
}
ensure_dir() { [[ -d "$1" ]] || mkdir -p "$1"; }

link_to() {
  # link_to <src> <dst> (idempotente)
  local src="$1" dst="$2"
  if [[ -e "$dst" || -L "$dst" ]]; then
    if [[ -L "$dst" && "$(readlink -f "$dst")" == "$(readlink -f "$src")" ]]; then
      ok "Symlink ya correcto: $dst -> $src"; return 0
    fi
    warn "Existe $dst. Lo elimino para recrear symlink."
    rm -rf -- "$dst"
  fi
  ln -s "$src" "$dst"
  ok "Creado symlink: $dst -> $src"
}

apt_update_once() {
  if [[ -z "${__APT_UPDATED:-}" ]]; then
    need_sudo
    sudo apt-get update -y
    __APT_UPDATED=1
  fi
}
apt_install() {
  apt_update_once
  need_sudo
  DEBIAN_FRONTEND=noninteractive sudo apt-get install -y --no-install-recommends "$@"
}

detect_repo_root() {
  if [[ -n "$REPO_ROOT" ]]; then
    REPO_ROOT="$(cd "$REPO_ROOT" && pwd -P)"; return
  fi
  local script_dir; script_dir="$(cd -- "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd -P)"
  # Asumimos que install.sh está en <REPO_ROOT>/ubuntu-install/, así que el root es ..
  if [[ -d "$script_dir/.." ]]; then REPO_ROOT="$(cd "$script_dir/.." && pwd -P)"; else REPO_ROOT="$script_dir"; fi
}

ubuntu_version_id() { . /etc/os-release; echo "$VERSION_ID"; }

# ----------------------------- Pre-reqs base ---------------------------------
detect_repo_root
log "REPO_ROOT = $REPO_ROOT"

log "Instalando herramientas base y dependencias…"
apt_install ca-certificates gnupg lsb-release software-properties-common
apt_install git curl wget jq
apt_install ripgrep fzf tmux
apt_install postgresql-client
apt_install build-essential pkg-config
# deps de pyenv
apt_install make libssl-dev zlib1g-dev libbz2-dev libreadline-dev libsqlite3-dev \
            libncursesw5-dev xz-utils tk-dev libxml2-dev libxmlsec1-dev libffi-dev liblzma-dev
# clang/llvm del sistema
apt_install clang clangd lldb lld || true
# starship (si no está, pondremos fallback luego)
apt_install starship || true
# pipx
apt_install pipx || true
ok "Herramientas base listas."

# ----------------------------- Zsh + default shell ---------------------------
if ! need_cmd zsh; then
  log "Instalando zsh…"
  apt_install zsh
fi
if [[ -x "$(command -v zsh)" ]]; then
  CURRENT_SHELL="$(getent passwd "$USER" | cut -d: -f7 || echo "")"
  if [[ "$CURRENT_SHELL" != "$(command -v zsh)" ]]; then
    log "Cambiando shell por defecto a zsh para $USER…"
    chsh -s "$(command -v zsh)" "$USER" || warn "No pude cambiar shell por defecto (¿sesión no interactiva?)."
  fi
fi

# ----------------------------- Estructura HOME -------------------------------
ensure_dir "$HOME/bin"
ensure_dir "$HOME/.config"

# ----------------------------- oh-my-zsh + plugins ---------------------------
if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
  log "Instalando oh-my-zsh (unattended)…"
  RUNZSH=no CHSH=no KEEP_ZSHRC=yes sh -c \
    "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
else
  ok "oh-my-zsh ya está presente."
fi

ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
ensure_dir "$ZSH_CUSTOM/plugins"

# zsh-autosuggestions
if [[ -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ]]; then
  log "Actualizando zsh-autosuggestions…"
  git -C "$ZSH_CUSTOM/plugins/zsh-autosuggestions" pull --ff-only || true
else
  log "Instalando zsh-autosuggestions…"
  git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions \
    "$ZSH_CUSTOM/plugins/zsh-autosuggestions"
fi

# zsh-syntax-highlighting
if [[ -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ]]; then
  log "Actualizando zsh-syntax-highlighting…"
  git -C "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" pull --ff-only || true
else
  log "Instalando zsh-syntax-highlighting…"
  git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting \
    "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"
fi

# ----------------------------- Symlinks dotfiles -----------------------------
log "Creando symlinks a tu repo…"
[[ -d "$REPO_ROOT/nvim/.config/nvim" ]] && link_to "$REPO_ROOT/nvim/.config/nvim" "$HOME/.config/nvim" || warn "No existe $REPO_ROOT/nvim/.config/nvim"
[[ -f "$REPO_ROOT/wezterm/.wezterm.lua" ]] && link_to "$REPO_ROOT/wezterm/.wezterm.lua" "$HOME/.wezterm.lua" || warn "No existe $REPO_ROOT/wezterm/.wezterm.lua"

# >>> CAMBIO: .zshrc ahora vive en ubuntu-install/.zshrc <<<
[[ -f "$REPO_ROOT/ubuntu-install/.zshrc" ]] && link_to "$REPO_ROOT/ubuntu-install/.zshrc" "$HOME/.zshrc" || warn "No existe $REPO_ROOT/ubuntu-install/.zshrc"

# .zshenv (opcional, si lo mantienes en zsh/.zshenv)
if [[ -f "$REPO_ROOT/zsh/.zshenv" ]]; then
  link_to "$REPO_ROOT/zsh/.zshenv" "$HOME/.zshenv"
fi

# ----------------------------- Node: nvm + LTS -------------------------------
if ! need_cmd bash; then err "bash no está disponible y es requerido para nvm."; exit 1; fi
if [[ ! -d "$HOME/.nvm" ]]; then
  log "Instalando nvm…"
  curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
else
  ok "nvm ya está presente."
fi
export NVM_DIR="$HOME/.nvm"
[[ -s "$NVM_DIR/nvm.sh" ]] && . "$NVM_DIR/nvm.sh"
if ! need_cmd node; then
  log "Instalando Node LTS…"
  nvm install --lts
  nvm alias default "lts/*"
else
  ok "Node ya instalado. Asegurando LTS por defecto…"
  nvm install --lts >/dev/null 2>&1 || true
  nvm alias default "lts/*" || true
fi

# ----------------------------- Python: pyenv + última 3.x --------------------
if [[ "$USE_SYSTEM_PYTHON" == "true" ]]; then
  ok "Omitiendo pyenv; usarás python3 del sistema."
else
  if [[ ! -d "$HOME/.pyenv" ]]; then
    log "Instalando pyenv…"
    curl -fsSL https://pyenv.run | bash
  else
    ok "pyenv ya está presente."
  fi

  export PYENV_ROOT="$HOME/.pyenv"
  export PATH="$PYENV_ROOT/bin:$PATH"
  if command -v pyenv >/dev/null 2>&1; then
    log "Resolviendo última Python 3.x en pyenv…"
    latest_py=$(pyenv install -l | grep -E '^\s*3\.[0-9]+\.[0-9]+$' | tr -d ' ' | tail -n 1)
    if [[ -n "${latest_py:-}" ]]; then
      if ! pyenv versions --bare | grep -q "^${latest_py}\$"; then
        log "Compilando Python ${latest_py} (tarda)…"
        CFLAGS="-O3" pyenv install -s "$latest_py"
      fi
      pyenv global "$latest_py"
      ok "Python global fijado a ${latest_py}."
    else
      warn "No pude resolver la última 3.x; deja pyenv sin global."
    fi
  else
    warn "pyenv no está en PATH durante la instalación; revisa tu zshrc/zshenv."
  fi

  # Poetry (via pipx)
  if command -v pipx >/dev/null 2>&1; then
    if pipx list 2>/dev/null | grep -q 'package poetry'; then
      log "Actualizando Poetry…"
      pipx upgrade poetry || true
    else
      log "Instalando Poetry…"
      pipx install poetry || true
    fi
  else
    warn "pipx no está disponible; Poetry no se instalará."
  fi
fi

# ----------------------------- Neovim: última estable ------------------------
if [[ "$USE_SYSTEM_NVIM" == "true" ]]; then
  log "Instalando Neovim desde apt (puede ser antiguo)…"
  apt_install neovim
else
  log "Instalando Neovim última estable en /opt/nvim…"
  need_sudo
  tmpdir="$(mktemp -d)"; trap 'rm -rf "$tmpdir"' EXIT
  tag=$(curl -fsSL https://api.github.com/repos/neovim/neovim/releases/latest | jq -r .tag_name)
  if [[ -z "$tag" || "$tag" == "null" ]]; then err "No pude resolver la última release de Neovim."; exit 1; fi
  curl -fsSL -o "$tmpdir/nvim.tar.gz" "https://github.com/neovim/neovim/releases/download/${tag}/nvim-linux64.tar.gz"
  tar -C "$tmpdir" -xzf "$tmpdir/nvim.tar.gz"
  sudo rm -rf /opt/nvim /opt/nvim-*
  sudo mv "$tmpdir/nvim-linux64" "/opt/nvim-${tag#v}"
  sudo ln -sfn "/opt/nvim-${tag#v}" /opt/nvim
  sudo ln -sfn /opt/nvim/bin/nvim /usr/local/bin/nvim
  ok "Neovim ${tag} instalado."
fi

# ----------------------------- WezTerm ---------------------------------------
if [[ "$SKIP_WEZTERM" == "true" ]]; then
  ok "Omitiendo WezTerm (--skip-wezterm)."
else
  if apt-cache show wezterm >/dev/null 2>&1; then
    log "Instalando WezTerm desde apt…"
    apt_install wezterm || true
  fi
  if ! need_cmd wezterm; then
    log "Instalando WezTerm vía .deb oficial…"
    ver_id="$(ubuntu_version_id)"
    arch="amd64"
    case "$ver_id" in
      2[4-9].* ) ubuntu_tag="Ubuntu24.04" ;;
      22.* ) ubuntu_tag="Ubuntu22.04" ;;
      * ) ubuntu_tag="Ubuntu20.04" ;;
    esac
    tmpdir2="$(mktemp -d)"; trap 'rm -rf "$tmpdir2"' EXIT
    api="https://api.github.com/repos/wez/wezterm/releases/latest"
    deb_url=$(curl -fsSL "$api" | jq -r --arg ut "$ubuntu_tag" --arg arch "$arch" '
      .assets[] | select(.name | test($ut) and test($arch) and endswith(".deb")) | .browser_download_url' | head -n1)
    if [[ -z "$deb_url" ]]; then err "No encontré .deb de WezTerm para $ubuntu_tag/$arch"; exit 1; fi
    curl -fsSL -o "$tmpdir2/wezterm.deb" "$deb_url"
    need_sudo
    sudo apt-get install -y --no-install-recommends "$tmpdir2/wezterm.deb" || sudo dpkg -i "$tmpdir2/wezterm.deb"
    sudo apt-get -f install -y || true
    ok "WezTerm instalado."
  else
    ok "WezTerm ya está instalado."
  fi
fi

# ----------------------------- Starship fallback -----------------------------
if ! command -v starship >/dev/null 2>&1; then
  log "Instalando Starship con script oficial…"
  curl -fsSL https://starship.rs/install.sh | sh -s -- -y
fi

ok "Instalación completada. Abre una nueva sesión de terminal (zsh) para cargar todo."
