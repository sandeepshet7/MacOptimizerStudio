import Foundation

public enum BrokenDownloadType: String, Sendable, CaseIterable {
    case crdownload
    case download
    case part
    case tmp
    case partial
    case opdownload
    case other

    public var label: String {
        switch self {
        case .crdownload: "Chrome"
        case .download: "Safari"
        case .part: "Firefox"
        case .tmp: "Temp"
        case .partial: "Partial"
        case .opdownload: "Opera"
        case .other: "Other"
        }
    }

    public static func from(extension ext: String) -> BrokenDownloadType {
        switch ext.lowercased() {
        case "crdownload": .crdownload
        case "download": .download
        case "part": .part
        case "tmp": .tmp
        case "partial": .partial
        case "opdownload": .opdownload
        default: .other
        }
    }
}

public struct BrokenDownload: Identifiable, Sendable {
    public let id: UUID
    public let name: String
    public let path: String
    public let sizeBytes: UInt64
    public let modifiedDate: Date?
    public let downloadType: BrokenDownloadType

    public init(
        id: UUID = UUID(),
        name: String,
        path: String,
        sizeBytes: UInt64,
        modifiedDate: Date?,
        downloadType: BrokenDownloadType
    ) {
        self.id = id
        self.name = name
        self.path = path
        self.sizeBytes = sizeBytes
        self.modifiedDate = modifiedDate
        self.downloadType = downloadType
    }
}

public struct BrokenDownloadsScanResult: Sendable {
    public let files: [BrokenDownload]
    public let totalBytes: UInt64

    public init(files: [BrokenDownload], totalBytes: UInt64) {
        self.files = files
        self.totalBytes = totalBytes
    }

    public static let empty = BrokenDownloadsScanResult(files: [], totalBytes: 0)
}
