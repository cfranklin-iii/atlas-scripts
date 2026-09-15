#!/usr/bin/env bash
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$REPO_DIR/lib/common.sh" || {
    echo "atlas-scripts: cannot load lib/common.sh" >&2; exit 1
}

# What to install, in logical names. `buildtools` is spelled differently on
# every distro, so lib/common.sh resolves it; everything else is spelled the
# same everywhere and passes straight through.
GROUP_ORDER=(core shell tools dev)
declare -A GROUP_PKGS=(
    [core]="git curl wget"
    [shell]="fish"
    [tools]="tree btop fastfetch"
    [dev]="buildtools"
)
declare -A GROUP_DESC=(
    [core]="fetching and version control"
    [shell]="the fish shell"
    [tools]="terminal tools"
    [dev]="compiler toolchain"
)

usage() {
    cat <<USAGE
Usage: install.sh [options]

Updates the system and installs packages with the detected package manager.

With no selection option and a terminal to draw on, install.sh shows a menu of
the packages below, everything pre-selected - so a bare Enter installs the lot.
With no terminal (CI, a piped install) it installs everything without asking.

Options:
  -a, --all       Install everything without showing the menu.
  -o, --only LIST Install just these packages or sets (comma or space separated).
  -x, --exclude LIST
                  Drop these packages or sets from the selection.
  -L, --list      List the packages and sets, then exit.
  -n, --dry-run   Report what would be run without installing anything.
  -h, --help      Show this help.
USAGE
}

while [ $# -gt 0 ]; do
    if sel_flag "$@"; then
        shift "$SEL_SHIFT"
        continue
    fi
    # Both arms exit, so there is nothing left to shift past.
    case "$1" in
        -h | --help) usage; exit 0 ;;
        *)           err "Unknown option: $1"; usage >&2; exit 1 ;;
    esac
done
sel_check

# Detection has to come first: the menu shows each package's real name on this
# distro, which is exactly what the package manager determines.
info "Detecting package manager..."
detect_pkg_manager || exit 1

MENU_ITEMS=()
for g in "${GROUP_ORDER[@]}"; do
    MENU_ITEMS+=("$g|Sets|${GROUP_DESC[$g]}|${GROUP_PKGS[$g]}")
done
for g in "${GROUP_ORDER[@]}"; do
    read -ra group_pkgs <<< "${GROUP_PKGS[$g]}"
    for p in "${group_pkgs[@]}"; do
        real="$(resolve_pkg "$p")"
        if [ -z "$real" ]; then
            label="not needed on $PKG_MANAGER"
        elif [ "$real" = "$p" ]; then
            label=""
        else
            label="$real"
        fi
        MENU_ITEMS+=("$p|Packages|$label|")
    done
done

ms_load "${MENU_ITEMS[@]}"

if [ "$LIST_ONLY" -eq 1 ]; then
    info "Packages install.sh can install (via $PKG_MANAGER):"
    sel_list
    exit 0
fi

SELECTED=()
choose SELECTED "Select packages to install:" || { info "Nothing to do."; exit 0; }

# Expand logical names to real ones. One logical name can yield several real
# packages (zypper's "gcc make") or none at all, and the same package can be
# reachable from two sets, so dedupe on the way through.
declare -A PKG_SEEN=()
PACKAGES=()
add_logical() {
    local logical real
    local -a parts
    for logical in "$@"; do
        parts=()
        read -ra parts <<< "$(resolve_pkg "$logical")"
        for real in ${parts[@]+"${parts[@]}"}; do
            if [ -n "${PKG_SEEN[$real]:-}" ]; then continue; fi
            PKG_SEEN[$real]=1
            PACKAGES+=("$real")
        done
    done
}
add_logical ${SELECTED[@]+"${SELECTED[@]}"}

if [ "${#PACKAGES[@]}" -eq 0 ]; then
    info "Nothing selected."
    exit 0
fi

# --dry-run keeps the old narrated output: there is nothing to show progress
# for, and run() already describes every command it would have run.
if [ "$DRY_RUN" -eq 1 ]; then
    info "\nUpdating system packages using $PKG_MANAGER..."
    pm_update || die "Failed to update system packages."
    info "\nInstalling: ${PACKAGES[*]}"
    for pkg in "${PACKAGES[@]}"; do pm_install "$pkg"; done
    ok "\nInstallation complete!"
    exit 0
fi

# Everything below hides command output behind the progress bar, so get the
# password prompt out of the way while it can still be seen.
sudo_prime
PM_LOG="$(mktemp -t atlas-install.XXXXXX.log)"

if ! spin_run "Updating system packages ($PKG_MANAGER)..." pm_update; then
    err "Failed to update system packages. Check your network and package manager."
    info "Log: $PM_LOG"
    exit 1
fi
ok "System packages updated."

# One package at a time, so the count in the bar is the real count. It costs a
# dependency resolution per package, but it is the only way to know which of
# them is installing right now - and it makes a failure name exactly one.
info "\nInstalling ${#PACKAGES[@]} package(s)..."
FAILED=()
FAILED_LOG=()
n=0
for pkg in "${PACKAGES[@]}"; do
    n=$((n + 1))
    progress_bar "$n" "${#PACKAGES[@]}" "$pkg"
    out="$(mktemp -t "atlas-pkg.XXXXXX")"
    if ! pm_install "$pkg" >"$out" 2>&1; then
        FAILED+=("$pkg")
        FAILED_LOG+=("$(grep -iE '^(E:|error|warning)' "$out" | tail -3)")
    fi
    cat "$out" >>"$PM_LOG"
    rm -f "$out"
done
progress_end

if [ "${#FAILED[@]}" -gt 0 ]; then
    err "\nCould not install: ${FAILED[*]}"
    for n in "${!FAILED[@]}"; do
        printf '  %s\n' "${FAILED[$n]}"
        # The package manager's own words, which is what makes this fixable.
        printf '%s\n' "${FAILED_LOG[$n]}" | sed 's/^/    /'
    done
    info "These are probably not in your distro's repos; install them manually."
    info "Full log: $PM_LOG"
    exit 1
fi

rm -f "$PM_LOG"
ok "Successfully installed: ${PACKAGES[*]}!"
ok "\nInstallation complete!"
