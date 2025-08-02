# Dev Terminal Setup (Windows)

This folder contains two scripts that bootstrap and tear down a complete terminal/editor setup on Windows:

* `install.ps1` – installs the tooling and links your config
* `uninstall.ps1` – removes the installed packages and symlinks

> **Scope:** this setup targets Windows 11. It assumes you will mostly work in **WezTerm** + **Neovim**, with optional WSL usage. The scripts are safe to run more than once.

---

## 0) Prerequisites (install manually)

There are two components you should install **before** running the scripts. Installing them from the script is possible, but it is more predictable to do it manually once per machine.

1. **PowerShell 7 (pwsh.exe)**

   * Required because the config uses `pwsh.exe` as the default shell in WezTerm.
   * Install with *one* of the following:

     * Microsoft Store / official installer, or
     * **Winget:**

       ```powershell
       winget install --id Microsoft.PowerShell -e
       ```
   * After installing, confirm it’s available:

     ```powershell
     where pwsh
     pwsh -v
     ```

2. **Visual Studio 2022** (or **Build Tools for VS**)

   * Useful for compilers, SDKs and C/C++ toolchains that some plugins and native Node modules expect.
   * Recommended workload: **Desktop development with C++** (at minimum the MSVC toolset & Windows SDK).
   * You can also install **Build Tools for Visual Studio** if you don’t want the full IDE.

> If `pwsh.exe` is missing, WezTerm may show: `Process "pwsh.exe -NoLogo" didn't exit cleanly (code 1)`. Install PowerShell 7 or change `default_prog` in `.wezterm.lua` to `powershell.exe` temporarily.

---

## 1) What `install.ps1` does

* Elevates to Administrator (UAC prompt) but **remembers your original user profile** to write links/files there.
* Installs **Chocolatey** if not present.
* Offers to install, via Chocolatey (you can opt in/out per item):

  * WezTerm, jq, Neovim, Node.js LTS, ripgrep, fzf, psql, LLVM/Clang
* Creates `~/bin` (if missing) and adds it to your **user** PATH (not system-wide).
* Creates symlinks for your configs **into your user profile**:

  * `~/.wezterm.lua  ->  <repo>/wezterm/.wezterm.lua`
  * `~/AppData/Local/nvim  ->  <repo>/nvim/.config/nvim`
  * Example script into `~/bin/example-script.ps1`

### How to run it

Open **PowerShell 7** and execute from this folder:

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File .\install.ps1
```

Then answer the Y/N prompts for each component you want.

> The first time you run it, a new admin PowerShell window opens automatically to complete the install. When finished, open a **new** terminal so the updated PATH is picked up.

---

## 2) What `uninstall.ps1` does

* Elevates to Administrator and preserves your original user profile.
* Prompts (Y/N) to **uninstall** the same packages installed via Chocolatey.
* Removes symlinks and folders created under your profile:

  * `~/.wezterm.lua`, `~/AppData/Local/nvim`, `~/AppData/Local/nvim-data`, `~/bin` (if it was created by the setup)
* Attempts to remove Chocolatey (classic or portable) folders and cleans its PATH entries.

### How to run it

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File .\uninstall.ps1
```

> **Data safety:** the scripts remove **symlinks** and **created folders**, but they do **not** delete unrelated user data inside your repos. Review the prompts before confirming.

---

## 3) After installation – What you get

### WezTerm

* Default shell: **PowerShell 7** (`pwsh.exe`), with a safe fallback in the config if you choose to enable it.
* **Default workspace & CWD**: `.dotfiles` (if the folder exists), otherwise falls back to your home folder.
* **Fullscreen on startup** (if you enabled the `gui-startup` block in your config).
* **Launch Menu** (right–click on `+` in the tab bar, or via a keybinding) with entries for PowerShell, WSL Ubuntu, Git Bash, etc.

#### Key highlights (defaults in the provided config)

