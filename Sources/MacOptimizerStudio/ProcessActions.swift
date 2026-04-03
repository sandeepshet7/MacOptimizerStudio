import MacOptimizerStudioCore
import SwiftUI

// MARK: - Process Detail Formatter

/// Determines how process details are displayed in the quit confirmation sheet
/// and audit log. MemoryView shows RSS; CPUView shows CPU%.
enum ProcessDetailStyle {
    case memory
    case cpu

    func sheetDetail(for process: ProcessMemoryEntry, signalName: String) -> String {
        switch self {
        case .memory:
            return "PID: \(process.pid) — RSS: \(ByteFormatting.string(process.rssBytes)) — Signal: \(signalName)"
        case .cpu:
            return "PID: \(process.pid) — CPU: \(String(format: "%.1f%%", process.cpuPercent ?? 0)) — Signal: \(signalName)"
        }
    }

    func auditDetail(for process: ProcessMemoryEntry, signalName: String) -> String {
        switch self {
        case .memory:
            return "\(signalName) sent to \(process.name) (PID \(process.pid), RSS: \(ByteFormatting.string(process.rssBytes)))"
        case .cpu:
            return "\(signalName) sent to \(process.name) (PID \(process.pid), CPU: \(String(format: "%.1f%%", process.cpuPercent ?? 0)))"
        }
    }
}

// MARK: - Process Quit Sheet Modifier

struct ProcessQuitSheetModifier: ViewModifier {
    @Binding var pendingQuitProcess: ProcessMemoryEntry?
    @Binding var pendingForceQuitProcess: ProcessMemoryEntry?
    @Binding var lastQuitResult: String?

    let detailStyle: ProcessDetailStyle
    var onProcessQuit: (() -> Void)?

    private let executor = SafeExecutor()
    private let auditLog = AuditLogService()

    func body(content: Content) -> some View {
        content
            .sheet(item: $pendingQuitProcess) { process in
                quitConfirmSheet(process: process, isForce: false)
            }
            .sheet(item: $pendingForceQuitProcess) { process in
                quitConfirmSheet(process: process, isForce: true)
            }
    }

    private func quitConfirmSheet(process: ProcessMemoryEntry, isForce: Bool) -> some View {
        let signalName = isForce ? "SIGKILL (Force Quit)" : "SIGTERM (Quit)"
        let signal: Int32 = isForce ? 9 : 15

        return DoubleConfirmSheet(
            title: isForce ? "Force Quit Process" : "Quit Process",
            warning: isForce
                ? "FORCE QUIT will terminate the process immediately. Unsaved data WILL be lost."
                : "The process will be asked to exit gracefully. Unsaved data may be lost.",
            confirmLabel: isForce ? "Force Quit Now" : "Quit Now",
            items: [(process.name, detailStyle.sheetDetail(for: process, signalName: signalName))],
            onCancel: {
                pendingQuitProcess = nil
                pendingForceQuitProcess = nil
            },
            onConfirm: {
                let success = executor.sendSignal(signal, toPid: process.pid)
                lastQuitResult = success
                    ? "\(signalName) sent to \(process.name) (PID \(process.pid))"
                    : "Failed to send signal to PID \(process.pid). Permission denied."

                if success {
                    let log = auditLog
                    let entry = AuditLogEntry(
                        action: isForce ? .processForceKilled : .processKilled,
                        details: detailStyle.auditDetail(for: process, signalName: signalName),
                        paths: [],
                        totalBytes: nil,
                        itemCount: 1,
                        userConfirmed: true
                    )
                    Task.detached { log.log(entry) }
                }

                pendingQuitProcess = nil
                pendingForceQuitProcess = nil
                onProcessQuit?()
            }
        )
    }
}

// MARK: - View Extension

extension View {
    func processQuitSheets(
        pendingQuitProcess: Binding<ProcessMemoryEntry?>,
        pendingForceQuitProcess: Binding<ProcessMemoryEntry?>,
        lastQuitResult: Binding<String?>,
        detailStyle: ProcessDetailStyle,
        onProcessQuit: (() -> Void)? = nil
    ) -> some View {
        modifier(ProcessQuitSheetModifier(
            pendingQuitProcess: pendingQuitProcess,
            pendingForceQuitProcess: pendingForceQuitProcess,
            lastQuitResult: lastQuitResult,
            detailStyle: detailStyle,
            onProcessQuit: onProcessQuit
        ))
    }
}
