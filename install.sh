#!/usr/bin/env bash
# Install Godot Launcher on Arch / CachyOS (KDE Plasma).
#
#   ./install.sh                 from a downloaded copy of the repo
#   curl -fsSL https://raw.githubusercontent.com/milanraphael/godot-launcher/main/install.sh | bash
#
# Options (with curl … | bash, pass them as:  | bash -s -- --with-dotnet):
#   --with-dotnet   answer yes to the .NET SDK questions: install it if missing, or move to
#                   pacman's newer SDK if yours is older or from Microsoft's install script
#   --no-dotnet     skip the .NET SDK check entirely
#
# Godot itself is installed from the launcher: open it and click Install….
# Without a window (e.g. over SSH):  ~/.local/bin/godot-launcher --install-latest [--standard]
#
# Safe to re-run: dependencies and files are only touched when needed.
set -euo pipefail

ROOT="$HOME/Applications/Godot"
BIN_DIR="$HOME/.local/bin"
APPS_DIR="$HOME/.local/share/applications"
# Where the launcher's files are downloaded from when install.sh runs on its own
# (curl … | bash): the newest commit on main, see section 0. Overridable for testing.
REPO=milanraphael/godot-launcher
BRANCH=main
SOURCE="${GODOT_LAUNCHER_SOURCE:-}"

dotnet=ask
for arg in "$@"; do
    case $arg in
        --with-dotnet) dotnet=yes ;;
        --no-dotnet) dotnet=no ;;
        -h | --help) sed -n '2,/^set /{/^#/p}' "${BASH_SOURCE[0]:-/dev/null}" 2>/dev/null | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) echo "unknown option: $arg (see --help)" >&2; exit 2 ;;
    esac
done

say() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
note() { printf '    %s\n' "$*"; }
die() { printf '\033[1;31merror:\033[0m %s\n' "$*" >&2; exit 1; }

# With curl … | bash, stdin is the script itself, so prompts must read the terminal directly.
has_tty() { (: </dev/tty) 2>/dev/null; }

[[ $EUID -ne 0 ]] || die "run this as your normal user, not with sudo — it installs into your home folder"
command -v pacman >/dev/null || die "this installer is for Arch-based systems (Arch, CachyOS, EndeavourOS, …); pacman not found"

# Say up front what this touches: people rightly hesitate before piping a script into bash.
printf '\033[1mGodot Launcher installer\033[0m\n'
note "Installs into your home folder: ~/.local/bin, ~/Applications/Godot, ~/.local/share/applications"
note "sudo is only used for pacman, and only when something is missing; pacman lists it first"
echo

# --- 0. launcher files: next to this script, or downloaded -----------------------
HERE=$(cd "$(dirname "${BASH_SOURCE[0]:-.}")" && pwd)
if [[ ! -f $HERE/godot-launcher ]]; then
    command -v curl >/dev/null || die "curl is needed to download the launcher"
    say "Downloading Godot Launcher"
    if [[ -z $SOURCE ]]; then
        # raw.githubusercontent.com caches .../main/... for up to 5 minutes, so right
        # after a push it can still serve the old launcher. A commit URL never goes
        # stale, so ask the API (not cached) which commit main is on.
        commit=$(curl -fsSL -H 'Accept: application/vnd.github.sha' \
            "https://api.github.com/repos/$REPO/commits/$BRANCH" 2>/dev/null || true)
        if [[ $commit =~ ^[0-9a-f]{40}$ ]]; then
            SOURCE=https://raw.githubusercontent.com/$REPO/$commit
            note "version: ${commit:0:7} (latest on $BRANCH)"
        else
            # e.g. GitHub's API limit (60 requests an hour) reached: fine, maybe minutes old.
            SOURCE=https://raw.githubusercontent.com/$REPO/$BRANCH
            note "version: latest on $BRANCH (couldn't look up the commit; may be a few minutes old)"
        fi
    fi
    HERE=$(mktemp -d)
    trap 'rm -rf "$HERE"' EXIT
    for file in godot-launcher godot-logo.svg; do
        curl -fsSL -o "$HERE/$file" "$SOURCE/$file" || die "could not download $SOURCE/$file"
        note "$file"
    done
    # A login page or error HTML would otherwise be installed as the launcher.
    head -n1 "$HERE/godot-launcher" | grep -q '^#!/usr/bin/env python3' || die "downloaded launcher looks wrong; nothing installed"
