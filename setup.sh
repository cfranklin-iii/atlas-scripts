#!/usr/bin/env bash
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$REPO_DIR/lib/common.sh" || {
    echo "atlas-scripts: cannot load lib/common.sh" >&2; exit 1
}

CONFIG_DIR="$REPO_DIR/config"
CFG="${XDG_CONFIG_HOME:-$HOME/.config}"

LINK_MODE=0
DRY_RUN=0
ASSUME_YES=0

usage() {
    cat <<USAGE
Usage: setup.sh [options]

Deploys the tracked configs in config/ into \$XDG_CONFIG_HOME
(currently $CFG). Existing files are backed up first.

Options:
  -l, --link      Symlink the configs instead of copying, so repo edits take
                  effect immediately and local edits survive the next run.
  -n, --dry-run   Report what would change without touching anything.
  -y, --yes       Assume yes for prompts (e.g. setting fish as login shell).
  -h, --help      Show this help.
USAGE
}

while [ $# -gt 0 ]; do
    case "$1" in
        -l | --link)    LINK_MODE=1 ;;
        -n | --dry-run) DRY_RUN=1 ;;
        -y | --yes)     ASSUME_YES=1 ;;
        -h | --help)    usage; exit 0 ;;
        *)              err "Unknown option: $1"; usage >&2; exit 1 ;;
    esac
    shift
done

# Run a command, or just describe it under --dry-run.
run() {
    if [ "$DRY_RUN" -eq 1 ]; then
        info "  [dry-run] $*"
    else
        "$@"
    fi
}

# ok(), but silent during a dry run - run() has already narrated the action,
# and claiming it was done would be a lie. Always returns 0 for `set -e`.
did() { [ "$DRY_RUN" -eq 1 ] || ok "$*"; return 0; }

# Back up whatever is at $1, if anything, to a timestamped .bak.
backup() {
    local dest="$1" stamp bak n=1
    [ -e "$dest" ] || [ -L "$dest" ] || return 0
    stamp="$dest.bak.$(date +%Y%m%d%H%M%S)"
    # Two backups inside the same second would otherwise overwrite each other,
    # which is exactly what a backup must not do.
    bak="$stamp"
    while [ -e "$bak" ]; do
        bak="$stamp.$n"
        n=$((n + 1))
    done
    run cp -P "$dest" "$bak"
    info "Backed up $dest -> $(basename "$bak")"
}

# Deploy one tracked file, backing up anything it replaces.
install_file() {
    local src="$1" dest="$2"

    if [ "$LINK_MODE" -eq 1 ]; then
        if [ -L "$dest" ] && [ "$(readlink -f "$dest")" = "$(readlink -f "$src")" ]; then
            info "Already linked: $dest"
            return 0
        fi
        backup "$dest"
        run ln -sfn "$src" "$dest"
        did "Linked $dest"
        return 0
    fi

    # Identical content means there is nothing to replace, and nothing worth
    # backing up - otherwise every re-run leaves another .bak behind.
    if [ -f "$dest" ] && [ ! -L "$dest" ] && cmp -s "$src" "$dest"; then
        info "Up to date: $dest"
        return 0
    fi
    backup "$dest"
    run cp "$src" "$dest"
    did "Installed $dest"
}

# Create a local-overrides template only if it is missing (never overwrite).
create_local() {
    [ -f "$1" ] && return 0
    if [ "$DRY_RUN" -eq 1 ]; then
        info "  [dry-run] create $1"
        return 0
    fi
    printf '%s\n' \
        '# Machine-specific overrides.' \
        '# This file is NOT managed by atlas-scripts and will not be overwritten.' \
        '# Add your personal aliases / settings below.' > "$1"
    ok "Created local overrides file: $1"
}

# Offer to make fish the login shell - installing the config is only half the
# job if the user still lands in bash on every login.
set_login_shell() {
    local fish_path
    fish_path="$(command -v fish)"
    [ "${SHELL:-}" = "$fish_path" ] && return 0

    if ! grep -qxF "$fish_path" /etc/shells 2>/dev/null; then
        info "$fish_path is not listed in /etc/shells; adding it needs sudo."
        run sudo tee -a /etc/shells <<<"$fish_path" >/dev/null || {
            err "Could not update /etc/shells; skipping login shell change."
            return 0
        }
    fi

    if [ "$ASSUME_YES" -eq 1 ] || confirm "Set fish as your login shell?"; then
        if run chsh -s "$fish_path"; then
            did "Login shell set to fish (takes effect at next login)."
        else
            err "chsh failed; set it manually with: chsh -s $fish_path"
        fi
    fi
    return 0
}

[ -d "$CONFIG_DIR" ] || die "Config directory not found: $CONFIG_DIR"
[ "$DRY_RUN" -eq 1 ] && info "Dry run - no changes will be made.\n"

info "Pulling configs from $REPO_DIR..."

# -- Fish --
if command -v fish &>/dev/null; then
    info "\nSetting up fish shell..."
    run mkdir -p "$CFG/fish/conf.d" "$CFG/fish/functions"

    install_file "$CONFIG_DIR/fish/config.fish"  "$CFG/fish/config.fish"
    install_file "$CONFIG_DIR/fish/aliases.fish" "$CFG/fish/conf.d/aliases.fish"

    for fn in "$CONFIG_DIR"/fish/functions/*.fish; do
        [ -e "$fn" ] || continue
        install_file "$fn" "$CFG/fish/functions/$(basename "$fn")"
    done

    create_local "$CFG/fish/config.local.fish"
    create_local "$CFG/fish/aliases.local.fish"
    ok "Fish config, aliases and functions loaded."
    set_login_shell
else
    err "Fish shell not installed, skipping."
fi

# -- Fastfetch --
if command -v fastfetch &>/dev/null; then
    info "\nSetting up fastfetch..."
    run mkdir -p "$CFG/fastfetch"
    install_file "$CONFIG_DIR/fastfetch/config.jsonc" "$CFG/fastfetch/config.jsonc"
    ok "Fastfetch config loaded to: $CFG/fastfetch/config.jsonc"
else
    err "Fastfetch not installed, skipping."
fi

# -- Git --
if command -v git &>/dev/null; then
    info "\nApplying git config settings..."
    set_git() {  # $1=key  $2=prompt
        git config --global "$1" >/dev/null && return 0
        if [ -t 0 ]; then
            # An empty answer is fine - just leave the key unset. Every path
            # returns 0 so `set -e` never aborts the rest of the script.
            read -rp "$2: " val || return 0
            [ -n "$val" ] && run git config --global "$1" "$val"
        else
            info "No git $1 set and input is not interactive; skipping."
        fi
        return 0
    }
    set_git user.email "Enter Git email"
    set_git user.name  "Enter Git name"
    run git config --global init.defaultBranch main
    ok "Git config applied."
else
    err "Git not installed, skipping."
fi

ok "\nSetup complete."
