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

# shellcheck disable=SC2034  # read by restore.sh, not from this file
declare -A SECTION_DIRS=(
    [fish]="$CFG/fish"
    [fastfetch]="$CFG/fastfetch"
    [nano]="$CFG/nano"
)

# A package the distro does not have is installed into ~/.local/bin instead
# (see "Upstream fallbacks" below), and not every distro has that on PATH.
# Adding it here, for this process only, means a binary installed by one of
# these scripts is found by the same run that installed it - and by setup.sh
# afterwards, which deploys a config only for a tool it can see. The original
# is kept so local_bin_note() can tell whether the user's own shell would have
# found the binary without our help.
PATH_BEFORE="$PATH"
if [ -d "$HOME/.local/bin" ]; then
    case ":$PATH:" in
        *":$HOME/.local/bin:"*) ;;
        *) PATH="$HOME/.local/bin:$PATH"; export PATH ;;
    esac
fi

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

# shellcheck disable=SC2034
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

# Can the package manager actually install $1? Asked only about packages that
# have an upstream fallback, where knowing in advance turns an alarming install
# failure into a deliberate choice of route. Every form below is a read-only
# metadata query and needs no root.
pm_has_pkg() {
    case "$PKG_MANAGER" in
        # A simulated install rather than apt-cache policy: it needs no
        # parsing of output that some locales translate.
        apt)    apt-get install -s -qq -- "$1" &>/dev/null ;;
        pacman) pacman -Si -- "$1" &>/dev/null ;;
        dnf)    dnf -q info -- "$1" &>/dev/null ;;
        zypper) zypper --non-interactive search --match-exact -- "$1" &>/dev/null ;;
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

