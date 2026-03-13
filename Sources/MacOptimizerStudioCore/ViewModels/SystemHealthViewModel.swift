import Combine
import Foundation

public enum OverallHealthStatus: String, Sendable {
    case healthy
    case warning
    case critical

    public var label: String {
        switch self {
        case .healthy: return "Healthy"
        case .warning: return "Needs Attention"
        case .critical: return "Critical"
        }
    }
}

@MainActor
public final class SystemHealthViewModel: ObservableObject {
    @Published public private(set) var snapshot: SystemHealthSnapshot?
    @Published public private(set) var isLoading = false
    @Published public var memoryPressure: MemoryPressureLevel = .unknown

    private let service: SystemHealthService

    public init(service: SystemHealthService = SystemHealthService()) {
        self.service = service
    }

    public func refresh() async {
        isLoading = true
        defer { isLoading = false }

        let healthService = service
        let result = await Task.detached(priority: .userInitiated) {
            healthService.captureSnapshot()
        }.value

        snapshot = result
    }

    public func updateMemoryPressure(_ pressure: MemoryPressureLevel) {
        memoryPressure = pressure
    }

    public var overallHealth: OverallHealthStatus {
        guard let snapshot else { return .healthy }

        if snapshot.diskUsage.usagePercent > 90 || memoryPressure == .critical {
            return .critical
        }
        if snapshot.diskUsage.usagePercent > 75 || memoryPressure == .warning {
            return .warning
        }
        if let battery = snapshot.battery, battery.healthPercent < 60 {
            return .critical
        }

        return .healthy
    }

    public var uptimeFormatted: String {
        guard let uptime = snapshot?.hardware.uptimeSeconds else { return "-" }
        let days = Int(uptime) / 86400
        let hours = (Int(uptime) % 86400) / 3600
        let minutes = (Int(uptime) % 3600) / 60

        if days > 0 {
            return "\(days)d \(hours)h \(minutes)m"
        } else if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }

    public var diskHealthColor: String {
        guard let usage = snapshot?.diskUsage else { return "gray" }
        if usage.usagePercent < 70 { return "green" }
        if usage.usagePercent < 75 { return "orange" }
        return "red"
    }

    public var recommendations: [String] {
        guard let snapshot else { return [] }
        var notes: [String] = []

        if memoryPressure == .critical {
            notes.append("Memory pressure is CRITICAL. Close heavy applications or restart to free memory.")
        } else if memoryPressure == .warning {
            notes.append("Memory pressure is elevated. Consider closing unused applications.")
        }

        let disk = snapshot.diskUsage
        if disk.usagePercent > 90 {
            notes.append("Disk usage is critical (\(String(format: "%.0f%%", disk.usagePercent))). Free up space immediately.")
        } else if disk.usagePercent > 75 {
            notes.append("Disk usage is high (\(String(format: "%.0f%%", disk.usagePercent))). Consider cleaning caches.")
        }

        if let battery = snapshot.battery {
            if battery.healthPercent < 80 {
                notes.append("Battery health is degraded (\(String(format: "%.0f%%", battery.healthPercent))). Consider service.")
            }
            if battery.cycleCount > 800 {
                notes.append("Battery cycle count is high (\(battery.cycleCount)). Battery may need replacement soon.")
            }
        }

        let enabledAgents = snapshot.startupItems.filter { $0.isEnabled }
        if enabledAgents.count > 20 {
            notes.append("\(enabledAgents.count) startup items are active. Disabling unused ones may improve boot time.")
        }

        if snapshot.hardware.uptimeSeconds > 7 * 86400 {
            notes.append("System has been running for over 7 days. A restart can clear accumulated memory pressure.")
        }

        if notes.isEmpty {
            notes.append("All systems nominal. No immediate concerns detected.")
        }

        return notes
    }

    public func launchctlDisableCommand(for item: StartupItem) -> String {
        switch item.source {
        case .userAgent:
            return "launchctl bootout gui/$(id -u) \(ShellEscaper.quote(item.path))"
        case .globalAgent, .globalDaemon:
            return "sudo launchctl bootout system \(ShellEscaper.quote(item.path))"
        }
    }
}
