# ---------------------------
# wezterm-project-launcher.ps1
# ---------------------------
$baseDirs = @(
  "$HOME\General\Program"
  #,"$HOME\personal"
  #,"$HOME\sandbox"
  #,"$HOME\tutorials"
)

$allDirs = @()
foreach ($dir in $baseDirs) {
  if (Test-Path $dir) {
    $allDirs += Get-ChildItem -Directory -Path $dir -Recurse:$false | Select-Object -ExpandProperty FullName
  }
}

if (-not $allDirs) {
  Write-Host "No hay directorios válidos para seleccionar."
  exit 1
}

# Selección con fzf
$selected = $allDirs | fzf.exe
if (-not $selected) {
  exit 0
}

$selected_name = Split-Path $selected -Leaf -Resolve
$selected_name = $selected_name -replace '\.', '_' -replace '\s', '_'

# Verifica si ya hay un workspace con ese nombre
$weztermCli = "wezterm"
$existing = & $weztermCli cli list --format json | ConvertFrom-Json
$matchingPane = $existing | Where-Object { $_.workspace -eq $selected_name }

if ($matchingPane) {
  # Enviar OSC 1337 SetUserVar a **STDOUT en crudo** (NO Write-Host)
  $b64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($selected_name))
  $esc = [char]27
  $bel = [char]7
  $bytes = [Text.Encoding]::ASCII.GetBytes("$esc]1337;SetUserVar=WEZ_SWITCH_WS=$b64$bel")
  $stdout = [Console]::OpenStandardOutput()
  $stdout.Write($bytes, 0, $bytes.Length)
  $stdout.Flush()
  exit 0
}

Write-Host "[+] Lanzando nuevo workspace '$selected_name' en '$selected'"
Start-Process wezterm -ArgumentList @("cli","spawn","--new-window","--workspace",$selected_name,"--cwd",$selected)
