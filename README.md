# MacOptimizer Studio

A native macOS system optimization app built with SwiftUI and a bundled Rust disk scanner. Monitor, clean, and maintain your Mac from a single dashboard.

## Features

### Monitor
- **Memory** — Live memory pressure gauge, per-process RSS tracking, growing process detection
- **CPU** — CPU-intensive process list with quit/force-quit actions
- **Battery** — Battery health %, charge cycles, thermal state (gracefully hidden on desktop Macs)
- **Network** — Real-time upload/download bandwidth, active connections

### Cleanup
- **Cache** — Scan 11+ cache categories (app caches, Xcode, package managers, browsers, system logs) with risk levels
- **Disk** — Rust-powered scan across 15 ecosystems (node_modules, .build, __pycache__, .gradle, etc.) with drag-and-drop folder roots
- **Docker** — Manage images, volumes, containers; bulk prune; disk usage stats
- **Maintenance** — System maintenance scripts (flush DNS, rebuild Spotlight, verify disk, etc.)
- **Storage Tools** — Large file finder, duplicate detection
- **Photo Junk** — Screenshot and photo cleanup
- **File Shredder** — Secure 3x-overwrite deletion
- **Downloads** — Broken/incomplete download detection
- **Screenshots** — Date-based screenshot organization

### System
- **Login Items** — Manage startup agents and daemons
- **Privacy** — Browser cache/cookie/history cleanup, app permission scanner (camera, mic, location)
- **Apps** — Full app uninstaller with associated file size calculation
- **Updater** — Homebrew package update checker
- **Extensions** — Safari, QuickLook, input method, and screen saver extension manager
- **Disk Health** — S.M.A.R.T. monitoring
- **Startup Time** — Boot time analysis with startup contributors
- **Disk Benchmark** — Read/write speed testing
- **Activity Log** — Full audit trail of all destructive actions with export

### Extras
- Menu bar widget with live gauges and quick actions (Empty Trash, Flush DNS, Purge RAM)
- 5-step onboarding wizard for new users
- Multi-step confirmation dialogs for all destructive actions
- Toast notifications and alert cooldowns
- Light/Dark/System theme support
- Keyboard shortcuts (Cmd+1..9)

## Requirements

- macOS 14+ (Sonoma or later)
- Apple Silicon (M1–M5) or Intel
- Rust toolchain (for building the scanner)

## Quick Start

```bash
# 1. Build Rust scanner
./scripts/build_rust_scanner.sh

# 2. Run the app
MACOPT_SCANNER_PATH="$(pwd)/rust/macopt-scanner/target/debug/macopt-scanner" swift run MacOptimizerStudio
```

## Build for Distribution

Generate a standalone `.app`, `.zip`, and unsigned `.dmg`:

```bash
./scripts/package_clickable_app.sh
```

Artifacts:
- `build/local-app/MacOptimizerStudio.app`
- `build/local-app/MacOptimizerStudio.zip`
- `build/local-app/MacOptimizerStudio-unsigned.dmg`

On another Mac (unsigned builds): **Right-click** the app > **Open** to bypass Gatekeeper.

## Project Structure

```
Sources/MacOptimizerStudio/          # SwiftUI views (35 files)
Sources/MacOptimizerStudioCore/      # Models, ViewModels, Services
  Models/                            # 22 data model files
  ViewModels/                        # 21 view model files
  Services/                          # 24 service files
rust/macopt-scanner/                 # Rust disk scanner binary
scripts/
  build_rust_scanner.sh              # Build Rust component
  package_clickable_app.sh           # Build unsigned .app/.dmg
  release_dmg.sh                     # Build signed/notarized .dmg (requires Developer ID)
Tests/MacOptimizerStudioCoreTests/   # Unit tests
```

## Running Tests

```bash
swift test --disable-sandbox
```

## Tech Stack

- **UI**: SwiftUI, macOS 14+, Swift 6.0 (strict concurrency)
- **Scanner**: Rust (fast parallel disk scanning)
- **Package Manager**: Swift Package Manager
- **System APIs**: Darwin/libproc, FileManager, Process, IOKit

## Safety

- Every destructive action requires multi-step confirmation
- All operations are logged to the Activity Log with timestamps and paths
- Audit trail is exportable as a text file
- Alert cooldowns prevent notification spam (5 min per type)

## License

Private — All rights reserved.
