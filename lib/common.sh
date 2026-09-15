# shellcheck shell=bash
# Shared helpers for atlas-scripts. Source this file, and check that it loaded:
#   . "$(dirname "$0")/lib/common.sh" || { echo "cannot load common.sh" >&2; exit 1; }

set -euo pipefail

if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
    RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
else
    RED=''; GREEN=''; YELLOW=''; NC=''
fi

info() { printf '%b%b%b\n' "$YELLOW" "$*" "$NC"; }
ok()   { printf '%b%b%b\n' "$GREEN"  "$*" "$NC"; }
err()  { printf '%b%b%b\n' "$RED"    "$*" "$NC" >&2; }
die()  { err "$*"; exit 1; }

CFG="${XDG_CONFIG_HOME:-$HOME/.config}"

declare -A SECTION_DIRS=(
    [fish]="$CFG/fish"
    [fastfetch]="$CFG/fastfetch"
    [nano]="$CFG/nano"
)

DRY_RUN="${DRY_RUN:-0}"

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

have_tty() { [ -t 0 ]; }
confirm() {
    have_tty || return 1
    local reply
    read -rp "$1 [y/N] " reply || return 1
    case "$reply" in
        [yY] | [yY][eE][sS]) return 0 ;;
        *) return 1 ;;
    esac
}

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

declare -A PKG_apt=(    [buildtools]="build-essential"    [kernelheaders]="" )
# shellcheck disable=SC2034
declare -A PKG_pacman=( [buildtools]="base-devel"         [kernelheaders]="" )
# shellcheck disable=SC2034
declare -A PKG_dnf=(    [buildtools]="@development-tools" [kernelheaders]="kernel-devel" )
# shellcheck disable=SC2034
declare -A PKG_zypper=( [buildtools]="gcc make"           [kernelheaders]="kernel-default-devel" )

resolve_pkg() {
    [ -n "$PKG_MANAGER" ] || die "resolve_pkg called before detect_pkg_manager"
    local -n __pkg_map="PKG_${PKG_MANAGER}"
    # '-' rather than ':-', so a deliberately empty mapping stays empty.
    printf '%s\n' "${__pkg_map[$1]-$1}"
}

pm_refresh() {
    case "$PKG_MANAGER" in
        apt)    run sudo apt-get update ;;
        pacman) run sudo pacman -Syu --noconfirm ;;
        dnf)    ;;  # dnf refreshes metadata on its own schedule
        zypper) run sudo zypper --non-interactive refresh ;;
    esac
}

pm_update() {
    pm_refresh || return 1
    case "$PKG_MANAGER" in
        apt)    run sudo apt-get full-upgrade -y ;;
        pacman) ;;  # the -Syu in pm_refresh already upgraded
        dnf)    run sudo dnf -y upgrade --refresh ;;
        zypper) run sudo zypper --non-interactive update ;;
    esac
}

pm_install() {
    case "$PKG_MANAGER" in
        apt)    run sudo apt-get install -y "$@" ;;
        pacman) run sudo pacman -S --needed --noconfirm "$@" ;;
        dnf)    run sudo dnf install -y "$@" ;;
        zypper) run sudo zypper --non-interactive install "$@" ;;
    esac
}

PM_LOG=""
PROGRESS_ACTIVE=0

term_cols() {
    local c="${COLUMNS:-}"
    [ -n "$c" ] || c="$(tput cols 2>/dev/null || echo 80)"
    case "$c" in
        '' | *[!0-9]*) c=80 ;;
        *) [ "$c" -ge 40 ] || c=80 ;;
    esac
    printf '%s\n' "$c"
}

progress_bar() {
    local done="$1" total="$2" label="$3"
    local pct cols barw labelw fill i bar=""

    [ "$total" -gt 0 ] || return 0
    pct=$(( done * 100 / total ))

    if [ ! -t 1 ]; then
        printf ' (%d/%d) installing %s\n' "$done" "$total" "$label"
        return 0
    fi

    cols="$(term_cols)"
    barw=24
    labelw=$(( cols - barw - 32 ))
    [ "$labelw" -lt 10 ] && labelw=10
    [ "$labelw" -gt 28 ] && labelw=28

    fill=$(( pct * barw / 100 ))
    for ((i = 0; i < barw; i++)); do
        if   [ "$i" -lt $((fill - 1)) ];  then bar+="-"
        elif [ "$i" -eq $((fill - 1)) ];  then bar+="C"
        elif (( (i - fill) % 2 == 0 ));   then bar+="•"
        else                                   bar+=" "
        fi
    done

    printf '\r\033[K (%d/%d) installing %-*.*s [%b%b%b] %3d%%' \
        "$done" "$total" "$labelw" "$labelw" "$label" \
        "$YELLOW" "$bar" "$NC" "$pct"
    PROGRESS_ACTIVE=1
}

