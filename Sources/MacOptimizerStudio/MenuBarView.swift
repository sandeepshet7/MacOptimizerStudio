import MacOptimizerStudioCore
import SwiftUI

// MARK: - MiniGaugeView

struct MiniGaugeView: View {
    let value: Double
    let color: Color
    let label: String

    private let lineWidth: CGFloat = 4

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.2), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: CGFloat(min(max(value, 0), 1)))
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text(label)
                .font(.system(size: 9, weight: .semibold, design: .rounded))
                .foregroundStyle(color)
        }
        .frame(width: 40, height: 40)
    }
}

// MARK: - MenuBarView

struct MenuBarView: View {
    @EnvironmentObject private var memoryViewModel: MemoryViewModel
    @EnvironmentObject private var systemHealthViewModel: SystemHealthViewModel
    @EnvironmentObject private var dockerViewModel: DockerViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header
            HStack {
                Image(systemName: "gearshape.2.fill")
                    .foregroundStyle(.orange)
                Text("MacOptimizer Studio")
                    .font(.headline)
            }
            .padding(.bottom, 2)

            Divider()

            // Compact gauges row
            HStack(spacing: 16) {
                gaugeItem(
                    value: memoryUsageRatio,
                    color: memoryColor,
                    title: "Memory",
                    detail: memoryDetail
                )

                gaugeItem(
                    value: diskUsageRatio,
                    color: diskColor,
                    title: "Disk",
                    detail: diskDetail
                )

                if let cpuPct = topCPUPercent {
                    gaugeItem(
                        value: cpuPct / 100.0,
                        color: cpuPct > 80 ? .red : (cpuPct > 50 ? .orange : .green),
                        title: "CPU",
                        detail: topCPUName
                    )
                }
            }
            .padding(.vertical, 2)

            Divider()

            // Quick action
            Button { emptyTrash() } label: {
                Label("Empty Trash", systemImage: "trash")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Divider()

            // Bottom
            HStack {
                Button {
                    memoryViewModel.refreshNow()
                    Task { await systemHealthViewModel.refresh() }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .keyboardShortcut("r")

                Spacer()

                if !systemHealthViewModel.uptimeFormatted.isEmpty {
                    Text("Uptime: \(systemHealthViewModel.uptimeFormatted)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }

                Spacer()

                Button {
                    NSApplication.shared.terminate(nil)
                } label: {
                    Label("Quit", systemImage: "power")
                }
                .keyboardShortcut("q")
            }
            .font(.subheadline)
        }
        .padding(12)
        .frame(width: 300)
        .task {
            if memoryViewModel.snapshot == nil {
                memoryViewModel.startPolling(interval: 10)
            }
            if systemHealthViewModel.snapshot == nil {
                await systemHealthViewModel.refresh()
            }
        }
    }

    // MARK: - Gauge Item

    private func gaugeItem(value: Double, color: Color, title: String, detail: String) -> some View {
        VStack(spacing: 4) {
            MiniGaugeView(
                value: value,
                color: color,
                label: String(format: "%.0f%%", value * 100)
            )
            Text(title)
                .font(.caption2.weight(.medium))
            Text(detail)
                .font(.system(size: 8))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Computed Properties

    private var memoryUsageRatio: Double {
        guard let stats = memoryViewModel.snapshot?.memoryStats else { return 0 }
        return Double(stats.usedBytes) / Double(max(stats.totalBytes, 1))
    }

    private var memoryColor: Color {
        guard let pressure = memoryViewModel.snapshot?.systemMemoryPressure else { return .secondary }
        switch pressure {
        case .normal: return .green
        case .warning: return .orange
        case .critical: return .red
        case .unknown: return .secondary
        }
    }

    private var memoryDetail: String {
        guard let stats = memoryViewModel.snapshot?.memoryStats else { return "No data" }
        return "\(ByteFormatting.memoryString(stats.freeBytes)) free"
    }

    private var diskUsageRatio: Double {
        guard let hw = systemHealthViewModel.snapshot else { return 0 }
        return hw.diskUsage.usagePercent / 100.0
    }

    private var diskColor: Color {
        guard let hw = systemHealthViewModel.snapshot else { return .secondary }
        if hw.diskUsage.usagePercent > 90 { return .red }
        if hw.diskUsage.usagePercent > 75 { return .orange }
        return .green
    }

    private var diskDetail: String {
        guard let hw = systemHealthViewModel.snapshot else { return "No data" }
        return "\(ByteFormatting.string(hw.diskUsage.freeBytes)) free"
    }

    private var topCPUPercent: Double? {
        memoryViewModel.snapshot?.processes.compactMap(\.cpuPercent).max()
    }

    private var topCPUName: String {
        guard let snapshot = memoryViewModel.snapshot,
              let top = snapshot.processes.max(by: { ($0.cpuPercent ?? 0) < ($1.cpuPercent ?? 0) })
        else { return "Idle" }
        return top.name
    }

    // MARK: - Actions

    private func emptyTrash() {
        Task.detached {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            process.arguments = ["-e", "tell application \"Finder\" to empty the trash"]
            try? process.run()
            process.waitUntilExit()
        }
    }

}
