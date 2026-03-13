import Foundation

@MainActor
public final class PhotoJunkViewModel: ObservableObject {
    @Published public private(set) var report: PhotoJunkReport?
    @Published public private(set) var isScanning = false
    @Published public var selectedPaths: Set<String> = []

    private let service: PhotoJunkService
    private let auditLog: AuditLogService

    public init(service: PhotoJunkService = PhotoJunkService(), auditLog: AuditLogService = AuditLogService()) {
        self.service = service
        self.auditLog = auditLog
    }

    public func scan() async {
        isScanning = true
        defer { isScanning = false }

        let svc = service
        let result = await Task.detached(priority: .userInitiated) {
            svc.scan()
        }.value

        report = result
        selectedPaths = []
    }

    // MARK: - Selection

    public func toggleSelection(_ item: PhotoJunkItem) {
        if selectedPaths.contains(item.path) {
            selectedPaths.remove(item.path)
        } else {
            selectedPaths.insert(item.path)
        }
    }

    public func selectAllScreenshots() {
        guard let report else { return }
        for item in report.screenshots {
            selectedPaths.insert(item.path)
        }
    }

    public func selectAllLargePhotos() {
        guard let report else { return }
        for item in report.largePhotos {
            selectedPaths.insert(item.path)
        }
    }

    public func deselectAll() {
        selectedPaths.removeAll()
    }

    public var selectedItems: [PhotoJunkItem] {
        guard let report else { return [] }
        let all = report.screenshots + report.largePhotos
        return all.filter { selectedPaths.contains($0.path) }
    }

    public var selectedTotalBytes: UInt64 {
        selectedItems.reduce(0) { $0 + $1.sizeBytes }
    }

    public var selectedCount: Int {
        selectedPaths.count
    }

    // MARK: - Trash

    public func moveSelectedToTrash() -> (success: Bool, trashedCount: Int, errors: [String]) {
        let items = selectedItems
        var errors: [String] = []
        var trashedCount = 0

        for item in items {
            do {
                if FileManager.default.fileExists(atPath: item.path) {
                    try FileManager.default.trashItem(at: URL(fileURLWithPath: item.path), resultingItemURL: nil)
                    trashedCount += 1
                }
            } catch {
                errors.append("Failed to trash \(item.name): \(error.localizedDescription)")
            }
        }

        // Remove trashed items from selections
        for item in items {
            selectedPaths.remove(item.path)
        }

        if trashedCount > 0 {
            let log = auditLog
            let paths = items.map(\.path)
            let totalSize = items.reduce(0 as UInt64) { $0 + $1.sizeBytes }
            Task.detached { log.log(AuditLogEntry(action: .photoJunkTrashed, details: "Trashed \(trashedCount) photo junk item(s)", paths: paths, totalBytes: totalSize, itemCount: trashedCount)) }
        }

        return (errors.isEmpty, trashedCount, errors)
    }
}