progress_end() {
    [ "$PROGRESS_ACTIVE" -eq 1 ] || return 0
    PROGRESS_ACTIVE=0
    printf '\n'
}

spin_run() {
    local title="$1"; shift
    local pid i=0 rc=0
    local -a frames=(- \\ '|' /)

    if [ ! -t 1 ]; then
        info "$title"
        "$@" >>"$PM_LOG" 2>&1
        return
    fi

    "$@" >>"$PM_LOG" 2>&1 &
    pid=$!
    while kill -0 "$pid" 2>/dev/null; do
        printf '\r\033[K %b%s%b %s' "$YELLOW" "${frames[i % 4]}" "$NC" "$title"
        i=$((i + 1))
        sleep 0.15
    done
    wait "$pid" || rc=$?
    printf '\r\033[K'
    return "$rc"
}

sudo_prime() {
    command -v sudo &>/dev/null || return 0
    [ "$(id -u)" -ne 0 ] || return 0
    sudo -v || die "sudo is required to install packages."
}

# -- Multi-select menu --------------------------------------------------------
# A checkbox menu shared by install.sh, setup.sh and restore.sh.
#
#   ms_load <item>...   then   choose <out-array-name> <title>
#     item := "key|section|label|members"
#
# A row with empty `members` is a leaf and holds the actual on/off state. A row
# with members is a set: it holds no state of its own, rendering [x] when all
# its members are on, [~] when some are and [ ] when none, and toggling it
# drives every member to the new value. Deriving set state rather than storing
# it is what stops the two tiers from ever disagreeing.
#
# `section` prints as a heading whenever it changes, so grouping is controlled
# purely by the order the caller passes items in.
#
# Menu and prompt both go to stderr - bash writes `read -p` there anyway, so
# this keeps the two from interleaving and leaves stdout clean for --list.

MS_KEY=(); MS_SECTION=(); MS_LABEL=(); MS_MEMBERS=(); MS_STATE=()
declare -A MS_INDEX=()

# Where every way of picking rows leaves its answer. A shared buffer rather
# than stdout: a command substitution would run these in a subshell, where a
# `die` on an unknown name exits only that subshell and lets the script carry
# on with a short list.
SEL_EXPANDED=()

# Parse item records into the MS_* arrays, everything pre-selected so that a
# bare Enter reproduces the all-inclusive behaviour these scripts had before
# the menu existed.
ms_load() {
    MS_KEY=(); MS_SECTION=(); MS_LABEL=(); MS_MEMBERS=(); MS_STATE=(); MS_INDEX=()
    local item rest key
    for item in "$@"; do
        [ "${item//[^|]/}" = "|||" ] || die "multiselect: bad item record: $item"
        key="${item%%|*}"
        [ -z "${MS_INDEX[$key]:-}" ] || die "multiselect: duplicate row key: $key"
        MS_INDEX[$key]="${#MS_KEY[@]}"
        MS_KEY+=("$key");            rest="${item#*|}"
        MS_SECTION+=("${rest%%|*}"); rest="${rest#*|}"
        MS_LABEL+=("${rest%%|*}")
        MS_MEMBERS+=("${rest#*|}")
        MS_STATE+=(1)
    done
}

# How much of set row $1 is selected: 2 = all, 1 = some, 0 = none.
ms_set_state() {
    local m j on=0 total=0
    local -a members=()
    read -ra members <<< "${MS_MEMBERS[$1]}"
    for m in ${members[@]+"${members[@]}"}; do
        j="${MS_INDEX[$m]:-}"
        [ -n "$j" ] || continue
        total=$((total + 1))
        if [ "${MS_STATE[$j]}" -eq 1 ]; then on=$((on + 1)); fi
    done
    if [ "$total" -eq 0 ] || [ "$on" -eq 0 ]; then
        printf '0\n'
    elif [ "$on" -eq "$total" ]; then
        printf '2\n'
    else
        printf '1\n'
    fi
}

