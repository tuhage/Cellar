<p align="center">
  <img src="logo.jpg" width="128" height="128" alt="Cellar Logo" />
</p>

<h1 align="center">Cellar</h1>

<p align="center">
  A native macOS app for managing Homebrew packages, casks, and services.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/macOS-15%2B-blue" alt="macOS 15+" />
  <img src="https://img.shields.io/badge/Swift-6-orange" alt="Swift 6" />
  <img src="https://img.shields.io/badge/License-MIT-green" alt="MIT License" />
</p>

---

## Features

- **Dashboard** — Overview of installed packages, services, and system health at a glance
- **Package Management** — Browse, install, upgrade, and uninstall Homebrew formulae and casks
- **Services** — Start, stop, and monitor Homebrew services with real-time status
- **Dependency Graph** — Visualize package dependencies interactively
- **Resource Monitor** — Track Homebrew disk usage and system resources
- **Maintenance** — Run cleanup, doctor checks, and manage taps
- **Brewfile Support** — View and manage Brewfiles from your projects
- **Search** — Find new packages with integrated Homebrew search
- **Widget** — WidgetKit extension with small, medium, and large sizes
- **CLI Tool** — `cellar` command-line tool for quick operations
- **Finder Sync** — Badges directories containing Brewfiles, right-click service controls
- **Spotlight** — All installed packages indexed for system-wide search
- **Keyboard Shortcuts** — Configurable shortcuts for common actions

## Screenshots

> Coming soon

## Requirements

- macOS 15 or later
- [Homebrew](https://brew.sh) installed
- Xcode 16+ (to build from source)

## Installation

### Build from Source

```bash
git clone https://github.com/tuhage/Cellar.git
cd Cellar
xcodebuild -project Cellar.xcodeproj -scheme Cellar -configuration Release build -allowProvisioningUpdates
```

The built app will be in `DerivedData/Build/Products/Release/Cellar.app`.

## Architecture

Cellar follows the **Model-View (MV)** pattern — no ViewModels. Views bind directly to Models and Stores.

All shared code lives in the **CellarCore** local Swift package, which every target imports.

| Target | Product | Description |
|--------|---------|-------------|
| Cellar | Cellar.app | Main macOS app |
| CellarWidget | CellarWidget.appex | WidgetKit extension |
| CellarCLI | cellar | Command-line tool |
| CellarFinderSync | CellarFinderSync.appex | Finder Sync extension |
| CellarCore | CellarCore.framework | Shared models and services |

All data is derived from the `brew` CLI at runtime — there is no local database. No third-party dependencies are used.

## CLI Usage

The `cellar` command-line tool provides quick access to common operations:

```bash
cellar status              # Show summary of installed packages and services
cellar start <service>     # Start a Homebrew service
cellar stop <service>      # Stop a Homebrew service
cellar health              # Run brew doctor and show results
cellar cleanup             # Clean up old downloads and cache files
cellar version             # Show version
cellar help                # Show help message
```

## Widget

The Cellar widget reads a snapshot from the shared App Group container and displays Homebrew status on your desktop:

- **Small** — Service count
- **Medium** — Services and outdated packages
- **Large** — Full summary

## URL Scheme

Cellar supports deep linking via the `cellar://` URL scheme:

```
cellar://formula/<name>    # Navigate to a formula
cellar://cask/<token>      # Navigate to a cask
cellar://dashboard         # Open dashboard
cellar://services          # Open services
```

## License

This project is licensed under the MIT License. See [LICENSE](LICENSE) for details.
