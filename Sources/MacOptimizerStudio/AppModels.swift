import Foundation

// MARK: - Centralized AppStorage Keys

enum StorageKeys {
    static let defaultScanPreset = "default_scan_preset"
    static let autoScanOnLaunch = "auto_scan_on_launch"
    static let confirmBeforeCleanup = "confirm_before_cleanup"
    static let memoryPollInterval = "memory_poll_interval"
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
    case loginItems
    case privacy
    case apps
    case network
    case brokenDownloads
    case activityLog

    var title: String {
        switch self {
        case .home: return "Home"
        case .memory: return "Memory"
        case .cache: return "Cache"
        case .disk: return "Disk"
        case .duplicateFinder: return "Duplicates"
        case .cpu: return "CPU"
        case .battery: return "Battery"
        case .loginItems: return "Login Items"
        case .privacy: return "Privacy"
        case .apps: return "Apps"
        case .network: return "Network"
        case .brokenDownloads: return "Downloads"
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
        case .cpu: return "cpu"
        case .battery: return "battery.75percent"
        case .loginItems: return "power"
        case .privacy: return "hand.raised.fill"
        case .apps: return "square.stack.3d.up"
        case .network: return "network"
        case .brokenDownloads: return "arrow.down.circle.dotted"
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
        case .cpu: return "Top processes"
        case .battery: return "Health & thermal"
        case .loginItems: return "Startup items"
        case .privacy: return "Cleanup & permissions"
        case .apps: return "App footprint"
        case .network: return "Bandwidth & connections"
        case .brokenDownloads: return "Incomplete files"
        case .activityLog: return "Action history"
        }
    }

    var group: SidebarGroup {
        switch self {
        case .home: return .dashboard
        case .memory, .cpu, .battery, .network: return .monitor
        case .cache, .disk, .duplicateFinder, .brokenDownloads: return .cleanup
        case .loginItems, .privacy, .apps, .activityLog: return .system
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
