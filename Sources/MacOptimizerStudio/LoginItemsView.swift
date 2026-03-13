import MacOptimizerStudioCore
import SwiftUI

struct LoginItemsView: View {
    @EnvironmentObject private var systemHealthViewModel: SystemHealthViewModel
    @EnvironmentObject private var toastManager: ToastManager

    @State private var filter = ""
    @State private var selectedSource: StartupSource? = nil
    @State private var pendingDisableItem: StartupItem?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                controls

                if let snapshot = systemHealthViewModel.snapshot {
                    summaryCards(snapshot.startupItems)
                    itemsList(snapshot.startupItems)
                } else if systemHealthViewModel.isLoading {
                    SkeletonCard(height: 80)
                    SkeletonCard(height: 200)
                } else {
                    emptyState
                }
            }
            .padding(20)
            .frame(maxWidth: 1200)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .task {
            if systemHealthViewModel.snapshot == nil {
                await systemHealthViewModel.refresh()
            }
        }
        .sheet(item: $pendingDisableItem) { item in
            disableConfirmSheet(item)
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Login Items")
                .font(.largeTitle.weight(.bold))
            Text("Manage startup agents and daemons that launch with your Mac.")
                .font(.body)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Controls

    private var controls: some View {
        HStack(spacing: 10) {
            Button("Refresh") {
                Task { await systemHealthViewModel.refresh() }
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)

            Picker("Source", selection: $selectedSource) {
                Text("All").tag(nil as StartupSource?)
                Text("User Agents").tag(StartupSource.userAgent as StartupSource?)
                Text("Global Agents").tag(StartupSource.globalAgent as StartupSource?)
                Text("Global Daemons").tag(StartupSource.globalDaemon as StartupSource?)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 360)

            Spacer()

            TextField("Filter", text: $filter)
                .textFieldStyle(.roundedBorder)
                .frame(width: 180)
        }
    }

    // MARK: - Summary

    private func summaryCards(_ items: [StartupItem]) -> some View {
        let enabled = items.filter(\.isEnabled).count
        let disabled = items.count - enabled
        let userAgents = items.filter { $0.source == .userAgent }.count
        let globalItems = items.filter { $0.source != .userAgent }.count

        return LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 12)], spacing: 12) {
            summaryCard(title: "Total Items", value: "\(items.count)", detail: "Login agents & daemons", tint: .blue)
            summaryCard(title: "Enabled", value: "\(enabled)", detail: enabled > 20 ? "Consider disabling some" : "Active at startup", tint: enabled > 20 ? .orange : .green)
            summaryCard(title: "Disabled", value: "\(disabled)", detail: "Won't load at startup", tint: .secondary)
            summaryCard(title: "User / Global", value: "\(userAgents) / \(globalItems)", detail: "User agents vs system", tint: .purple)
        }
    }

    private func summaryCard(title: String, value: String, detail: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.headline)
            Text(detail).font(.caption).foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(tint.opacity(0.15), lineWidth: 1))
    }

    // MARK: - Items List

    private func itemsList(_ items: [StartupItem]) -> some View {
        let filtered = filteredItems(items)

        return VStack(alignment: .leading, spacing: 10) {
            Text("Items (\(filtered.count))")
                .font(.headline)

            if filtered.isEmpty {
                Text("No items match your filter.")
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 20)
            } else {
                VStack(spacing: 0) {
                    itemHeader
                    Divider()
                    ForEach(filtered, id: \.id) { item in
                        itemRow(item)
                        Divider()
                    }
                }
                .background(.thinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    private var itemHeader: some View {
        HStack(spacing: 0) {
            Text("Name")
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("Source")
                .frame(width: 120, alignment: .center)
            Text("Status")
                .frame(width: 80, alignment: .center)
            Text("Actions")
                .frame(width: 140, alignment: .center)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.primary.opacity(0.03))
    }

    private func itemRow(_ item: StartupItem) -> some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.subheadline)
                    .lineLimit(1)
                Text(item.path)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 4) {
                Image(systemName: item.source.icon)
                    .font(.caption2)
                Text(item.source.displayName)
                    .font(.caption)
            }
            .foregroundStyle(.secondary)
            .frame(width: 120, alignment: .center)

            HStack(spacing: 4) {
                Circle()
                    .fill(item.isEnabled ? .green : .secondary)
                    .frame(width: 6, height: 6)
                Text(item.isEnabled ? "Enabled" : "Disabled")
                    .font(.caption)
            }
            .frame(width: 80, alignment: .center)

            HStack(spacing: 4) {
                Button("Reveal") {
                    revealInFinder(path: item.path)
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)

                if item.isEnabled && item.source == .userAgent {
                    Button("Disable") {
                        pendingDisableItem = item
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                    .tint(.red)
                }
            }
            .frame(width: 140, alignment: .center)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    // MARK: - Confirm Sheet

    private func disableConfirmSheet(_ item: StartupItem) -> some View {
        let command = systemHealthViewModel.launchctlDisableCommand(for: item)
        return DoubleConfirmSheet(
            title: "Disable Login Item",
            warning: """
            You are about to disable:

            Name: \(item.name)
            Source: \(item.source.displayName)
            Path: \(item.path)

            This will run:
            \(command)

            The item will no longer launch at startup.
            """,
            confirmLabel: "Disable Now",
            onCancel: { pendingDisableItem = nil },
            onConfirm: {
                let executor = SafeExecutor()
                let result = executor.execute(commands: [command]) { _, _ in }
                if result.success {
                    toastManager.show("Disabled \(item.name)")
                } else {
                    toastManager.show("Failed to disable: \(result.errors.first ?? "Unknown error")", isError: true)
                }
                pendingDisableItem = nil
                Task { await systemHealthViewModel.refresh() }
            }
        )
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.secondary.opacity(0.08))
                    .frame(width: 80, height: 80)
                Image(systemName: "power")
                    .font(.system(size: 32))
                    .foregroundStyle(.secondary)
            }
            Text("Loading Login Items...")
                .font(.headline)
            Button("Scan Now") {
                Task { await systemHealthViewModel.refresh() }
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    // MARK: - Helpers

    private func filteredItems(_ items: [StartupItem]) -> [StartupItem] {
        var result = items
        if let source = selectedSource {
            result = result.filter { $0.source == source }
        }
        if !filter.isEmpty {
            let needle = filter.lowercased()
            result = result.filter { $0.name.lowercased().contains(needle) || $0.path.lowercased().contains(needle) }
        }
        return result
    }

    private func revealInFinder(path: String) {
        NSWorkspace.shared.selectFile(path, inFileViewerRootedAtPath: (path as NSString).deletingLastPathComponent)
    }
}
