import Combine
import Foundation

public struct ScanHistoryEntry: Identifiable, Sendable {
    public let id = UUID()
    public let startedAt: Date
    public let durationSeconds: TimeInterval
    public let rootCount: Int
    public let totalBytes: UInt64
    public let targetCount: Int

    public init(startedAt: Date, durationSeconds: TimeInterval, rootCount: Int, totalBytes: UInt64, targetCount: Int) {
        self.startedAt = startedAt
        self.durationSeconds = durationSeconds
        self.rootCount = rootCount
        self.totalBytes = totalBytes
        self.targetCount = targetCount
    }
}

@MainActor
public final class DiskViewModel: ObservableObject {
    @Published public private(set) var roots: [URL]
    @Published public private(set) var report: ScanReport?
    @Published public private(set) var isScanning = false
    @Published public private(set) var lastError: String?
    @Published public private(set) var lastScanDuration: TimeInterval?
    @Published public private(set) var scanHistory: [ScanHistoryEntry] = []

    // Cached derived data — rebuilt when report changes
    private var cachedByKind: [TargetKind: [TargetEntry]] = [:]
    private var cachedByCategory: [TargetCategory: [TargetEntry]] = [:]
    @Published public private(set) var allEntries: [TargetEntry] = []

    private let bookmarkStore: BookmarkStore
    private let scannerService: RustScannerService

    public init(
        bookmarkStore: BookmarkStore = BookmarkStore(),
        scannerService: RustScannerService = RustScannerService()
    ) {
        self.bookmarkStore = bookmarkStore
        self.scannerService = scannerService
        self.roots = bookmarkStore.loadRoots()
    }

    public func addRoots(_ newRoots: [URL]) {
        var merged = roots
        for root in newRoots where !merged.contains(root) {
            merged.append(root)
        }
        roots = merged.sorted { $0.path < $1.path }
        bookmarkStore.saveRoots(roots)
        invalidateScanResults()
    }

    public func removeRoot(_ root: URL) {
        roots.removeAll { $0.path == root.path }
        bookmarkStore.saveRoots(roots)
        invalidateScanResults()
    }

    public func clearError() {
        lastError = nil
    }

    public func scan(maxDepth: Int = 6, top: Int = 200) async {
        guard !roots.isEmpty else {
            lastError = "Select at least one root folder before scanning."
            return
        }

        let startedAt = Date()
        isScanning = true
        defer { isScanning = false }

        let scopedRoots = roots.filter { $0.startAccessingSecurityScopedResource() }
        defer {
            for root in scopedRoots {
                root.stopAccessingSecurityScopedResource()
            }
        }

        do {
            let scanRoots = scopedRoots.isEmpty ? roots : scopedRoots
            let service = scannerService
            let scanReport = try await Task.detached(priority: .userInitiated) {
                try service.scan(roots: scanRoots, maxDepth: maxDepth, top: top)
            }.value
            report = scanReport
            rebuildCaches()
            lastError = nil

            let duration = Date().timeIntervalSince(startedAt)
            lastScanDuration = duration
            appendScanHistory(for: scanReport, startedAt: startedAt, duration: duration)
        } catch {
            lastError = error.localizedDescription
            ErrorCollector.shared.record(source: "DiskScan", message: error.localizedDescription)
        }
    }

    private func rebuildCaches() {
        let targets = report?.targets ?? []
        allEntries = targets

        var byKind: [TargetKind: [TargetEntry]] = [:]
        var byCategory: [TargetCategory: [TargetEntry]] = [:]
        for entry in targets {
            byKind[entry.kind, default: []].append(entry)
            byCategory[entry.kind.category, default: []].append(entry)
        }
        for key in byKind.keys { byKind[key]?.sort { $0.sizeBytes > $1.sizeBytes } }
        for key in byCategory.keys { byCategory[key]?.sort { $0.sizeBytes > $1.sizeBytes } }
        cachedByKind = byKind
        cachedByCategory = byCategory
    }

    public func entries(for kind: TargetKind) -> [TargetEntry] {
        cachedByKind[kind] ?? []
    }

    public func entries(for category: TargetCategory) -> [TargetEntry] {
        cachedByCategory[category] ?? []
    }

    public func summary(for kind: TargetKind) -> (count: Int, sizeBytes: UInt64) {
        let e = entries(for: kind)
        return (e.count, e.reduce(UInt64(0)) { $0 + $1.sizeBytes })
    }

    public func summary(for category: TargetCategory) -> (count: Int, sizeBytes: UInt64) {
        let e = entries(for: category)
        return (e.count, e.reduce(UInt64(0)) { $0 + $1.sizeBytes })
    }

    public var totalCleanupCount: Int {
        allEntries.count
    }

    public var totalCleanupBytes: UInt64 {
        allEntries.reduce(UInt64(0)) { $0 + $1.sizeBytes }
    }

    public var activeCategories: [TargetCategory] {
        Array(Set(cachedByCategory.keys)).sorted { $0.rawValue < $1.rawValue }
    }

    public var activeKinds: [TargetKind] {
        Array(Set(cachedByKind.keys)).sorted { $0.rawValue < $1.rawValue }
    }

    public func entriesGrouped() -> [TargetKind: [TargetEntry]] {
        cachedByKind
    }

    private func invalidateScanResults() {
        report = nil
        lastError = nil
        lastScanDuration = nil
        cachedByKind = [:]
        cachedByCategory = [:]
        allEntries = []
    }

    private func appendScanHistory(for report: ScanReport, startedAt: Date, duration: TimeInterval) {
        let rootPaths = Set(report.roots)
        let rootTotal = report.folderTotals
            .filter { rootPaths.contains($0.path) }
            .reduce(UInt64(0)) { $0 + $1.sizeBytes }

        let entry = ScanHistoryEntry(
            startedAt: startedAt,
            durationSeconds: duration,
            rootCount: report.roots.count,
            totalBytes: rootTotal,
            targetCount: report.targets.count
        )

        scanHistory.insert(entry, at: 0)
        if scanHistory.count > 30 {
            scanHistory.removeLast(scanHistory.count - 30)
        }
    }
}
