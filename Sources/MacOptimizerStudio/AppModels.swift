import Foundation

// MARK: - Centralized AppStorage Keys

enum StorageKeys {
    static let defaultScanPreset = "default_scan_preset"
    static let autoScanOnLaunch = "auto_scan_on_launch"
    static let confirmBeforeCleanup = "confirm_before_cleanup"
    static let memoryPollInterval = "memory_poll_interval"
    static let colorSchemeOverride = "color_scheme_override"
    static let hasSeenIntro = "has_seen_intro"
    static let alertMemoryCritical = "alert_memory_critical"
    static let alertCPUHigh = "alert_cpu_high"
    static let alertDiskFull = "alert_disk_full"
    static let batteryRefreshInterval = "battery_refresh_interval"
}

enum SidebarGroup: String, CaseIterable {
    case dashboard
    case monitor
    case cleanup
    case system
}

enum AppSection: String, CaseIterable, Hashable {
    case home
    case memory
    case cpu
    case battery
    case cache
    case disk
    case duplicateFinder
    case docker
    case maintenance
    case storageTools
    case loginItems
    case privacy
    case apps
    case photoJunk
    case shredder
    case updater
    case extensions
    case network
    case diskHealth
    case startupTime
    case diskBenchmark
    case brokenDownloads
    case screenshotOrganizer
    case activityLog

    var title: String {
        switch self {
        case .home: return "Home"
        case .memory: return "Memory"
        case .cache: return "Cache"
        case .disk: return "Disk"
        case .duplicateFinder: return "Duplicates"
        case .docker: return "Docker"
        case .cpu: return "CPU"
        case .battery: return "Battery"
        case .maintenance: return "Maintenance"
        case .storageTools: return "Storage Tools"
        case .loginItems: return "Login Items"
        case .privacy: return "Privacy"
        case .apps: return "Apps"
        case .photoJunk: return "Photo Junk"
        case .shredder: return "File Shredder"
        case .updater: return "Updater"
        case .extensions: return "Extensions"
        case .network: return "Network"
        case .diskHealth: return "Disk Health"
        case .startupTime: return "Startup Time"
        case .diskBenchmark: return "Disk Benchmark"
        case .brokenDownloads: return "Downloads"
        case .screenshotOrganizer: return "Screenshots"
        case .activityLog: return "Activity Log"
        }
    }

    var icon: String {
        switch self {
        case .home: return "square.grid.2x2"
        case .memory: return "memorychip"
        case .cache: return "archivebox"
        case .disk: return "externaldrive"
        case .duplicateFinder: return "doc.on.doc"
        case .docker: return "shippingbox"
        case .cpu: return "cpu"
        case .battery: return "battery.75percent"
        case .maintenance: return "wrench.and.screwdriver"
        case .storageTools: return "chart.bar.doc.horizontal"
        case .loginItems: return "power"
        case .privacy: return "hand.raised.fill"
        case .apps: return "square.stack.3d.up"
        case .photoJunk: return "photo.on.rectangle.angled"
        case .shredder: return "flame"
        case .updater: return "arrow.down.circle"
        case .extensions: return "puzzlepiece.extension"
        case .network: return "network"
        case .diskHealth: return "stethoscope"
        case .startupTime: return "stopwatch"
        case .diskBenchmark: return "gauge.with.dots.needle.67percent"
        case .brokenDownloads: return "arrow.down.circle.dotted"
        case .screenshotOrganizer: return "photo.on.rectangle.angled"
        case .activityLog: return "shield.lefthalf.filled"
        }
    }

    var subtitle: String {
        switch self {
        case .home: return "Overview"
        case .memory: return "Usage & pressure"
        case .cache: return "System caches"
        case .disk: return "Scan & cleanup"
        case .duplicateFinder: return "Find duplicate files"
        case .docker: return "Images & volumes"
        case .cpu: return "Top processes"
        case .battery: return "Health & thermal"
        case .maintenance: return "System scripts"
        case .storageTools: return "Lens & large files"
        case .loginItems: return "Startup items"
        case .privacy: return "Cleanup & permissions"
        case .apps: return "Uninstaller"
        case .photoJunk: return "Screenshots & photos"
        case .shredder: return "Secure delete"
        case .updater: return "Homebrew updates"
        case .extensions: return "Plugins & add-ons"
        case .network: return "Bandwidth & connections"
        case .diskHealth: return "S.M.A.R.T. status"
        case .startupTime: return "Boot time analysis"
        case .diskBenchmark: return "Read/write speed"
        case .brokenDownloads: return "Incomplete files"
        case .screenshotOrganizer: return "Sort by date"
        case .activityLog: return "Action history"
        }
    }

    var group: SidebarGroup {
        switch self {
        case .home: return .dashboard
        case .memory, .cpu, .battery, .network: return .monitor
        case .cache, .disk, .duplicateFinder, .docker, .maintenance, .storageTools, .photoJunk, .shredder, .brokenDownloads, .screenshotOrganizer: return .cleanup
        case .loginItems, .privacy, .apps, .updater, .extensions, .diskHealth, .startupTime, .diskBenchmark, .activityLog: return .system
        }
    }

    static var grouped: [(SidebarGroup, [AppSection])] {
        let groups = Dictionary(grouping: allCases, by: \.group)
        return SidebarGroup.allCases.compactMap { group in
            guard let sections = groups[group], !sections.isEmpty else { return nil }
            return (group, sections)
        }
    }
}

extension SidebarGroup {
    var title: String {
        switch self {
        case .dashboard: return ""
        case .monitor: return "Monitor"
        case .cleanup: return "Cleanup"
        case .system: return "System"
        }
    }
}

enum ScanPreset: String, CaseIterable, Identifiable {
    case fast
    case balanced
    case deep

    var id: String { rawValue }

    var title: String {
        switch self {
        case .fast: return "Fast"
        case .balanced: return "Balanced"
        case .deep: return "Deep"
        }
    }

    var maxDepth: Int {
        switch self {
        case .fast: return 4
        case .balanced: return 6
        case .deep: return 10
        }
    }

    var top: Int {
        switch self {
        case .fast: return 120
        case .balanced: return 220
        case .deep: return 500
        }
    }

    var subtitle: String {
        switch self {
        case .fast: return "Shallow traversal"
        case .balanced: return "Moderate depth"
        case .deep: return "Full recursive scan"
        }
    }
}
