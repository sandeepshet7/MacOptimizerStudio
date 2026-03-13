import Foundation

public struct PhotoJunkService: Sendable {
    public init() {}

    /// Minimum file size to qualify as a "large photo" (10 MB).
    private static let largePhotoThreshold: UInt64 = 10 * 1024 * 1024

    /// Image file extensions to consider when scanning for large photos.
    private static let imageExtensions: Set<String> = [
        "jpg", "jpeg", "png", "heic", "heif", "tiff", "tif", "bmp", "raw", "cr2", "nef", "arw", "dng", "webp",
    ]

    // MARK: - Public API

    public func scan() -> PhotoJunkReport {
        let home = FileManager.default.homeDirectoryForCurrentUser.path

        // Scan for screenshots on Desktop and Downloads
        let screenshotDirs = [
            "\(home)/Desktop",
            "\(home)/Downloads",
        ]
        var screenshots: [PhotoJunkItem] = []
        for dir in screenshotDirs {
            screenshots.append(contentsOf: findScreenshots(in: dir))
        }
        screenshots.sort { $0.sizeBytes > $1.sizeBytes }

        // Scan for large photos in ~/Pictures
        let picturesDir = "\(home)/Pictures"
        let largePhotos = findLargePhotos(in: picturesDir).sorted { $0.sizeBytes > $1.sizeBytes }

        let totalScreenshotBytes = screenshots.reduce(0 as UInt64) { $0 + $1.sizeBytes }
        let totalLargePhotoBytes = largePhotos.reduce(0 as UInt64) { $0 + $1.sizeBytes }

        return PhotoJunkReport(
            screenshots: screenshots,
            largePhotos: largePhotos,
            totalScreenshotBytes: totalScreenshotBytes,
            totalLargePhotoBytes: totalLargePhotoBytes
        )
    }

    // MARK: - Screenshots

    private func findScreenshots(in directory: String) -> [PhotoJunkItem] {
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(atPath: directory) else { return [] }

        var items: [PhotoJunkItem] = []
        for fileName in contents {
            let lower = fileName.lowercased()
            let isScreenshot = lower.hasPrefix("screenshot") || lower.hasPrefix("screen shot")
            guard isScreenshot else { continue }

            let filePath = "\(directory)/\(fileName)"
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: filePath, isDirectory: &isDir), !isDir.boolValue else { continue }

            let attrs = try? fm.attributesOfItem(atPath: filePath)
            let size = attrs?[.size] as? UInt64 ?? 0
            let created = attrs?[.creationDate] as? Date
            guard size > 0 else { continue }

            items.append(PhotoJunkItem(
                path: filePath,
                name: fileName,
                sizeBytes: size,
                createdDate: created,
                isScreenshot: true
            ))
        }
        return items
    }

    // MARK: - Large Photos

    private func findLargePhotos(in directory: String) -> [PhotoJunkItem] {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(
            at: URL(fileURLWithPath: directory),
            includingPropertiesForKeys: [.fileSizeKey, .creationDateKey, .isDirectoryKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else { return [] }

        var items: [PhotoJunkItem] = []

        for case let fileURL as URL in enumerator {
            let ext = fileURL.pathExtension.lowercased()
            guard Self.imageExtensions.contains(ext) else { continue }

            guard let values = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .creationDateKey, .isDirectoryKey]) else { continue }
            guard values.isDirectory != true else { continue }

            let size = UInt64(values.fileSize ?? 0)
            guard size >= Self.largePhotoThreshold else { continue }

            items.append(PhotoJunkItem(
                path: fileURL.path,
                name: fileURL.lastPathComponent,
                sizeBytes: size,
                createdDate: values.creationDate,
                isScreenshot: false
            ))
        }
        return items
    }
}
