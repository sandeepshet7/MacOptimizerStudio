import Foundation

public struct InstalledApp: Identifiable, Sendable {
    public let id: String
    public let name: String
    public let bundleId: String?
    public let path: String
    public let sizeBytes: UInt64
    public let version: String?
    public let icon: String?
    public let associatedFiles: [AppAssociatedFile]

    public init(name: String, bundleId: String?, path: String, sizeBytes: UInt64, version: String?, icon: String?, associatedFiles: [AppAssociatedFile]) {
        self.id = path
        self.name = name
        self.bundleId = bundleId
        self.path = path
        self.sizeBytes = sizeBytes
        self.version = version
        self.icon = icon
        self.associatedFiles = associatedFiles
    }

    public var totalAssociatedBytes: UInt64 {
        associatedFiles.reduce(0) { $0 + $1.sizeBytes }
    }

    public var totalFootprint: UInt64 {
        sizeBytes + totalAssociatedBytes
    }
}

public struct AppAssociatedFile: Identifiable, Sendable {
    public let id: String
    public let path: String
    public let category: AssociatedFileCategory
    public let sizeBytes: UInt64

    public init(path: String, category: AssociatedFileCategory, sizeBytes: UInt64) {
        self.id = path
        self.path = path
        self.category = category
        self.sizeBytes = sizeBytes
    }
}

public enum AssociatedFileCategory: String, CaseIterable, Sendable {
    case preferences
    case cache
    case applicationSupport
    case containers
    case logs
    case savedState
    case webKit
    case crashReports

    public var displayName: String {
        switch self {
        case .preferences: return "Preferences"
        case .cache: return "Caches"
        case .applicationSupport: return "Application Support"
        case .containers: return "Containers"
        case .logs: return "Logs"
        case .savedState: return "Saved State"
        case .webKit: return "WebKit Data"
        case .crashReports: return "Crash Reports"
        }
    }

    public var icon: String {
        switch self {
        case .preferences: return "gearshape"
        case .cache: return "archivebox"
        case .applicationSupport: return "folder"
        case .containers: return "shippingbox"
        case .logs: return "doc.text"
        case .savedState: return "bookmark"
        case .webKit: return "globe"
        case .crashReports: return "exclamationmark.triangle"
        }
    }
}