# Draw step $1 of $2, named $3. $4 renames the verb - the default reads right
# for install.sh, which was the only caller when this bar was written.
progress_bar() {
    local done="$1" total="$2" label="$3" verb="${4:-installing}"
    local pct cols barw labelw fill i bar=""

    [ "$total" -gt 0 ] || return 0
    pct=$(( done * 100 / total ))

    if [ ! -t 1 ]; then
        printf ' (%d/%d) %s %s\n' "$done" "$total" "$verb" "$label"
        return 0
    fi

    cols="$(term_cols)"
    barw=24
    labelw=$(( cols - barw - ${#verb} - 22 ))
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

    printf '\r\033[K (%d/%d) %s %-*.*s [%b%b%b] %3d%%' \
        "$done" "$total" "$verb" "$labelw" "$labelw" "$label" \
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

# -- Static binary downloads --------------------------------------------------
# Shared machinery for "this distro has no package, so fetch the project's own
# static build". Deliberately not the projects' apt/yum repos: a menu or a
# system-info printer is not worth leaving a third-party package source and
# signing key on someone's machine, and a plain binary in ~/.local/bin needs no
# root and is one `rm` to undo.
FETCH_LOG=""
FETCH_STEPS=3

# One step of a fetch, drawn on the shared progress bar. The command's own
# output goes to the log, where it cannot scribble over the bar's line.
fetch_step() {
    local n="$1" verb="$2" label="$3"; shift 3
    progress_bar "$n" "$FETCH_STEPS" "$label" "$verb"
    "$@" >>"$FETCH_LOG" 2>&1
}

# Fetch the .tar.gz at $2, find the executable named $1 inside it and install
# that into ~/.local/bin. $3 labels the progress bar. Sets FETCHED_BIN to the
# installed path on success.
FETCHED_BIN=""
fetch_static_bin() {
    local name="$1" url="$2" label="$3"
    local tmp found fail=""

    FETCHED_BIN=""
    command -v curl &>/dev/null || { err "curl is needed to fetch $name."; return 1; }
    command -v tar  &>/dev/null || { err "tar is needed to unpack $name."; return 1; }
    tmp="$(mktemp -d)"
    FETCH_LOG="$tmp/fetch.log"

    # Named steps rather than a byte count: curl's own meter wants the line to
    # itself, and unpacking and installing are worth showing as well. Failures
    # are saved and reported after progress_end, so the message lands on a line
    # of its own instead of on the tail of the bar.
    if ! fetch_step 1 downloading "$label" curl -fsSL "$url" -o "$tmp/dl.tgz"; then
        fail="Could not download $name from $url"
    elif ! fetch_step 2 unpacking "$label" tar -xzf "$tmp/dl.tgz" -C "$tmp"; then
        fail="Could not unpack the $name archive."
    else
        # bin/ and the executable bit first, because these archives also ship
        # a shell completion named after the tool. -print -quit rather than
        # `| head -1`, which would hand find a closed pipe.
        found="$(find "$tmp" -type f -perm -u+x -path "*bin/$name" -print -quit)"
        if [ -z "$found" ]; then
            found="$(find "$tmp" -type f -perm -u+x -name "$name" -print -quit)"
        fi
        if [ -z "$found" ]; then
            fail="No $name binary inside the archive."
        else
            mkdir -p "$HOME/.local/bin"
            fetch_step 3 installing "$label" \
                install -m 755 "$found" "$HOME/.local/bin/$name" \
                || fail="Could not install $name into $HOME/.local/bin."
        fi
    fi
    progress_end

    if [ -n "$fail" ]; then
        err "$fail"
        if [ -s "$FETCH_LOG" ]; then tail -3 "$FETCH_LOG" | sed 's/^/    /' >&2; fi
    fi
    rm -rf "$tmp"
    FETCH_LOG=""
    [ -z "$fail" ] || return 1

    FETCHED_BIN="$HOME/.local/bin/$name"
    return 0
}

# This process already has ~/.local/bin on PATH, but the user's shell may not.
local_bin_note() {
    case ":${PATH_BEFORE:-$PATH}:" in
        *":$HOME/.local/bin:"*) ;;
        *) info "Add $HOME/.local/bin to your PATH so your shell finds $1 too." ;;
    esac
}

# -- Upstream fallbacks -------------------------------------------------------
# Some of what install.sh offers is missing from perfectly current distros:
# fastfetch has no package in Debian 12 or 13, and Ubuntu only got one in
# 24.10. A package named here has a function that installs it from the
# project's own release instead, so a missing package is a different route
# rather than a failed run.
declare -A PKG_FALLBACK=( [fastfetch]="fastfetch_install" )

has_fallback() { [ -n "${PKG_FALLBACK[$1]:-}" ]; }

# Install $1 the other way. Returns 1 when there is no fallback for it, or the
# fallback itself failed.
pkg_fallback() {
    local fn="${PKG_FALLBACK[$1]:-}"
    [ -n "$fn" ] || return 1
    if [ "$DRY_RUN" -eq 1 ]; then
        info "  [dry-run] fetch $1 from its upstream release into $HOME/.local/bin"
        return 0
    fi
    "$fn"
}

# Bumping this is the whole maintenance cost of the fastfetch fallback; the
# asset names have been stable across the 2.x line. Overridable from the
# environment, so pinning a different release needs no edit.
FASTFETCH_VERSION="${FASTFETCH_VERSION:-2.68.1}"
fastfetch_install() {
    local arch url
    case "$(uname -m)" in
        x86_64)          arch=amd64 ;;
        aarch64 | arm64) arch=aarch64 ;;
        armv7l)          arch=armv7l ;;
        *) err "No fastfetch build for $(uname -m)."; return 1 ;;
    esac
    url="https://github.com/fastfetch-cli/fastfetch/releases/download/$FASTFETCH_VERSION/fastfetch-linux-$arch.tar.gz"

    fetch_static_bin fastfetch "$url" "fastfetch $FASTFETCH_VERSION" || return 1
    ok "Installed fastfetch to $FETCHED_BIN"
    local_bin_note fastfetch
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

