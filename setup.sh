#!/usr/bin/env bash
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$REPO_DIR/lib/common.sh" || {
    echo "atlas-scripts: cannot load lib/common.sh" >&2; exit 1
}

CONFIG_DIR="$REPO_DIR/config"

LINK_MODE=0
ASSUME_YES=0

MENU_ITEMS=(
    "fish|Sets|config.fish, aliases and functions|fish-config fish-aliases fish-functions"
    "nano|Sets|nanorc and syntax highlighting|nano-config nano-syntax"
    "fish-config|Configs|config.fish, local overrides, login shell|"
    "fish-aliases|Configs|conf.d/aliases.fish and local overrides|"
    "fish-functions|Configs|functions/*.fish|"
    "nano-config|Configs|nano/nanorc|"
    "nano-syntax|Configs|nano/syntax/*.nanorc|"
    "fastfetch|Configs|fastfetch/config.jsonc|"
    "git|Configs|user.name, user.email, init.defaultBranch|"
)

usage() {
    cat <<USAGE
Usage: setup.sh [options]

Deploys the tracked configs in config/ into \$XDG_CONFIG_HOME
(currently $CFG). Existing files are backed up first.

With no selection option and a terminal to draw on, setup.sh shows a menu of
the configs below, everything pre-selected - so a bare Enter deploys the lot.
With no terminal (CI, a piped install) it deploys everything without asking.

Options:
  -a, --all       Deploy everything without showing the menu.
  -o, --only LIST Deploy just these configs or sets (comma or space separated).
  -x, --exclude LIST
                  Drop these configs or sets from the selection.
  -L, --list      List the configs and sets, then exit.
  -l, --link      Symlink the configs instead of copying, so repo edits take
                  effect immediately and local edits survive the next run.
  -n, --dry-run   Report what would change without touching anything.
  -y, --yes       Assume yes for prompts, and deploy everything without asking.
  -h, --help      Show this help.
USAGE
}

while [ $# -gt 0 ]; do
    if sel_flag "$@"; then
        shift "$SEL_SHIFT"
        continue
    fi
    case "$1" in
        -l | --link)    LINK_MODE=1 ;;
        -y | --yes)     ASSUME_YES=1; SEL_ALL=1 ;;
        -h | --help)    usage; exit 0 ;;
        *)              err "Unknown option: $1"; usage >&2; exit 1 ;;
    esac
    shift
done
sel_check

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
    local src="$1" dest="$2" nolink="${3:-}"

    if [ "$LINK_MODE" -eq 1 ] && [ "$nolink" != nolink ]; then
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

need_cmd() {
    command -v "$1" &>/dev/null && return 0
    err "$1 not installed, skipping $2."
    return 1
}

set_git() {  # $1=key  $2=prompt
    git config --global "$1" >/dev/null && return 0
    if have_tty; then
        read -rp "$2: " val || return 0
        [ -n "$val" ] && run git config --global "$1" "$val"
    else
        info "No git $1 set and input is not interactive; skipping."
    fi
    return 0
}

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

# === Selectable Configs ===

deploy_fish_config() {
    need_cmd fish "fish config" || return 0
    info "\nInstalling fish config..."
    run mkdir -p "$CFG/fish"
    install_file "$CONFIG_DIR/fish/config.fish" "$CFG/fish/config.fish"
    create_local "$CFG/fish/config.local.fish"
    set_login_shell
}

deploy_fish_aliases() {
    need_cmd fish "fish aliases" || return 0
    info "\nInstalling fish aliases..."
    run mkdir -p "$CFG/fish/conf.d"
    install_file "$CONFIG_DIR/fish/aliases.fish" "$CFG/fish/conf.d/aliases.fish"
    create_local "$CFG/fish/aliases.local.fish"
}

deploy_fish_functions() {
    need_cmd fish "fish functions" || return 0
    info "\nInstalling fish functions..."
    run mkdir -p "$CFG/fish/functions"
    for fn in "$CONFIG_DIR"/fish/functions/*.fish; do
        [ -e "$fn" ] || continue
        install_file "$fn" "$CFG/fish/functions/$(basename "$fn")"
    done
}

deploy_nano_config() {
    need_cmd nano "nano config" || return 0
    info "\nInstalling nano config..."
    run mkdir -p "$CFG/nano"

    local staged
    staged="$(mktemp)"
    
    if [ -f "$CONFIG_DIR/nano/nanorc" ]; then
        cat "$CONFIG_DIR/nano/nanorc" > "$staged"
    fi

    for f in "$CONFIG_DIR"/nano/syntax/*.nanorc; do
        [ -e "$f" ] || continue
        printf 'include "%s/nano/syntax/%s"\n' "$CFG" "$(basename "$f")" >> "$staged"
    done

    install_file "$staged" "$CFG/nano/nanorc" nolink
    rm -f "$staged"

    if [ -f "$HOME/.nanorc" ]; then
        err "$HOME/.nanorc exists and takes precedence over $CFG/nano/nanorc."
        info "Move or delete it for the deployed config to take effect."
    fi
}

deploy_nano_syntax() {
    need_cmd nano "nano syntax files" || return 0
    info "\nInstalling nano syntax files..."
    run mkdir -p "$CFG/nano/syntax"
    local f found=0
    for f in "$CONFIG_DIR"/nano/syntax/*.nanorc; do
        [ -e "$f" ] || continue
        install_file "$f" "$CFG/nano/syntax/$(basename "$f")"
        found=1
    done
    [ "$found" -eq 1 ] || info "No syntax files in config/nano/syntax/ yet."
    return 0
}

deploy_fastfetch() {
    need_cmd fastfetch "fastfetch config" || return 0
    info "\nInstalling fastfetch config..."
    run mkdir -p "$CFG/fastfetch"
    install_file "$CONFIG_DIR/fastfetch/config.jsonc" "$CFG/fastfetch/config.jsonc"
}

deploy_git() {
    need_cmd git "git config" || return 0
    info "\nApplying git config settings..."
    set_git user.email "Enter Git email"
    set_git user.name  "Enter Git name"
    run git config --global init.defaultBranch main
    ok "Git config applied."
}

[ -d "$CONFIG_DIR" ] || die "Config directory not found: $CONFIG_DIR"

ms_load "${MENU_ITEMS[@]}"

if [ "$LIST_ONLY" -eq 1 ]; then
    info "Configs setup.sh can deploy:"
    sel_list
    exit 0
fi

[ "$DRY_RUN" -eq 1 ] && info "Dry run - no changes will be made.\n"

SELECTED=()
choose SELECTED "Select configs to deploy:" || { info "Nothing to do."; exit 0; }
if [ "${#SELECTED[@]}" -eq 0 ]; then
    info "Nothing selected."
    exit 0
fi

info "Pulling configs from $REPO_DIR..."
for s in "${SELECTED[@]}"; do
    case "$s" in
        fish-config)    deploy_fish_config ;;
        fish-aliases)   deploy_fish_aliases ;;
        fish-functions) deploy_fish_functions ;;
        nano-config)    deploy_nano_config ;;
        nano-syntax)    deploy_nano_syntax ;;
        fastfetch)      deploy_fastfetch ;;
        git)            deploy_git ;;
    esac
done

ok "\nSetup complete."
