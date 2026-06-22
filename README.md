# Atlas Scripts (v1.3)

=== Manifest ===

`setup.sh`
 - Checks if fish is installed
 - If not, errors
 - If yes, pushes functions, aliases, and config.fish to local
 - Configures git global user name and email (if not already set)

`install.sh`
 - Automatically detects package manager (`apt` or `pacman`)
 - Updates the system
 - Installs packages (`git`, `fish`, `tree`, `btop`, `fastfetch`, `curl`, `wget`, `build-essential`/`base-devel`) in a single optimized command

`nvidia-595.sh`
 - Interactive script for installing NVIDIA drivers and container toolkit
 - Refactored to use variables for version numbers (595.80) to simplify updates

### Notes for Future Versions / Things to Add:
- Add support for other package managers like `dnf` or `zypper`.
- Add an uninstaller or cleanup script to remove dotfiles/packages easily.
- Make the git user name and email prompt user for input rather than defaulting to hardcoded values if not set.
- Make NVIDIA driver version dynamically fetch the latest release version instead of hardcoding.