# Flip row $1. A set drives all its members to the same new value; a partly
# selected set fills up first, which is the least surprising direction.
ms_toggle_row() {
    local i="$1" new m j
    local -a members=()
    if [ -z "${MS_MEMBERS[$i]}" ]; then
        MS_STATE[i]=$((1 - MS_STATE[i]))
        return 0
    fi
    if [ "$(ms_set_state "$i")" -eq 2 ]; then new=0; else new=1; fi
    read -ra members <<< "${MS_MEMBERS[$i]}"
    for m in ${members[@]+"${members[@]}"}; do
        j="${MS_INDEX[$m]:-}"
        [ -n "$j" ] || continue
        MS_STATE[j]=$new
    done
    return 0
}

# Drive every leaf to $1 (0 or 1), or flip them all when $1 is `invert`.
ms_set_all() {
    local i
    for i in "${!MS_STATE[@]}"; do
        if [ -n "${MS_MEMBERS[$i]}" ]; then continue; fi
        if [ "$1" = invert ]; then
            MS_STATE[i]=$((1 - MS_STATE[i]))
        else
            MS_STATE[i]="$1"
        fi
    done
}

# Apply one line of menu input to MS_STATE. Split out from the menu loop so the
# token grammar can be exercised in CI without a terminal.
# Returns 0 if every token was understood, 1 if any was rejected (the good ones
# still apply - a typo should not discard the rest of the line), 2 to quit.
ms_apply_tokens() {
    local tok lo hi i rc=0
    local -a toks=()
    read -ra toks <<< "${1//,/ }"
    for tok in ${toks[@]+"${toks[@]}"}; do
        case "$tok" in
            a | A | all)    ms_set_all 1 ;;
            n | N | none)   ms_set_all 0 ;;
            v | V | invert) ms_set_all invert ;;
            q | Q | quit)   return 2 ;;
            *[!0-9-]*)  # a row name - matched after the single-letter commands,
                        # so a row keyed 'a', 'n', 'v' or 'q' is unreachable by name
                i="${MS_INDEX[$tok]:-}"
                if [ -n "$i" ]; then
                    ms_toggle_row "$i"
                else
                    err "Not a valid choice: $tok"; rc=1
                fi ;;
            *-*)        # numeric range
                lo="${tok%%-*}"; hi="${tok##*-}"
                if [ -z "$lo" ] || [ -z "$hi" ] \
                    || [ -n "${lo//[0-9]/}" ] || [ -n "${hi//[0-9]/}" ] \
                    || [ "$lo" -lt 1 ] || [ "$hi" -gt "${#MS_KEY[@]}" ] \
                    || [ "$lo" -gt "$hi" ]; then
                    err "Bad range: $tok"; rc=1; continue
                fi
                for ((i = lo; i <= hi; i++)); do ms_toggle_row "$((i - 1))"; done ;;
            *)          # a single row number
                if [ "$tok" -ge 1 ] && [ "$tok" -le "${#MS_KEY[@]}" ]; then
                    ms_toggle_row "$((tok - 1))"
                else
                    err "Out of range: $tok"; rc=1
                fi ;;
        esac
    done
    return "$rc"
}

# Draw the menu. Reprints rather than moving the cursor, so line wrapping and
# scrollback both stay sane.
ms_render() {
    local i mark last=$'\001'
    printf '\n%b%s%b\n\n' "$YELLOW" "$1" "$NC" >&2
    for i in "${!MS_KEY[@]}"; do
        if [ "${MS_SECTION[$i]}" != "$last" ]; then
            last="${MS_SECTION[$i]}"
            if [ -n "$last" ]; then printf '  %b%s%b\n' "$YELLOW" "$last" "$NC" >&2; fi
        fi
        if [ -n "${MS_MEMBERS[$i]}" ]; then
            case "$(ms_set_state "$i")" in
                2) mark='x' ;;
                1) mark='~' ;;
                *) mark=' ' ;;
            esac
        elif [ "${MS_STATE[$i]}" -eq 1 ]; then
            mark='x'
        else
            mark=' '
        fi
        printf '   %2d) [%s] %-16s %s\n' \
            "$((i + 1))" "$mark" "${MS_KEY[$i]}" "${MS_LABEL[$i]}" >&2
    done
    printf '\n  %s\n  %s\n' \
        'numbers or ranges toggle a row (e.g. 1 3-5); a name toggles that row' \
        'a=all  n=none  v=invert  q=quit  Enter=confirm' >&2
}

