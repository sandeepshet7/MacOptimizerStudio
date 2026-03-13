import Foundation

public struct BrokenDownloadsService: Sendable {
    public init() {}

    /// File extensions that indicate incomplete/broken downloads.
    private static let brokenExtensions: Set<String> = [
        "crdownload", "download", "part", "tmp", "partial", "opdownload",
    ]

    /// Minimum age (in seconds) before a file with a download extension is considered broken.
    /// Files younger than this may still be actively downloading.
    private static let minimumAgeSeconds: TimeInterval = 3600 // 1 hour

    // MARK: - Public API

    public func scan(paths: [URL]) -> BrokenDownloadsScanResult {
        var allFiles: [BrokenDownload] = []

        for path in paths {
            allFiles.append(contentsOf: scanDirectory(path))
        }

        allFiles.sort { $0.sizeBytes > $1.sizeBytes }
        let totalBytes = allFiles.reduce(0 as UInt64) { $0 + $1.sizeBytes }

        return BrokenDownloadsScanResult(files: allFiles, totalBytes: totalBytes)
    }

    public func trash(files: [BrokenDownload]) -> (trashed: Int, errors: [String]) {
        let fm = FileManager.default
        var trashed = 0
        var errors: [String] = []

        for file in files {
            do {
                let url = URL(fileURLWithPath: file.path)
                if fm.fileExists(atPath: file.path) {
                    try fm.trashItem(at: url, resultingItemURL: nil)
                    trashed += 1
                }
            } catch {
                errors.append("Failed to trash \(file.name): \(error.localizedDescription)")
            }
        }

        return (trashed, errors)
    }

    // MARK: - Private

    private func scanDirectory(_ directory: URL) -> [BrokenDownload] {
        let fm = FileManager.default
        let directoryPath = directory.path

        guard fm.fileExists(atPath: directoryPath) else { return [] }

        guard let contents = try? fm.contentsOfDirectory(atPath: directoryPath) else { return [] }

        let now = Date()
        var items: [BrokenDownload] = []

        for fileName in contents {
            let filePath = "\(directoryPath)/\(fileName)"
            let ext = (fileName as NSString).pathExtension.lowercased()

            guard Self.brokenExtensions.contains(ext) else { continue }

            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: filePath, isDirectory: &isDir) else { continue }

            // Safari .download bundles are directories
            let attrs: [FileAttributeKey: Any]?
            if isDir.boolValue {
                // For directories, get the directory attributes
                attrs = try? fm.attributesOfItem(atPath: filePath)
            } else {
                attrs = try? fm.attributesOfItem(atPath: filePath)
            }

            let modDate = attrs?[.modificationDate] as? Date
            let size: UInt64

            if isDir.boolValue {
                size = directorySize(at: filePath)
            } else {
                size = attrs?[.size] as? UInt64 ?? 0
            }

            // Only consider files older than the minimum age threshold
            if let modDate, now.timeIntervalSince(modDate) < Self.minimumAgeSeconds {
                continue
            }

            items.append(BrokenDownload(
                name: fileName,
                path: filePath,
                sizeBytes: size,
                modifiedDate: modDate,
                downloadType: BrokenDownloadType.from(extension: ext)
            ))
        }

        return items
    }

    /// Calculate the total size of a directory recursively.
    private func directorySize(at path: String) -> UInt64 {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(
            at: URL(fileURLWithPath: path),
            includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return 0 }

        var total: UInt64 = 0
        for case let fileURL as URL in enumerator {
            guard let values = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .isDirectoryKey]) else { continue }
            guard values.isDirectory != true else { continue }
            total += UInt64(values.fileSize ?? 0)
        }
        return total
    }
}
