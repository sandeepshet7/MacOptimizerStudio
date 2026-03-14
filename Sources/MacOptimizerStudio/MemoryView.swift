import MacOptimizerStudioCore
import SwiftUI

struct MemoryView: View {
    @EnvironmentObject private var viewModel: MemoryViewModel

    @EnvironmentObject private var toastManager: ToastManager

    @State private var pendingQuitProcess: ProcessMemoryEntry?
    @State private var pendingForceQuitProcess: ProcessMemoryEntry?
    @State private var lastQuitResult: String?
    @State private var processFilter = ""
    @State private var isPurging = false
    @State private var pendingPurge = false

    private let executor = SafeExecutor()
    private let auditLog = AuditLogService()

    @AppStorage("memory_poll_interval") private var memoryPollInterval = 3

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                controls
                summaryRow
                pressureCard
                processTable
            }
            .padding(20)
            .frame(maxWidth: 1180)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .onAppear {
            viewModel.startPolling(interval: TimeInterval(memoryPollInterval))
        }
        .onDisappear {
            viewModel.stopPolling()
        }
        .onChange(of: memoryPollInterval) { _ in
            viewModel.stopPolling()
            viewModel.startPolling(interval: TimeInterval(memoryPollInterval))
        }
        .onChange(of: viewModel.topCount) { _ in
            viewModel.refreshNow()
        }
        .sheet(item: $pendingQuitProcess) { process in
            quitConfirmSheet(process: process, isForce: false)
        }
        .sheet(item: $pendingForceQuitProcess) { process in
            quitConfirmSheet(process: process, isForce: true)
        }
        .sheet(isPresented: $pendingPurge) {
            DoubleConfirmSheet(
                title: "Purge Inactive Memory",
                warning: """
                This will run the macOS `purge` command to flush inactive memory.

                - Frees memory held by inactive caches
                - May briefly slow the system as caches rebuild
                - Safe to run — no data loss
                - Requires admin privileges (you may be prompted for your password)

                The system will naturally recache frequently used data afterward.
                """,
                confirmLabel: "Purge Now",
                onCancel: { pendingPurge = false },
                onConfirm: {
                    pendingPurge = false
                    isPurging = true
                    let exec = SafeExecutor()
                    let result = exec.execute(commands: ["purge"]) { _, _ in }
                    isPurging = false
                    if result.success {
                        toastManager.show("Memory purge completed")
                    } else {
                        toastManager.show("Purge failed — may need admin privileges", isError: true)
                    }
                    viewModel.refreshNow()
                }
            )
        }
    }

    // MARK: - Controls

    private var controls: some View {
        StyledCard {
            HStack(spacing: 10) {
                Button("Refresh") {
                    viewModel.refreshNow()
                }
                .buttonStyle(.borderedProminent)

                Button(viewModel.isPaused ? "Resume" : "Pause") {
                    viewModel.togglePaused()
                }
                .buttonStyle(.bordered)

                Button {
                    pendingPurge = true
                } label: {
                    HStack(spacing: 4) {
                        if isPurging {
                            ProgressView().controlSize(.mini)
                        }
                        Text("Purge RAM")
                    }
                }
                .buttonStyle(.bordered)
                .tint(.purple)
                .disabled(isPurging)

                Picker("Top", selection: $viewModel.topCount) {
                    Text("Top 5").tag(5)
                    Text("Top 10").tag(10)
                    Text("Top 20").tag(20)
                }
                .pickerStyle(.segmented)
                .frame(width: 220)

                if let capturedAt = viewModel.snapshot?.capturedAt {
                    Text("Captured: \(capturedAt.formatted(date: .omitted, time: .standard))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                TextField("Filter processes", text: $processFilter)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 180)

                Text("Auto-refresh: \(memoryPollInterval)s")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Summary

    private var summaryRow: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 12)], spacing: 12) {
            StatCard(icon: "gauge.medium", title: "Pressure", value: pressureLabel, tint: pressureTint)
            StatCard(icon: "list.bullet", title: "Tracked Processes", value: "\(viewModel.snapshot?.processes.count ?? 0)", tint: .blue)
            StatCard(icon: "memorychip", title: "Highest RSS", value: highestRSSValue, tint: .orange)
            StatCard(icon: "cpu", title: "Highest CPU", value: highestCPUValue, tint: .purple)
        }
    }

    // MARK: - Pressure Gauge

    private var pressureCard: some View {
        let pressure = viewModel.snapshot?.systemMemoryPressure ?? .unknown
        let stats = viewModel.snapshot?.memoryStats

        return StyledCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    CardSectionHeader(icon: "gauge.with.dots.needle.33percent", title: "System Memory Pressure", color: color(for: pressure))
                    Spacer()
                    Text(pressure.rawValue.capitalized)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(color(for: pressure))
                }

                Divider()

                // Gauge bars
                HStack(spacing: 4) {
                    gaugeBar(active: pressure == .normal || pressure == .warning || pressure == .critical, color: .green)
                    gaugeBar(active: pressure == .warning || pressure == .critical, color: .orange)
                    gaugeBar(active: pressure == .critical, color: .red)
                }

                // Labels under each bar
                HStack(spacing: 4) {
                    gaugeLabelCell(label: "Normal", color: .green, isCurrent: pressure == .normal)
                    gaugeLabelCell(label: "Warning", color: .orange, isCurrent: pressure == .warning)
                    gaugeLabelCell(label: "Critical", color: .red, isCurrent: pressure == .critical)
                }

                // Current level description
                HStack(spacing: 6) {
                    Circle()
                        .fill(color(for: pressure))
                        .frame(width: 8, height: 8)
                    Text(pressureDescription(pressure))
                        .font(.caption)
                        .foregroundStyle(color(for: pressure))
                }
                .padding(.horizontal, 4)

                if let stats {
                    Divider()

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 8)], spacing: 8) {
                        memStat(label: "Used", value: ByteFormatting.memoryString(stats.usedBytes), tint: stats.usedBytes > stats.totalBytes * 85 / 100 ? .red : .primary)
                        memStat(label: "App Memory", value: ByteFormatting.memoryString(stats.appBytes), tint: .primary)
                        memStat(label: "Wired", value: ByteFormatting.memoryString(stats.wiredBytes), tint: .primary)
                        memStat(label: "Compressed", value: ByteFormatting.memoryString(stats.compressedBytes), tint: stats.compressedBytes > 2 * 1024 * 1024 * 1024 ? .orange : .primary)
                        memStat(label: "Free", value: ByteFormatting.memoryString(stats.freeBytes), tint: .green)
                        memStat(label: "Swap Used", value: ByteFormatting.memoryString(stats.swapUsedBytes), tint: stats.swapUsedBytes > 0 ? .orange : .primary)
                    }
                }

                Text("Pressure reflects compression + swap demand across all processes, not just top RSS.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func memStat(label: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(tint)
                .animation(.easeInOut(duration: 0.4), value: value)
        }
    }

    private func gaugeBar(active: Bool, color: Color) -> some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(active ? color : color.opacity(0.15))
            .frame(height: 12)
    }

    private func gaugeLabelCell(label: String, color: Color, isCurrent: Bool) -> some View {
        HStack(spacing: 3) {
            if isCurrent {
                Image(systemName: "arrowtriangle.up.fill")
                    .font(.system(size: 6))
                    .foregroundStyle(color)
            }
            Text(label)
                .font(.caption.weight(isCurrent ? .bold : .regular))
                .foregroundStyle(isCurrent ? color : .secondary.opacity(0.4))
        }
        .frame(maxWidth: .infinity)
    }

    private func pressureDescription(_ pressure: MemoryPressureLevel) -> String {
        switch pressure {
        case .normal: return "Plenty of free memory — system is healthy"
        case .warning: return "System is compressing memory — consider closing apps"
        case .critical: return "Heavy swap usage — apps may slow down significantly"
        case .unknown: return "Unable to determine memory pressure"
        }
    }

    // MARK: - Process Table

    @State private var expandedGroups: Set<String> = []

    private var processTable: some View {
        StyledCard {
            VStack(alignment: .leading, spacing: 14) {
                CardSectionHeader(icon: "list.bullet.rectangle", title: "Top Processes by RSS", color: .blue)

                Divider()

                if let snapshot = viewModel.snapshot {
                    let filtered = filteredProcesses(snapshot.processes)
                    let groups = groupProcesses(filtered)

                    if groups.isEmpty {
                        Text("No processes match filter.")
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 24)
                    } else {
                        VStack(spacing: 0) {
                            processHeader
                            Divider()
                            ForEach(groups, id: \.name) { group in
                                if group.processes.count == 1 {
                                    processRow(group.processes[0])
                                    Divider()
                                } else {
                                    groupRow(group)
                                    Divider()
                                    if expandedGroups.contains(group.name) {
                                        ForEach(group.processes) { entry in
                                            processRow(entry, indented: true)
                                            Divider()
                                        }
                                    }
                                }
                            }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }

                    if let result = lastQuitResult {
                        HStack(spacing: 6) {
                            Image(systemName: "info.circle.fill")
                                .foregroundStyle(.blue)
                            Text(result)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(8)
                    }
                } else {
                    VStack(spacing: 0) {
                        SkeletonRow()
                        Divider()
                        SkeletonRow()
                        Divider()
                        SkeletonRow()
                        Divider()
                        SkeletonRow()
                        Divider()
                        SkeletonRow()
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
    }

    private var processHeader: some View {
        HStack(spacing: 0) {
            Text("Process")
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("PID")
                .frame(width: 60, alignment: .trailing)
            Text("Trend")
                .frame(width: 70, alignment: .center)
            Text("CPU")
                .frame(width: 70, alignment: .trailing)
            Text("RSS")
                .frame(width: 90, alignment: .trailing)
            Text("Actions")
                .frame(width: 140, alignment: .center)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.primary.opacity(0.03))
    }

    private func groupRow(_ group: ProcessGroup) -> some View {
        let isExpanded = expandedGroups.contains(group.name)

        return Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                if expandedGroups.contains(group.name) {
                    expandedGroups.remove(group.name)
                } else {
                    expandedGroups.insert(group.name)
                }
            }
        } label: {
            HStack(spacing: 0) {
                HStack(spacing: 6) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 10)
                    Text(group.name)
                        .font(.body.weight(.semibold))
                        .lineLimit(1)
                    Text("(\(group.processes.count))")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Text("")
                    .frame(width: 60)

                Text("")
                    .frame(width: 70)

                Text(String(format: "%.1f%%", group.totalCPU))
                    .foregroundStyle(group.totalCPU > 100 ? .orange : .primary)
                    .frame(width: 70, alignment: .trailing)

                Text(ByteFormatting.string(group.totalRSS))
                    .frame(width: 90, alignment: .trailing)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(group.totalRSS > 2 * 1024 * 1024 * 1024 ? .red : .primary)

                Text("")
                    .frame(width: 140)
            }
            .font(.subheadline)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.primary.opacity(0.02))
        }
        .buttonStyle(.plain)
    }

    private func processRow(_ entry: ProcessMemoryEntry, indented: Bool = false) -> some View {
        let isHigh = entry.rssBytes > 1024 * 1024 * 1024
        let cpuHigh = (entry.cpuPercent ?? 0) > 50
        let growing = viewModel.isGrowing(pid: entry.pid)

        return HStack(spacing: 0) {
            HStack(spacing: 4) {
                if indented {
                    Text("")
                        .frame(width: 16)
                }
                Text(entry.name)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .foregroundStyle(isHigh ? .red : .primary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text("\(entry.pid)")
                .frame(width: 60, alignment: .trailing)
                .foregroundStyle(.secondary)

            HStack(spacing: 2) {
                Text(trendSymbol(for: entry))
                    .foregroundStyle(trendColor(for: entry))
                if growing {
                    Text("Growing")
                        .font(.system(.caption2, design: .rounded).weight(.bold))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Color.orange.opacity(0.15))
                        .foregroundStyle(.orange)
                        .clipShape(Capsule())
                }
            }
            .frame(width: 70, alignment: .center)

            Group {
                if let cpu = entry.cpuPercent {
                    Text(String(format: "%.1f%%", cpu))
                        .foregroundStyle(cpuHigh ? .orange : .primary)
                } else {
                    Text("-").foregroundStyle(.secondary)
                }
            }
            .frame(width: 70, alignment: .trailing)

            Text(ByteFormatting.string(entry.rssBytes))
                .frame(width: 90, alignment: .trailing)
                .font(.subheadline.weight(isHigh ? .semibold : .regular))
                .foregroundStyle(isHigh ? .red : .primary)

            HStack(spacing: 4) {
                Button("Quit") {
                    pendingQuitProcess = entry
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)

                Button("Force") {
                    pendingForceQuitProcess = entry
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)
                .tint(.red)
            }
            .frame(width: 140, alignment: .center)
        }
        .font(.subheadline)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    // MARK: - Quit Confirmation Sheet

    private func quitConfirmSheet(process: ProcessMemoryEntry, isForce: Bool) -> some View {
        let signalName = isForce ? "SIGKILL (Force Quit)" : "SIGTERM (Quit)"
        let signal: Int32 = isForce ? 9 : 15

        return DoubleConfirmSheet(
            title: isForce ? "Force Quit Process" : "Quit Process",
            warning: isForce
                ? "FORCE QUIT will terminate the process immediately. Unsaved data WILL be lost."
                : "The process will be asked to exit gracefully. Unsaved data may be lost.",
            confirmLabel: isForce ? "Force Quit Now" : "Quit Now",
            items: [(process.name, "PID: \(process.pid) — RSS: \(ByteFormatting.string(process.rssBytes)) — Signal: \(signalName)")],
            onCancel: {
                pendingQuitProcess = nil
                pendingForceQuitProcess = nil
            },
            onConfirm: {
                let success = executor.sendSignal(signal, toPid: process.pid)
                let result = success
                    ? "\(signalName) sent to \(process.name) (PID \(process.pid))"
                    : "Failed to send signal to PID \(process.pid). Permission denied."

                if success {
                    let log = auditLog
                    let entry = AuditLogEntry(
                        action: isForce ? .processForceKilled : .processKilled,
                        details: "\(signalName) sent to \(process.name) (PID \(process.pid), RSS: \(ByteFormatting.string(process.rssBytes)))",
                        paths: [],
                        totalBytes: nil,
                        itemCount: 1,
                        userConfirmed: true
                    )
                    Task.detached { log.log(entry) }
                }

                pendingQuitProcess = nil
                pendingForceQuitProcess = nil
                lastQuitResult = result
                viewModel.refreshNow()
            }
        )
    }

    // MARK: - Process Grouping

    private struct ProcessGroup {
        let name: String
        let processes: [ProcessMemoryEntry]
        var totalRSS: UInt64 { processes.reduce(0) { $0 + $1.rssBytes } }
        var totalCPU: Double { processes.reduce(0.0) { $0 + ($1.cpuPercent ?? 0) } }
    }

    private func appGroupName(for processName: String) -> String {
        let suffixes = [" Helper (Renderer)", " Helper (GPU)", " Helper (Plugin)", " Helper", " Networking", " Web Content"]
        var name = processName
        for suffix in suffixes {
            if name.hasSuffix(suffix) {
                name = String(name.dropLast(suffix.count))
                break
            }
        }
        return name
    }

    private func groupProcesses(_ processes: [ProcessMemoryEntry]) -> [ProcessGroup] {
        let grouped = Dictionary(grouping: processes) { appGroupName(for: $0.name) }
        return grouped.map { ProcessGroup(name: $0.key, processes: $0.value.sorted { $0.rssBytes > $1.rssBytes }) }
            .sorted { $0.totalRSS > $1.totalRSS }
    }

    // MARK: - Helpers

    private func filteredProcesses(_ processes: [ProcessMemoryEntry]) -> [ProcessMemoryEntry] {
        if processFilter.isEmpty { return processes }
        let needle = processFilter.lowercased()
        return processes.filter { $0.name.lowercased().contains(needle) }
    }

    private func trendSymbol(for entry: ProcessMemoryEntry) -> String {
        guard let old = previousRSS(for: entry.pid) else { return "-" }
        if entry.rssBytes > old { return "▲" }
        if entry.rssBytes < old { return "▼" }
        return "→"
    }

    private func trendColor(for entry: ProcessMemoryEntry) -> Color {
        guard let old = previousRSS(for: entry.pid) else { return .secondary }
        if entry.rssBytes > old { return .orange }
        if entry.rssBytes < old { return .green }
        return .secondary
    }

    private func previousRSS(for pid: Int32) -> UInt64? {
        viewModel.previousSnapshot?.processes.first(where: { $0.pid == pid })?.rssBytes
    }

    private var pressureLabel: String {
        viewModel.snapshot?.systemMemoryPressure.rawValue.capitalized ?? "Unknown"
    }

    private var pressureTint: Color {
        color(for: viewModel.snapshot?.systemMemoryPressure ?? .unknown)
    }

    private var highestRSSValue: String {
        guard let top = viewModel.snapshot?.processes.first else { return "-" }
        return ByteFormatting.string(top.rssBytes)
    }

    private var highestRSSName: String {
        viewModel.snapshot?.processes.first?.name ?? "No snapshot"
    }

    private var highestCPUEntry: ProcessMemoryEntry? {
        viewModel.snapshot?.processes.max { lhs, rhs in
            (lhs.cpuPercent ?? -1) < (rhs.cpuPercent ?? -1)
        }
    }

    private var highestCPUValue: String {
        guard let cpu = highestCPUEntry?.cpuPercent else { return "-" }
        return String(format: "%.1f%%", cpu)
    }

    private var highestCPUName: String {
        highestCPUEntry?.name ?? "No CPU data"
    }

    private func color(for pressure: MemoryPressureLevel) -> Color {
        switch pressure {
        case .normal: return .green
        case .warning: return .orange
        case .critical: return .red
        case .unknown: return .secondary
        }
    }
}