fi

# --- 1. dependencies ------------------------------------------------------------
say "Checking dependencies"
# qt6-svg is easy to miss: without it the SVG icon silently fails to load.
packages=(python-pyqt6 qt6-svg desktop-file-utils curl)
missing=()
for pkg in "${packages[@]}"; do
    pacman -Qq "$pkg" &>/dev/null || missing+=("$pkg")
done
declare -A why=(
    [python-pyqt6]="the launcher's window"
    [qt6-svg]="renders the icon"
    [desktop-file-utils]="registers the app menu entry"
    [curl]="downloads files"
)
if ((${#missing[@]})); then
    for pkg in "${missing[@]}"; do note "missing: $pkg (${why[$pkg]})"; done
    has_tty || die "no terminal to ask for the sudo password; install them first:  sudo pacman -S ${missing[*]}"
    note "Installing with pacman; sudo will ask for your password."
    sudo pacman -S --needed "${missing[@]}" </dev/tty
else
    note "all present"
fi

# --- 2. .NET SDK ----------------------------------------------------------------
# Godot's Mono edition (the launcher's default) can't build C# projects without a
# .NET SDK. pacman's dotnet-sdk is the recommended source: it updates with the
# system and lives at /usr/bin/dotnet, which every app finds, including ones
# started from the Plasma panel. Microsoft's install script (~/.dotnet) works too,
# but only if ~/.dotnet is put on PATH everywhere, and it never updates itself.

# ask "question" Y|N: honours --with-dotnet, and is "no" without a terminal.
ask() {
    [[ $dotnet == yes ]] && return 0
    if ! has_tty; then
        note "(no terminal to ask; re-run with --with-dotnet to answer yes)"
        return 1
    fi
    local answer
    printf '    %s %s ' "$1" "$([[ $2 == Y ]] && echo '[Y/n]' || echo '[y/N]')"
    read -r answer </dev/tty
    if [[ $2 == Y ]]; then [[ ! $answer =~ ^[Nn] ]]; else [[ $answer =~ ^[Yy] ]]; fi
}

install_dotnet() {
    has_tty || die "installing the .NET SDK needs a terminal for the sudo password"
    sudo pacman -S --needed dotnet-sdk </dev/tty
    note "installed: .NET SDK $(newest_sdk /usr/bin/dotnet)"
}

newest_sdk() { "$1" --list-sdks 2>/dev/null | awk '{print $1}' | sort -V | tail -n1; }

# Everywhere ~/.dotnet is put on PATH; all of these must go to switch to pacman's SDK.
dotnet_path_settings() {
    grep -lsE '\.dotnet' ~/.config/fish/config.fish ~/.config/fish/conf.d/*.fish ~/.bashrc \
        ~/.bash_profile ~/.profile ~/.zshrc ~/.zprofile ~/.config/environment.d/*.conf || true
    if command -v fish >/dev/null && fish -c 'string match -q -- "*/.dotnet*" $fish_user_paths' 2>/dev/null; then
        echo "fish_user_paths (remove with: set -U fish_user_paths (string match -v -- '*/.dotnet*' \$fish_user_paths))"
    fi
}

say "Checking .NET SDK (for Godot's Mono/C# edition)"
if [[ $dotnet == no ]]; then
    note "skipped (--no-dotnet)"
else
    # The dotnet Godot will use: the first on PATH, else the usual install locations.
    active=$(command -v dotnet || true)
    for candidate in "$HOME/.dotnet/dotnet" /usr/share/dotnet/dotnet; do
        [[ -n $active ]] || { [[ -x $candidate ]] && active=$candidate; } || true
    done
    current=""
    [[ -n $active ]] && current=$(newest_sdk "$active")
    available=$(pacman -Si dotnet-sdk 2>/dev/null | awk '/^Version/ {print $3; exit}')  # e.g. 10.0.12.sdk112-1
    available_major=${available%%.*}

    if [[ -z $current ]]; then
        note "Not found. Needed only for C# projects (Godot's Mono edition, the launcher's default)."
        note "pacman's dotnet-sdk ${available_major:+(.NET $available_major) }is about a 150 MB download."
        if ask "Install the .NET SDK now?" Y; then
            install_dotnet
        else
            note "skipped. Install later with:  sudo pacman -S dotnet-sdk"
        fi
    elif pacman -Qqo "$(realpath "$active")" &>/dev/null; then
        note "found: .NET SDK $current (pacman)"
        if [[ -n $available_major && ${current%%.*} -lt $available_major ]]; then
            # e.g. only dotnet-sdk-8.0 installed. dotnet-sdk installs alongside it.
            note "pacman has a newer major version: .NET $available_major (keeps $current installed)."
            if ask "Install .NET SDK $available_major too?" N; then install_dotnet; fi
        elif pacman -Qu dotnet-sdk &>/dev/null; then
            note "an update is available; it arrives with your next:  sudo pacman -Syu"
        else
            note "updates arrive with your normal system updates (sudo pacman -Syu)"
        fi
    else
        dir=${active%/dotnet}
        note "found: .NET SDK $current in ${dir/#$HOME/\~} (not managed by pacman)"
        if pacman -Qq dotnet-host &>/dev/null; then
            note "pacman's .NET is installed too, but this one comes first on your PATH."
        else
            note "Recommended: switch to pacman's dotnet-sdk${available_major:+ (.NET $available_major)}, which updates with your system."
            if ask "Install pacman's .NET SDK now?" N; then install_dotnet; fi
        fi
        if pacman -Qq dotnet-host &>/dev/null; then
            note "To finish switching, remove ~/.dotnet from these settings, then log out and back in:"
            while IFS= read -r setting; do note "  - ${setting/#$HOME/\~}"; done < <(dotnet_path_settings)
            note "After that, the old SDK in ~/.dotnet can be deleted (keep ~/.dotnet/tools if you use global tools)."
        fi
    fi
fi

# --- 3. launcher + icon ---------------------------------------------------------
say "Installing launcher"
install -Dm755 "$HERE/godot-launcher" "$BIN_DIR/godot-launcher"
note "$BIN_DIR/godot-launcher"

mkdir -p "$ROOT"
if [[ -f $HERE/godot-logo.svg ]]; then
    install -m644 "$HERE/godot-logo.svg" "$ROOT/godot-logo.svg"
else
    curl -fsSL -o "$ROOT/godot-logo.svg" "${SOURCE:-https://raw.githubusercontent.com/$REPO/$BRANCH}/godot-logo.svg"
fi
note "$ROOT/godot-logo.svg"

# --- 4. menu entry --------------------------------------------------------------
say "Registering Godot Launcher in the app menu"
# Generate the .desktop file with the launcher's own code instead of opening its
# window, so this also works over SSH. run_path doesn't trigger main().
python3 -I -c '
import runpy, sys
launcher = runpy.run_path(sys.argv[1])
launcher["sync_desktop"](launcher["discover"]())
' "$BIN_DIR/godot-launcher"
desktop-file-validate "$APPS_DIR/godot-launcher.desktop"
update-desktop-database "$APPS_DIR" 2>/dev/null || true
if command -v kbuildsycoca6 >/dev/null; then
    kbuildsycoca6 --noincremental &>/dev/null || true
fi
versions=$(grep -c '^\[Desktop Action ' "$APPS_DIR/godot-launcher.desktop" || true)
note "$APPS_DIR/godot-launcher.desktop ($versions version(s) in the right-click menu)"

# --- done -----------------------------------------------------------------------
say "Done"
if [[ ":$PATH:" != *":$BIN_DIR:"* ]]; then
    note "Note: $BIN_DIR is not on your PATH. In fish run:  fish_add_path ~/.local/bin"
fi
note "Pin it: open the app menu, search 'Godot Launcher', right-click → Pin to Task Manager."
if ((versions > 0)); then
    note "$versions Godot version$( ((versions == 1)) || echo s) installed. Open the launcher to start one, or Install… to add more."
else
    note "Get Godot: open the launcher and click Install…"
    note "  (over SSH: godot-launcher --install-latest, add --standard for the non-C# edition)"
fi
