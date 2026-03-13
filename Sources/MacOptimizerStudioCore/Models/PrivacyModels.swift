import Foundation

// MARK: - Privacy Cleanup

public enum PrivacyCategory: String, CaseIterable, Sendable, Identifiable {
    case browserCache
    case browserHistory
    case recentFiles
    case downloads
    case trash

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .browserCache: return "Browser Caches"
        case .browserHistory: return "Browser Data"
        case .recentFiles: return "Recent Files List"
        case .downloads: return "Downloads"
        case .trash: return "Trash"
        }
    }

    public var icon: String {
        switch self {
        case .browserCache: return "globe"
        case .browserHistory: return "clock.arrow.circlepath"
        case .recentFiles: return "doc.text.magnifyingglass"
        case .downloads: return "arrow.down.circle"
        case .trash: return "trash"
        }
    }

    public var description: String {
        switch self {
        case .browserCache: return "Cached files from Safari, Chrome, Firefox, and other browsers"
        case .browserHistory: return "Cookies, local storage, and session data from browsers"
        case .recentFiles: return "macOS recent documents and application recent file lists"
        case .downloads: return "Files in your Downloads folder"
        case .trash: return "Files waiting in the Trash to be permanently deleted"
        }
    }
}

public struct PrivacyItem: Identifiable, Sendable {
    public let id: String
    public let category: PrivacyCategory
    public let name: String
    public let path: String
    public let sizeBytes: UInt64
    public let itemCount: Int

    public init(category: PrivacyCategory, name: String, path: String, sizeBytes: UInt64, itemCount: Int) {
        self.id = path
        self.category = category
        self.name = name
        self.path = path
        self.sizeBytes = sizeBytes
        self.itemCount = itemCount
    }
}

public struct PrivacyScanReport: Sendable {
    public let capturedAt: Date
    public let items: [PrivacyItem]

    public init(capturedAt: Date, items: [PrivacyItem]) {
        self.capturedAt = capturedAt
        self.items = items
    }

    public var totalBytes: UInt64 {
        items.reduce(0) { $0 + $1.sizeBytes }
    }

    public func items(for category: PrivacyCategory) -> [PrivacyItem] {
        items.filter { $0.category == category }
    }

    public func totalBytes(for category: PrivacyCategory) -> UInt64 {
        items(for: category).reduce(0) { $0 + $1.sizeBytes }
    }
}

// MARK: - App Permissions

public enum PermissionType: String, Sendable, CaseIterable, Identifiable {
    case camera = "kTCCServiceCamera"
    case microphone = "kTCCServiceMicrophone"
    case accessibility = "kTCCServiceAccessibility"
    case fullDiskAccess = "kTCCServiceSystemPolicyAllFiles"
    case screenRecording = "kTCCServiceScreenCapture"
    case contacts = "kTCCServiceAddressBook"
    case calendar = "kTCCServiceCalendar"
    case photos = "kTCCServicePhotos"
    case location = "kTCCServiceLocation"
    case reminders = "kTCCServiceReminders"
    case inputMonitoring = "kTCCServiceListenEvent"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .camera: return "Camera"
        case .microphone: return "Microphone"
        case .accessibility: return "Accessibility"
        case .fullDiskAccess: return "Full Disk Access"
        case .screenRecording: return "Screen Recording"
        case .contacts: return "Contacts"
        case .calendar: return "Calendar"
        case .photos: return "Photos"
        case .location: return "Location"
        case .reminders: return "Reminders"
        case .inputMonitoring: return "Input Monitoring"
        }
    }

    public var icon: String {
        switch self {
        case .camera: return "camera.fill"
        case .microphone: return "mic.fill"
        case .accessibility: return "accessibility"
        case .fullDiskAccess: return "externaldrive.fill"
        case .screenRecording: return "rectangle.inset.filled.and.person.filled"
        case .contacts: return "person.crop.circle.fill"
        case .calendar: return "calendar"
        case .photos: return "photo.fill"
        case .location: return "location.fill"
        case .reminders: return "checklist"
        case .inputMonitoring: return "keyboard.fill"
        }
    }
}

public struct AppPermission: Identifiable, Sendable {
    public let id: String
    public let bundleId: String
    public let appName: String
    public let permission: PermissionType
    public let isAllowed: Bool

    public init(bundleId: String, appName: String, permission: PermissionType, isAllowed: Bool) {
        self.id = "\(bundleId)-\(permission.rawValue)"
        self.bundleId = bundleId
        self.appName = appName
        self.permission = permission
        self.isAllowed = isAllowed
    }
}
