# Atlas Scripts (v1.69)

Bootstrap scripts and fish/fastfetch configs for setting up a fresh Linux box.

### Quick start

```bash
git clone https://github.com/cfranklin-iii/atlas-scripts.git
cd atlas-scripts

./install.sh   # 1. system packages (needs sudo)
./setup.sh     # 2. deploy configs into ~/.config
```

`setup.sh` takes a few options:

| Option | Effect |
| --- | --- |
| `-l`, `--link` | Symlink the configs instead of copying, so repo edits apply immediately |
| `-n`, `--dry-run` | Report what would change without touching anything |
| `-y`, `--yes` | Assume yes for prompts (e.g. setting fish as the login shell) |
| `-h`, `--help` | Show usage |

Changed your mind? `./restore.sh` puts back whatever `setup.sh` replaced.

Run `install.sh` first — `setup.sh` only deploys configs for tools it finds on
`PATH`, so anything not yet installed is skipped with a warning.

`nvidia.sh` is optional and interactive; run it only on machines with an NVIDIA GPU.

### Overview

`lib/common.sh`
 - Shared helpers sourced by every script: colors, `info`/`ok`/`err` log functions,
   and `detect_pkg_manager` — keeps the scripts consistent.

`config/`
 - The tracked dotfiles themselves (`fish/`, `fastfetch/`), deployed by `setup.sh`.

`setup.sh`
 - Checks if fish is installed and errors if not
 - Pushes functions, aliases, and config.fish to local
 - Backs up any existing configs to a timestamped `.bak` (never clobbers a previous backup)
 - Creates `config.local.fish` / `aliases.local.fish` for machine-specific overrides (never overwritten)
 - Deploys a custom **boxed-style** fastfetch config to `~/.config/fastfetch/config.jsonc`
 - Prompts & configures git global user name and email if not already set
   (an empty answer or a non-interactive shell just leaves the key unset)

`install.sh`
 - Automatically detects package manager (`apt` or `pacman`)
 - Updates the system and installs core packages (`git`, `fish`, `tree`, `btop`, `fastfetch`, etc.)
 - Uses safe array-based commands (no `eval`); adds `--needed` on pacman so already-installed
   packages are not rebuilt

`nvidia.sh`
 - Interactive script for installing NVIDIA drivers (v595.99.02) and Container Toolkit
 - Robust error handling: uses `trap` for automatic cleanup of `.run` files
 - Smart guards: detects system type to provide tailored instructions for Container Toolkit (apt-native, Arch/AUR instructions)
 - Verifies the download against NVIDIA's published SHA-256 before running it as root
 - Pre-flight checks for a running graphical session, Secure Boot and loaded nouveau
 - Installs via `--dkms` so the module survives kernel updates

`restore.sh`
 - Restores each config from the most recent backup `setup.sh` took
 - Same `--dry-run` / `--yes` flags, plus `--list` to see what is available
 - Leaves backups in place, so restoring is repeatable

### Key Features
- **Modern Fastfetch:** Custom UI-like boxed configuration, split into System and
  Hardware panels with colored keys.
- **Fish Integration:** The fastfetch banner is guarded by `status is-interactive`, so
  it never writes to the stream and breaks `scp`/`rsync`.
- **Local Overrides:** Drop personal settings in `~/.config/fish/config.local.fish` and
  aliases in `~/.config/fish/aliases.local.fish`. These are auto-sourced by the managed
  files and are never overwritten by `setup.sh`.
- **Safe Backups:** Existing configs are backed up with a timestamp before being replaced,
  and `restore.sh` brings them back. Unchanged files are skipped, so re-running does not
  pile up identical backups.
- **XDG-Aware:** Respects `$XDG_CONFIG_HOME` when locating config directories.
- **Safety First:** All scripts use `set -euo pipefail`, avoid dangerous `eval` calls,
  verify that `lib/common.sh` actually loaded, and the NVIDIA installer downloads into a
  temp dir cleaned up via `trap`.
- **Tested in CI:** Every push runs shellcheck, a bash/fish syntax pass, and a smoke test
  that deploys the configs into a scratch `$HOME` and restores them again.

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
