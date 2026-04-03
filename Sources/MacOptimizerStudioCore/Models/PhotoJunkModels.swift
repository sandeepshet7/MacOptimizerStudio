import Foundation

public struct PhotoJunkReport: Sendable {
    public let screenshots: [PhotoJunkItem]
    public let largePhotos: [PhotoJunkItem]
    public let totalScreenshotBytes: UInt64
    public let totalLargePhotoBytes: UInt64

    public init(screenshots: [PhotoJunkItem], largePhotos: [PhotoJunkItem], totalScreenshotBytes: UInt64, totalLargePhotoBytes: UInt64) {
        self.screenshots = screenshots
        self.largePhotos = largePhotos
        self.totalScreenshotBytes = totalScreenshotBytes
        self.totalLargePhotoBytes = totalLargePhotoBytes
    }

    public var totalBytes: UInt64 {
        totalScreenshotBytes + totalLargePhotoBytes
    }

    public var totalCount: Int {
        screenshots.count + largePhotos.count
    }
}

public struct PhotoJunkItem: Identifiable, Sendable {
    public let id: String
    public let path: String
    public let name: String
    public let sizeBytes: UInt64
    public let createdDate: Date?
    public let isScreenshot: Bool

    public init(path: String, name: String, sizeBytes: UInt64, createdDate: Date?, isScreenshot: Bool) {
        self.id = path
        self.path = path
        self.name = name
        self.sizeBytes = sizeBytes
        self.createdDate = createdDate
        self.isScreenshot = isScreenshot
    }
}
