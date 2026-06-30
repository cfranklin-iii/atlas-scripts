# Atlas Scripts (v1.4)

=== Manifest ===

`setup.sh`
 - Checks if fish is installed
 - If not, errors
 - If yes, pushes functions, aliases, and config.fish to local
 - Deploys a custom **boxed-style** fastfetch config to `~/.config/fastfetch/config.jsonc`
 - Configures git global user name and email (if not already set)

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
- **Safety First:** All scripts use `set -e` and avoid dangerous `eval` calls.

### Notes for Future Versions / Things to Add:
- Add support for other package managers like `dnf` or `zypper`.
- Add an uninstaller or cleanup script to remove dotfiles/packages easily.
- Make the git user name and email prompt user for input rather than defaulting to hardcoded values if not set.
- Make NVIDIA driver version dynamically fetch the latest release version instead of hardcoding.
