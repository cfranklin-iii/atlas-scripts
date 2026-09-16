# Atlas Scripts (v1.71)

Bootstrap scripts and fish/fastfetch configs for setting up a fresh Linux box.

### Quick start

```bash
git clone https://github.com/cfranklin-iii/atlas-scripts.git
cd atlas-scripts

./install.sh   # 1. system packages (needs sudo)
./setup.sh     # 2. deploy configs into ~/.config
```

Run `install.sh` first — `setup.sh` only deploys configs for tools it finds on
`PATH`, so anything not yet installed is skipped with a warning.

`nvidia.sh` is optional and interactive; run it only on machines with an NVIDIA GPU.

### Choosing what you get

`install.sh`, `setup.sh` and `restore.sh` all open a checkbox menu when they
have a terminal to draw on. Everything starts selected, so a bare Enter does
exactly what these scripts have always done — installing or deploying the lot.

The menu is drawn with [gum](https://github.com/charmbracelet/gum):

```
Select configs to deploy:
(sets: fish - pick one with --only)

> ✓ Configs    fish-config      config.fish, local overrides, login shell
  ✓ Configs    fish-aliases     conf.d/aliases.fish and local overrides
  ✓ Configs    fish-functions   functions/*.fish
  ✓ Configs    fastfetch        fastfetch/config.jsonc
  ✓ Configs    git              user.name, user.email, init.defaultBranch

x toggle • ←↓↑→ navigate • enter submit • ctrl+a select all
```

**If gum isn't installed**, the scripts offer to install it: first from your
distro's package manager, then — since gum is missing from Debian 12, Ubuntu
24.04, Fedora and openSUSE — by fetching the official static binary into
`~/.local/bin`. Charm's apt/yum repo is deliberately *not* added; a menu isn't
worth leaving a third-party package source and signing key on your machine.

**If that fails**, or you decline, or the installed gum turns out to be too old
for the menu, or you're running `--dry-run` (which never installs anything), the
scripts fall back to a built-in menu that needs nothing but bash:

```
Select configs to deploy:

  Sets
    1) [x] fish             config.fish, aliases and functions
  Configs
    2) [x] fish-config      config.fish, local overrides, login shell
    3) [~] fish-aliases     conf.d/aliases.fish and local overrides
    ...

  numbers or ranges toggle a row (e.g. 1 3-5); a name toggles that row
  a=all  n=none  v=invert  q=quit  Enter=confirm
>
```

Type row numbers (`5`), ranges (`5-8`), or names (`tools`) to flip rows on and
off; several at once is fine (`1 3-5 dev`). Here a set row drives all its
members, and shows `[~]` when only some of them are selected.

With **no terminal** — CI, a piped install, cron — there is nothing to prompt
on, so everything is selected, gum is never consulted, and the run proceeds
without asking.

#### Theming the menu

gum takes its colours from the environment, so `lib/common.sh` sets them in one
place. Each accepts an ANSI 256 number (`212`) or a hex string (`#00D7AF`):

| Variable | What it colours |
| --- | --- |
| `GUM_CHOOSE_HEADER_FOREGROUND` | The title line above the list |
| `GUM_CHOOSE_CURSOR_FOREGROUND` | The `>` on the row you are on |
| `GUM_CHOOSE_SELECTED_FOREGROUND` | Rows with a `✓` |
| `GUM_CHOOSE_ITEM_FOREGROUND` | Unselected rows |

They are set with `${VAR:-default}`, so exporting one in your shell wins
without editing the repo:

```bash
export GUM_CHOOSE_SELECTED_FOREGROUND='#FFAA00'
./setup.sh
```

Every gum command follows the same `GUM_<COMMAND>_<ELEMENT>_<PROPERTY>` pattern,
and `*_BACKGROUND` exists alongside each `*_FOREGROUND`. `gum choose --help`
lists the full set.

### Installation progress

`install.sh` installs one package at a time and draws a pacman-style
ILoveCandy bar, the way CachyOS renders it:

```
 (5/8) installing tree                 [-------------C• • • • • ]  62%
```

The package manager's own output is hidden in a log rather than scrolling past.
If a package fails, its error is printed and the log path is reported; on a
clean run the log is deleted. Because the output is hidden, the sudo password
is asked for up front — a hidden password prompt is indistinguishable from a
hang. With no terminal the bar degrades to one plain line per package, so CI
logs stay readable, and `--dry-run` keeps the fully narrated output.

Fetching gum draws the same bar over its three steps, so the one download these
scripts do on their own looks like every other install:

```
 (2/3) unpacking gum 0.17.0            [--------------C• • • • •]  66%
```

Installing per package costs a dependency resolution each time, which is
slightly slower than one batched call, but it is what makes the count real and
lets a failure name exactly one package.

To skip the menu entirely:

| Option | Effect |
| --- | --- |
| `-a`, `--all` | Take everything, no menu |
| `-o`, `--only LIST` | Just these items or sets, comma or space separated |
| `-x`, `--exclude LIST` | Drop these from the selection |
| `-L`, `--list` | Show the items and sets, then exit |
| `-n`, `--dry-run` | Report what would happen, change nothing |
| `-h`, `--help` | Show usage |

```bash
./install.sh --only core,tools     # no fish, no compiler toolchain
./install.sh --all --exclude dev   # everything but the compiler toolchain
./setup.sh   --only fastfetch      # leave the fish config alone
./setup.sh   --list
```

A name that matches nothing is an error rather than a silent skip, so a typo
can't quietly leave out a config you asked for.

`setup.sh` adds two of its own:

| Option | Effect |
| --- | --- |
| `-l`, `--link` | Symlink the configs instead of copying, so repo edits apply immediately |
| `-y`, `--yes` | Assume yes for prompts (e.g. the login shell), and take everything |

Changed your mind? `./restore.sh` puts back whatever `setup.sh` replaced.

### Overview

`lib/common.sh`
 - Shared helpers sourced by every script: colors, `info`/`ok`/`err` log functions,
   `run`/`did` for dry runs, the menus, and the package-manager tables — one
   place to change, so the scripts cannot drift apart
 - `ensure_gum` resolves gum, installing it if you let it, and reports failure
   so callers drop to the built-in `multiselect` menu rather than giving up
 - `resolve_pkg` maps a logical package name to what the local distro calls it,
   so `buildtools` becomes `build-essential`, `base-devel`, `@development-tools`
   or `gcc make` without any script having to know the difference

`config/`
 - The tracked dotfiles themselves (`fish/`, `fastfetch/`, `nano/`), deployed by
   `setup.sh`.

`install.sh`
 - Detects the package manager (`apt`, `pacman`, `dnf` or `zypper`)
 - Updates the system, then installs the selected packages
 - Package sets: `core` (git, curl, wget), `shell` (fish), `tools` (tree, btop,
   fastfetch) and `dev` (the distro's compiler toolchain)
 - Uses safe array-based commands (no `eval`); adds `--needed` on pacman so
   already-installed packages are not rebuilt
 - Falls back to installing one package at a time if the batch fails, so a
   single package missing from your distro's repos doesn't sink the rest

`setup.sh`
 - Selectable configs: `fish-config`, `fish-aliases`, `fish-functions` (grouped
   as the `fish` set), `nano-config` and `nano-syntax` (the `nano` set),
   `fastfetch` and `git`
 - Pushes functions, aliases, and config.fish to local
 - Skips with a warning — not an error — if the tool for a config isn't installed
 - Backs up any existing configs to a timestamped `.bak` (never clobbers a previous backup)
 - Creates `config.local.fish` / `aliases.local.fish` for machine-specific overrides (never overwritten)
 - Deploys a custom **boxed-style** fastfetch config to `~/.config/fastfetch/config.jsonc`
 - Prompts & configures git global user name and email if not already set
   (an empty answer or a non-interactive shell just leaves the key unset)

`nvidia.sh`
 - Interactive script for installing NVIDIA drivers (v595.99.02) and Container Toolkit
 - Robust error handling: uses `trap` for automatic cleanup of `.run` files
 - Smart guards: detects system type to provide tailored instructions for Container Toolkit (apt-native, Arch/AUR instructions)
 - Verifies the download against NVIDIA's published SHA-256 before running it as root
 - Pre-flight checks for a running graphical session, Secure Boot and loaded nouveau
 - Installs via `--dkms` so the module survives kernel updates

`restore.sh`
 - Restores each config from the most recent backup `setup.sh` took
 - Same menu and selection flags, plus `--list` to see what is available
 - Leaves backups in place, so restoring is repeatable
 - Git settings are never backed up, so `restore.sh` cannot undo those

### Key Features
- **Pick What You Want:** A gum checkbox menu for packages and configs, with sets
  for the common groupings — and flags for when you'd rather not be asked at all.
- **Degrades Gracefully:** gum is installed on demand, but nothing depends on it.
  No gum, no network, no terminal — each case has a defined fallback, and only a
  terminal is ever actually required.
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
- **Tested in CI:** Every push runs shellcheck, a bash/fish syntax pass, a unit test of
  the menu's input grammar, and a smoke test that deploys the configs into a scratch
  `$HOME` and restores them again.

### Nano

Put your `nanorc` in `config/nano/nanorc` and any syntax definitions in
`config/nano/syntax/*.nanorc`. `setup.sh` deploys them to
`~/.config/nano/nanorc` and `~/.config/nano/syntax/`.

Everything in `config/nano/nanorc` above this marker is copied verbatim:

```
## --- atlas-scripts: generated includes below, do not edit ---
```

Below it, `setup.sh` regenerates one `include` line per syntax file, with
absolute paths — which is why it is generated rather than tracked, and why
`--link` does not apply to that one file. Dropping a new `.nanorc` into
`config/nano/syntax/` and re-running `setup.sh` is the whole workflow; nothing
else needs editing.

Note that nano reads `~/.nanorc` in preference to the XDG path, so `setup.sh`
warns if one exists — it would silently win over the deployed config.

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
