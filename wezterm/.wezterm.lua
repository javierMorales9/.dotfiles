-- ~/.wezterm.lua  —  WezTerm configuration adapted from your tmux workflow
-- Tested against WezTerm ≥ 20240203‑110809‑a1b0d8e8 on Windows 11 & WSL.

local wezterm = require("wezterm")
local act = wezterm.action
local config = wezterm.config_builder()

-- ##########################################################################
-- 0.  Basics
-- ##########################################################################
config.default_prog = { "pwsh.exe", "-NoLogo" } -- open directly in PowerShell Core
config.leader = { key = "h", mods = "CTRL" } -- same prefix as your tmux <C-h>
config.hide_tab_bar_if_only_one_tab = false -- always show the tab bar

-- ensure we have a keys table before we start inserting
config.keys = {}

-- ##########################################################################
-- 1.  Sessionizer → Workspaces
--     Ctrl‑h f → list top‑level dirs and switch/create workspace
-- ##########################################################################
local roots = {
	wezterm.home_dir .. "/work",
	wezterm.home_dir .. "/personal",
	wezterm.home_dir .. "/sandbox",
	wezterm.home_dir .. "/tutorials",
}

--- read first‑level children of each root and build {id=path, label=dir}
local function collect_projects()
	local choices = {}
	for _, root in ipairs(roots) do
		local ok, items = pcall(wezterm.read_dir, root)
		if ok then
			for _, p in ipairs(items) do
				local label = p:match("[^/\\]+$")
				table.insert(choices, { id = p, label = label })
			end
		end
	end
	table.sort(choices, function(a, b)
		return a.label < b.label
	end)
	return choices
end

-- Ctrl‑h f: fuzzy selector –> workspace
config.keys[#config.keys + 1] = {
	mods = "LEADER",
	key = "f",
	action = act.InputSelector({
		title = "Open Workspace",
		description = "Selecciona proyecto",
		fuzzy = true,
		choices = collect_projects(),
		action = wezterm.action_callback(function(win, p, id, label)
			if not id then
				return
			end
			win:perform_action(
				act.SwitchToWorkspace({
					name = label:gsub("[^%w_]", "_"),
					spawn = { cwd = id, label = "󰏖  " .. label },
				}),
				p
			)
		end),
	}),
}

-- ##########################################################################
-- 2.  Pane / Tab management (mirrors tmux bindings)
-- ##########################################################################
local function map(mods, key, action)
	config.keys[#config.keys + 1] = { mods = mods, key = key, action = action }
end

map("CTRL", "f", act.SendString("wezterm-launcher\r"))
map("LEADER", "w", act.SpawnTab("CurrentPaneDomain"))
-- splits
map("LEADER", "d", act.SplitHorizontal({ domain = "CurrentPaneDomain" }))
map("LEADER", "a", act.SplitVertical({ domain = "CurrentPaneDomain" }))
map("CTRL", "d", act.CloseCurrentPane({ confirm = true }))
-- focus movement (vim‑style)
map("LEADER", "H", act.ActivatePaneDirection("Left"))
map("LEADER", "J", act.ActivatePaneDirection("Down"))
map("LEADER", "K", act.ActivatePaneDirection("Up"))
map("LEADER", "L", act.ActivatePaneDirection("Right"))
-- new tab
-- jump to tab 1..9
for i = 1, 9 do
	map("LEADER", tostring(i), act.ActivateTab(i - 1))
end

map(
	"LEADER",
	"t",
	act.ShowLauncherArgs({
		flags = "FUZZY|WORKSPACES",
	})
)

map(
	"LEADER",
	"n",
	wezterm.action_callback(function(win, pane)
		--pane:send_paste("Antes")
		wezterm.sleep_ms(50) -- pequeño respiro
		local ok, out = wezterm.run_child_process({ "cmd", "/c", "dir" })
		wezterm.sleep_ms(50)
		--pane:send_paste(("Despues\n%s\n%s\n"):format(out or "", err or ""))
	end)
)

-- ##########################################################################
-- 3.  Direct shortcuts to favourite repos (j/k/l/m/p)
-- ##########################################################################
local quick = {
	j = wezterm.home_dir .. "/.dotfiles",
	k = wezterm.home_dir .. "/General/Program/manuscritten",
	--l = wezterm.home_dir .. "/personal/bluesun",
	--m = wezterm.home_dir .. "/personal/rideshare",
	--p = wezterm.home_dir .. "/personal/rideshare-go",
}

wezterm.on("user-var-changed", function(window, pane, name, value)
	if name == "WEZ_SWITCH_WS" and value and #value > 0 then
		window:perform_action(act.SwitchToWorkspace({ name = value }), pane)
	end
end)

for key, path in pairs(quick) do
	map(
		"LEADER",
		key,
		act.SwitchToWorkspace({
			name = path:match("[^/\\]+$"),
			spawn = { cwd = path },
		})
	)
end

-- ##########################################################################
-- 4.  Launch menu entries (Ctrl‑Shift‑T → right‑click +)
-- ##########################################################################
config.launch_menu = {
	{
		label = "PowerShell",
		args = { "pwsh.exe", "-NoLogo" },
	},
	{
		label = "WSL Ubuntu",
		domain = { DomainName = "WSL:Ubuntu-22.04" },
	},
	{
		label = "Git Bash",
		args = { "C:/Program Files/Git/bin/bash.exe", "--login", "-i" },
	},
}

-- ##########################################################################
-- 5.  Appearance: show workspace in window title + colours similar to tmux
-- ##########################################################################
wezterm.on("format-window-title", function()
	return "🗂  " .. (wezterm.mux.get_active_workspace() or "")
end)

config.colors = {
	tab_bar = {
		background = "#333333",
		active_tab = { bg_color = "#333333", fg_color = "#5eacd3" },
		inactive_tab = { bg_color = "#222222", fg_color = "#bbbbbb" },
	},
}

return config
