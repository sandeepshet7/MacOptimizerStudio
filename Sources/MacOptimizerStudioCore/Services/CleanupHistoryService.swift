import Foundation

public struct CleanupHistoryService: Sendable {
    private static let fileName = "cleanup_history.json"

    public init() {}

    private var fileURL: URL {
        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return FileManager.default.temporaryDirectory.appendingPathComponent("MacOptimizerStudio_cleanup_history.json")
        }
        let dir = appSupport.appendingPathComponent("MacOptimizerStudio", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent(Self.fileName)
    }

    public func loadRecords() -> [CleanupRecord] {
        guard let data = try? Data(contentsOf: fileURL) else { return [] }
        return (try? JSONDecoder().decode([CleanupRecord].self, from: data)) ?? []
    }

    public func saveRecord(_ record: CleanupRecord) {
        var records = loadRecords()
        records.insert(record, at: 0)
        if records.count > 500 { records = Array(records.prefix(500)) }
        if let data = try? JSONEncoder().encode(records) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }

    public func clearHistory() {
        try? FileManager.default.removeItem(at: fileURL)
    }
}
