import AppKit
import MacOptimizerStudioCore
import SwiftUI

struct AuditLogView: View {
    @EnvironmentObject private var viewModel: AuditLogViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                statsBar
                logEntries
            }
            .padding(20)
            .frame(maxWidth: 1200)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .task {
            await viewModel.load()
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Activity Log")
                    .font(.largeTitle.weight(.bold))
                Text("Complete history of all cleanup and deletion actions. This log protects you — it proves every action was user-initiated and confirmed.")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                exportLog()
            } label: {
                Label("Export", systemImage: "square.and.arrow.up")
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)

            Button {
                Task { await viewModel.load() }
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.bordered)
        }
    }

    // MARK: - Stats

    private var statsBar: some View {
        HStack(spacing: 16) {
            statCard(title: "Total Actions", value: "\(viewModel.totalActions)", icon: "list.bullet.clipboard", tint: .blue)
            statCard(title: "Space Freed", value: ByteFormatting.string(viewModel.totalBytesFreed), icon: "externaldrive", tint: .green)
            statCard(title: "Action Types", value: "\(viewModel.actionCounts.count)", icon: "tag", tint: .purple)
        }
    }

    private func statCard(title: String, value: String, icon: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .foregroundStyle(tint)
                    .font(.caption)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(value)
                .font(.headline)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Log Entries

    @ViewBuilder
    private var logEntries: some View {
        if viewModel.entries.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "checkmark.shield")
                    .font(.system(size: 36))
                    .foregroundStyle(.green)
                Text("No actions recorded yet")
                    .font(.headline)
                Text("Actions like file shredding, cache cleanup, and process termination will be logged here automatically.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 400)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)
        } else {
            LazyVStack(alignment: .leading, spacing: 16) {
                ForEach(viewModel.entriesByDay, id: \.0) { day, entries in
                    daySection(day: day, entries: entries)
                }
            }
        }
    }

    private func daySection(day: String, entries: [AuditLogEntry]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(day)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            VStack(spacing: 0) {
                ForEach(entries) { entry in
                    AuditEntryRow(entry: entry)
                    if entry.id != entries.last?.id {
                        Divider().padding(.leading, 44)
                    }
                }
            }
            .background(.thinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    // MARK: - Export

    private func exportLog() {
        let text = viewModel.exportText()
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText]
        panel.nameFieldStringValue = "MacOptimizerStudio_ActivityLog.txt"
        panel.title = "Export Activity Log"

        if panel.runModal() == .OK, let url = panel.url {
            try? text.write(to: url, atomically: true, encoding: .utf8)
        }
    }
}

// MARK: - Expandable Entry Row

private struct AuditEntryRow: View {
    let entry: AuditLogEntry
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                if !entry.paths.isEmpty {
                    withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() }
                }
            } label: {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: entry.action.icon)
                        .font(.body)
                        .foregroundStyle(severityColor(entry.action.severity))
                        .frame(width: 24)

                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Text(entry.action.label)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.primary)
                            actionBadge(entry.action)
                            Spacer()
                            Text(entry.timestamp.formatted(date: .omitted, time: .standard))
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        Text(entry.details)
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        HStack(spacing: 12) {
                            if let bytes = entry.totalBytes {
                                Label(ByteFormatting.string(bytes), systemImage: "doc")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                            if entry.itemCount > 1 {
                                Label("\(entry.itemCount) items", systemImage: "number")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                            if !entry.paths.isEmpty {
                                HStack(spacing: 3) {
                                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                                        .font(.system(size: 8, weight: .bold))
                                    Text("\(entry.paths.count) path(s)")
                                        .font(.caption2)
                                }
                                .foregroundStyle(.orange)
                            }
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded && !entry.paths.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(Array(entry.paths.enumerated()), id: \.offset) { _, path in
                        HStack(spacing: 6) {
                            Image(systemName: "minus.circle.fill")
                                .font(.system(size: 8))
                                .foregroundStyle(.red.opacity(0.5))
                            Text(path)
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                    }
                }
                .padding(.leading, 46)
                .padding(.trailing, 12)
                .padding(.bottom, 8)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private func actionBadge(_ action: AuditAction) -> some View {
        let (text, color): (String, Color) = {
            switch action {
            case .fileShredded: return ("Permanently Destroyed", .red)
            case .cacheCleanup: return ("Deleted", .orange)
            case .brokenDownloadsTrashed: return ("Moved to Trash", .green)
            case .screenshotsMoved: return ("Moved", .blue)
            case .processKilled: return ("Quit", .orange)
            case .processForceKilled: return ("Force Quit", .red)
            case .diskCleanup: return ("Deleted", .orange)
            case .dockerImageRemoved: return ("Removed", .orange)
            case .dockerVolumeRemoved: return ("Removed", .orange)
            case .dockerContainerRemoved: return ("Removed", .orange)
            case .dockerPrune: return ("Pruned", .red)
            case .appUninstalled: return ("Moved to Trash", .red)
            case .appDataReset: return ("Reset", .orange)
            case .extensionRemoved: return ("Removed", .orange)
            case .maintenanceTaskRun: return ("Executed", .blue)
            case .photoJunkTrashed: return ("Moved to Trash", .green)
            case .privacyDataCleaned: return ("Deleted", .orange)
            }
        }()

        return Text(text)
            .font(.system(size: 9, weight: .semibold))
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .background(color.opacity(0.12))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }

    private func severityColor(_ severity: AuditSeverity) -> Color {
        switch severity {
        case .destructive: return .red
        case .warning: return .orange
        case .info: return .blue
        }
    }
}
