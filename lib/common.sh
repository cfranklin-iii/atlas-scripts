# shellcheck shell=bash
# Shared helpers for atlas-scripts. Source this file, and check that it loaded:
#   . "$(dirname "$0")/lib/common.sh" || { echo "cannot load common.sh" >&2; exit 1; }
#
# Without that check a missing common.sh is near-silent: `set -e` is never
# enabled and info/err fall through to unrelated binaries on PATH (`info` is
# texinfo), so the script limps on and reports nonsense.

set -euo pipefail

# -- Colors (suppressed when not writing to a terminal, or when NO_COLOR is set) --
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
    RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
else
    RED=''; GREEN=''; YELLOW=''; NC=''
fi

# -- Logging helpers --
# %b keeps the \n escapes that callers pass in working.
info() { printf '%b%b%b\n' "$YELLOW" "$*" "$NC"; }
ok()   { printf '%b%b%b\n' "$GREEN"  "$*" "$NC"; }
err()  { printf '%b%b%b\n' "$RED"    "$*" "$NC" >&2; }
die()  { err "$*"; exit 1; }

# -- Prompt helper --
# Yes/no prompt. Returns 1 (no) when stdin is not a terminal, so unattended
# runs never block waiting for an answer that will not come.
confirm() {
    [ -t 0 ] || return 1
    local reply
    read -rp "$1 [y/N] " reply || return 1
    case "$reply" in
        [yY] | [yY][eE][sS]) return 0 ;;
        *) return 1 ;;
    esac
}

# -- Package manager detection --
# Sets PKG_MANAGER (apt|pacman|dnf|zypper), or returns 1 so the caller decides
# what to do. Safe to call multiple times.
PKG_MANAGER="${PKG_MANAGER:-}"
detect_pkg_manager() {
    if command -v apt-get &>/dev/null; then
        PKG_MANAGER="apt"
    elif command -v pacman &>/dev/null; then
        PKG_MANAGER="pacman"
    elif command -v dnf &>/dev/null; then
        PKG_MANAGER="dnf"
    elif command -v zypper &>/dev/null; then
        PKG_MANAGER="zypper"
    else
        err "Unsupported package manager. Please install packages manually."
        return 1
    fi
}
