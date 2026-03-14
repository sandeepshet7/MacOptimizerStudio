import Foundation

public enum CacheCategory: String, CaseIterable, Hashable, Sendable, Identifiable {
    case appCaches
    case systemLogs
    case xcodeData
    case packageManager
    case browserData
    case containerData
    case temporaryFiles
    case languageFiles
    case mailAttachments
    case iOSBackups
    case brokenPreferences
    case jetbrainsData
    case vsCodeData
    case communicationApps
    case gameCaches
    case aiModels
    case installerPackages
    case timeMachineSnapshots

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .appCaches: return "App Caches"
        case .systemLogs: return "System & App Logs"
        case .xcodeData: return "Xcode Data"
        case .packageManager: return "Package Managers"
        case .browserData: return "Browser Caches"
        case .containerData: return "Containers & VMs"
        case .temporaryFiles: return "Temporary Files"
        case .languageFiles: return "Language Files"
        case .mailAttachments: return "Mail Attachments"
        case .iOSBackups: return "iOS Backups"
        case .brokenPreferences: return "Broken Preferences"
        case .jetbrainsData: return "JetBrains IDEs"
        case .vsCodeData: return "VS Code & Cursor"
        case .communicationApps: return "Communication Apps"
        case .gameCaches: return "Game Libraries"
        case .aiModels: return "AI & ML Models"
        case .installerPackages: return "Installer Packages"
        case .timeMachineSnapshots: return "Time Machine"
        }
    }

    public var icon: String {
        switch self {
        case .appCaches: return "app.badge"
        case .systemLogs: return "doc.text.fill"
        case .xcodeData: return "hammer.fill"
        case .packageManager: return "shippingbox.fill"
        case .browserData: return "globe"
        case .containerData: return "cube.fill"
        case .temporaryFiles: return "clock.fill"
        case .languageFiles: return "globe"
        case .mailAttachments: return "paperclip"
        case .iOSBackups: return "iphone"
        case .brokenPreferences: return "wrench.and.screwdriver"
        case .jetbrainsData: return "curlybraces"
        case .vsCodeData: return "chevron.left.forwardslash.chevron.right"
        case .communicationApps: return "bubble.left.and.bubble.right.fill"
        case .gameCaches: return "gamecontroller.fill"
        case .aiModels: return "brain"
        case .installerPackages: return "arrow.down.doc.fill"
        case .timeMachineSnapshots: return "clock.arrow.circlepath"
        }
    }

    public var description: String {
        switch self {
        case .appCaches: return "Application cache folders in ~/Library/Caches"
        case .systemLogs: return "System and application log files"
        case .xcodeData: return "DerivedData, simulators, archives"
        case .packageManager: return "Homebrew, npm, pip, CocoaPods caches"
        case .browserData: return "Chrome, Safari, Firefox cache data"
        case .containerData: return "Docker, Parallels, and VM data"
        case .temporaryFiles: return "Temporary and scratch files"
        case .languageFiles: return "Unused localizations in applications"
        case .mailAttachments: return "Copies of email attachments stored locally"
        case .iOSBackups: return "Old iPhone/iPad backups"
        case .brokenPreferences: return "Corrupted or orphaned preference files"
        case .jetbrainsData: return "JetBrains IDE caches (IntelliJ, PyCharm, WebStorm, etc.)"
        case .vsCodeData: return "VS Code/Cursor editor caches only (not extensions)"
        case .communicationApps: return "Slack, Discord, Teams, Zoom media caches"
        case .gameCaches: return "Steam, Epic Games Store cached data"
        case .aiModels: return "Ollama, Hugging Face, LM Studio, PyTorch model caches"
        case .installerPackages: return "Old .dmg, .pkg, .app installer files in Downloads"
        case .timeMachineSnapshots: return "Local Time Machine snapshots and iOS backup data"
        }
    }

    public var whatBreaksIfDeleted: String {
        switch self {
        case .appCaches: return "Safe items auto-regenerate. Moderate items (Slack, Discord, Claude) may require re-login"
        case .systemLogs: return "Clears diagnostic history; new logs are created automatically"
        case .xcodeData: return "Next Xcode build will be a full rebuild (slower first compile)"
        case .packageManager: return "Next install will re-download packages from the network"
        case .browserData: return "Websites will load slower temporarily — logins, passwords, and bookmarks are not affected"
        case .containerData: return "Docker images/containers may need to be re-pulled or rebuilt"
        case .temporaryFiles: return "No impact — these are scratch files from completed operations"
        case .languageFiles: return "Apps will only show your language; re-download app to restore other languages"
        case .mailAttachments: return "Attachments will need to be re-downloaded from the mail server"
        case .iOSBackups: return "Old backups will be permanently lost — cannot be recovered"
        case .brokenPreferences: return "No impact — these preferences are already corrupted and non-functional"
        case .jetbrainsData: return "IDEs will rebuild indexes on next launch (slower first open)"
        case .vsCodeData: return "Editor caches rebuild automatically — extensions and settings are not affected"
        case .communicationApps: return "May require re-login to Slack, Discord, Teams. Chat history stays on server but cached media is lost"
        case .gameCaches: return "Game files may need to be re-downloaded or re-verified — can be very large"
        case .aiModels: return "Models will need to be re-downloaded (can be very large, 4-70GB each)"
        case .installerPackages: return "Installer files will be permanently deleted — re-download from source if needed"
        case .timeMachineSnapshots: return "Local snapshots will be recreated; backup history on external drive is unaffected"
        }
    }

    public var willRegenerate: Bool {
        switch self {
        case .appCaches, .systemLogs, .xcodeData, .packageManager, .temporaryFiles, .brokenPreferences,
             .jetbrainsData, .vsCodeData, .aiModels, .timeMachineSnapshots: return true
        case .browserData, .containerData, .languageFiles, .mailAttachments, .iOSBackups,
             .gameCaches, .installerPackages, .communicationApps: return false
        }
    }
}

public enum CacheRiskLevel: String, Sendable {
    case safe
    case moderate
    case caution

    public var displayName: String {
        switch self {
        case .safe: return "Safe"
        case .moderate: return "Moderate"
        case .caution: return "Caution"
        }
    }

    public var deletionImpactSummary: String {
        switch self {
        case .safe: return "Will be recreated automatically by the application"
        case .moderate: return "May require re-login or app restart to rebuild"
        case .caution: return "May contain user data or settings that cannot be recovered"
        }
    }
}

public struct CacheEntry: Identifiable, Hashable, Sendable {
    public let id: String
    public let category: CacheCategory
    public let name: String
    public let path: String
    public let sizeBytes: UInt64
    public let riskLevel: CacheRiskLevel
    public let itemDescription: String

    public init(category: CacheCategory, name: String, path: String, sizeBytes: UInt64, riskLevel: CacheRiskLevel, itemDescription: String) {
        self.id = path
        self.category = category
        self.name = name
        self.path = path
        self.sizeBytes = sizeBytes
        self.riskLevel = riskLevel
        self.itemDescription = itemDescription
    }

    public static func == (lhs: CacheEntry, rhs: CacheEntry) -> Bool {
        lhs.id == rhs.id
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

public struct CacheScanReport: Sendable {
    public let scannedAt: Date
    public let entries: [CacheEntry]
    public let totalBytes: UInt64
    public let categoryTotals: [CacheCategory: UInt64]

    public init(scannedAt: Date, entries: [CacheEntry], totalBytes: UInt64, categoryTotals: [CacheCategory: UInt64]) {
        self.scannedAt = scannedAt
        self.entries = entries
        self.totalBytes = totalBytes
        self.categoryTotals = categoryTotals
    }
}
