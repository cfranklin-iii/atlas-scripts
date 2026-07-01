#!/usr/bin/env bash
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$REPO_DIR/lib/common.sh"

DOTFILES_DIR="$REPO_DIR/dotfiles"
CFG="${XDG_CONFIG_HOME:-$HOME/.config}"

# Backup an existing file to a timestamped .bak, then install the new one.
install_file() {
    local src="$1" dest="$2"
    [ -f "$dest" ] && cp "$dest" "$dest.bak.$(date +%Y%m%d%H%M%S)" \
        && info "Backed up $dest"
    cp "$src" "$dest"
}

# Create a local-overrides template only if it is missing (never overwrite).
create_local() {
    [ -f "$1" ] && return
    printf '%s\n' \
        '# Machine-specific overrides.' \
        '# This file is NOT managed by atlas-scripts and will not be overwritten.' \
        '# Add your personal aliases / settings below.' > "$1"
    ok "Created local overrides file: $1"
}

info "Pulling configs from $REPO_DIR..."

# -- Fish --
if command -v fish &>/dev/null; then
    info "\nSetting up fish shell..."
    mkdir -p "$CFG/fish/conf.d" "$CFG/fish/functions"

    install_file "$DOTFILES_DIR/fish/config.fish"  "$CFG/fish/config.fish"
    install_file "$DOTFILES_DIR/fish/aliases.fish" "$CFG/fish/conf.d/aliases.fish"

    if compgen -G "$DOTFILES_DIR/fish/functions/*" >/dev/null; then
        cp "$DOTFILES_DIR/fish/functions/"* "$CFG/fish/functions/"
    fi

    create_local "$CFG/fish/config.local.fish"
    create_local "$CFG/fish/aliases.local.fish"
    ok "Fish config, aliases and functions loaded."
else
    err "Fish shell not installed, skipping."
fi

# -- Fastfetch --
if command -v fastfetch &>/dev/null; then
    info "\nSetting up fastfetch..."
    mkdir -p "$CFG/fastfetch"
    install_file "$DOTFILES_DIR/fastfetch/config.jsonc" "$CFG/fastfetch/config.jsonc"
    ok "Fastfetch config loaded to: $CFG/fastfetch/config.jsonc"
else
    err "Fastfetch not installed, skipping."
fi

# -- Git --
if command -v git &>/dev/null; then
    info "\nApplying git config settings..."
    set_git() {  # $1=key  $2=prompt
        git config --global "$1" >/dev/null && return
        if [ -t 0 ]; then
            read -rp "$2: " val && [ -n "$val" ] && git config --global "$1" "$val"
        else
            info "No git $1 set and input is not interactive; skipping."
        fi
    }
    set_git user.email "Enter Git email"
    set_git user.name  "Enter Git name"
    git config --global init.defaultBranch main
    ok "Git config applied."
else
    err "Git not installed, skipping."
fi
