# =============================
# install.ps1  –  Fresh Windows bootstrap
# =============================
<####################################################################
    This script installs your terminal & editor stack on a brand‑new
    Windows box.  It will...
        • Ensure it is running as Administrator (auto‑relaunch if not)
        • Install / upgrade Chocolatey
        • Optionally install  –  WezTerm ▸ Neovim ▸ Node.js (LTS) ▸ ripgrep
        • Create a symbolic link  $HOME\.wezterm.lua → <repo>\wezterm\.wezterm.lua
    How to run:
        PS> Set-ExecutionPolicy Bypass -Scope Process -Force
        PS> ./install.ps1
####################################################################>

Param()

#-----------------------------  Helper: Elevate  -----------------------------#
function Ensure‑Admin {
  $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent())
               .IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
  if (-not $isAdmin) {
    Write‑Host "[i] Re‑launching with elevated privileges …" -Foreground Yellow
    Start‑Process powershell "-NoProfile -ExecutionPolicy Bypass -File `\"$PSCommandPath`\"" -Verb RunAs
    exit
  }
}
Ensure‑Admin

#-----------------------------  Helper: Ask‑YesNo  ---------------------------#
function Ask‑YesNo ($Question, [switch]$DefaultYes) {
  $default = $DefaultYes ? "Y" : "N"
  $answer  = Read‑Host "$Question [$default/y/n]"
  if ([string]::IsNullOrWhiteSpace($answer)) { $answer = $default }
  return $answer.Trim().Substring(0,1).ToUpper() -eq "Y"
}

#-----------------------------  Chocolatey  ---------------------------------#
function Install‑Chocolatey {
  if (Get‑Command choco -ErrorAction SilentlyContinue) {
    Write‑Host "[✓] Chocolatey already installed." ‑Foreground Green
    return
  }
  if (-not (Ask‑YesNo "Chocolatey not found. Install now?" -DefaultYes)) { return }
  Write‑Host "[→] Installing Chocolatey …" -Foreground Cyan
  Set‑ExecutionPolicy Bypass -Scope Process -Force
  [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
  Invoke‑Expression ((New‑Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
  Write‑Host "[✓] Chocolatey installed." -Foreground Green
}
Install‑Chocolatey

#-----------------------------  Packages  ------------------------------------#
$Packages = @(
  @{Name='wezterm';        Friendly='WezTerm terminal';    Src='choco' },
  @{Name='neovim';         Friendly='Neovim';              Src='choco' },
  @{Name='nodejs-lts';     Friendly='Node.js (LTS)';       Src='choco' },
  @{Name='ripgrep';        Friendly='ripgrep';             Src='choco' }
)

function Install‑PackageIfWanted ($pkg) {
  $name  = $pkg.Name
  $label = $pkg.Friendly
  $already = choco list --local-only --exact $name | Select‑String "^$name "
  if ($already) {
    Write‑Host "[✓] $label already present." -Foreground Green
    return
  }
  if (-not (Ask‑YesNo "Install $label?" -DefaultYes)) { return }
  Write‑Host "[→] Installing $label …" -Foreground Cyan
  choco install $name -y --ignore-checksums
}

foreach ($p in $Packages) { Install‑PackageIfWanted $p }

#-----------------------------  Symlink .wezterm.lua  ------------------------#
$RepoRoot   = Split‑Path -Parent $PSCommandPath   # assumes script lives inside the repo
$TargetFile = Join‑Path $RepoRoot "wezterm\.wezterm.lua"
$LinkFile   = Join‑Path $HOME    ".wezterm.lua"

if (-not (Test‑Path $TargetFile)) {
  Write‑Host "[!] Expected config $TargetFile not found. Skipping symlink." -Foreground Yellow
} else {
  if (Test‑Path $LinkFile) {
    Write‑Host "[i] $LinkFile already exists → skipping link creation." -Foreground Yellow
  } else {
    if (Ask‑YesNo "Create symlink $LinkFile → $TargetFile?" -DefaultYes) {
      Write‑Host "[→] Creating symlink …" -Foreground Cyan
      cmd /c mklink "$LinkFile" "$TargetFile"  | Out‑Null
      Write‑Host "[✓] Symlink created." -Foreground Green
    }
  }
}

Write‑Host "\n===  Setup complete!  ===" -Foreground Green
