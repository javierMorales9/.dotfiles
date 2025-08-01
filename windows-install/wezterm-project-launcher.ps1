<#
  wezterm-project-launcher.ps1
  ---------------------------------
  PURPOSE
  -------
  • Interactive project switcher for WezTerm users on Windows.
  • Lets you fuzzy-search a list of project folders (via **fzf**),
    then either:
      – jump to the corresponding **workspace** if it already exists, or
      – create a brand-new workspace (and window) in that directory
        and immediately switch to it.

  HOW IT WORKS
  ------------
  1.  Build a list of candidate directories (`$baseDirs`).
  2.  Pipe that list into **fzf** so the user can pick one.
  3.  Derive a *workspace name* from the folder’s basename
      (dots and spaces replaced by underscores).
  4.  Ask the WezTerm **mux** for the current panes/workspaces:
        wezterm cli list --format json
  5.  If the desired workspace is already present:
        – Emit an OSC 1337 *user variable*  
           `SetUserVar=WEZ_SWITCH_WS=<base64(workspace)> BEL`  
           to stdout.  
        – A handler in `~/.wezterm.lua` listens for that variable and
          calls `SwitchToWorkspace { name = value }`, so the UI changes
          instantly without opening a new window.
  6.  If the workspace does **not** exist:
        – Spawn a **new window** in that workspace without stealing
          focus:  
           `wezterm cli spawn --new-window --workspace … --cwd …`
        – Poll the mux until the workspace is registered.
        – Emit the same OSC 1337 variable to switch once it’s ready.
  7.  All execution happens **inside an existing WezTerm pane**, so
      there’s always a mux to talk to; the script never blocks your
      current prompt.

  PREREQUISITES
  -------------
  • WezTerm running (at least one window open).
  • fzf.exe in PATH.
  • A handler in `~/.wezterm.lua` like:

      local wezterm = require 'wezterm'
      local act = wezterm.action
      wezterm.on('user-var-changed', function(win, pane, name, val)
        if name == 'WEZ_SWITCH_WS' and val and #val > 0 then
          win:perform_action(act.SwitchToWorkspace { name = val }, pane)
        end
      end)

  USAGE
  -----
  • Put this script somewhere in `$HOME\bin` and ensure that directory
    is in your user PATH, or create a `.cmd` wrapper.
  • From any WezTerm pane, run:

        wezterm-launcher     # or whatever alias/cmd you chose

    Pick a project, and you’ll land in the correct workspace
    (creating it if necessary) within seconds.

  AUTHOR  : Javier Morales de Vera
  LICENSE : MIT (optional)
#>

function Send-WezSwitchWs {
  param([Parameter(Mandatory=$true)][string]$WorkspaceName)
  $b64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($WorkspaceName))
  $esc = [char]27; $bel = [char]7
  $bytes = [Text.Encoding]::ASCII.GetBytes("$esc]1337;SetUserVar=WEZ_SWITCH_WS=$b64$bel")
  $stdout = [Console]::OpenStandardOutput()
  $stdout.Write($bytes, 0, $bytes.Length)
  $stdout.Flush()
}

function Get-WeztermListJson {
  $json = & wezterm cli list --format json 2>$null
  if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($json)) { return @() }
  try { return $json | ConvertFrom-Json } catch { return @() }
}

function Wait-WorkspaceRegistered {
  param(
    [Parameter(Mandatory=$true)][string]$WorkspaceName,
    [int]$TimeoutMs = 3000,
    [int]$IntervalMs = 100
  )
  $deadline = [DateTime]::UtcNow.AddMilliseconds($TimeoutMs)
  while ([DateTime]::UtcNow -lt $deadline) {
    $list = Get-WeztermListJson
    if ($list | Where-Object { $_.workspace -eq $WorkspaceName }) { return $true }
    Start-Sleep -Milliseconds $IntervalMs
  }
  return $false
}

# --- selección con fzf ---
$baseDirs = @(
  "$HOME\General\Program"
)

$allDirs = @()
foreach ($dir in $baseDirs) {
  if (Test-Path $dir) {
    $allDirs += Get-ChildItem -Directory -Path $dir -Recurse:$false | Select-Object -ExpandProperty FullName
  }
}

if (-not $allDirs) {
  Write-Host "No valid directories to select"
  exit 1
}

$selected = $allDirs | fzf.exe
if (-not $selected) { exit 0 }

$selected_name = Split-Path $selected -Leaf -Resolve
$selected_name = $selected_name -replace '\.', '_' -replace '\s', '_'

# --- lógica ---
$existing = Get-WeztermListJson
$matchingPane = $existing | Where-Object { $_.workspace -eq $selected_name }

if ($matchingPane) {
  Send-WezSwitchWs -WorkspaceName $selected_name
  exit 0
}

# Crear ventana en workspace nuevo sin cambiar foco
& wezterm cli spawn --new-window --workspace $selected_name --cwd $selected

# Esperar y luego cambiar
if (Wait-WorkspaceRegistered -WorkspaceName $selected_name) {
  Send-WezSwitchWs -WorkspaceName $selected_name
}
