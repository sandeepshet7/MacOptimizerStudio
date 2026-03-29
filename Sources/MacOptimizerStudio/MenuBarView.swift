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

    @State private var quickActionMessage: String?
    @State private var pendingAction: QuickAction?

    private enum QuickAction: String, Identifiable {
        case emptyTrash = "Empty Trash"
        case flushDNS = "Flush DNS Cache"
        case purgeRAM = "Purge Inactive RAM"

        var id: String { rawValue }

        var warning: String {
            switch self {
            case .emptyTrash: return "This will permanently delete all items in Trash. This cannot be undone."
            case .flushDNS: return "This will clear the DNS cache. Active connections are not affected."
            case .purgeRAM: return "This will purge inactive memory. Running apps are not affected."
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Image(systemName: "gauge.with.dots.needle.67percent")
                    .foregroundStyle(.orange)
                Text("MacOptimizer Studio")
                    .font(.headline)
            }
            .padding(.bottom, 2)

            Divider()

            // Memory Section
            memorySectionView

            Divider()

            // CPU Section
            cpuSectionView

            Divider()

            // Disk Section
            diskSectionView

            // Docker Section (conditional)
            if let dockerSnap = dockerViewModel.snapshot, dockerSnap.isInstalled {
                Divider()
                dockerSectionView(dockerSnap)
            }

            // Uptime
            if !systemHealthViewModel.uptimeFormatted.isEmpty {
                Divider()
                HStack(spacing: 6) {
                    Image(systemName: "clock")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("Uptime: \(systemHealthViewModel.uptimeFormatted)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            // Quick Actions
            quickActionsView

            // Status message
            if let message = quickActionMessage {
                Text(message)
                    .font(.caption2)
                    .foregroundStyle(.orange)
                    .transition(.opacity)
            }

            Divider()

            // Bottom buttons
            HStack {
                Button {
                    memoryViewModel.refreshNow()
                    Task { await systemHealthViewModel.refresh() }
                    Task { await dockerViewModel.refresh() }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .keyboardShortcut("r")

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
        .frame(width: 320)
        .task {
            if memoryViewModel.snapshot == nil {
                memoryViewModel.refreshNow()
            }
            if systemHealthViewModel.snapshot == nil {
                await systemHealthViewModel.refresh()
            }
            if dockerViewModel.snapshot == nil {
                await dockerViewModel.refresh()
            }
        }
        .alert(
            pendingAction?.rawValue ?? "Confirm",
            isPresented: Binding(get: { pendingAction != nil }, set: { if !$0 { pendingAction = nil } })
        ) {
            Button("Cancel", role: .cancel) { pendingAction = nil }
            Button("Confirm", role: .destructive) {
                if let action = pendingAction {
                    executeQuickAction(action)
                }
                pendingAction = nil
            }
        } message: {
            Text(pendingAction?.warning ?? "")
        }
    }

    // MARK: - Memory Section

    @ViewBuilder
    private var memorySectionView: some View {
        if let snapshot = memoryViewModel.snapshot {
            let pressure = snapshot.systemMemoryPressure
            HStack(spacing: 10) {
                if let stats = snapshot.memoryStats {
                    let usageRatio = Double(stats.usedBytes) / Double(max(stats.totalBytes, 1))
                    MiniGaugeView(
                        value: usageRatio,
                        color: pressureColor(pressure),
                        label: String(format: "%.0f%%", usageRatio * 100)
                    )
                } else {
                    MiniGaugeView(value: 0, color: .secondary, label: "--")
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(pressureColor(pressure))
                            .frame(width: 6, height: 6)
                        Text("Memory")
                            .font(.subheadline.weight(.medium))
                        Text("(\(pressure.rawValue.capitalized))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if let stats = snapshot.memoryStats {
                        Text("\(ByteFormatting.memoryString(stats.usedBytes)) used / \(ByteFormatting.memoryString(stats.totalBytes)) total")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        HStack(spacing: 8) {
                            statLabel("Wired", ByteFormatting.memoryString(stats.wiredBytes))
                            statLabel("Compressed", ByteFormatting.memoryString(stats.compressedBytes))
                        }
                    }

                    if let top = snapshot.processes.first {
                        Text("Top: \(top.name) (\(ByteFormatting.string(top.rssBytes)))")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }
                }

                Spacer()
            }
        } else {
            HStack(spacing: 10) {
                MiniGaugeView(value: 0, color: .secondary, label: "--")
                Text("Memory: No data")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
            }
        }
    }

    // MARK: - CPU Section

    @ViewBuilder
    private var cpuSectionView: some View {
        if let snapshot = memoryViewModel.snapshot {
            let topCPU = snapshot.processes.max { ($0.cpuPercent ?? 0) < ($1.cpuPercent ?? 0) }
            let cpuValue = (topCPU?.cpuPercent ?? 0) / 100.0
            let cpuColor: Color = (topCPU?.cpuPercent ?? 0) > 80 ? .red : ((topCPU?.cpuPercent ?? 0) > 50 ? .orange : .green)

            HStack(spacing: 10) {
                MiniGaugeView(
                    value: cpuValue,
                    color: cpuColor,
                    label: String(format: "%.0f%%", (topCPU?.cpuPercent ?? 0))
                )

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(cpuColor)
                            .frame(width: 6, height: 6)
                        Text("CPU")
                            .font(.subheadline.weight(.medium))
                    }

                    if let top = topCPU {
                        Text("Top: \(top.name)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)

                        if let cpuPct = top.cpuPercent {
                            Text(String(format: "%.1f%% CPU", cpuPct))
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    } else {
                        Text("Idle")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()
            }
        }
    }

    // MARK: - Disk Section

    @ViewBuilder
    private var diskSectionView: some View {
        if let hw = systemHealthViewModel.snapshot {
            let disk = hw.diskUsage
            let diskRatio = disk.usagePercent / 100.0
            let diskColor: Color = disk.usagePercent > 90 ? .red : (disk.usagePercent > 75 ? .orange : .green)

            HStack(spacing: 10) {
                MiniGaugeView(
                    value: diskRatio,
                    color: diskColor,
                    label: String(format: "%.0f%%", disk.usagePercent)
                )

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(diskColor)
                            .frame(width: 6, height: 6)
                        Text("Disk")
                            .font(.subheadline.weight(.medium))
                    }

                    Text("\(ByteFormatting.string(disk.usedBytes)) used / \(ByteFormatting.string(disk.totalBytes)) total")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("\(ByteFormatting.string(disk.freeBytes)) free")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }

                Spacer()
            }
        }
    }

    // MARK: - Docker Section

    @ViewBuilder
    private func dockerSectionView(_ snap: DockerSnapshot) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "shippingbox.fill")
                .font(.title3)
                .foregroundStyle(.blue)
                .frame(width: 40, height: 24)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text("Docker")
                        .font(.subheadline.weight(.medium))
                    if snap.isRunning {
                        Circle()
                            .fill(.green)
                            .frame(width: 6, height: 6)
                    } else {
                        Circle()
                            .fill(.red)
                            .frame(width: 6, height: 6)
                    }
                }

                HStack(spacing: 8) {
                    statLabel("Containers", "\(dockerViewModel.runningContainerCount)/\(dockerViewModel.containerCount)")
                    statLabel("Images", "\(dockerViewModel.imageCount)")
                    if dockerViewModel.totalDiskUsage > 0 {
                        statLabel("Disk", ByteFormatting.string(dockerViewModel.totalDiskUsage))
                    }
                }
            }

            Spacer()
        }
    }

    // MARK: - Quick Actions

    private var quickActionsView: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Quick Actions")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                quickActionButton(title: "Empty Trash", icon: "trash") { pendingAction = .emptyTrash }
                quickActionButton(title: "Flush DNS", icon: "network") { pendingAction = .flushDNS }
                quickActionButton(title: "Purge RAM", icon: "memorychip") { pendingAction = .purgeRAM }
            }
        }
    }

    private func quickActionButton(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: icon)
                    .font(.caption)
                Text(title)
                    .font(.system(size: 9))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
    }

    // MARK: - Quick Action Implementations

    private func executeQuickAction(_ action: QuickAction) {
        switch action {
        case .emptyTrash: emptyTrash()
        case .flushDNS: flushDNS()
        case .purgeRAM: purgeRAM()
        }
    }

    private func emptyTrash() {
        Task.detached {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            process.arguments = ["-e", "tell application \"Finder\" to empty the trash"]
            do {
                try process.run()
                process.waitUntilExit()
            } catch {
                ErrorCollector.shared.record(source: "MenuBarView", message: "Failed to launch empty trash process: \(error.localizedDescription)")
                await MainActor.run {
                    showQuickActionMessage("Failed to empty trash")
                }
                return
            }
            let ok = process.terminationStatus == 0
            await MainActor.run {
                showQuickActionMessage(ok ? "Trash emptied" : "Failed to empty trash")
            }
        }
    }

    private func flushDNS() {
        Task.detached {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/dscacheutil")
            process.arguments = ["-flushcache"]
            do {
                try process.run()
                process.waitUntilExit()
            } catch {
                ErrorCollector.shared.record(source: "MenuBarView", message: "Failed to launch DNS flush process: \(error.localizedDescription)")
                await MainActor.run {
                    showQuickActionMessage("DNS flush failed")
                }
                return
            }
            let ok = process.terminationStatus == 0
            await MainActor.run {
                showQuickActionMessage(ok ? "DNS cache flushed" : "DNS flush failed (needs sudo)")
            }
        }
    }

    private func purgeRAM() {
        Task.detached {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/purge")
            process.arguments = []
            do {
                try process.run()
                process.waitUntilExit()
            } catch {
                ErrorCollector.shared.record(source: "MenuBarView", message: "Failed to launch RAM purge process: \(error.localizedDescription)")
                await MainActor.run {
                    showQuickActionMessage("RAM purge failed")
                }
                return
            }
            let ok = process.terminationStatus == 0
            await MainActor.run {
                showQuickActionMessage(ok ? "RAM purge completed" : "RAM purge failed (needs sudo)")
                if ok { memoryViewModel.refreshNow() }
            }
        }
    }

    private func showQuickActionMessage(_ message: String) {
        withAnimation {
            quickActionMessage = message
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            withAnimation {
                if quickActionMessage == message {
                    quickActionMessage = nil
                }
            }
        }
    }

    // MARK: - Helpers

    private func pressureColor(_ pressure: MemoryPressureLevel) -> Color {
        switch pressure {
        case .normal: return .green
        case .warning: return .orange
        case .critical: return .red
        case .unknown: return .secondary
        }
    }

    private func statLabel(_ title: String, _ value: String) -> some View {
        HStack(spacing: 2) {
            Text("\(title):")
                .foregroundStyle(.tertiary)
            Text(value)
                .foregroundStyle(.secondary)
        }
        .font(.caption2)
    }
}
