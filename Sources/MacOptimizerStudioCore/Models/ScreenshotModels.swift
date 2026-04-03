import Foundation

public struct ScreenshotFile: Identifiable, Sendable {
    public let id: UUID
    public let name: String
    public let path: String
    public let sizeBytes: UInt64
    public let createdDate: Date
    public let monthKey: String

    public init(
        id: UUID = UUID(),
        name: String,
        path: String,
        sizeBytes: UInt64,
        createdDate: Date,
        monthKey: String
    ) {
        self.id = id
        self.name = name
        self.path = path
        self.sizeBytes = sizeBytes
        self.createdDate = createdDate
        self.monthKey = monthKey
    }
}

public struct ScreenshotScanResult: Sendable {
    public let files: [ScreenshotFile]
    public let totalBytes: UInt64
    public let byMonth: [String: [ScreenshotFile]]

    public init(files: [ScreenshotFile], totalBytes: UInt64, byMonth: [String: [ScreenshotFile]]) {
        self.files = files
        self.totalBytes = totalBytes
        self.byMonth = byMonth
    }

    public static let empty = ScreenshotScanResult(files: [], totalBytes: 0, byMonth: [:])

    /// Month keys sorted in descending order (newest first).
    public var sortedMonthKeys: [String] {
        byMonth.keys.sorted().reversed()
    }
}
