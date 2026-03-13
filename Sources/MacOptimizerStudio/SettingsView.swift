import MacOptimizerStudioCore
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var systemHealthViewModel: SystemHealthViewModel
    @EnvironmentObject private var auditLogViewModel: AuditLogViewModel

    var body: some View {
        TabView {
            GeneralSettingsTab()
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }

            MemoryMonitorSettingsTab()
                .tabItem {
                    Label("Memory Monitor", systemImage: "waveform.path.ecg")
                }

            NotificationSettingsTab()
                .tabItem {
                    Label("Notifications", systemImage: "bell")
                }

            AppearanceSettingsTab()
                .tabItem {
                    Label("Appearance", systemImage: "paintbrush")
                }

            BugReportSettingsTab(
                systemSnapshot: systemHealthViewModel.snapshot,
                auditEntries: auditLogViewModel.entries
            )
            .tabItem {
                Label("Bug Report", systemImage: "ladybug")
            }

            AboutSettingsTab()
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
        }
        .tabViewStyle(.automatic)
        .frame(width: 500)
    }
}

// MARK: - General

private struct GeneralSettingsTab: View {
    @AppStorage("default_scan_preset") private var defaultScanPreset: String = ScanPreset.balanced.rawValue
    @AppStorage("auto_scan_on_launch") private var autoScanOnLaunch: Bool = false
    @AppStorage("confirm_before_cleanup") private var confirmBeforeCleanup: Bool = true

    var body: some View {
        Form {
            Section("Scanning") {
                Picker("Default scan preset", selection: $defaultScanPreset) {
                    ForEach(ScanPreset.allCases) { preset in
                        Text(preset.rawValue.capitalized).tag(preset.rawValue)
                    }
                }
                Text("Fast: quick shallow scan. Balanced: moderate depth. Deep: full recursive scan for maximum coverage.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Toggle("Auto-scan on launch", isOn: $autoScanOnLaunch)
            }

            Section("Safety") {
                Toggle("Confirm before executing cleanup", isOn: $confirmBeforeCleanup)
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }
}

// MARK: - Memory Monitor

private struct MemoryMonitorSettingsTab: View {
    @AppStorage("memory_poll_interval") private var memoryPollInterval: Int = 3

    private let intervals: [Int] = [1, 3, 5, 10]

    var body: some View {
        Form {
            Section("Polling") {
                Picker("Refresh interval", selection: $memoryPollInterval) {
                    ForEach(intervals, id: \.self) { seconds in
                        Text("\(seconds)s").tag(seconds)
                    }
                }
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }
}

// MARK: - Notifications

private struct NotificationSettingsTab: View {
    @AppStorage("alert_memory_critical") private var alertMemoryCritical = true
    @AppStorage("alert_cpu_high") private var alertCPUHigh = true
    @AppStorage("alert_disk_full") private var alertDiskFull = true

    var body: some View {
        Form {
            Section("System Alerts") {
                Toggle("Memory pressure critical", isOn: $alertMemoryCritical)
                Text("Notify when memory enters critical state with heavy swap usage.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Toggle("CPU usage > 80% sustained", isOn: $alertCPUHigh)
                Text("Notify when a process uses more than 80% CPU.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Toggle("Disk usage > 90%", isOn: $alertDiskFull)
                Text("Notify when disk is nearly full.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Cooldown") {
                Text("Alerts are rate-limited to once every 5 minutes per type to avoid spam.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }
}

// MARK: - Appearance

private struct AppearanceSettingsTab: View {
    @AppStorage("color_scheme_override") private var colorSchemeOverride: String = "system"

    private let options: [(label: String, value: String)] = [
        ("System", "system"),
        ("Light", "light"),
        ("Dark", "dark"),
    ]

    var body: some View {
        Form {
            Section("Theme") {
                Picker("Color scheme", selection: $colorSchemeOverride) {
                    ForEach(options, id: \.value) { option in
                        Text(option.label).tag(option.value)
                    }
                }
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }
}

// MARK: - About

// MARK: - Bug Report

private struct BugReportSettingsTab: View {
    let systemSnapshot: SystemHealthSnapshot?
    let auditEntries: [AuditLogEntry]

    @State private var reportGenerated = false
    @State private var savedPath: String?

    var body: some View {
        Form {
            Section("Report a Problem") {
                Text("Generate a bug report with system info, recent errors, and activity log. No personal files or passwords are included.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack {
                    Button {
                        generateAndSave()
                    } label: {
                        Label("Generate Bug Report", systemImage: "ladybug")
                    }
                    .controlSize(.large)

                    if reportGenerated {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                }

                if let path = savedPath {
                    HStack(spacing: 6) {
                        Image(systemName: "doc.text")
                            .foregroundStyle(.secondary)
                        Text(path)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Spacer()
                        Button("Reveal") {
                            NSWorkspace.shared.selectFile(path, inFileViewerRootedAtPath: "")
                        }
                        .font(.caption)
                    }
                }
            }

            Section("What's Included") {
                VStack(alignment: .leading, spacing: 4) {
                    includedItem("Mac model, macOS version, CPU, RAM")
                    includedItem("Disk usage and battery info")
                    includedItem("Recent errors captured during this session")
                    includedItem("Last 20 Activity Log entries")
                    includedItem("A section for you to describe the issue")
                }
            }

            Section("Recent Errors This Session") {
                let errors = ErrorCollector.shared.recentErrors()
                if errors.isEmpty {
                    Text("No errors recorded")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(Array(errors.prefix(5).enumerated()), id: \.offset) { _, entry in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.source)
                                .font(.caption.weight(.medium))
                            Text(entry.message)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                    }
                    if errors.count > 5 {
                        Text("... and \(errors.count - 5) more")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private func includedItem(_ text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark")
                .font(.caption2)
                .foregroundStyle(.green)
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func generateAndSave() {
        let service = BugReportService()
        let report = service.generateReport(
            systemSnapshot: systemSnapshot,
            recentAuditEntries: auditEntries,
            recentErrors: ErrorCollector.shared.recentErrors()
        )

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText]
        panel.nameFieldStringValue = "MacOptimizerStudio_BugReport_\(dateStamp()).txt"
        panel.canCreateDirectories = true

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            try report.write(to: url, atomically: true, encoding: .utf8)
            savedPath = url.path
            reportGenerated = true
        } catch {
            // Failed to save
        }
    }

    private func dateStamp() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd_HHmm"
        return f.string(from: Date())
    }
}

// MARK: - About

private struct AboutSettingsTab: View {
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    var body: some View {
        Form {
            Section {
                HStack { Text("Application"); Spacer(); Text("MacOptimizer Studio").foregroundColor(.secondary) }
                HStack { Text("Version"); Spacer(); Text("\(appVersion) (\(buildNumber))").foregroundColor(.secondary) }
            }

            Section("Compatibility") {
                HStack { Text("Minimum macOS"); Spacer(); Text("macOS 12 Monterey").foregroundColor(.secondary) }
                HStack { Text("Architectures"); Spacer(); Text("Apple Silicon (M1-M5) & Intel").foregroundColor(.secondary) }
                Text("Runs natively on all Mac processors — Apple Silicon (M1, M2, M3, M4, M5) and Intel x86_64. Universal binary, no Rosetta required on Apple Silicon.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }
}
