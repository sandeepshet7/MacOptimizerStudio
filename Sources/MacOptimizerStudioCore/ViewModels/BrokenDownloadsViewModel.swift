import Foundation

@MainActor
public final class BrokenDownloadsViewModel: ObservableObject {
    @Published public private(set) var result: BrokenDownloadsScanResult?
    @Published public private(set) var isScanning = false
    @Published public var selectedPaths: Set<String> = []

    private let service: BrokenDownloadsService
    private let auditLog: AuditLogService

    public init(service: BrokenDownloadsService = BrokenDownloadsService(), auditLog: AuditLogService = AuditLogService()) {
        self.service = service
        self.auditLog = auditLog
    }

    // MARK: - Default Paths

    public var defaultScanPaths: [URL] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return [home.appendingPathComponent("Downloads")]
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
        selectedPaths = []
    }

    // MARK: - Selection

    public func toggleSelection(_ item: BrokenDownload) {
        if selectedPaths.contains(item.path) {
            selectedPaths.remove(item.path)
        } else {
            selectedPaths.insert(item.path)
        }
    }

    public func selectAll() {
        guard let result else { return }
        for file in result.files {
            selectedPaths.insert(file.path)
        }
    }

    public func deselectAll() {
        selectedPaths.removeAll()
    }

    public var selectedItems: [BrokenDownload] {
        guard let result else { return [] }
        return result.files.filter { selectedPaths.contains($0.path) }
    }

    public var selectedTotalBytes: UInt64 {
        selectedItems.reduce(0) { $0 + $1.sizeBytes }
    }

    public var selectedCount: Int {
        selectedPaths.count
    }

    // MARK: - Trash

    public func trashSelected() -> (trashed: Int, errors: [String]) {
        let items = selectedItems
        let trashResult = service.trash(files: items)

        // Audit log
        if trashResult.trashed > 0 {
            let log = auditLog
            let paths = items.map(\.path)
            let totalSize = items.reduce(UInt64(0)) { $0 + $1.sizeBytes }
            let entry = AuditLogEntry(
                action: .brokenDownloadsTrashed,
                details: "Trashed \(trashResult.trashed) broken download(s)",
                paths: paths,
                totalBytes: totalSize,
                itemCount: trashResult.trashed,
                userConfirmed: true
            )
            Task.detached { log.log(entry) }
        }

        // Remove trashed paths from selection
        for item in items {
            selectedPaths.remove(item.path)
        }

        return trashResult
    }
}
