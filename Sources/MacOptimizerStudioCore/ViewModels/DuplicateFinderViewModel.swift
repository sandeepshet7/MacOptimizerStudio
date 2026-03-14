import Foundation

@MainActor
public final class DuplicateFinderViewModel: ObservableObject {
    @Published public var report: DuplicateScanReport?
    @Published public var isScanning = false
    @Published public var scanProgress: String = ""
    @Published public var selectedPaths: Set<String> = []
    @Published public var roots: [URL] = []
    @Published public var minFileSize: UInt64 = 100 * 1024 // 100KB default
    @Published public var errorMessage: String?

    private let service = DuplicateFinderService()

    public init() {
        roots = [FileManager.default.homeDirectoryForCurrentUser]
    }

    public func scan() async {
        guard !isScanning else { return }
        isScanning = true
        scanProgress = "Scanning for duplicate files..."
        errorMessage = nil
        selectedPaths.removeAll()

        let rootPaths = roots.map(\.path)
        let minSize = minFileSize
        let svc = service

        let result = await Task.detached(priority: .userInitiated) {
            await svc.scan(roots: rootPaths, minFileSize: minSize)
        }.value

        report = result
        scanProgress = ""
        isScanning = false
    }

    public func addRoots(_ urls: [URL]) {
        for url in urls {
            if !roots.contains(where: { $0.path == url.path }) {
                roots.append(url)
            }
        }
    }

    public func removeRoot(_ url: URL) {
        roots.removeAll { $0.path == url.path }
    }

    public func toggleSelection(_ path: String) {
        if selectedPaths.contains(path) {
            selectedPaths.remove(path)
        } else {
            selectedPaths.insert(path)
        }
    }

    /// Select all duplicates but keep the first (oldest) in each group
    public func selectAllDuplicates() {
        guard let report = report else { return }
        var newSelection = Set<String>()
        for group in report.groups {
            // Skip the first path (original/oldest), select the rest
            for path in group.paths.dropFirst() {
                newSelection.insert(path)
            }
        }
        selectedPaths = newSelection
    }

    public func deselectAll() {
        selectedPaths.removeAll()
    }

    public var selectedCount: Int {
        selectedPaths.count
    }

    public var selectedBytes: UInt64 {
        guard let report = report else { return 0 }
        var total: UInt64 = 0
        for group in report.groups {
            for path in group.paths where selectedPaths.contains(path) {
                total += group.fileSize
            }
        }
        return total
    }

    /// Move selected files to trash
    public func deleteSelected() async {
        let pathsToDelete = Array(selectedPaths)
        guard !pathsToDelete.isEmpty else { return }

        var deletedCount = 0
        var deletedBytes: UInt64 = 0
        var errors: [String] = []

        for path in pathsToDelete {
            let url = URL(fileURLWithPath: path)
            do {
                // Get file size before deleting
                let attrs = try FileManager.default.attributesOfItem(atPath: path)
                let size = attrs[.size] as? UInt64 ?? 0

                try FileManager.default.trashItem(at: url, resultingItemURL: nil)
                deletedCount += 1
                deletedBytes += size
                selectedPaths.remove(path)
            } catch {
                errors.append("\(path): \(error.localizedDescription)")
            }
        }

        if !errors.isEmpty {
            errorMessage = "Failed to trash \(errors.count) file(s): \(errors.first ?? "")"
        }

        // Re-scan to update results
        if deletedCount > 0 {
            await scan()
        }
    }
}
