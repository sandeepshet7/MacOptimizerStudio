import Foundation

@MainActor
public final class StorageToolsViewModel: ObservableObject {
    // Space Lens
    @Published public private(set) var folderTree: FolderNode?
    @Published public private(set) var isScanningSizes = false
    @Published public var spaceLensRoot: URL?

    // Duplicates
    @Published public private(set) var duplicateGroups: [DuplicateGroup] = []
    @Published public private(set) var isScanningDuplicates = false
    @Published public private(set) var duplicateProgress = ""

    // Large Files
    @Published public private(set) var largeFiles: [LargeFile] = []
    @Published public private(set) var isScanningLargeFiles = false
    @Published public private(set) var largeFilesProgress = ""
    @Published public var minFileSizeMB: Double = 100
    @Published public var minAgeDays: Int? = nil

    // Purgeable
    @Published public private(set) var purgeableInfo: PurgeableInfo?
    @Published public private(set) var isLoadingPurgeable = false

    // Scan roots (shared with duplicates & large files)
    @Published public var scanRoots: [URL] = []

    private let service: StorageToolsService

    public init(service: StorageToolsService = StorageToolsService()) {
        self.service = service
    }

    // MARK: - Space Lens

    public func scanFolderSizes(at url: URL, maxDepth: Int = 4) async {
        isScanningSizes = true
        spaceLensRoot = url
        let svc = service
        let result = await Task.detached(priority: .userInitiated) {
            svc.scanFolderSizes(at: url, maxDepth: maxDepth)
        }.value
        folderTree = result
        isScanningSizes = false
    }

    // MARK: - Duplicates

    public func findDuplicates() async {
        guard !scanRoots.isEmpty else { return }
        isScanningDuplicates = true
        duplicateProgress = "Starting..."

        let svc = service
        let roots = scanRoots
        let result = await Task.detached(priority: .userInitiated) { [weak self] in
            svc.findDuplicates(in: roots, minSize: 1024) { progress in
                Task { @MainActor in
                    self?.duplicateProgress = progress
                }
            }
        }.value

        duplicateGroups = result
        isScanningDuplicates = false
    }

    // MARK: - Large & Old Files

    public func findLargeFiles() async {
        guard !scanRoots.isEmpty else { return }
        isScanningLargeFiles = true
        largeFilesProgress = "Starting..."

        let svc = service
        let roots = scanRoots
        let minBytes = UInt64(minFileSizeMB * 1024 * 1024)
        let ageDays = minAgeDays

        let result = await Task.detached(priority: .userInitiated) { [weak self] in
            svc.findLargeOldFiles(in: roots, minSizeBytes: minBytes, minAgeDays: ageDays) { progress in
                Task { @MainActor in
                    self?.largeFilesProgress = progress
                }
            }
        }.value

        largeFiles = result
        isScanningLargeFiles = false
    }

    // MARK: - Purgeable

    public func loadPurgeableSpace() async {
        isLoadingPurgeable = true
        let svc = service
        let result = await Task.detached(priority: .userInitiated) {
            svc.getPurgeableSpace()
        }.value
        purgeableInfo = result
        isLoadingPurgeable = false
    }

    // MARK: - Actions

    public func addRoots(_ urls: [URL]) {
        for url in urls where !scanRoots.contains(url) {
            scanRoots.append(url)
        }
    }

    public var totalDuplicateWaste: UInt64 {
        duplicateGroups.reduce(0) { $0 + $1.wastedBytes }
    }

    public var totalLargeFilesSize: UInt64 {
        largeFiles.reduce(0) { $0 + $1.sizeBytes }
    }
}
