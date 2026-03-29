import Foundation

@MainActor
public final class AuditLogViewModel: ObservableObject {
    @Published public private(set) var entries: [AuditLogEntry] = []
    @Published public private(set) var isLoading = false

    private let service: AuditLogService

    public init(service: AuditLogService = AuditLogService()) {
        self.service = service
    }

    public func load() async {
        isLoading = true
        defer { isLoading = false }

        let svc = service
        let result = await Task.detached(priority: .userInitiated) {
            svc.loadAll()
        }.value

        entries = result
    }

    public func exportText() -> String {
        service.exportAsText()
    }

    public func clearLog() async {
        let svc = service
        await Task.detached(priority: .userInitiated) {
            svc.clearAll()
        }.value
        entries = []
    }

    // MARK: - Grouped by Day

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()

    public var entriesByDay: [(String, [AuditLogEntry])] {
        let grouped = Dictionary(grouping: entries) { entry in
            Self.dayFormatter.string(from: entry.timestamp)
        }
        return grouped.sorted { pair1, pair2 in
            guard let d1 = pair1.value.first?.timestamp, let d2 = pair2.value.first?.timestamp else { return false }
            return d1 > d2
        }
    }

    // MARK: - Stats

    public var totalActions: Int { entries.count }

    public var totalBytesFreed: UInt64 {
        entries.compactMap(\.totalBytes).reduce(0, +)
    }

    public var actionCounts: [(AuditAction, Int)] {
        let grouped = Dictionary(grouping: entries, by: \.action)
        return grouped.map { ($0.key, $0.value.count) }
            .sorted { $0.1 > $1.1 }
    }
}