# Run the menu until the user confirms. Returns 1 if they quit.
multiselect() {
    local line rc
    while true; do
        ms_render "$1"
        if ! read -rp "> " line; then printf '\n' >&2; return 1; fi
        if [ -z "${line//[[:space:]]/}" ]; then break; fi
        rc=0; ms_apply_tokens "$line" || rc=$?
        if [ "$rc" -eq 2 ]; then return 1; fi
    done
    sel_selected
}

# -- gum ----------------------------------------------------------------------
# gum draws a far nicer menu than we can, so it is the preferred front end. It
# is not in every distro's repos though (Debian 12, Ubuntu 24.04, Fedora and
# openSUSE all lack it), so there are three tiers: use an installed gum, else
# install one, else fall back to the built-in menu in this file.
GUM_VERSION="0.17.0"
GUM_BIN=""
GUM_TRIED=0

# -- gum theme --
# gum reads its colours from the environment, so setting them here themes every
# menu from one place. Each takes either an ANSI 256 number ("212") or a hex
# string ("#00D7AF"); an empty value leaves gum's own default alone. The
# ${VAR:-default} form means anything already exported in your shell wins, so
# you can re-theme without editing the repo.
export GUM_CHOOSE_HEADER_FOREGROUND="${GUM_CHOOSE_HEADER_FOREGROUND:-#00D7AF}"
export GUM_CHOOSE_CURSOR_FOREGROUND="${GUM_CHOOSE_CURSOR_FOREGROUND:-#FF5FAF}"
export GUM_CHOOSE_SELECTED_FOREGROUND="${GUM_CHOOSE_SELECTED_FOREGROUND:-#5FFFAF}"
export GUM_CHOOSE_ITEM_FOREGROUND="${GUM_CHOOSE_ITEM_FOREGROUND:-}"

# Fetch the upstream static binary into ~/.local/bin. Deliberately not Charm's
# apt/yum repo: a menu is not worth leaving a third-party package source and
# signing key on someone's machine, and this needs no root.
gum_download() {
    local arch url tmp found rc=0
    case "$(uname -m)" in
        x86_64)          arch=x86_64 ;;
        aarch64 | arm64) arch=arm64 ;;
        *) err "No gum build for $(uname -m)."; return 1 ;;
    esac
    url="https://github.com/charmbracelet/gum/releases/download/v$GUM_VERSION/gum_${GUM_VERSION}_Linux_${arch}.tar.gz"

    command -v curl &>/dev/null || { err "curl is needed to fetch gum."; return 1; }
    tmp="$(mktemp -d)"
    info "Downloading gum $GUM_VERSION..."
    if ! curl -fsSL "$url" -o "$tmp/gum.tgz"; then
        err "Could not download gum from $url"
        rc=1
    elif ! tar -xzf "$tmp/gum.tgz" -C "$tmp"; then
        err "Could not unpack the gum archive."
        rc=1
    else
        found="$(find "$tmp" -type f -name gum | head -1)"
        if [ -z "$found" ]; then
            err "No gum binary inside the archive."
            rc=1
        else
            mkdir -p "$HOME/.local/bin"
            install -m 755 "$found" "$HOME/.local/bin/gum" || rc=1
        fi
    fi
    rm -rf "$tmp"
    [ "$rc" -eq 0 ] || return 1

    GUM_BIN="$HOME/.local/bin/gum"
    ok "Installed gum to $GUM_BIN"
    case ":$PATH:" in
        *":$HOME/.local/bin:"*) ;;
        *) info "Add $HOME/.local/bin to your PATH to use gum directly." ;;
    esac
}

