# =============================
# uninstall.ps1  –  Revert everything
# =============================
<####################################################################
    Removes the software installed by install.ps1 and deletes the
    symlink .wezterm.lua if it points inside your dotfiles repo.
####################################################################>
Param()

Ensure‑Admin  #  reuse the function above (PowerShell allows duplicate definitions)

$PackagesToRemove = @('wezterm','neovim','nodejs-lts','ripgrep')
foreach ($pkg in $PackagesToRemove) {
  if (choco list --local-only --exact $pkg | Select‑String "^$pkg ") {
    if (Ask‑YesNo "Uninstall $pkg?" ) {
      Write‑Host "[→] Uninstalling $pkg …" -Foreground Cyan
      choco uninstall $pkg -y
    }
  } else {
    Write‑Host "[i] $pkg not installed; skipping." -Foreground Yellow
  }
}

# Remove symlink if it exists and resolves to dotfiles repo
if (Test‑Path $LinkFile -PathType Leaf) {
  $linkInfo = Get‑Item $LinkFile -Force
  if ($linkInfo.LinkType -eq 'SymbolicLink' -and $linkInfo.Target -like "$RepoRoot*" ) {
    if (Ask‑YesNo "Remove symlink $LinkFile?" ) {
      Remove‑Item $LinkFile
      Write‑Host "[✓] Symlink removed." -Foreground Green
    }
  }
}

Write‑Host "\n===  Uninstall finished.  ===" -Foreground Green
################################################################################
