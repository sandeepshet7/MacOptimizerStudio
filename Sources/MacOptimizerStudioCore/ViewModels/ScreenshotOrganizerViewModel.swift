import Foundation

@MainActor
public final class ScreenshotOrganizerViewModel: ObservableObject {
    @Published public private(set) var result: ScreenshotScanResult?
    @Published public private(set) var isScanning = false
    @Published public private(set) var isOrganizing = false
    @Published public private(set) var organizeProgress: Double = 0
    @Published public var destinationURL: URL?

    private let service: ScreenshotOrganizerService
    private let auditLog: AuditLogService

    public init(service: ScreenshotOrganizerService = ScreenshotOrganizerService(), auditLog: AuditLogService = AuditLogService()) {
        self.service = service
        self.auditLog = auditLog
        let home = FileManager.default.homeDirectoryForCurrentUser
        self.destinationURL = home.appendingPathComponent("Pictures/Screenshots")
    }

    // MARK: - Default Scan Paths

    public var defaultScanPaths: [URL] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return [
            home.appendingPathComponent("Desktop"),
            home.appendingPathComponent("Downloads"),
        ]
    }

    // MARK: - Scan

    public func scan() async {
        isScanning = true
        defer { isScanning = false }

        let paths = defaultScanPaths
        let svc = service
        let scanResult = await Task.detached(priority: .userInitiated) {
            svc.scan(paths: paths)
        }.value

        result = scanResult
    }

    // MARK: - Organize

    public func organize() async -> (moved: Int, errors: [String]) {
        guard let result, let destination = destinationURL else {
            return (0, ["No scan result or destination folder set."])
        }

        isOrganizing = true
        organizeProgress = 0
        defer {
            isOrganizing = false
            organizeProgress = 0
        }

        let files = result.files
        let dest = destination
        let svc = service
        let organizeResult = await Task.detached(priority: .userInitiated) {
            svc.organize(files: files, into: dest, byMonth: true)
        }.value

        // Audit log
        if organizeResult.moved > 0 {
            let log = auditLog
            let paths = files.map(\.path)
            let totalSize = files.reduce(UInt64(0)) { $0 + $1.sizeBytes }
            let entry = AuditLogEntry(
                action: .screenshotsMoved,
                details: "Organized \(organizeResult.moved) screenshot(s) into \(dest.path)",
                paths: paths,
                totalBytes: totalSize,
                itemCount: organizeResult.moved,
                userConfirmed: true
            )
            Task.detached { log.log(entry) }
        }

        // Re-scan after organizing
        await scan()

        return organizeResult
    }

    // MARK: - Folder Structure Preview

    /// Returns the folder structure that would be created, grouped by month.
    public var folderPreview: [(folderName: String, count: Int, totalBytes: UInt64)] {
        guard let result else { return [] }

        return result.sortedMonthKeys.compactMap { key in
            guard let files = result.byMonth[key] else { return nil }
            let folderName = service.monthFolderName(for: key)
            let totalBytes = files.reduce(0 as UInt64) { $0 + $1.sizeBytes }
            return (folderName, files.count, totalBytes)
        }
    }
}
