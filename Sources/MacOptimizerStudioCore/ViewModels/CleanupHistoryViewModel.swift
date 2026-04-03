import Foundation

@MainActor
public final class CleanupHistoryViewModel: ObservableObject {
    @Published public private(set) var records: [CleanupRecord] = []
    @Published public private(set) var totalBytesFreed: UInt64 = 0

    private let service: CleanupHistoryService

    public init(service: CleanupHistoryService = CleanupHistoryService()) {
        self.service = service
        reload()
    }

    public func reload() {
        records = service.loadRecords()
        totalBytesFreed = records.reduce(0) { $0 + $1.bytesFreed }
    }

    public func addRecord(category: String, itemCount: Int, bytesFreed: UInt64, details: String) {
        let record = CleanupRecord(date: Date(), category: category, itemCount: itemCount, bytesFreed: bytesFreed, details: details)
        service.saveRecord(record)
        reload()
    }

    public func clearHistory() {
        service.clearHistory()
        reload()
    }

    private static let monthFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        return f
    }()

    public var recordsByMonth: [(String, [CleanupRecord])] {
        let grouped = Dictionary(grouping: records) { Self.monthFormatter.string(from: $0.date) }
        return grouped.sorted { ($0.value.first?.date ?? .distantPast) > ($1.value.first?.date ?? .distantPast) }
    }
}
