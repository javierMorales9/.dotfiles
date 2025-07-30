-- ~/.config/wezterm/wezterm.lua
local wezterm = require 'wezterm'
local mux      = wezterm.mux
local act      = wezterm.action
local config   = wezterm.config_builder()

----------------------------------------------------------------------
-- 1.   Ajustes básicos
----------------------------------------------------------------------
-- Prefijo equivalente al <C-h> de tmux
config.leader = { key = 'h', mods = 'CTRL' }

-- Arranca en PowerShell en Windows, pero define accesos rápidos
-- para WSL y Git‑Bash (tócalo a tu gusto).
config.default_domain = 'PowerShell'
config.launch_menu = {
  { label = 'PowerShell', domain = 'PowerShell' },
  { label = 'WSL Ubuntu', domain = 'WSL:Ubuntu-22.04' },
  { label = 'Git Bash',  domain = 'GitBash' },
}

----------------------------------------------------------------------
-- 2.   “Sessionizer” → InputSelector + Workspace
--      Ctrl‑h f  → lista de proyectos, crea/salta workspace
----------------------------------------------------------------------
--  Carpetas raíz que quieres escanear (ajusta las que necesites).
local roots = {
  wezterm.home_dir .. '/work',
  wezterm.home_dir .. '/personal',
  wezterm.home_dir .. '/sandbox',
  wezterm.home_dir .. '/tutorials',
}

-- Explora cada raíz (primer nivel) y construye la lista de proyectos.
local function collect_projects()
  local choices = {}
  for _, base in ipairs(roots) do
    for _, path in ipairs(wezterm.read_dir(base)) do            -- :contentReference[oaicite:0]{index=0}
      local label = path:match('[^/\\]+$')                      -- basename
      table.insert(choices, { id = path, label = label })
    end
  end
  table.sort(choices, function(a, b) return a.label < b.label end)
  return choices
end

-- Binding <LEADER> f  → muestra selector difuso y abre/salta workspace
table.insert(config.keys, {
  mods = 'LEADER', key = 'f',
  action = wezterm.action_callback(function(window, pane)
    window:perform_action(
      act.InputSelector{                                      -- :contentReference[oaicite:1]{index=1}
        fuzzy      = true,
        title      = 'Open workspace',
        description= 'Escribe para buscar proyecto',
        choices    = collect_projects(),
        action     = wezterm.action_callback(function(win, p, id, label)
          if not id then return end
          win:perform_action(
            act.SwitchToWorkspace{                            -- :contentReference[oaicite:2]{index=2}
              name  = label:gsub('[^%w_]', '_'),
              spawn = { cwd = id, label = '󰏖  ' .. label },
            }, p)
        end),
      },
      pane)
  end)
})

----------------------------------------------------------------------
-- 3.   Navegación y gestión de panes/tabs
----------------------------------------------------------------------
local nav_keys = {
  -- Splits
  {mods='LEADER', key='"', action=act.SplitHorizontal{domain='CurrentPaneDomain'}},
  {mods='LEADER', key='%', action=act.SplitVertical  {domain='CurrentPaneDomain'}},
  -- Mover foco entre panes (vi‑like)
  {mods='LEADER', key='H', action=act.ActivatePaneDirection'Left'},
  {mods='LEADER', key='J', action=act.ActivatePaneDirection'Down'},
  {mods='LEADER', key='K', action=act.ActivatePaneDirection'Up'},
  {mods='LEADER', key='L', action=act.ActivatePaneDirection'Right'},
  -- Nueva “window” (= tab)  Ctrl‑h w
  {mods='LEADER', key='w', action=act.SpawnTab'CurrentPaneDomain'},
}
-- 1…9 → tab n   (WezTerm empieza en 0)
for i = 1, 9 do
  table.insert(nav_keys,
    {mods='LEADER', key=tostring(i), action=act.ActivateTab(i-1)})
end
for _, k in ipairs(nav_keys) do table.insert(config.keys, k) end

----------------------------------------------------------------------
-- 4.   Atajos directos a carpetas concretas (j/k/l/m/p)
----------------------------------------------------------------------
local direct = {
  j = wezterm.home_dir .. '/.dotfiles',
  k = wezterm.home_dir .. '/work/cartas',
  l = wezterm.home_dir .. '/personal/bluesun',
  m = wezterm.home_dir .. '/personal/rideshare',
  p = wezterm.home_dir .. '/personal/rideshare-go',
}
for key, path in pairs(direct) do
  table.insert(config.keys, {
    mods='LEADER', key=key,
    action=act.SwitchToWorkspace{
      name  = path:match('[^/\\]+$'),
      spawn = { cwd = path },
    }
  })
end

----------------------------------------------------------------------
-- 5.   Barra de estado / títulos
----------------------------------------------------------------------
-- Muestra el nombre del workspace activo en la barra de título:
wezterm.on('format-window-title', function()
  return '🗂  ' .. (mux.get_active_workspace() or '')
end)                                                      -- :contentReference[oaicite:3]{index=3}

-- Colores parecidos a tu tmux (gris oscuro + texto azul):
config.colors = {
  tab_bar = {
    background = '#333333',
    active_tab = { bg_color = '#333333', fg_color = '#5eacd3' },
    inactive_tab = { bg_color = '#222222', fg_color = '#aaaaaa' },
  }
}

-- Deja visible la tab‑bar incluso con una sola pestaña
config.hide_tab_bar_if_only_one_tab = false

return config
