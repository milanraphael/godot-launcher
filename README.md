# Godot Launcher

[![Latest release](https://img.shields.io/github/v/release/milanraphael/godot-launcher?sort=semver)](https://github.com/milanraphael/godot-launcher/releases/latest)

One pinnable "Godot Launcher" app for KDE Plasma that lists every Godot version in
`~/Applications/Godot/` and launches the one you pick. Right-click the panel icon to jump straight
to a version. **Install…** downloads any stable Godot 4 release from GitHub, and **Remove…**
moves one to the Trash.

For Arch-based systems (Arch, CachyOS, EndeavourOS, …).

## Install

In a terminal (bash, zsh and fish all work):

```sh
curl -fsSL https://raw.githubusercontent.com/milanraphael/godot-launcher/main/install.sh | bash
```

Prefer to read it first? Download, inspect, then run:

```sh
curl -fsSLO https://raw.githubusercontent.com/milanraphael/godot-launcher/main/install.sh
less install.sh
bash install.sh
```

Or clone the repo and run `./install.sh`.

Run it as your normal user. It asks for `sudo` only to install missing packages. Re-running it is
safe, and it's also how you update the launcher: it installs the latest release.

### Options

```sh
… | bash -s -- --with-dotnet   # answer yes to the .NET questions (install, or move to pacman's newer SDK)
… | bash -s -- --no-dotnet     # skip the .NET check entirely
```

### After installing

1. Pin it: app menu → search **Godot Launcher** → right-click → **Pin to Task Manager**.
2. Open it and click **Install…** to get Godot. The latest stable version and the Mono (C#)
   edition are preselected.

Over SSH, with no window:

```sh
godot-launcher --install-latest             # Mono (C#)
godot-launcher --install-latest --standard  # standard edition
```

## Dependencies

The installer checks for these and installs what's missing with `pacman`:

| Package | Why |
|---|---|
| `python-pyqt6` | The launcher's GUI toolkit |
| `qt6-svg` | Renders the SVG icon; without it the icon silently fails to load |
| `desktop-file-utils` | Registers the app menu entry |
| `curl` | Downloads the launcher files when run via `curl … \| bash` |
| `dotnet-sdk` | **Optional, asked about.** Godot's Mono (C#) edition needs a .NET SDK to build C# projects; the standard edition doesn't. About a 150 MB download |

How the installer handles .NET:

- **None found:** offers to install pacman's `dotnet-sdk` (default yes).
- **From pacman, current:** nothing to do. Updates arrive with `sudo pacman -Syu`; the installer
  says so when one is waiting. It never updates a single package by itself, since partial upgrades
  aren't supported on Arch.
- **From pacman, older major version** (e.g. only `dotnet-sdk-8.0`): offers the newest `dotnet-sdk`
  alongside it (default no).
- **From Microsoft's install script (`~/.dotnet`):** recommends switching to pacman's, offers to
  install it (default no), and lists the settings that put `~/.dotnet` on your PATH so you can
  remove them. It never edits or deletes them itself.

The launcher shows the .NET SDK version Godot will use in its footer (when a Mono build is
installed), warns there if none is found, and warns after installing a Mono build without one.

## What gets installed

| Path | What it is |
|---|---|
| `~/.local/bin/godot-launcher` | The launcher (PyQt6) |
| `~/Applications/Godot/godot-logo.svg` | Official Godot logo, used as the app icon |
| `~/Applications/Godot/Godot_v*` | Godot versions, one folder (Mono) or binary (standard) each |
| `~/.local/share/applications/godot-launcher.desktop` | Menu entry and right-click list, rewritten by the launcher whenever the set of versions changes |
| `~/.cache/godot-launcher/` | Cached GitHub release list (refreshed hourly) and temporary download folders |

Downloads are checked against Godot's published SHA-512 checksums before anything is unpacked.
Failed or cancelled installs leave nothing behind.

You can still add versions by hand: unzip a Godot download into `~/Applications/Godot/` and it
shows up on the next launch.

To remove a version, select it and click **Remove…** (or press Delete, or right-click it). Its
folder (Mono) or binary (standard) goes to the Trash, so it can be restored from there. Projects
and editor settings aren't touched. A version that's still running has to be closed first.

## Versions

Releases are numbered `vMajor.Minor.Patch`, e.g. `v0.2.3`. Every commit that changes what gets
installed is released automatically with the next Patch number; commits that only change docs
aren't. Major.Minor comes from the `VERSION` file and is bumped by hand, which restarts Patch at 0.
See [all releases](https://github.com/milanraphael/godot-launcher/releases).

The installed version shows in the launcher's window title and with `godot-launcher --version`.
Installed from a clone, it reads like `0.2.3-2-gabc1234`: two commits after `v0.2.3`, plus
`-dirty` with uncommitted changes.

## Files

| File | Purpose |
|---|---|
| `install.sh` | The installer. Uses the files next to it, or downloads the latest release when run on its own |
| `godot-launcher` | The launcher |
| `godot-logo.svg` | Official Godot logo |
| `VERSION` | Major.Minor of the next release |
| `.github/workflows/release.yml` | Tags and publishes a release for every commit that changes the files above |

## Credits

The Godot logo (`godot-logo.svg`) is by Andrea Calabró, licensed under
[CC BY 4.0](https://creativecommons.org/licenses/by/4.0/). See the
[Godot press kit](https://godotengine.org/press/). This project isn't affiliated with or endorsed
by the Godot Foundation.

## License

MIT, see [LICENSE](LICENSE). The Godot logo is CC BY 4.0, see Credits above.
