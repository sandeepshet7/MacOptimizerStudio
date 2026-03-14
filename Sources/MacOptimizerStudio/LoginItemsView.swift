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
        StyledCard {
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
    }

    // MARK: - Summary

    private func summaryCards(_ items: [StartupItem]) -> some View {
        let enabled = items.filter(\.isEnabled).count
        let disabled = items.count - enabled
        let userAgents = items.filter { $0.source == .userAgent }.count
        let globalItems = items.filter { $0.source != .userAgent }.count

        return LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 12)], spacing: 12) {
            StatCard(icon: "list.number", title: "Total Items", value: "\(items.count)", tint: .blue)
            StatCard(icon: "power", title: "Enabled", value: "\(enabled)", tint: enabled > 20 ? .orange : .green)
            StatCard(icon: "moon.fill", title: "Disabled", value: "\(disabled)", tint: .secondary)
            StatCard(icon: "person.2.fill", title: "User / Global", value: "\(userAgents) / \(globalItems)", tint: .purple)
        }
    }

    // MARK: - Items List

    private func itemsList(_ items: [StartupItem]) -> some View {
        let filtered = filteredItems(items)

        return StyledCard {
            VStack(alignment: .leading, spacing: 10) {
                CardSectionHeader(icon: "power", title: "Items (\(filtered.count))", color: .orange)

                if filtered.isEmpty {
                    Text("No items match your filter.")
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 20)
                } else {
                    Divider()

                    VStack(spacing: 0) {
                        itemHeader
                        Divider()
                        ForEach(filtered, id: \.id) { item in
                            itemRow(item)
                            Divider()
                        }
                    }
                }
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
        .padding(.vertical, 6)
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
        .padding(.vertical, 4)
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
        StyledCard {
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
            .padding(.vertical, 24)
        }
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