# Locate gum, installing it if we are allowed to. Returns 1 when we end up
# without one, so the caller can fall back to the built-in menu.
ensure_gum() {
    GUM_BIN="$(command -v gum 2>/dev/null || true)"
    [ -n "$GUM_BIN" ] && return 0
    if [ -x "$HOME/.local/bin/gum" ]; then
        GUM_BIN="$HOME/.local/bin/gum"
        return 0
    fi

    # Only try once per run, however many menus a script shows.
    [ "$GUM_TRIED" -eq 0 ] || return 1
    GUM_TRIED=1

    # Installing anything would break the promise --dry-run makes.
    if [ "$DRY_RUN" -eq 1 ]; then
        info "gum is not installed; --dry-run will not install it."
        return 1
    fi

    info "gum is not installed. It gives these menus a nicer interface."
    confirm "Install gum?" || { info "Using the built-in menu instead."; return 1; }

    # The distro package first - a managed package beats a loose binary when
    # the distro actually has one.
    if detect_pkg_manager; then
        pm_install gum || true
        GUM_BIN="$(command -v gum 2>/dev/null || true)"
        if [ -n "$GUM_BIN" ]; then
            ok "Installed gum with $PKG_MANAGER."
            return 0
        fi
        info "gum is not in this distro's repos; fetching the official build."
    fi

    gum_download || { err "Could not install gum; using the built-in menu."; return 1; }
    return 0
}

# Render the leaf rows as `gum choose` arguments. Each is "<display>\t<key>",
# which --label-delimiter splits so gum shows the display text but prints back
# the bare key. Split out from gum_menu so CI can check it without a terminal.
#
# Set rows are deliberately left out. gum's list is flat, and its --selected
# cannot preselect by value, so a set row would have to start checked like
# everything else - and unchecking it would then appear to do nothing, because
# its members stay checked on their own. Sets remain available through --only,
# --exclude and --list, and the built-in menu still shows them as real rows.
gum_args() {
    local i
    GUM_ARGS=()
    for i in "${!MS_KEY[@]}"; do
        [ -z "${MS_MEMBERS[$i]}" ] || continue
        GUM_ARGS+=("$(printf '%-10s %-16s %s\t%s' \
            "${MS_SECTION[$i]}" "${MS_KEY[$i]}" "${MS_LABEL[$i]}" "${MS_KEY[$i]}")")
    done
}
GUM_ARGS=()

# Name the sets in the header, so they stay discoverable from the menu even
# though they are not rows in it.
gum_header() {
    local i sets=""
    for i in "${!MS_KEY[@]}"; do
        [ -n "${MS_MEMBERS[$i]}" ] || continue
        sets="$sets ${MS_KEY[$i]}"
    done
    if [ -n "$sets" ]; then
        printf '%s\n(sets:%s - pick one with --only)' "$1" "$sets"
    else
        printf '%s' "$1"
    fi
}