* **Leader key**: `Ctrl + h`
* Workspaces launcher (Lua InputSelector): `Leader + f`
* WezTerm external project launcher (PowerShell): `Ctrl + f` (optional; can be guarded to avoid conflicts in Neovim)
* New tab: `Leader + w`
* Pane splits: `Leader + d` (horizontal), `Leader + a` (vertical)
* Close pane: `Ctrl + Shift + d` (we avoid using `Ctrl + d` so Neovim can keep half-page down)
* Pane navigation: `Leader + H/J/K/L`
* Show Launch Menu via keyboard: e.g. `Ctrl + Shift + T` or `Leader + t` (depending on your mapping)

### Neovim

* Config is symlinked from this repo.
* Plugins managed by **lazy.nvim**.
* Useful Telescope bindings, LSP setup, formatting, etc. (see your `lazy_config`).

### `~/bin`

* A user-local folder for small utilities and scripts (e.g. `example-script.ps1`).
* Added to your **user** PATH so you can call commands like `wezterm-launcher` or your own tools without modifying system PATH.

---

## 4) Working with WSL (optional)

You can:

* Open new tabs/windows directly inside a **WSL domain**:

  * Launch Menu → *WSL Ubuntu*
  * Or a keybinding that uses `domain = { DomainName = "WSL:Ubuntu-22.04" }`, `cwd = "/home/<user>"`, and `args = { "bash", "-lc", "exec bash -l" }`
* Spawn workspaces in WSL from your external launcher by detecting `\\wsl$\\<distro>\...` paths and converting them to Linux paths with `wslpath`, then passing `--domain WSL:<distro>` and `--cwd /linux/path` to `wezterm cli spawn`.

> For best performance, keep repos you’ll build/run frequently in **Linux FS** (e.g. `/home/<user>/repo`) rather than `/mnt/c/...`.

---

## 5) Troubleshooting

* **WezTerm shows**: `pwsh.exe ... didn't exit cleanly (code 1)`

  * Install **PowerShell 7** or adjust `default_prog` to `powershell.exe` temporarily.
* **Missing `.dotfiles` folder**

  * Either create `~/.dotfiles` or change `default_workspace`/`default_cwd` in `.wezterm.lua`.
* **`wezterm-launcher` not found from Neovim**

  * Ensure `~/bin` is in your **user** PATH and start a **new** terminal, or in Neovim use a route that doesn’t rely on PATH, e.g. `jobstart(vim.fn.expand("$USERPROFILE") .. "\\bin\\wezterm-launcher.cmd")`.
* **Permissions / UAC prompts**

  * Expected. The scripts elevate to install packages and create symlinks. They still write your config into the **original user profile** captured at startup.
* **Corporate proxy**

  * Chocolatey obeys system proxy. Configure `netsh winhttp set proxy` or environment variables if needed.

---

## 6) Updating

* You can rerun `install.ps1` to add more components or recreate the symlinks.
* Use `choco upgrade all -y` to update installed packages.
* Keep your repo up to date; WezTerm/Neovim will pick up config changes on reload.

---

## 7) Uninstalling everything

When you no longer need the setup:

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File .\uninstall.ps1
```

Confirm each prompt. This removes Chocolatey packages you select, your symlinks, and Chocolatey itself (classic or portable). It does **not** delete your personal git repos or unrelated data.

---

## 8) Notes & Limitations

* The scripts modify only the **user** PATH (not system-wide) to avoid impacting other users.
* If you want a machine-wide PATH entry for shared tools, prefer a neutral folder like `C:\Tools` instead of a per-user path.
* Some features rely on WezTerm being open (e.g. `wezterm cli spawn`), which is expected in your daily flow.

---

**Happy hacking!** If anything fails on a clean machine, check the prerequisites first (PowerShell 7, Visual Studio workloads) and then re-run `install.ps1`. If you want to add more packages to the installer prompts, edit `Install-PackageIfConfirmed` calls in `install.ps1`.
