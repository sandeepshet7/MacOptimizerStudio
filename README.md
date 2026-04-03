<p align="center">
  <img src="logo.png" width="128" height="128" alt="MacOptimizer Studio icon">
</p>

<h1 align="center">MacOptimizer Studio Free</h1>
<p align="center"><strong>Your Mac, But Faster</strong></p>

<p align="center">
  A native macOS system optimization app built with SwiftUI and a high-performance Rust disk scanner.<br>
  Monitor, clean, and maintain your Mac from a single dashboard.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/macOS-12%2B-blue?logo=apple&logoColor=white" alt="macOS 12+">
  <img src="https://img.shields.io/badge/Swift-6.0-orange?logo=swift&logoColor=white" alt="Swift 6.0">
  <img src="https://img.shields.io/badge/Rust-scanner-b7410e?logo=rust&logoColor=white" alt="Rust">
  <img src="https://img.shields.io/badge/license-MIT-green" alt="MIT License">
</p>

<p align="center">
  <a href="https://github.com/sandeepshet7/MacOptimizerStudio-Free/releases">Download</a> &middot;
  <a href="https://sandeepshet7.github.io/MacOptimizerStudio-Free/">Website</a>
</p>

---

## Screenshots

| Home Dashboard | Memory Monitor | Cache Cleanup |
|:-:|:-:|:-:|
| ![Home](screenshots/home.png) | ![Memory](screenshots/memory.png) | ![Cache](screenshots/cache.png) |

| Disk Analysis | CPU Monitor | Battery Monitor |
|:-:|:-:|:-:|
| ![Disk](screenshots/disk.png) | ![CPU](screenshots/cpu.png) | ![Battery](screenshots/battery.png) |

---

## Features

### Real-time Monitoring
- **Home Dashboard** -- Overview cards with system health insights, disk usage ring chart, and quick actions
- **Memory** -- Live memory pressure gauge, per-process RSS tracking, growing process detection
- **CPU** -- CPU-intensive process list with quit/force-quit
- **Battery** -- Battery health %, charge cycles, thermal state, configurable auto-refresh
- **Network** -- Real-time upload/download bandwidth and active connections

### Scan & Cleanup
- **Quick Clean** -- One-click safe junk cleanup (caches, logs, temp files) with single confirmation
- **Cache Cleanup** -- 18 cache categories with smart risk levels:
  - App Caches, System Logs, Xcode Data, Package Managers (Homebrew, npm, pip, Conda, CocoaPods, Bun, Flutter)
  - Browser Caches, Containers & VMs, JetBrains IDEs, VS Code & Cursor
  - Communication Apps, Game Libraries, AI & ML Models, Installer Packages, Temporary Files
- **Disk Analysis** -- Rust-powered scan with sortable largest folders, drag-and-drop scan roots
- **Duplicate File Finder** -- SHA256-based detection with partial hash optimization
- **Broken Downloads** -- Scan for incomplete files in Downloads folder

### Smart Safety
- Electron apps marked as "Moderate" risk -- may require re-login after cleanup
- Pure caches marked as "Safe" -- auto-regenerate
- "Select All Safe" never touches login-sensitive data
- Every category shows "What breaks if deleted" info

### System & Privacy
- **Login Items Manager** -- Control startup agents and daemons
- **Privacy Scanner** -- Browser cache/cookie/history cleanup, app permission scanner
- **App Manager** -- View installed apps and their data footprint
- **Audit Log** -- Full trail of all actions with timestamps, paths, bytes freed (exportable)

### Extras
- Menu bar widget with compact gauges (Memory, Disk, CPU) and quick actions
- Onboarding wizard for new users
- Multi-step confirmation dialogs for all destructive actions
- Dark theme
- Keyboard shortcuts (Cmd+1..9)
- Settings with configurable poll intervals and scan presets

---

## Requirements

| | Minimum |
|---|---|
| **macOS** | 12 Monterey or later |
| **Hardware** | Intel Macs (2015+) or any Apple Silicon (M1--M5) |
| **Rust** | Required only for building the disk scanner from source |

---

## Installation

### Download (Recommended)

Download the latest `.dmg` from [Releases](https://github.com/sandeepshet7/MacOptimizerStudio-Free/releases).

> **Note:** This app is not signed with an Apple Developer ID. macOS will show a security warning -- this is expected for open-source apps distributed outside the App Store. The full source code is available on this repo for verification.

**First launch (one-time setup):**

1. Open the `.dmg` and drag MacOptimizer Studio to **Applications**
2. Try to open the app -- macOS will block it with a warning
3. Go to **System Settings > Privacy & Security**
4. Scroll down -- you'll see *"MacOptimizerStudio was blocked from use because it is not from an identified developer"*
5. Click **"Open Anyway"** > enter your password > click **"Open"**
6. You only need to do this once -- the app opens normally after that

### Build from Source

```bash
# Clone the repository
git clone https://github.com/sandeepshet7/MacOptimizerStudio-Free.git
cd MacOptimizerStudio-Free

# Build the Rust disk scanner
./scripts/build_rust_scanner.sh

# Run the app
MACOPT_SCANNER_PATH="$(pwd)/rust/macopt-scanner/target/debug/macopt-scanner" swift run MacOptimizerStudio
```

### Build for Distribution

Generate a standalone `.app`, `.zip`, and unsigned `.dmg`:

```bash
./scripts/package_clickable_app.sh
```

Artifacts are placed in `build/local-app/`:
- `MacOptimizerStudio.app`
- `MacOptimizerStudio.zip`
- `MacOptimizerStudio-unsigned.dmg`

---

## Tech Stack

| Layer | Technology |
|---|---|
| **UI** | SwiftUI, Swift 6.0 (strict concurrency) |
| **Disk Scanner** | Rust (`macopt-scanner`) -- fast parallel disk scanning |
| **Package Manager** | Swift Package Manager |
| **System APIs** | Darwin/libproc, FileManager, Process, IOKit |

---

## Project Structure

```
MacOptimizerStudio-Free/
├── Sources/
│   ├── MacOptimizerStudio/           # SwiftUI views
│   │   ├── Assets.xcassets/          # App icons and colors
│   │   └── Resources/               # Bundled resources
│   └── MacOptimizerStudioCore/       # Business logic layer
│       ├── Models/                   # Data models
│       ├── ViewModels/               # View models
│       └── Services/                 # Services
├── rust/macopt-scanner/              # Rust disk scanner binary
├── scripts/
│   ├── build_rust_scanner.sh         # Build Rust component
│   ├── package_clickable_app.sh      # Build unsigned .app/.dmg
│   └── release_dmg.sh               # Signed/notarized .dmg (requires Developer ID)
├── Tests/                            # Unit tests
├── docs/                             # Landing page (GitHub Pages)
└── Package.swift                     # SPM configuration
```

---

## Safety

- Every destructive action requires multi-step confirmation
- Smart risk levels per cache item (Safe / Moderate / Caution)
- All operations are logged to the Audit Log with timestamps and file paths
- Audit trail is exportable as a text file

---

## Contributing

Contributions are welcome! To get started:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/your-feature`)
3. Make your changes and ensure tests pass (`swift test --disable-sandbox`)
4. Commit with a clear message describing the change
5. Open a pull request against `main`

---

## License

MIT License. See [LICENSE](LICENSE) for details.