# The gum front end. Fills SEL_EXPANDED; returns 1 if the user aborted.
gum_menu() {
    local height rc=0
    local -a chosen=()
    gum_args

    # Show every row at once where the terminal allows it, rather than making
    # the user scroll a list of six things.
    height=$(( ${#GUM_ARGS[@]} + 1 ))
    [ "$height" -gt 20 ] && height=20

    mapfile -t chosen < <("$GUM_BIN" choose \
        --no-limit --selected='*' --height="$height" \
        --header="$(gum_header "$1")" --label-delimiter=$'\t' \
        "${GUM_ARGS[@]}") || rc=$?
    # gum exits 130 on ctrl-c and 1 when it cannot open a terminal.
    [ "$rc" -eq 0 ] || return 1

    expand_keys ${chosen[@]+"${chosen[@]}"}
}

# -- Selection ----------------------------------------------------------------
# Flag state shared by every script that offers a menu, seeded here so the
# helpers below are safe under `set -u` before args have been parsed.
SEL_ALL=0
SEL_ONLY=""
SEL_EXCLUDE=""

# Leaf keys, in row order: every one, or only those currently toggled on.
sel_leaves()   { sel_filter all; }
sel_selected() { sel_filter on; }
sel_filter() {
    local i
    SEL_EXPANDED=()
    for i in "${!MS_KEY[@]}"; do
        [ -z "${MS_MEMBERS[$i]}" ] || continue
        if [ "$1" = all ] || [ "${MS_STATE[$i]}" -eq 1 ]; then
            SEL_EXPANDED+=("${MS_KEY[$i]}")
        fi
    done
}

# Expand row names - sets or leaves - into leaf keys, deduped and in canonical
# row order. An unknown name is fatal: a typo must never silently skip
# something the user asked for.
expand_keys() {
    local tok i j
    local -a members=()
    declare -A want=()
    for tok in "$@"; do
        i="${MS_INDEX[$tok]:-}"
        [ -n "$i" ] || die "Unknown selection '$tok'; see --list"
        if [ -n "${MS_MEMBERS[$i]}" ]; then
            read -ra members <<< "${MS_MEMBERS[$i]}"
            for j in ${members[@]+"${members[@]}"}; do want[$j]=1; done
        else
            want[$tok]=1
        fi
    done
    SEL_EXPANDED=()
    for i in "${!MS_KEY[@]}"; do
        if [ -z "${MS_MEMBERS[$i]}" ] && [ -n "${want[${MS_KEY[$i]}]:-}" ]; then
            SEL_EXPANDED+=("${MS_KEY[$i]}")
        fi
    done
}

# The same, for a comma- or space-separated list as --only and --exclude take.
expand_names() {
    local -a toks=()
    read -ra toks <<< "${1//,/ }"
    expand_keys ${toks[@]+"${toks[@]}"}
}

# Print the loaded rows for --list, on stdout so it can be piped or grepped.
sel_list() {
    local i
    for i in "${!MS_KEY[@]}"; do
        if [ -n "${MS_MEMBERS[$i]}" ]; then
            printf '  %-16s set: %s\n' "${MS_KEY[$i]}" "${MS_MEMBERS[$i]}"
        else
            printf '  %-16s %s\n' "${MS_KEY[$i]}" "${MS_LABEL[$i]}"
        fi
    done
}

# The selection flow shared by install.sh, setup.sh and restore.sh: --only wins
# over --all, either one skips the menu, and --exclude is subtracted last. With
# no flags we show the menu, or - with no terminal to show it on - keep the
# all-inclusive behaviour these scripts had before.
# MS_* must already be loaded. Returns 1 if the user quit the menu.
choose() {
    local -n __ch_out="$1"
    local key
    declare -A drop=()
    local -a kept=()

    if [ -n "$SEL_ONLY" ]; then
        expand_names "$SEL_ONLY"
    elif [ "$SEL_ALL" -eq 1 ]; then
        sel_leaves
    elif have_tty; then
        if ensure_gum; then
            gum_menu "$2" || return 1
        else
            multiselect "$2" || return 1
        fi
    else
        info "Non-interactive: selecting everything (use --only to narrow)."
        sel_leaves
    fi

    if [ -n "$SEL_EXCLUDE" ]; then
        kept=("${SEL_EXPANDED[@]}")
        expand_names "$SEL_EXCLUDE"
        for key in "${SEL_EXPANDED[@]}"; do drop[$key]=1; done
        SEL_EXPANDED=()
        for key in "${kept[@]}"; do
            if [ -z "${drop[$key]:-}" ]; then SEL_EXPANDED+=("$key"); fi
        done
    fi

    __ch_out=("${SEL_EXPANDED[@]}")
    return 0
}

# Shared flag handling. Returns 0 if it consumed $1 - setting SEL_SHIFT to how
# many arguments to drop - and 1 if the caller should handle the flag itself.
# Call as `sel_flag "$@"` so the value-taking forms can see their argument.
LIST_ONLY=0
SEL_SHIFT=1
# shellcheck disable=SC2034  # LIST_ONLY and SEL_SHIFT are read by the callers
sel_flag() {
    SEL_SHIFT=1
    case "$1" in
        -a | --all)     SEL_ALL=1 ;;
        -L | --list)    LIST_ONLY=1 ;;
        -n | --dry-run) DRY_RUN=1 ;;
        --only=*)       SEL_ONLY="$SEL_ONLY ${1#*=}" ;;
        --exclude=*)    SEL_EXCLUDE="$SEL_EXCLUDE ${1#*=}" ;;
        -o | --only)
            [ $# -ge 2 ] || die "$1 needs a list of names."
            SEL_ONLY="$SEL_ONLY $2"; SEL_SHIFT=2 ;;
        -x | --exclude)
            [ $# -ge 2 ] || die "$1 needs a list of names."
            SEL_EXCLUDE="$SEL_EXCLUDE $2"; SEL_SHIFT=2 ;;
        *) return 1 ;;
    esac
    return 0
}

# --all and --only both claim to be the whole answer; honouring one silently
# would hide the other.
sel_check() {
    if [ "$SEL_ALL" -eq 1 ] && [ -n "$SEL_ONLY" ]; then
        die "--all cannot be combined with --only."
    fi
}
