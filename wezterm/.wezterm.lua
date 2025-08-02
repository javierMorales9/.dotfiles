--[[
WezTerm Configuration — Fully Annotated
======================================
A self‑contained, cross‑platform configuration that illustrates:
  • Using **workspaces** as lightweight “projects”.
  • Creating an **interactive launcher** (fzf‑style) in Lua only; no external script required.
  • Key maps for tabs, panes and favourite directories.
  • How to pass information from the shell **back into WezTerm** through a
    *user variable* and react to it with the `user‑var‑changed` event.

All comments are in English and deliberately verbose so you can use this file
as living documentation.
--]]

local wezterm = require("wezterm")
local act = wezterm.action
local config = wezterm.config_builder()

-- ##########################################################################
-- 0.  BASIC PREFERENCES  ───────────────────────────────────────────────────
-- ##########################################################################
config.default_prog = { "pwsh.exe", "-NoLogo" } -- start in PowerShell Core on Windows
config.leader = { key = "h", mods = "CTRL" } -- prefix for custom key‑bindings
config.hide_tab_bar_if_only_one_tab = false -- keep tab‑bar for context
config.keys = {} -- ensure fresh key table

config.default_workspace = ".dotfiles" -- **NEW**: spawn into this workspace
config.default_cwd = wezterm.home_dir .. "/.dotfiles" -- open first tab in ~/.dotfiles

-- ##########################################################################
-- 1.  PROJECT LAUNCHER (WORKSPACE SELECTOR)  ───────────────────────────────
-- ##########################################################################
-- Purpose  : Let the user fuzzy‑pick a directory and drop into a dedicated
--            workspace.  One workspace per directory keeps long‑running
--            tasks isolated and is cheaper than opening a full OS terminal.
-- How it works:
--   1. We scan a few high‑level folders below home.
--   2. The list is fed into `InputSelector` with `fuzzy=true`.
--   3. When the user hits <Enter>, WezTerm triggers `SwitchToWorkspace`.
--      If the workspace does not exist yet, `spawn` tells WezTerm to create
--      the first tab in that workspace using the given CWD.

local search_roots = {
	wezterm.home_dir .. "/",
	wezterm.home_dir .. "/work",
	wezterm.home_dir .. "/personal",
	wezterm.home_dir .. "/sandbox",
	wezterm.home_dir .. "/tutorials",
	wezterm.home_dir .. "/General", -- For windows
	wezterm.home_dir .. "/General/Program", -- For windows
}

---@return table[]  list of {id=<absolute path>, label=<leaf>}
local function collect_projects()
	local list = {}
	for _, root in ipairs(search_roots) do
		local ok, entries = pcall(wezterm.read_dir, root)
		if ok then
			for _, p in ipairs(entries) do
				local leaf = p:match("[^/\\]+$")
				table.insert(list, { id = p, label = leaf })
			end
		end
	end
	table.sort(list, function(a, b)
		return a.label:lower() < b.label:lower()
	end)
	return list
end

-- Leader f  → open launcher
config.keys[#config.keys + 1] = {
	mods = "LEADER",
	key = "f",
	action = act.InputSelector({
		title = "Open Project Workspace",
		description = "Type to fuzzy‑match a directory",
		fuzzy = true,
		choices = collect_projects(),
		action = wezterm.action_callback(function(win, pane, id, label)
			if not id then
				return
			end
			local ws = label:gsub("[^%w_]", "_")
			win:perform_action(
				act.SwitchToWorkspace({
					name = ws,
					spawn = { cwd = id, label = "📂  " .. label },
				}),
				pane
			)
		end),
	}),
}

-- ##########################################################################
-- 2.  TABS, PANES, NAVIGATION  ─────────────────────────────────────────────
-- ##########################################################################
local function map(mods, key, action)
	config.keys[#config.keys + 1] = { mods = mods, key = key, action = action }
end

-- Basic tab management
map("LEADER", "w", act.SpawnTab("CurrentPaneDomain"))
for i = 1, 9 do
	map("LEADER", tostring(i), act.ActivateTab(i - 1))
end

-- Split / close panes
map("LEADER", "d", act.SplitHorizontal({ domain = "CurrentPaneDomain" }))
map("LEADER", "a", act.SplitVertical({ domain = "CurrentPaneDomain" }))
map("LEADER", "D", act.QuitApplication)

-- Move focus (vim‑style H/J/K/L)
map("LEADER", "H", act.ActivatePaneDirection("Left"))
map("LEADER", "J", act.ActivatePaneDirection("Down"))
map("LEADER", "K", act.ActivatePaneDirection("Up"))
map("LEADER", "L", act.ActivatePaneDirection("Right"))

-- Quick launcher for PE scripts from the current pane (example)
map("CTRL", "f", act.SendString("wezterm-launcher\r"))

-- ##########################################################################
-- 3.  QUICK‑ACCESS WORKSPACES (OPTIONAL SHORTCUTS)  ────────────────────────
-- ##########################################################################
-- Single‑key jumps for most‑used repos.  Comment out if not needed.
local quick = {
	j = wezterm.home_dir .. "/.dotfiles",
	k = wezterm.home_dir .. "/General/Program/manuscritten",
}
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
-- 4.  LAUNCH MENU (CTRL‑SHIFT‑T context)  ──────────────────────────────────
-- ##########################################################################
config.launch_menu = {
	{ label = "PowerShell", args = { "pwsh.exe", "-NoLogo" } },
	{ label = "WSL Ubuntu", domain = { DomainName = "WSL:Ubuntu-22.04" } },
	{ label = "Git Bash", args = { "C:/Program Files/Git/bin/bash.exe", "--login", "-i" } },
}

-- ##########################################################################
-- 5.  THE `user‑var‑changed` EVENT  ────────────────────────────────────────
-- ##########################################################################
-- WezTerm allows a pane to receive **OSC‑1337** escape sequences that encode
-- arbitrary *user variables* (name/value).  Syntax from the shell:
--
--   printf "\e]1337;SetUserVar=<NAME>=<BASE64_VALUE>\a"
--
-- The string is Base64‑encoded because OSC payloads must be printable.
-- When such a sequence arrives, WezTerm fires **`user‑var‑changed`** and
-- passes you:
--   • window   – the main window object
--   • pane     – the originating pane
--   • name     – variable name (string)
--   • value    – decoded UTF‑8 value (string)
--
-- Here we leverage that to implement an *out‑of‑band workspace switch*:
-- a shell script (or external process) can tell WezTerm, "please activate
-- workspace X" without needing a dedicated CLI flag.

wezterm.on("user-var-changed", function(window, pane, name, value)
	if name == "WEZ_SWITCH_WS" and value and #value > 0 then
		-- The action is deferred to WezTerm; scripts only emit the signal.
		window:perform_action(act.SwitchToWorkspace({ name = value }), pane)
	end
end)

-- ##########################################################################
-- 6.  APPEARANCE  ──────────────────────────────────────────────────────────
-- ##########################################################################
-- Display the active workspace in the window title for quick orientation.
wezterm.on("format-window-title", function()
	return "🗂  " .. (wezterm.mux.get_active_workspace() or "")
end)

config.font_size = 15

config.colors = {
	tab_bar = {
		background = "#333333",
		active_tab = { bg_color = "#333333", fg_color = "#5eacd3" },
		inactive_tab = { bg_color = "#222222", fg_color = "#bbbbbb" },
	},
}

return config
