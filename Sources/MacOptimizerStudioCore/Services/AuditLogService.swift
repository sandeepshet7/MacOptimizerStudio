import Foundation

public struct AuditLogService: Sendable {
    private static let maxEntries = 10_000

    public init() {}

    private var logFileURL: URL {
        guard let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return FileManager.default.temporaryDirectory.appendingPathComponent("MacOptimizerStudio_audit_log.json")
        }
        let appDir = support.appendingPathComponent("MacOptimizerStudio")
        try? FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)
        return appDir.appendingPathComponent("audit_log.json")
    }

    // MARK: - Write

    public func log(_ entry: AuditLogEntry) {
        var entries = loadAll()
        entries.insert(entry, at: 0)

        if entries.count > Self.maxEntries {
            entries = Array(entries.prefix(Self.maxEntries))
        }

        save(entries)
    }

    // MARK: - Read

    public func loadAll() -> [AuditLogEntry] {
        let url = logFileURL
        guard FileManager.default.fileExists(atPath: url.path) else { return [] }

        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode([AuditLogEntry].self, from: data)
        } catch {
            return []
        }
    }

    // MARK: - Export

    public func exportAsText() -> String {
        let entries = loadAll()
        if entries.isEmpty { return "No audit log entries." }

        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .medium

        var lines: [String] = []
        lines.append("MacOptimizer Studio — Activity Log")
        lines.append("Exported: \(dateFormatter.string(from: Date()))")
        lines.append("Total entries: \(entries.count)")
        lines.append(String(repeating: "=", count: 60))
        lines.append("")

        for entry in entries {
            lines.append("[\(dateFormatter.string(from: entry.timestamp))]")
            lines.append("Action: \(entry.action.label)")
            lines.append("Details: \(entry.details)")
            if let bytes = entry.totalBytes {
                lines.append("Size: \(ByteFormatting.string(bytes))")
            }
            lines.append("Items: \(entry.itemCount)")
            lines.append("User confirmed: \(entry.userConfirmed ? "Yes" : "No")")
            if !entry.paths.isEmpty {
                lines.append("Paths:")
                for path in entry.paths.prefix(20) {
                    lines.append("  - \(path)")
                }
                if entry.paths.count > 20 {
                    lines.append("  ... and \(entry.paths.count - 20) more")
                }
            }
            lines.append("")
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - Private

    private func save(_ entries: [AuditLogEntry]) {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(entries)
            try data.write(to: logFileURL, options: .atomic)
        } catch {
            // Silently fail — audit logging should never crash the app
        }
    }
}
