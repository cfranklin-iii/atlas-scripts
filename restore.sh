#!/usr/bin/env bash
# Put back the configs that setup.sh replaced, using the newest .bak of each.
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$REPO_DIR/lib/common.sh" || {
    echo "atlas-scripts: cannot load lib/common.sh" >&2; exit 1
}

usage() {
    cat <<USAGE
Usage: restore.sh [options]

Restores each config setup.sh backed up, from its most recent .bak.<timestamp>.
Backups are left in place, so restoring is repeatable.

With no selection option and a terminal to draw on, restore.sh shows a menu of
the available backups, everything pre-selected. With no terminal it restores
everything without asking.

Note that git settings are never backed up, so restore.sh cannot undo them.

Options:
  -a, --all       Restore everything without showing the menu.
  -o, --only LIST Restore just these files or directories.
  -x, --exclude LIST
                  Drop these files or directories from the selection.
  -L, --list      List the backups that would be restored, then exit.
  -n, --dry-run   Report what would change without touching anything.
  -y, --yes       Restore everything without asking.
  -h, --help      Show this help.
USAGE
}

while [ $# -gt 0 ]; do
    if sel_flag "$@"; then
        shift "$SEL_SHIFT"
        continue
    fi
    case "$1" in
        -y | --yes)  SEL_ALL=1 ;;
        -h | --help) usage; exit 0 ;;
        *)           err "Unknown option: $1"; usage >&2; exit 1 ;;
    esac
    shift
done
sel_check

# Search exactly where setup.sh writes. Missing directories are dropped rather
# than passed to find, which would make it complain about every one of them.
SEARCH_DIRS=()
for sect in "${!SECTION_DIRS[@]}"; do
    if [ -d "${SECTION_DIRS[$sect]}" ]; then SEARCH_DIRS+=("${SECTION_DIRS[$sect]}"); fi
done
if [ "${#SEARCH_DIRS[@]}" -eq 0 ]; then
    info "No managed config directories found under $CFG"
    exit 0
fi

# Map each managed file to its newest backup. The timestamp format sorts
# lexicographically, so the last match wins.
declare -A NEWEST=()
while IFS= read -r bak; do
    [ -n "$bak" ] || continue
    NEWEST["${bak%.bak.*}"]="$bak"
done < <(find "${SEARCH_DIRS[@]}" -maxdepth 2 -name '*.bak.*' | sort)

# ${NEWEST[*]+x} rather than ${#NEWEST[@]}: under `set -u` bash treats an
# associative array with no elements as unbound and aborts.
if [ -z "${NEWEST[*]+x}" ]; then
    info "No backups found under: ${SEARCH_DIRS[*]}"
    exit 0
fi

# Rows are keyed by the path relative to $CFG, so they stay short enough to
# type at the menu, and grouped under a set per config directory.
mapfile -t DESTS < <(printf '%s\n' "${!NEWEST[@]}" | sort)

declare -A SET_MEMBERS=()
SET_ORDER=()
for dest in "${DESTS[@]}"; do
    rel="${dest#"$CFG"/}"
    sect="${rel%%/*}"
    if [ -z "${SET_MEMBERS[$sect]:-}" ]; then SET_ORDER+=("$sect"); fi
    SET_MEMBERS[$sect]="${SET_MEMBERS[$sect]:-} $rel"
done

MENU_ITEMS=()
for sect in "${SET_ORDER[@]}"; do
    MENU_ITEMS+=("$sect|Sets|every backup under $sect/|${SET_MEMBERS[$sect]# }")
done
for dest in "${DESTS[@]}"; do
    MENU_ITEMS+=("${dest#"$CFG"/}|Backups|from $(basename "${NEWEST[$dest]}")|")
done

ms_load "${MENU_ITEMS[@]}"

if [ "$LIST_ONLY" -eq 1 ]; then
    info "Backups available to restore:"
    for dest in "${DESTS[@]}"; do
        printf '  %s\n    <- %s\n' "$dest" "$(basename "${NEWEST[$dest]}")"
    done
    exit 0
fi

SELECTED=()
choose SELECTED "Select backups to restore:" || { info "Nothing to do."; exit 0; }

restored=0
for rel in ${SELECTED[@]+"${SELECTED[@]}"}; do
    dest="$CFG/$rel"
    run cp -P "${NEWEST[$dest]}" "$dest"
    did "Restored $dest"
    restored=$((restored + 1))
done

if [ "$DRY_RUN" -eq 1 ]; then
    info "\nWould restore $restored file(s)."
else
    ok "\nRestored $restored file(s)."
fi
