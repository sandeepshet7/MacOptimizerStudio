import Foundation

public enum AuditAction: String, Codable, Sendable, CaseIterable {
    case fileShredded
    case cacheCleanup
    case brokenDownloadsTrashed
    case screenshotsMoved
    case processKilled
    case processForceKilled
    case diskCleanup
    case dockerImageRemoved
    case dockerVolumeRemoved
    case dockerContainerRemoved
    case dockerPrune
    case appUninstalled
    case appDataReset
    case extensionRemoved
    case maintenanceTaskRun
    case photoJunkTrashed
    case privacyDataCleaned

    public var label: String {
        switch self {
        case .fileShredded: return "File Shredded"
        case .cacheCleanup: return "Cache Cleanup"
        case .brokenDownloadsTrashed: return "Downloads Cleaned"
        case .screenshotsMoved: return "Screenshots Organized"
        case .processKilled: return "Process Quit"
        case .processForceKilled: return "Process Force Quit"
        case .diskCleanup: return "Disk Cleanup"
        case .dockerImageRemoved: return "Docker Image Removed"
        case .dockerVolumeRemoved: return "Docker Volume Removed"
        case .dockerContainerRemoved: return "Docker Container Removed"
        case .dockerPrune: return "Docker Prune"
        case .appUninstalled: return "App Uninstalled"
        case .appDataReset: return "App Data Reset"
        case .extensionRemoved: return "Extension Removed"
        case .maintenanceTaskRun: return "Maintenance Task"
        case .photoJunkTrashed: return "Photo Junk Trashed"
        case .privacyDataCleaned: return "Privacy Data Cleaned"
        }
    }

    public var icon: String {
        switch self {
        case .fileShredded: return "flame.fill"
        case .cacheCleanup: return "archivebox"
        case .brokenDownloadsTrashed: return "arrow.down.circle.dotted"
        case .screenshotsMoved: return "photo.on.rectangle.angled"
        case .processKilled: return "xmark.circle"
        case .processForceKilled: return "xmark.circle.fill"
        case .diskCleanup: return "externaldrive"
        case .dockerImageRemoved: return "shippingbox"
        case .dockerVolumeRemoved: return "externaldrive.badge.minus"
        case .dockerContainerRemoved: return "square.stack.3d.up.slash"
        case .dockerPrune: return "trash.circle"
        case .appUninstalled: return "square.stack.3d.up"
        case .appDataReset: return "arrow.counterclockwise"
        case .extensionRemoved: return "puzzlepiece.extension"
        case .maintenanceTaskRun: return "wrench.and.screwdriver"
        case .photoJunkTrashed: return "photo.on.rectangle.angled"
        case .privacyDataCleaned: return "hand.raised.fill"
        }
    }

    public var severity: AuditSeverity {
        switch self {
        case .fileShredded, .processForceKilled, .appUninstalled: return .destructive
        case .cacheCleanup, .brokenDownloadsTrashed, .diskCleanup, .processKilled,
             .dockerImageRemoved, .dockerVolumeRemoved, .dockerContainerRemoved, .dockerPrune,
             .appDataReset, .extensionRemoved, .photoJunkTrashed, .privacyDataCleaned: return .warning
        case .screenshotsMoved, .maintenanceTaskRun: return .info
        }
    }
}

public enum AuditSeverity: String, Codable, Sendable {
    case info
    case warning
    case destructive
}

public struct AuditLogEntry: Identifiable, Codable, Sendable {
    public let id: UUID
    public let timestamp: Date
    public let action: AuditAction
    public let details: String
    public let paths: [String]
    public let totalBytes: UInt64?
    public let itemCount: Int
    public let userConfirmed: Bool

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        action: AuditAction,
        details: String,
        paths: [String] = [],
        totalBytes: UInt64? = nil,
        itemCount: Int = 1,
        userConfirmed: Bool = true
    ) {
        self.id = id
        self.timestamp = timestamp
        self.action = action
        self.details = details
        self.paths = paths
        self.totalBytes = totalBytes
        self.itemCount = itemCount
        self.userConfirmed = userConfirmed
    }
}
