import Combine
import Foundation

@MainActor
public final class CacheViewModel: ObservableObject {
    @Published public private(set) var report: CacheScanReport?
    @Published public private(set) var isScanning = false
    @Published public var selectedPaths: Set<String> = []

    // Cached derived data — rebuilt only when report changes
    @Published public private(set) var entriesByCategory: [CacheCategory: [CacheEntry]] = [:]
    @Published public private(set) var safeTotalBytes: UInt64 = 0
    @Published public private(set) var safeEntryCount: Int = 0
    @Published public private(set) var topOffenders: [CacheEntry] = []

    private let cacheService: SystemCacheService
    private let auditLog: AuditLogService

    public init(cacheService: SystemCacheService = SystemCacheService(), auditLog: AuditLogService = AuditLogService()) {
        self.cacheService = cacheService
        self.auditLog = auditLog
    }

    public func scan() async {
        isScanning = true
        defer { isScanning = false }

        let service = cacheService
        let result = await Task.detached(priority: .userInitiated) {
            service.scan()
        }.value

        report = result
        selectedPaths = []
        rebuildCaches()
        rebuildSelection()
    }

    private func rebuildCaches() {
        let entries = report?.entries ?? []
        var grouped: [CacheCategory: [CacheEntry]] = [:]
        for entry in entries {
            grouped[entry.category, default: []].append(entry)
        }
        for key in grouped.keys {
            grouped[key]?.sort { $0.sizeBytes > $1.sizeBytes }
        }
        entriesByCategory = grouped

        let safeEntries = entries.filter { $0.riskLevel == .safe }
        safeTotalBytes = safeEntries.reduce(0) { $0 + $1.sizeBytes }
        safeEntryCount = safeEntries.count
        topOffenders = Array(entries.sorted { $0.sizeBytes > $1.sizeBytes }.prefix(3))
    }

    public func entries(for category: CacheCategory) -> [CacheEntry] {
        entriesByCategory[category] ?? []
    }

    public func categoryTotal(_ category: CacheCategory) -> UInt64 {
        report?.categoryTotals[category] ?? 0
    }

    public func categoryCount(_ category: CacheCategory) -> Int {
        entriesByCategory[category]?.count ?? 0
    }

    @Published public private(set) var selectedEntries: [CacheEntry] = []
    @Published public private(set) var selectedTotalBytes: UInt64 = 0

    private func rebuildSelection() {
        selectedEntries = (report?.entries ?? []).filter { selectedPaths.contains($0.path) }
        selectedTotalBytes = selectedEntries.reduce(UInt64(0)) { $0 + $1.sizeBytes }
    }

    public func toggleSelection(_ entry: CacheEntry) {
        if selectedPaths.contains(entry.path) {
            selectedPaths.remove(entry.path)
        } else {
            selectedPaths.insert(entry.path)
        }
        rebuildSelection()
    }

    public func selectAll(for category: CacheCategory) {
        let entries = self.entries(for: category)
        for entry in entries {
            selectedPaths.insert(entry.path)
        }
        rebuildSelection()
    }

    public func deselectAll(for category: CacheCategory) {
        let entries = self.entries(for: category)
        for entry in entries {
            selectedPaths.remove(entry.path)
        }
        rebuildSelection()
    }

    public func selectAllSafe() {
        guard let report else { return }
        for entry in report.entries where entry.riskLevel == .safe {
            selectedPaths.insert(entry.path)
        }
        rebuildSelection()
    }

    public func deselectAll() {
        selectedPaths.removeAll()
        rebuildSelection()
    }

    private var trashDir: String {
        "~/.Trash/MacOptimizerStudio-$(date +%Y%m%d-%H%M%S)"
    }

    public func cleanupCommands() -> [String] {
        guard !selectedEntries.isEmpty else { return [] }
        let dest = trashDir
        var cmds: [String] = ["mkdir -p \(dest)"]
        for entry in selectedEntries {
            cmds.append("mv \(ShellEscaper.quote(entry.path)) \(dest)/")
        }
        return cmds
    }

    public func logCleanup(itemCount: Int) {
        let paths = selectedEntries.map(\.path)
        let totalSize = selectedTotalBytes
        let log = auditLog
        let entry = AuditLogEntry(
            action: .cacheCleanup,
            details: "Moved \(itemCount) cache item(s) to Trash",
            paths: paths,
            totalBytes: totalSize,
            itemCount: itemCount,
            userConfirmed: true
        )
        Task.detached { log.log(entry) }
    }

    public func executionRequest() -> ExecutionRequest {
        let items = selectedEntries.map { entry in
            ExecutionItem(label: entry.name, path: entry.path, sizeBytes: entry.sizeBytes)
        }

        let cautionCount = selectedEntries.filter { $0.riskLevel == .caution }.count
        let risk: ExecutionRisk = cautionCount > 0 ? .danger : .moderate

        var warning = "You are about to move \(items.count) cache folders totaling \(ByteFormatting.string(selectedTotalBytes)) to the Trash."
        if cautionCount > 0 {
            warning += "\n\n\(cautionCount) item(s) are marked CAUTION and may contain important data. Items can be recovered from Trash until you empty it."
        } else {
            warning += "\n\nThese are cache files that will be regenerated by their applications. Items can be recovered from Trash if needed."
        }

        return ExecutionRequest(
            title: "Move Selected Caches to Trash",
            warningMessage: warning,
            risk: risk,
            items: items,
            commands: cleanupCommands(),
            confirmationWord: cautionCount > 0 ? "DELETE" : "CONFIRM"
        )
    }
}
