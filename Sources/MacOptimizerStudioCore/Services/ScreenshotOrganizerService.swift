import Foundation

public struct ScreenshotOrganizerService: Sendable {
    public init() {}

    /// Patterns that identify screenshot and screen recording files.
    private static let screenshotPrefixes: [String] = [
        "screenshot",
        "screen shot",
        "screen recording",
        "cleanshot",
    ]

    /// File extensions that are typically screenshots or screen recordings.
    private static let screenshotExtensions: Set<String> = [
        "png", "jpg", "jpeg", "heic", "tiff", "mov", "mp4",
    ]

    // MARK: - Date Formatting

    private static let monthKeyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    private static let monthNameFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMMM"
        f.locale = Locale(identifier: "en_US")
        return f
    }()

    // MARK: - Public API

    public func scan(paths: [URL]) -> ScreenshotScanResult {
        var allFiles: [ScreenshotFile] = []

        for path in paths {
            allFiles.append(contentsOf: scanDirectory(path))
        }

        allFiles.sort { $0.createdDate > $1.createdDate }

        let totalBytes = allFiles.reduce(0 as UInt64) { $0 + $1.sizeBytes }
        var byMonth: [String: [ScreenshotFile]] = [:]
        for file in allFiles {
            byMonth[file.monthKey, default: []].append(file)
        }

        return ScreenshotScanResult(files: allFiles, totalBytes: totalBytes, byMonth: byMonth)
    }

    public func organize(
        files: [ScreenshotFile],
        into destinationFolder: URL,
        byMonth: Bool
    ) -> (moved: Int, errors: [String]) {
        let fm = FileManager.default
        var moved = 0
        var errors: [String] = []

        // Ensure destination exists
        do {
            try fm.createDirectory(at: destinationFolder, withIntermediateDirectories: true)
        } catch {
            return (0, ["Failed to create destination folder: \(error.localizedDescription)"])
        }

        for file in files {
            let sourceURL = URL(fileURLWithPath: file.path)
            guard fm.fileExists(atPath: file.path) else { continue }

            let targetDir: URL
            if byMonth {
                let folderName = monthFolderName(for: file.monthKey)
                targetDir = destinationFolder.appendingPathComponent(folderName)
            } else {
                targetDir = destinationFolder
            }

            do {
                try fm.createDirectory(at: targetDir, withIntermediateDirectories: true)

                var destURL = targetDir.appendingPathComponent(file.name)

                // Handle name collisions
                var counter = 1
                let baseName = (file.name as NSString).deletingPathExtension
                let ext = (file.name as NSString).pathExtension
                while fm.fileExists(atPath: destURL.path) {
                    let newName = "\(baseName) (\(counter)).\(ext)"
                    destURL = targetDir.appendingPathComponent(newName)
                    counter += 1
                }

                try fm.moveItem(at: sourceURL, to: destURL)
                moved += 1
            } catch {
                errors.append("Failed to move \(file.name): \(error.localizedDescription)")
            }
        }

        return (moved, errors)
    }

    // MARK: - Helpers

    /// Returns a folder name like "2024-01 January" for a given month key.
    public func monthFolderName(for monthKey: String) -> String {
        let parts = monthKey.split(separator: "-")
        guard parts.count == 2,
              let year = Int(parts[0]),
              let month = Int(parts[1])
        else {
            return monthKey
        }

        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = 1

        guard let date = Calendar.current.date(from: components) else {
            return monthKey
        }

        let monthName = Self.monthNameFormatter.string(from: date)
        return "\(monthKey) \(monthName)"
    }

    // MARK: - Private

    private func scanDirectory(_ directory: URL) -> [ScreenshotFile] {
        let fm = FileManager.default
        let directoryPath = directory.path

        guard fm.fileExists(atPath: directoryPath) else { return [] }
        guard let contents = try? fm.contentsOfDirectory(atPath: directoryPath) else { return [] }

        var items: [ScreenshotFile] = []

        for fileName in contents {
            let lower = fileName.lowercased()
            let ext = (lower as NSString).pathExtension

            // Must have a valid screenshot extension
            guard Self.screenshotExtensions.contains(ext) else { continue }

            // Check if filename matches a screenshot pattern
            let isScreenshot = Self.screenshotPrefixes.contains { prefix in
                lower.hasPrefix(prefix)
            }
            guard isScreenshot else { continue }

            let filePath = "\(directoryPath)/\(fileName)"
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: filePath, isDirectory: &isDir), !isDir.boolValue else { continue }

            let attrs = try? fm.attributesOfItem(atPath: filePath)
            let size = attrs?[.size] as? UInt64 ?? 0
            let created = (attrs?[.creationDate] as? Date) ?? Date()
            guard size > 0 else { continue }

            let monthKey = Self.monthKeyFormatter.string(from: created)

            items.append(ScreenshotFile(
                name: fileName,
                path: filePath,
                sizeBytes: size,
                createdDate: created,
                monthKey: monthKey
            ))
        }

        return items
    }
}
