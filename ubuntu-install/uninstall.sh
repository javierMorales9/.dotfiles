#!/usr/bin/env bash
# =============================================================================
# uninstall.sh – Reversa del bootstrap (Ubuntu)
# =============================================================================
# Qué hace:
#   • Limpia symlinks si apuntan a <REPO_ROOT>
#   • Elimina Neovim en /opt + /usr/local/bin/nvim
#   • Desinstala paquetes (a menos que uses --keep-tools)
#   • Opcional: borra ~/.nvm, ~/.pyenv, ~/.oh-my-zsh, Poetry (pipx), Starship
#
# Uso:
#   chmod +x uninstall.sh
#   ./uninstall.sh [--repo-root PATH] [--remove-nvm] [--remove-pyenv] \
#                  [--remove-omz] [--remove-poetry] [--remove-starship] [--keep-tools]
# =============================================================================

set -euo pipefail

REPO_ROOT=""
REMOVE_PYENV="false"
REMOVE_NVM="false"
REMOVE_OMZ="false"
REMOVE_POETRY="false"
REMOVE_STARSHIP="false"
KEEP_TOOLS="false"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo-root) REPO_ROOT="$2"; shift 2 ;;
    --remove-pyenv) REMOVE_PYENV="true"; shift ;;
    --remove-nvm) REMOVE_NVM="true"; shift ;;
    --remove-omz) REMOVE_OMZ="true"; shift ;;
    --remove-poetry) REMOVE_POETRY="true"; shift ;;
    --remove-starship) REMOVE_STARSHIP="true"; shift ;;
    --keep-tools) KEEP_TOOLS="true"; shift ;;
    *) echo "Flag desconocida: $1" >&2; exit 1 ;;
  esac
done

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

detect_repo_root() {
  if [[ -n "$REPO_ROOT" ]]; then
    REPO_ROOT="$(cd "$REPO_ROOT" && pwd -P)"; return
  fi
  local script_dir; script_dir="$(cd -- "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd -P)"
  # uninstall.sh está en <REPO_ROOT>/ubuntu-install/, así que el root es ..
  if [[ -d "$script_dir/.." ]]; then REPO_ROOT="$(cd "$script_dir/.." && pwd -P)"; else REPO_ROOT="$script_dir"; fi
}

safe_unlink() {
  # safe_unlink <path> — sólo si es symlink y apunta a REPO_ROOT
  local target="$1"
  if [[ -L "$target" ]]; then
    local dst; dst="$(readlink -f "$target" || true)"
    if [[ -n "$dst" && "$dst" == "$REPO_ROOT"* ]]; then
      rm -f -- "$target"
      ok "Eliminado symlink: $target (-> $dst)"
    else
      warn "No elimino $target (no apunta a REPO_ROOT)."
    fi
  elif [[ -e "$target" ]]; then
    warn "$target no es symlink; lo conservo."
  fi
}

detect_repo_root
log "REPO_ROOT = $REPO_ROOT"

# ----------------------------- Symlinks --------------------------------------
safe_unlink "$HOME/.wezterm.lua"
safe_unlink "$HOME/.config/nvim"

# >>> CAMBIO: .zshrc apuntaba a ubuntu-install/.zshrc dentro de REPO_ROOT <<<
safe_unlink "$HOME/.zshrc"

# .zshenv (si lo enlazaste desde <REPO_ROOT>/zsh/.zshenv)
safe_unlink "$HOME/.zshenv"

# ----------------------------- Neovim en /opt --------------------------------
need_sudo
[[ -L /opt/nvim ]] && sudo rm -f /opt/nvim
if ls /opt/nvim-* >/dev/null 2>&1; then
  sudo rm -rf /opt/nvim-*
  ok "Eliminadas instalaciones de Neovim en /opt."
fi
[[ -e /usr/local/bin/nvim ]] && sudo rm -f /usr/local/bin/nvim

# ----------------------------- Paquetes del sistema ---------------------------
if [[ "$KEEP_TOOLS" == "true" ]]; then
  warn "KEEP_TOOLS: no desinstalo paquetes del sistema."
else
  need_sudo
  sudo apt-get remove -y wezterm || true
  sudo apt-get remove -y ripgrep fzf jq postgresql-client || true
  sudo apt-get remove -y clang clangd lldb lld || true
  sudo apt-get remove -y neovim || true
  sudo apt-get autoremove -y || true
  ok "Paquetes del sistema desinstalados (cuando procedía)."
fi

# ----------------------------- nvm / pyenv / omz / poetry / starship ----------
if [[ "$REMOVE_NVM" == "true" ]]; then
  rm -rf "$HOME/.nvm"
  ok "Eliminado ~/.nvm"
fi
if [[ "$REMOVE_PYENV" == "true" ]]; then
  rm -rf "$HOME/.pyenv"
  ok "Eliminado ~/.pyenv"
fi
if [[ "$REMOVE_OMZ" == "true" ]]; then
  rm -rf "$HOME/.oh-my-zsh"
  ok "Eliminado ~/.oh-my-zsh"
fi
if [[ "$REMOVE_POETRY" == "true" ]] && command -v pipx >/dev/null 2>&1; then
  pipx uninstall poetry || true
  ok "Poetry desinstalado via pipx"
fi
if [[ "$REMOVE_STARSHIP" == "true" ]]; then
  need_sudo
  sudo apt-get remove -y starship || true
  rm -f "$HOME/.local/bin/starship" 2>/dev/null || true
  ok "Starship eliminado (apt/local)."
fi

# ----------------------------- ~/bin -----------------------------------------
if [[ -d "$HOME/bin" && -z "$(ls -A "$HOME/bin")" ]]; then
  rmdir "$HOME/bin" && ok "Eliminado ~/bin (estaba vacío)."
fi

ok "Desinstalación completada."
