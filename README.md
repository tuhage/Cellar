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
- **Package Management** — Browse, install, upgrade, and uninstall formulae and casks
- **Services** — Start, stop, and monitor Homebrew services with real-time status
- **Dependency Graph** — Visualize package dependencies interactively
- **Resource Monitor** — Track Homebrew disk usage and system resources
- **Maintenance** — Run cleanup, doctor checks, and manage taps
- **Brewfile Support** — View and manage Brewfiles from your projects
- **Search** — Find new packages with integrated search
- **Widget** — Desktop widget with small, medium, and large sizes
- **CLI Tool** — `cellar` command-line tool for quick terminal operations
- **Finder Integration** — Badges directories containing Brewfiles, right-click service controls
- **Spotlight** — All installed packages indexed for system-wide search

## Screenshots

> Coming soon

## Installation

### Download

Download the latest `.dmg` from the [Releases](https://github.com/tuhage/Cellar/releases) page. Open the `.dmg` and drag **Cellar** to your **Applications** folder.

### Requirements

- macOS 15 or later
- [Homebrew](https://brew.sh) installed

### Build from Source

```bash
git clone https://github.com/tuhage/Cellar.git
cd Cellar
xcodebuild -project Cellar.xcodeproj -scheme Cellar -configuration Release build -allowProvisioningUpdates
```

## CLI Tool

Cellar includes a command-line tool for quick terminal access:

```bash
cellar status              # Package and service summary
cellar start <service>     # Start a service
cellar stop <service>      # Stop a service
cellar health              # Run brew doctor
cellar cleanup             # Clean up old downloads and cache
```

## URL Scheme

Open specific sections directly via `cellar://` links:

```
cellar://formula/<name>
cellar://cask/<token>
cellar://dashboard
cellar://services
```

## License

MIT — see [LICENSE](LICENSE) for details.
