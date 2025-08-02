# =============================
# install.ps1  –  Bootstrap de entorno terminal/editor
# =============================
<#
  Este script:
    • Eleva permisos si es necesario.
    • Instala Chocolatey si no está.
    • Instala opcionalmente: WezTerm, Neovim, Node.js LTS, ripgrep.
    • Crea symlink: $HOME\.wezterm.lua -> <repo>\wezterm\.wezterm.lua

  Usa $originalUserHome para escribir en el perfil del usuario original (no admin).

  Uso:
    PS> ./install.ps1
#>

param(
  [string]$originalUserHome
)
if(-not $originalUserHome) {
  $originalUserHome = $env:USERPROFILE
}

Write-Host "Usuario: $originalUserHome"

$binDir = Join-Path $originalUserHome "bin"
if (-not (Test-Path $binDir)) {
  Write-Host "[..] Creando directorio $binDir" -ForegroundColor Yellow
  New-Item -ItemType Directory -Path $binDir | Out-Null

  $currentPath = [Environment]::GetEnvironmentVariable("PATH", "User")
  if ($currentPath -notlike "*$binDir*") {
    $newPath = "$currentPath;$binDir"
    [Environment]::SetEnvironmentVariable("PATH", $newPath, "User")
    Write-Host "[OK] Añadido $binDir al PATH de usuario. Reinicia la terminal para que surta efecto." -ForegroundColor Green
  } else {
    Write-Host "[i] $binDir ya está en el PATH de usuario." -ForegroundColor Gray
  }
}

# -------------------------- Elevación + captura del usuario ----------------------------
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
if (-not $isAdmin) {
  Write-Host "[i] Re-lanzando como administrador..." -ForegroundColor Yellow
  $args = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$PSCommandPath`"", '-originalUserHome', "`"$originalUserHome`"")
  Start-Process -FilePath powershell.exe -ArgumentList $args -Verb RunAs
  exit
}

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# ----------------------------  Helper: Pregunta  ---------------------------
function Ask-YesNo {
  param(
    [Parameter(Mandatory = $true)][string]$Question,
    [switch]$DefaultYes
  )
  $default = if ($DefaultYes) { "Y" } else { "N" }
  $answer  = Read-Host "$Question [$default/y/n]"
  if ([string]::IsNullOrWhiteSpace($answer)) { $answer = $default }
  return ($answer.Trim().Substring(0,1).ToUpper() -eq "Y")
}

# ----------------------------  Chocolatey  ----------------------------------
function Install-Chocolatey {
  if (Get-Command choco -ErrorAction SilentlyContinue) {
    Write-Host "[OK] Chocolatey ya está instalado." -ForegroundColor Green
    return
  }

  Write-Host "[..] Instalando Chocolatey..." -ForegroundColor Yellow
  Set-ExecutionPolicy Bypass -Scope Process -Force
  [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
  Invoke-Expression (
    (New-Object Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1')
  )

  if (Get-Command choco -ErrorAction SilentlyContinue) {
    Write-Host "[OK] Chocolatey instalado correctamente." -ForegroundColor Green
  } else {
    Write-Host "[ERROR] No se pudo instalar Chocolatey." -ForegroundColor Red
    throw "Fallo al instalar Chocolatey."
  }
}

# ----------------------------  Instalaciones opcionales  ---------------------------
function Install-PackageIfConfirmed {
  param(
    [Parameter(Mandatory = $true)][string]$PackageName,
    [Parameter(Mandatory = $true)][string]$DisplayName
  )

  Write-Host "¿Quieres instalar $DisplayName"
  if (Ask-YesNo "?" -DefaultYes) {
    Write-Host "[..] Instalando $DisplayName..." -ForegroundColor Yellow
    choco install $PackageName -y
  } else {
    Write-Host "[i] Saltando $DisplayName." -ForegroundColor DarkGray
  }
}

# ----------------------------  Symlink wezterm.lua -------------------------
function Create-Link {
  param(
    [Parameter(Mandatory = $true)][string]$source,
    [Parameter(Mandatory = $true)][string]$target
  )

  if (Test-Path $target) {
    Write-Host "[i] Ya existe $target. Eliminando..." -ForegroundColor DarkYellow
    Remove-Item $target -Force
  }

  Write-Host "[..] Creando symlink: $target -> $source" -ForegroundColor Yellow
  New-Item -ItemType SymbolicLink -Path $target -Target $source | Out-Null
}

# ----------------------------  MAIN  ----------------------------------------
Install-Chocolatey

Install-PackageIfConfirmed 'wezterm'     'WezTerm'
Install-PackageIfConfirmed 'jq'          'jq'
Install-PackageIfConfirmed 'neovim'      'Neovim'
Install-PackageIfConfirmed 'nodejs-lts'  'Node.js LTS'
Install-PackageIfConfirmed 'ripgrep'     'ripgrep'
Install-PackageIfConfirmed 'fzf'         'fzf'
Install-PackageIfConfirmed 'psql'        'psql'
Install-PackageIfConfirmed 'llvm'        'Clang (LLVM)'

$nvimConfigSrc = Join-Path $PSScriptRoot '..\nvim\.config\nvim'
$nvimConfigDest = Join-Path $originalUserHome 'AppData\Local\nvim'
Create-Link $nvimConfigSrc $nvimConfigDest

$weztermSrc = Join-Path $PSScriptRoot '..\wezterm\.wezterm.lua'
$weztermDest = Join-Path $originalUserHome '.wezterm.lua'
Create-Link $weztermSrc $weztermDest

$fzfSrc = Join-Path $PSScriptRoot '.\wezterm-project-launcher.ps1'
$fzfDst = Join-Path $binDir "wezterm-launcher.ps1"
Create-Link $fzfSrc $fzfDst

Write-Host "[OK] Instalación completada." -ForegroundColor Green
Ask-YesNo "Pincha cualquier tecla para finiquitar" -DefaultYes
