# Atlas Scripts (v1.6)

=== Manifest ===

`lib/common.sh`
 - Shared helpers sourced by every script: colors, `info`/`ok`/`err` log functions,
   and `detect_pkg_manager` — keeps the scripts DRY and consistent.

`setup.sh`
 - Checks if fish is installed
 - If not, errors
 - If yes, pushes functions, aliases, and config.fish to local
 - Backs up any existing configs to a timestamped `.bak` (never clobbers a previous backup)
 - Creates `config.local.fish` / `aliases.local.fish` for machine-specific overrides (never overwritten)
 - Deploys a custom **boxed-style** fastfetch config to `~/.config/fastfetch/config.jsonc`
 - Configures git global user name and email (if not already set; skips prompts when non-interactive)

`install.sh`
 - Automatically detects package manager (`apt` or `pacman`)
 - Updates the system and installs core packages (`git`, `fish`, `tree`, `btop`, `fastfetch`, etc.)
 - Uses safe array-based commands (no `eval`) and `--needed` flags for efficiency

`nvidia-595.sh`
 - Interactive script for installing NVIDIA drivers (v595.80) and Container Toolkit
 - Robust error handling: uses `trap` for automatic cleanup of `.run` files
 - Smart guards: detects system type to provide tailored instructions for Container Toolkit (apt-native, Arch/AUR instructions)

### ✨ Features
- **Modern Fastfetch:** Custom UI-like boxed configuration with Nerd Font icons.
- **Fish Integration:** Interactive-only greeting guard to prevent `scp`/`rsync` breakages.
- **Local Overrides:** Drop personal settings in `~/.config/fish/config.local.fish` and
  aliases in `~/.config/fish/aliases.local.fish`. These are auto-sourced by the managed
  files and are never overwritten by `setup.sh`.
- **Safe Backups:** Existing configs are backed up with a timestamp before being replaced.
- **XDG-Aware:** Respects `$XDG_CONFIG_HOME` when locating config directories.
- **Safety First:** All scripts use `set -e`, avoid dangerous `eval` calls, and the NVIDIA
  installer downloads into a temp dir cleaned up via `trap`.

### 🔧 Local Overrides — keeping your own configs/aliases
Anything you want to keep that shouldn't live in the repo goes in a `*.local.fish` file:

```fish
# ~/.config/fish/aliases.local.fish
alias work 'cd ~/projects/work'

# ~/.config/fish/config.local.fish
set -gx EDITOR nvim
```

`setup.sh` creates empty templates for these on first run and never touches them again,
so re-running the script won't wipe your customizations.

### Notes for Future Versions / Things to Add:
- Add support for other package managers like `dnf` or `zypper`.
- Add an uninstaller or cleanup script to remove dotfiles/packages easily.
- Make NVIDIA driver version dynamically fetch the latest release version instead of hardcoding.
