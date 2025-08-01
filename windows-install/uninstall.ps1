# =============================
# uninstall.ps1 – Desinstala terminal stack + Chocolatey (normal y portable)
# =============================
<#
  Este script desinstala:
    • Paquetes instalados con Chocolatey (WezTerm, Neovim, Node.js LTS, ripgrep)
    • Chocolatey clásico o portable
    • Symlink .wezterm.lua del perfil original (aunque se eleve a admin)

  Eleva permisos si es necesario y conserva el $HOME del usuario original.

  Uso:
    PS> ./uninstall.ps1
#>

param(
  [string]$originalUserHome
)

# -------------------------- Capturar usuario antes de escalar ----------------------------
if (-not $originalUserHome) {
  $originalUserHome = $env:USERPROFILE
  $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)

  if (-not $isAdmin) {
    Write-Host "[i] Re-lanzando como administrador..." -ForegroundColor Yellow
    $args = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$PSCommandPath`"", '-originalUserHome', "`"$originalUserHome`"")
    Start-Process -FilePath powershell.exe -ArgumentList $args -Verb RunAs
    exit
  }
}

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# -------------------------- Pregunta simple -------------------------------
function Ask-YesNo {
  param(
    [Parameter(Mandatory = $true)][string]$Question,
    [switch]$DefaultYes,
    [switch]$DefaultNo
  )

  $default = if ($DefaultYes) { "Y" } elseif ($DefaultNo) { "N" } else { "" }
  $suffix = if ($default -ne "") { " [$default/y/n]" } else { " [y/n]" }
  $answer = Read-Host "$Question$suffix"

  if ([string]::IsNullOrWhiteSpace($answer)) { $answer = $default }
  return ($answer.Trim().Substring(0,1).ToUpper() -eq "Y")
}

# -------------------------- Forzar desinstalación directa ------------------
function Uninstall-Package {
  param(
    [Parameter(Mandatory = $true)][string]$PackageName,
    [Parameter(Mandatory = $true)][string]$DisplayName
  )

  Write-Host "Quieres desinstalar $DisplayName"
  if (Ask-YesNo "?" -DefaultYes) {
    Write-Host "[..] Ejecutando desinstalación de $DisplayName..." -ForegroundColor Yellow
    try {
      choco uninstall $PackageName -y | Out-Null
      Write-Host "[OK] Desinstalación de $DisplayName finalizada." -ForegroundColor Green
    } catch {
      Write-Host "[ERROR] Fallo al desinstalar $DisplayName." -ForegroundColor Red
    }
  } else {
    Write-Host "[i] Saltando $DisplayName." -ForegroundColor DarkGray
  }
}

# -------------------------- Eliminar symlink wezterm.lua --------------------
function Remove-TargetIfDirOrSymlink {
  param (
    [string]$target
  )

  <#
    This function deletes the specified target **only if** it is a directory or a symbolic link.
    - Regular files (non-symlinks) are ignored.
    - Both symlinked files and symlinked directories will be removed.
    - Directories (even non-symlinks) will be deleted recursively.
  #>

  if (-not (Test-Path $target)) {
    Write-Host "[i] Target $target does not exist." -ForegroundColor Gray
    return
  }

  $item = Get-Item $target -Force

  Write-Host "Thing to remove $item"
  if ($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint -or $item.PSIsContainer) {
    $type = if ($item.PSIsContainer) { "directory" } else { "symlink" }
    Write-Host "[..] Removing $type $target" -ForegroundColor Yellow
    Remove-Item $target -Recurse -Force
  } else {
    Write-Host "[i] Skipping regular file $target" -ForegroundColor DarkGray
  }
}

function Remove-Dir {
  param(
    
  )
}

# -------------------------- Eliminar Chocolatey y portable ------------------
function Remove-Chocolatey {
  $locations = @(
    "C:\ProgramData\chocolatey",
    "C:\ProgramData\chocoportable"
  )

  foreach ($path in $locations) {
    if (Test-Path $path) {
      if (Ask-YesNo "¿Quieres eliminar Chocolatey en '$path'?" -DefaultNo) {
        try {
          Stop-Process -Name choco -Force -ErrorAction SilentlyContinue
        } catch {}

        try {
          Remove-Item -Recurse -Force $path -ErrorAction SilentlyContinue
          Write-Host "[OK] Carpeta '$path' eliminada." -ForegroundColor Green
        } catch {
          Write-Host "[ERROR] No se pudo eliminar $path." -ForegroundColor Red
        }

        $currentPath = [Environment]::GetEnvironmentVariable("Path", "Machine")
        $newPath = ($currentPath -split ';') -notmatch [Regex]::Escape($path) -join ';'
        [Environment]::SetEnvironmentVariable("Path", $newPath, "Machine")

        Write-Host "[OK] Eliminado del PATH del sistema." -ForegroundColor Green
      }
    }
  }

  $chocoExe = Get-Command choco -ErrorAction SilentlyContinue
  if ($chocoExe) {
    Write-Host "[WARN] El ejecutable 'choco.exe' sigue en: $($chocoExe.Source)" -ForegroundColor Red
    if (Ask-YesNo "¿Quieres intentar eliminarlo?" -DefaultYes) {
      try {
        Remove-Item $chocoExe.Source -Force
        Write-Host "[OK] 'choco.exe' eliminado." -ForegroundColor Green
      } catch {
        Write-Host "[ERROR] No se pudo eliminar el ejecutable." -ForegroundColor Red
      }
    }
  }
}

# -------------------------- MAIN ---------------------------------------------

Uninstall-Package 'wezterm'     'WezTerm'
Uninstall-Package 'neovim'      'Neovim'
Uninstall-Package 'nodejs-lts'  'Node.js LTS'
Uninstall-Package 'ripgrep'     'ripgrep'
Uninstall-Package 'llvm'        'Clang (LLVM)'

Remove-TargetIfDirOrSymlink -target (Join-Path $originalUserHome '.wezterm.lua')
Remove-TargetIfDirOrSymlink -target (Join-Path $originalUserHome 'AppData\Local\nvim')
Remove-TargetIfDirOrSymlink -target (Join-Path $originalUserHome 'AppData\Local\nvim-data')
Remove-Chocolatey

Write-Host ""
Write-Host "[OK] Desinstalación completada." -ForegroundColor Green

Write-Host "[OK] Desinstlación completada." -ForegroundColor Green
Ask-YesNo "Pincha cualquier tecla para finiquitar" -DefaultYes