#!/usr/bin/env bash
# Put back the configs that setup.sh replaced, using the newest .bak of each.
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$REPO_DIR/lib/common.sh" || {
    echo "atlas-scripts: cannot load lib/common.sh" >&2; exit 1
}

CFG="${XDG_CONFIG_HOME:-$HOME/.config}"
SEARCH_DIRS=("$CFG/fish" "$CFG/fastfetch")

LIST_ONLY=0
DRY_RUN=0
ASSUME_YES=0

usage() {
    cat <<USAGE
Usage: restore.sh [options]

Restores each config setup.sh backed up, from its most recent .bak.<timestamp>.
Backups are left in place, so restoring is repeatable.

Options:
  -L, --list      List the backups that would be restored, then exit.
  -n, --dry-run   Report what would change without touching anything.
  -y, --yes       Restore everything without asking per file.
  -h, --help      Show this help.
USAGE
}

while [ $# -gt 0 ]; do
    case "$1" in
        -L | --list)    LIST_ONLY=1 ;;
        -n | --dry-run) DRY_RUN=1 ;;
        -y | --yes)     ASSUME_YES=1 ;;
        -h | --help)    usage; exit 0 ;;
        *)              err "Unknown option: $1"; usage >&2; exit 1 ;;
    esac
    shift
done

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

# Map each managed file to its newest backup. The timestamp format sorts
# lexicographically, so the last match wins.
declare -A NEWEST
while IFS= read -r bak; do
    [ -n "$bak" ] || continue
    NEWEST["${bak%.bak.*}"]="$bak"
done < <(find "${SEARCH_DIRS[@]}" -maxdepth 2 -name '*.bak.*' 2>/dev/null | sort)

# ${NEWEST[*]+x} rather than ${#NEWEST[@]}: under `set -u` bash treats an
# associative array with no elements as unbound and aborts.
if [ -z "${NEWEST[*]+x}" ]; then
    info "No backups found under: ${SEARCH_DIRS[*]}"
    exit 0
fi

if [ "$LIST_ONLY" -eq 1 ]; then
    info "Backups available to restore:"
    for dest in "${!NEWEST[@]}"; do
        printf '  %s\n    <- %s\n' "$dest" "$(basename "${NEWEST[$dest]}")"
    done
    exit 0
fi

restored=0
for dest in "${!NEWEST[@]}"; do
    bak="${NEWEST[$dest]}"
    if [ "$ASSUME_YES" -eq 1 ] || confirm "Restore $dest from $(basename "$bak")?"; then
        run cp -P "$bak" "$dest"
        did "Restored $dest"
        restored=$((restored + 1))
    else
        info "Skipped $dest"
    fi
done

ok "\nRestored $restored file(s)."
