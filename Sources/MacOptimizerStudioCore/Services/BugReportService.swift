import Foundation

public struct BugReportService: Sendable {
    public init() {}

    public func generateReport(
        systemSnapshot: SystemHealthSnapshot?,
        recentAuditEntries: [AuditLogEntry],
        recentErrors: [ErrorLogEntry]
    ) -> String {
        var lines: [String] = []
        let divider = String(repeating: "─", count: 60)

        // Header
        lines.append("MacOptimizer Studio — Bug Report")
        lines.append("Generated: \(ISO8601DateFormatter().string(from: Date()))")
        lines.append("App Version: \(appVersion) (\(buildNumber))")
        lines.append(divider)

        // System Info
        lines.append("")
        lines.append("## SYSTEM INFO")
        if let hw = systemSnapshot?.hardware {
            lines.append("  macOS: \(hw.macOSVersion) (Build \(hw.macOSBuild))")
            lines.append("  CPU: \(hw.cpuModel)")
            lines.append("  Cores: \(hw.cpuCoreCount)")
            lines.append("  RAM: \(ByteFormatting.memoryString(hw.totalRAMBytes))")
            lines.append("  Hostname: \(hw.hostname)")
            lines.append("  Uptime: \(formatUptime(hw.uptimeSeconds))")
        } else {
            lines.append("  (Not available)")
        }

        // Disk
        if let disk = systemSnapshot?.diskUsage {
            lines.append("")
            lines.append("## DISK")
            lines.append("  Total: \(ByteFormatting.string(disk.totalBytes))")
            lines.append("  Used: \(ByteFormatting.string(disk.usedBytes)) (\(String(format: "%.1f%%", disk.usagePercent)))")
            lines.append("  Free: \(ByteFormatting.string(disk.freeBytes))")
        }

        // Battery
        if let bat = systemSnapshot?.battery {
            lines.append("")
            lines.append("## BATTERY")
            lines.append("  Health: \(bat.healthPercent)%")
            lines.append("  Charge: \(bat.chargePercent)%")
            lines.append("  Cycle Count: \(bat.cycleCount)")
            lines.append("  Charging: \(bat.isCharging ? "Yes" : "No")")
        }

        // Recent Errors
        lines.append("")
        lines.append("## RECENT ERRORS (\(recentErrors.count))")
        if recentErrors.isEmpty {
            lines.append("  None recorded")
        } else {
            let df = DateFormatter()
            df.dateStyle = .short
            df.timeStyle = .medium
            for entry in recentErrors.prefix(50) {
                lines.append("  [\(df.string(from: entry.timestamp))] \(entry.source)")
                lines.append("    \(entry.message)")
                if let context = entry.context {
                    lines.append("    Context: \(context)")
                }
                lines.append("")
            }
        }

        // Recent Activity (last 20 audit entries)
        lines.append(divider)
        lines.append("## RECENT ACTIVITY (last 20)")
        let df = DateFormatter()
        df.dateStyle = .short
        df.timeStyle = .medium
        for entry in recentAuditEntries.prefix(20) {
            var line = "  [\(df.string(from: entry.timestamp))] \(entry.action.label): \(entry.details)"
            if let bytes = entry.totalBytes {
                line += " (\(ByteFormatting.string(bytes)))"
            }
            lines.append(line)
        }
        if recentAuditEntries.isEmpty {
            lines.append("  No activity recorded")
        }

        lines.append("")
        lines.append(divider)
        lines.append("## USER DESCRIPTION")
        lines.append("[Please describe what happened, what you expected, and steps to reproduce]")
        lines.append("")
        lines.append(divider)
        lines.append("End of report")

        return lines.joined(separator: "\n")
    }

    // MARK: - Helpers

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    private func formatUptime(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let days = hours / 24
        let remainingHours = hours % 24
        if days > 0 {
            return "\(days)d \(remainingHours)h"
        }
        return "\(hours)h \(Int(seconds) % 3600 / 60)m"
    }
}

// MARK: - Error Log

public struct ErrorLogEntry: Sendable, Codable {
    public let timestamp: Date
    public let source: String
    public let message: String
    public let context: String?

    public init(source: String, message: String, context: String? = nil) {
        self.timestamp = Date()
        self.source = source
        self.message = message
        self.context = context
    }
}

public final class ErrorCollector: @unchecked Sendable {
    public static let shared = ErrorCollector()

    private let lock = NSLock()
    private var entries: [ErrorLogEntry] = []
    private static let maxEntries = 200

    private init() {}

    public func record(source: String, message: String, context: String? = nil) {
        let entry = ErrorLogEntry(source: source, message: message, context: context)
        lock.lock()
        entries.insert(entry, at: 0)
        if entries.count > Self.maxEntries {
            entries = Array(entries.prefix(Self.maxEntries))
        }
        lock.unlock()
    }

    public func recentErrors() -> [ErrorLogEntry] {
        lock.lock()
        defer { lock.unlock() }
        return entries
    }

    public func clear() {
        lock.lock()
        entries.removeAll()
        lock.unlock()
    }
}