# Fetch the upstream static binary into ~/.local/bin, via the shared fetch
# above - same three tiers as everything else that is missing from a distro.
gum_download() {
    local arch url
    case "$(uname -m)" in
        x86_64)          arch=x86_64 ;;
        aarch64 | arm64) arch=arm64 ;;
        *) err "No gum build for $(uname -m)."; return 1 ;;
    esac
    url="https://github.com/charmbracelet/gum/releases/download/v$GUM_VERSION/gum_${GUM_VERSION}_Linux_${arch}.tar.gz"

    fetch_static_bin gum "$url" "gum $GUM_VERSION" || return 1
    GUM_BIN="$FETCHED_BIN"
    ok "Installed gum to $GUM_BIN"
    local_bin_note gum
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

# Render the leaf rows as `gum choose` arguments, remembering which key each
# rendered row stands for. gum prints the option strings back verbatim, so
# mapping display -> key here keeps us off --label-delimiter, which gum only
# grew in v0.15 and which older distro builds reject with a usage error.
# Split out from gum_menu so CI can check it without a terminal.
#
# Set rows are deliberately left out. gum's list is flat, and its --selected
# cannot preselect by value, so a set row would have to start checked like
# everything else - and unchecking it would then appear to do nothing, because
# its members stay checked on their own. Sets remain available through --only,
# --exclude and --list, and the built-in menu still shows them as real rows.
gum_args() {
    local i row
    GUM_ARGS=()
    GUM_KEY_OF=()
    for i in "${!MS_KEY[@]}"; do
        [ -z "${MS_MEMBERS[$i]}" ] || continue
        row="$(printf '%-10s %-16s %s' \
            "${MS_SECTION[$i]}" "${MS_KEY[$i]}" "${MS_LABEL[$i]}")"
        GUM_ARGS+=("$row")
        GUM_KEY_OF["$row"]="${MS_KEY[$i]}"
    done
}
GUM_ARGS=()
declare -A GUM_KEY_OF=()

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

# The gum front end. Fills SEL_EXPANDED. Returns 1 if the user aborted, and 2
# if gum itself failed - the caller falls back to the built-in menu on 2, but
# must not second-guess a deliberate abort.
gum_menu() {
    local height rc=0 out line
    local -a chosen=() keys=()
    gum_args

    # Show every row at once where the terminal allows it, rather than making
    # the user scroll a list of six things.
    height=$(( ${#GUM_ARGS[@]} + 1 ))
    [ "$height" -gt 20 ] && height=20

    # Via a file, not a process substitution: `mapfile < <(gum)` reports
    # mapfile's status, not gum's, so a gum that bailed out looked like a
    # successful pick and its usage text arrived as the selection.
    out="$(mktemp)"
    "$GUM_BIN" choose \
        --no-limit --selected='*' --height="$height" \
        --header="$(gum_header "$1")" \
        "${GUM_ARGS[@]}" >"$out" || rc=$?
    mapfile -t chosen <"$out"
    rm -f "$out"

    # gum exits 130 on ctrl-c; anything else non-zero is gum failing on us.
    if [ "$rc" -eq 130 ]; then return 1; fi
    if [ "$rc" -ne 0 ]; then
        err "gum exited with status $rc; using the built-in menu."
        return 2
    fi

    for line in ${chosen[@]+"${chosen[@]}"}; do
        [ -n "$line" ] || continue
        keys+=("${GUM_KEY_OF["$line"]:-$line}")
    done
    expand_keys ${keys[@]+"${keys[@]}"}
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
        local gum_rc=0
        if ensure_gum; then
            gum_menu "$2" || gum_rc=$?
            # 1 is a deliberate abort, and second-guessing it with another
            # menu would be worse than useless.
            if [ "$gum_rc" -eq 1 ]; then return 1; fi
        else
            gum_rc=2
        fi
        # 2 = no usable gum, so draw the menu ourselves rather than letting a
        # broken gum be the end of the run.
        if [ "$gum_rc" -ne 0 ]; then
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
