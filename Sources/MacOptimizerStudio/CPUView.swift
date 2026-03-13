import MacOptimizerStudioCore
import SwiftUI

struct CPUView: View {
    @EnvironmentObject private var memoryViewModel: MemoryViewModel
    @EnvironmentObject private var systemHealthViewModel: SystemHealthViewModel

    @State private var pendingQuitProcess: ProcessMemoryEntry?
    @State private var pendingForceQuitProcess: ProcessMemoryEntry?
    @State private var lastQuitResult: String?
    @State private var processFilter = ""
    @State private var sortByCPU = true

    @AppStorage("memory_poll_interval") private var memoryPollInterval = 3

    private let executor = SafeExecutor()
    private let auditLog = AuditLogService()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                controls
                cpuSummaryCards
                cpuInsightBanner
                processTable
            }
            .padding(20)
            .frame(maxWidth: 1200)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            memoryViewModel.startPolling(interval: TimeInterval(memoryPollInterval))
        }
        .onDisappear {
            memoryViewModel.stopPolling()
        }
        .sheet(item: $pendingQuitProcess) { process in
            quitConfirmSheet(process: process, isForce: false)
        }
        .sheet(item: $pendingForceQuitProcess) { process in
            quitConfirmSheet(process: process, isForce: true)
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("CPU")
                .font(.largeTitle.weight(.bold))
            Text("Shows which processes are using the most CPU. High CPU usage can cause slowness, fan noise, and battery drain.")
                .font(.body)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Controls

    private var controls: some View {
        HStack(spacing: 10) {
            Button("Refresh") {
                memoryViewModel.refreshNow()
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)

            Button(memoryViewModel.isPaused ? "Resume" : "Pause") {
                memoryViewModel.togglePaused()
            }
            .buttonStyle(.bordered)

            Picker("Sort", selection: $sortByCPU) {
                Text("By CPU").tag(true)
                Text("By Memory").tag(false)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 180)

            if let capturedAt = memoryViewModel.snapshot?.capturedAt {
                Text(capturedAt.formatted(date: .omitted, time: .standard))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            TextField("Filter", text: $processFilter)
                .textFieldStyle(.roundedBorder)
                .frame(width: 160)

            Text("Refresh: \(memoryPollInterval)s")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: - Summary Cards

    private var cpuSummaryCards: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 200), spacing: 12)], spacing: 12) {
            summaryCard(
                title: "Highest CPU",
                value: highestCPUValue,
                detail: highestCPUName,
                tint: (highestCPUEntry?.cpuPercent ?? 0) > 80 ? .red : .purple
            )

            summaryCard(
                title: "Processes > 50%",
                value: "\(highCPUCount)",
                detail: highCPUCount > 0 ? "May slow your Mac" : "All processes normal",
                tint: highCPUCount > 0 ? .orange : .green
            )

            if let hw = systemHealthViewModel.snapshot?.hardware {
                summaryCard(
                    title: "CPU",
                    value: hw.cpuModel,
                    detail: "\(hw.cpuCoreCount) cores",
                    tint: .blue
                )
            }

            summaryCard(
                title: "Uptime",
                value: systemHealthViewModel.uptimeFormatted,
                detail: systemHealthViewModel.snapshot?.hardware.hostname ?? "",
                tint: .secondary
            )
        }
    }

    private func summaryCard(title: String, value: String, detail: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .animation(.easeInOut(duration: 0.4), value: value)
            Text(detail)
                .font(.caption)
                .foregroundStyle(.tertiary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(tint.opacity(0.15), lineWidth: 1)
        )
    }

    // MARK: - Insight Banner

    @ViewBuilder
    private var cpuInsightBanner: some View {
        if let snapshot = memoryViewModel.snapshot {
            let sorted = snapshot.processes.sorted { ($0.cpuPercent ?? 0) > ($1.cpuPercent ?? 0) }
            let topCPU = sorted.first?.cpuPercent ?? 0
            let topName = sorted.first?.name ?? ""
            let criticalCount = sorted.filter { ($0.cpuPercent ?? 0) > 80 }.count
            let highCount = sorted.filter { ($0.cpuPercent ?? 0) > 50 }.count

            if criticalCount > 0 {
                insightCard(
                    icon: "exclamationmark.triangle.fill",
                    color: .red,
                    title: "\(criticalCount) process\(criticalCount == 1 ? "" : "es") using excessive CPU",
                    message: "\"\(topName)\" is at \(String(format: "%.0f%%", topCPU)) CPU. This can cause your Mac to feel slow, fans to spin up, and battery to drain faster. Consider quitting it if not needed.",
                    tip: topName.lowercased().contains("macoptimizer") ? "MacOptimizer Studio uses CPU briefly during scans and refreshes — this is normal and temporary." : "Tip: Use Quit or Force Quit below to stop runaway processes."
                )
            } else if highCount > 0 {
                insightCard(
                    icon: "info.circle.fill",
                    color: .orange,
                    title: "\(highCount) process\(highCount == 1 ? "" : "es") using moderate CPU",
                    message: "\"\(topName)\" is the top consumer at \(String(format: "%.0f%%", topCPU)). This is normal during active work like compiling, rendering, or updates.",
                    tip: "If your Mac feels sluggish, these processes may be the cause."
                )
            } else {
                insightCard(
                    icon: "checkmark.circle.fill",
                    color: .green,
                    title: "CPU usage is normal",
                    message: "No processes are consuming excessive CPU. Your Mac should be running smoothly.",
                    tip: "Processes are sorted by highest CPU usage. The list updates every \(memoryPollInterval) seconds."
                )
            }
        }
    }

    private func insightCard(icon: String, color: Color, title: String, message: String, tip: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
                .frame(width: 24, alignment: .top)

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(tip)
                    .font(.caption2.italic())
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(color.opacity(0.15), lineWidth: 1))
    }

    // MARK: - Process Table

    private var processTable: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Processes")
                .font(.headline)

            if let snapshot = memoryViewModel.snapshot {
                let sorted = sortedProcesses(snapshot.processes)
                let filtered = filteredProcesses(sorted)

                if filtered.isEmpty {
                    Text("No processes match filter.")
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 20)
                } else {
                    VStack(spacing: 0) {
                        processHeader
                        Divider()
                        ForEach(filtered) { entry in
                            processRow(entry)
                            Divider()
                        }
                    }
                    .background(.thinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
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
                Text("Collecting process data...")
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 20)
            }
        }
    }

    private var processHeader: some View {
        HStack(spacing: 0) {
            Text("Process")
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("PID")
                .frame(width: 60, alignment: .trailing)
            Text("CPU %")
                .frame(width: 80, alignment: .trailing)
            Text("Memory")
                .frame(width: 90, alignment: .trailing)
            Text("Actions")
                .frame(width: 130, alignment: .center)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.primary.opacity(0.03))
    }

    private func processRow(_ entry: ProcessMemoryEntry) -> some View {
        let cpuHigh = (entry.cpuPercent ?? 0) > 50
        let cpuCritical = (entry.cpuPercent ?? 0) > 80

        return HStack(spacing: 0) {
            HStack(spacing: 6) {
                if cpuCritical {
                    Circle().fill(.red).frame(width: 6, height: 6)
                } else if cpuHigh {
                    Circle().fill(.orange).frame(width: 6, height: 6)
                }
                Text(entry.name)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text("\(entry.pid)")
                .frame(width: 60, alignment: .trailing)
                .foregroundStyle(.secondary)

            Group {
                if let cpu = entry.cpuPercent {
                    Text(String(format: "%.1f%%", cpu))
                        .font(.subheadline.weight(cpuHigh ? .semibold : .regular))
                        .foregroundColor(cpuCritical ? .red : (cpuHigh ? .orange : .primary))
                } else {
                    Text("-").foregroundStyle(.secondary)
                }
            }
            .frame(width: 80, alignment: .trailing)

            Text(ByteFormatting.string(entry.rssBytes))
                .frame(width: 90, alignment: .trailing)
                .foregroundStyle(.secondary)

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
            .frame(width: 130, alignment: .center)
        }
        .font(.subheadline)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    // MARK: - Quit Sheet

    private func quitConfirmSheet(process: ProcessMemoryEntry, isForce: Bool) -> some View {
        let signalName = isForce ? "SIGKILL (Force Quit)" : "SIGTERM (Quit)"
        let signal: Int32 = isForce ? 9 : 15

        return DoubleConfirmSheet(
            title: isForce ? "Force Quit Process" : "Quit Process",
            warning: isForce
                ? "FORCE QUIT will terminate immediately. Unsaved data WILL be lost."
                : "The process will be asked to exit gracefully. Unsaved data may be lost.",
            confirmLabel: isForce ? "Force Quit Now" : "Quit Now",
            items: [(process.name, "PID: \(process.pid) — CPU: \(String(format: "%.1f%%", process.cpuPercent ?? 0)) — Signal: \(signalName)")],
            onCancel: {
                pendingQuitProcess = nil
                pendingForceQuitProcess = nil
            },
            onConfirm: {
                let success = executor.sendSignal(signal, toPid: process.pid)
                lastQuitResult = success
                    ? "\(signalName) sent to \(process.name) (PID \(process.pid))"
                    : "Failed to send signal. Permission denied."

                if success {
                    let log = auditLog
                    let entry = AuditLogEntry(
                        action: isForce ? .processForceKilled : .processKilled,
                        details: "\(signalName) sent to \(process.name) (PID \(process.pid), CPU: \(String(format: "%.1f%%", process.cpuPercent ?? 0)))",
                        paths: [],
                        totalBytes: nil,
                        itemCount: 1,
                        userConfirmed: true
                    )
                    Task.detached { log.log(entry) }
                }

                pendingQuitProcess = nil
                pendingForceQuitProcess = nil
                memoryViewModel.refreshNow()
            }
        )
    }

    // MARK: - Helpers

    private func sortedProcesses(_ processes: [ProcessMemoryEntry]) -> [ProcessMemoryEntry] {
        if sortByCPU {
            return processes.sorted { ($0.cpuPercent ?? 0) > ($1.cpuPercent ?? 0) }
        } else {
            return processes.sorted { $0.rssBytes > $1.rssBytes }
        }
    }

    private func filteredProcesses(_ processes: [ProcessMemoryEntry]) -> [ProcessMemoryEntry] {
        if processFilter.isEmpty { return processes }
        let needle = processFilter.lowercased()
        return processes.filter { $0.name.lowercased().contains(needle) }
    }

    private var highestCPUEntry: ProcessMemoryEntry? {
        memoryViewModel.snapshot?.processes.max { ($0.cpuPercent ?? -1) < ($1.cpuPercent ?? -1) }
    }

    private var highestCPUValue: String {
        guard let cpu = highestCPUEntry?.cpuPercent else { return "-" }
        return String(format: "%.1f%%", cpu)
    }

    private var highestCPUName: String {
        highestCPUEntry?.name ?? "No data"
    }

    private var highCPUCount: Int {
        memoryViewModel.snapshot?.processes.filter { ($0.cpuPercent ?? 0) > 50 }.count ?? 0
    }
}
