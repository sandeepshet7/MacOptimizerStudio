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
        .frame(width: 520, height: 520)
        .background(DesignTokens.pageBackground)
    }
}

// MARK: - General

private struct GeneralSettingsTab: View {
    @AppStorage(StorageKeys.defaultScanPreset) private var defaultScanPreset: String = ScanPreset.balanced.rawValue
    @AppStorage(StorageKeys.autoScanOnLaunch) private var autoScanOnLaunch: Bool = false
    @AppStorage(StorageKeys.confirmBeforeCleanup) private var confirmBeforeCleanup: Bool = true
    @AppStorage(StorageKeys.memoryPollInterval) private var memoryPollInterval: Int = 10
    @AppStorage(StorageKeys.alertMemoryCritical) private var alertMemoryCritical = true
    @AppStorage(StorageKeys.alertCPUHigh) private var alertCPUHigh = true
    @AppStorage(StorageKeys.alertDiskFull) private var alertDiskFull = true
    @AppStorage(StorageKeys.batteryRefreshInterval) private var batteryRefreshInterval: Int = 0

    private let pollIntervals: [Int] = [5, 10, 15, 30]
    private let batteryIntervals: [(label: String, value: Int)] = [
        ("Off", 0), ("10s", 10), ("30s", 30), ("60s", 60),
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Scanning & Safety
                StyledCard {
                    VStack(alignment: .leading, spacing: 14) {
                        CardSectionHeader(icon: "magnifyingglass", title: "Scanning", color: .blue)

                        Divider()

                        HStack {
                            Text("Default preset")
                                .font(.body)
                            Spacer()
                            Picker("", selection: $defaultScanPreset) {
                                ForEach(ScanPreset.allCases) { preset in
                                    Text(preset.rawValue.capitalized).tag(preset.rawValue)
                                }
                            }
                            .labelsHidden()
                            .frame(width: 130)
                        }

                        Text("Fast: shallow scan. Balanced: moderate depth. Deep: full recursive scan.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)

                        Toggle("Auto-scan on launch", isOn: $autoScanOnLaunch)
                            .font(.body)

                        Divider()

                        Toggle("Confirm before cleanup", isOn: $confirmBeforeCleanup)
                            .font(.body)
                    }
                }

                // Monitor & Alerts
                StyledCard {
                    VStack(alignment: .leading, spacing: 14) {
                        CardSectionHeader(icon: "waveform.path.ecg", title: "Monitor & Alerts", color: .orange)

                        Divider()

                        HStack {
                            Text("Memory refresh interval")
                                .font(.body)
                            Spacer()
                            Picker("", selection: $memoryPollInterval) {
                                ForEach(pollIntervals, id: \.self) { seconds in
                                    Text("\(seconds)s").tag(seconds)
                                }
                            }
                            .labelsHidden()
                            .frame(width: 80)
                        }

                        HStack {
                            Text("Battery refresh interval")
                                .font(.body)
                            Spacer()
                            Picker("", selection: $batteryRefreshInterval) {
                                ForEach(batteryIntervals, id: \.value) { option in
                                    Text(option.label).tag(option.value)
                                }
                            }
                            .labelsHidden()
                            .frame(width: 80)
                        }

                        Divider()

                        VStack(alignment: .leading, spacing: 8) {
                            Toggle("Memory pressure critical", isOn: $alertMemoryCritical)
                                .font(.body)
                            Toggle("CPU usage > 80% sustained", isOn: $alertCPUHigh)
                                .font(.body)
                            Toggle("Disk usage > 90%", isOn: $alertDiskFull)
                                .font(.body)
                        }

                        Text("Alerts are rate-limited to once every 5 minutes per type.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

            }
            .padding(20)
        }
    }
}

// MARK: - Bug Report

private struct BugReportSettingsTab: View {
    let systemSnapshot: SystemHealthSnapshot?
    let auditEntries: [AuditLogEntry]

    @State private var reportGenerated = false
    @State private var savedPath: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Report Action
                StyledCard {
                    VStack(alignment: .leading, spacing: 14) {
                        CardSectionHeader(icon: "ladybug", title: "Report a Problem", color: .red)

                        Divider()

                        Text("Generate a bug report with system info, recent errors, and activity log. No personal files or passwords are included.")
                            .font(.body)
                            .foregroundColor(.secondary)

                        HStack {
                            Button {
                                generateAndSave()
                            } label: {
                                Label("Generate Bug Report", systemImage: "doc.text.magnifyingglass")
                                    .font(.body.weight(.medium))
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.orange)

                            if reportGenerated {
                                HStack(spacing: 4) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                    Text("Saved")
                                        .font(.caption)
                                        .foregroundColor(.green)
                                }
                            }
                        }

                        if let path = savedPath {
                            HStack(spacing: 8) {
                                Image(systemName: "doc.text")
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                                Text(path)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                Spacer()
                                Button {
                                    NSWorkspace.shared.selectFile(path, inFileViewerRootedAtPath: "")
                                } label: {
                                    Text("Reveal in Finder")
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(10)
                            .background(DesignTokens.pageBackground)
                            .cornerRadius(6)
                        }
                    }
                }

                // What's Included
                StyledCard {
                    VStack(alignment: .leading, spacing: 14) {
                        CardSectionHeader(icon: "checklist", title: "What's Included", color: .green)

                        Divider()

                        VStack(alignment: .leading, spacing: 8) {
                            includedItem("Mac model, macOS version, CPU, RAM")
                            includedItem("Disk usage and battery info")
                            includedItem("Recent errors captured during this session")
                            includedItem("Last 20 Activity Log entries")
                            includedItem("A section for you to describe the issue")
                        }
                    }
                }

                // Recent Errors
                StyledCard {
                    VStack(alignment: .leading, spacing: 14) {
                        CardSectionHeader(icon: "exclamationmark.triangle", title: "Recent Errors", color: .yellow)

                        Divider()

                        let errors = ErrorCollector.shared.recentErrors()
                        if errors.isEmpty {
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.circle")
                                    .foregroundColor(.green)
                                Text("No errors recorded this session")
                                    .font(.body)
                                    .foregroundColor(.secondary)
                            }
                        } else {
                            ForEach(Array(errors.prefix(5).enumerated()), id: \.offset) { _, entry in
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(entry.source)
                                        .font(.caption.weight(.medium))
                                    Text(entry.message)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .lineLimit(2)
                                }
                            }
                            if errors.count > 5 {
                                Text("... and \(errors.count - 5) more")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
            .padding(20)
        }
    }

    private func includedItem(_ text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.caption)
                .foregroundColor(.green)
            Text(text)
                .font(.body)
                .foregroundColor(.primary)
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
            savedPath = nil
            reportGenerated = false
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
        ScrollView {
            VStack(spacing: 16) {
                // App Identity
                StyledCard {
                    VStack(spacing: 14) {
                        // App icon + name
                        Group {
                            if let iconURL = ResourceBundle.bundle?.url(forResource: "app_icon", withExtension: "png"),
                               let nsImage = NSImage(contentsOf: iconURL) {
                                Image(nsImage: nsImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                            } else {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(LinearGradient(colors: [.orange, .orange.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing))
                                    Image(systemName: "gauge.with.dots.needle.67percent")
                                        .font(.system(size: 28))
                                        .foregroundColor(.white)
                                }
                            }
                        }
                        .frame(width: 64, height: 64)

                        Text("MacOptimizer Studio")
                            .font(.title2.weight(.bold))

                        Text("Version \(appVersion) (Build \(buildNumber))")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        Text("Your Mac, But Faster")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .italic()
                    }
                    .frame(maxWidth: .infinity)
                }

                // System Info
                StyledCard {
                    VStack(alignment: .leading, spacing: 14) {
                        CardSectionHeader(icon: "desktopcomputer", title: "Compatibility", color: .blue)

                        Divider()

                        InfoRow(label: "Minimum macOS", value: "macOS 12 Monterey")
                        Divider()
                        InfoRow(label: "Architectures", value: "Apple Silicon & Intel")
                        Divider()
                        InfoRow(label: "Apple Silicon", value: "M1, M2, M3, M4, M5")
                        Divider()
                        InfoRow(label: "Intel", value: "x86_64 (2015+)")

                        Text("Universal binary — runs natively on all supported Mac processors. No Rosetta required on Apple Silicon.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                // Links
                StyledCard {
                    VStack(alignment: .leading, spacing: 14) {
                        CardSectionHeader(icon: "link", title: "Links", color: .orange)

                        Divider()

                        Button {
                            if let url = URL(string: "https://github.com/sandeepshet7/MacOptimizerStudio-Free") {
                                NSWorkspace.shared.open(url)
                            }
                        } label: {
                            HStack {
                                Image(systemName: "chevron.left.forwardslash.chevron.right")
                                    .foregroundColor(.orange)
                                    .frame(width: 20)
                                Text("Source Code on GitHub")
                                    .font(.body)
                                    .foregroundColor(.primary)
                                Spacer()
                                Image(systemName: "arrow.up.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .buttonStyle(.plain)

                        Divider()

                        Button {
                            if let url = URL(string: "https://sandeepshet7.github.io/MacOptimizerStudio-Free/") {
                                NSWorkspace.shared.open(url)
                            }
                        } label: {
                            HStack {
                                Image(systemName: "globe")
                                    .foregroundColor(.orange)
                                    .frame(width: 20)
                                Text("Website")
                                    .font(.body)
                                    .foregroundColor(.primary)
                                Spacer()
                                Image(systemName: "arrow.up.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .buttonStyle(.plain)

                        Divider()

                        Button {
                            if let url = URL(string: "https://github.com/sandeepshet7/MacOptimizerStudio-Free/issues") {
                                NSWorkspace.shared.open(url)
                            }
                        } label: {
                            HStack {
                                Image(systemName: "exclamationmark.bubble")
                                    .foregroundColor(.orange)
                                    .frame(width: 20)
                                Text("Report Issue")
                                    .font(.body)
                                    .foregroundColor(.primary)
                                Spacer()
                                Image(systemName: "arrow.up.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }

                // Disclaimer
                StyledCard {
                    VStack(alignment: .leading, spacing: 14) {
                        CardSectionHeader(icon: "exclamationmark.shield", title: "Disclaimer", color: .orange)

                        Divider()

                        Text("This software is provided \"as is\" without warranty of any kind. The developers are not liable for any data loss, system damage, or other harm resulting from use of this application. Destructive operations (file deletion, cache cleanup, process termination) cannot be undone. Always review actions before confirming.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Text("Made with Swift & Rust")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.bottom, 4)
            }
            .padding(20)
        }
    }
}
