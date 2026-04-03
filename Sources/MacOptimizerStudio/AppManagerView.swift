import MacOptimizerStudioCore
import SwiftUI

struct AppManagerView: View {
    @EnvironmentObject private var appManagerViewModel: AppManagerViewModel

    @State private var selectedApp: InstalledApp?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                controls

                if !appManagerViewModel.apps.isEmpty {
                    summaryCards
                    appsList
                } else if appManagerViewModel.isScanning {
                    scanningState
                } else {
                    emptyState
                }
            }
            .padding(20)
            .frame(maxWidth: 1200)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .background(DesignTokens.pageBackground)
        .task {
            if appManagerViewModel.apps.isEmpty {
                await appManagerViewModel.scan()
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Apps")
                .font(.largeTitle.weight(.bold))
            Text("View installed applications and their data footprint.")
                .font(.body)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Controls

    private var controls: some View {
        StyledCard {
            HStack(spacing: 10) {
                Button("Scan Apps") {
                    Task { await appManagerViewModel.scan() }
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                .disabled(appManagerViewModel.isScanning)

                if appManagerViewModel.isScanning {
                    ProgressView().controlSize(.small)
                    Text(appManagerViewModel.scanProgress)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                TextField("Search apps", text: $appManagerViewModel.searchQuery)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 200)
            }
        }
    }

    // MARK: - Summary

    private var summaryCards: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 200), spacing: 12)], spacing: 12) {
            StatCard(icon: "square.stack.3d.up", title: "Total Apps", value: "\(appManagerViewModel.apps.count)", tint: .blue)
            StatCard(icon: "internaldrive", title: "Total Footprint", value: ByteFormatting.string(appManagerViewModel.totalFootprint), tint: .orange)
            StatCard(icon: "doc.on.doc", title: "Associated Data", value: ByteFormatting.string(appManagerViewModel.totalAssociatedBytes), tint: .purple)
        }
    }

    // MARK: - Apps List

    private var appsList: some View {
        StyledCard {
            VStack(alignment: .leading, spacing: 10) {
                CardSectionHeader(icon: "square.stack.3d.up", title: "Applications (\(appManagerViewModel.filteredApps.count))", color: .orange)

                Divider()

                VStack(spacing: 0) {
                    appHeader
                    Divider()
                    ForEach(appManagerViewModel.filteredApps) { app in
                        appRow(app)
                        if selectedApp?.id == app.id {
                            appDetail(app)
                        }
                        Divider()
                    }
                }
            }
        }
    }

    private var appHeader: some View {
        HStack(spacing: 0) {
            Text("Name").frame(maxWidth: .infinity, alignment: .leading)
            Text("Version").frame(width: 80, alignment: .center)
            Text("App Size").frame(width: 90, alignment: .trailing)
            Text("Data").frame(width: 90, alignment: .trailing)
            Text("Total").frame(width: 90, alignment: .trailing)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)
        .padding(.vertical, 6)
    }

    private func appRow(_ app: InstalledApp) -> some View {
        let isExpanded = selectedApp?.id == app.id

        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedApp = isExpanded ? nil : app
            }
        } label: {
            HStack(spacing: 0) {
                HStack(spacing: 8) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(width: 12)
                    Text(app.name)
                        .font(.subheadline)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Text(app.version ?? "-")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 80, alignment: .center)

                Text(ByteFormatting.string(app.sizeBytes))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 90, alignment: .trailing)

                Text(ByteFormatting.string(app.totalAssociatedBytes))
                    .font(.caption)
                    .foregroundStyle(app.totalAssociatedBytes > 100_000_000 ? .orange : .secondary)
                    .frame(width: 90, alignment: .trailing)

                Text(ByteFormatting.string(app.totalFootprint))
                    .font(.caption.weight(.medium))
                    .frame(width: 90, alignment: .trailing)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }

    private func appDetail(_ app: InstalledApp) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if let bundleId = app.bundleId {
                HStack {
                    Text("Bundle ID:")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(bundleId)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }

            Text("Path: \(app.path)")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.tertiary)

            if !app.associatedFiles.isEmpty {
                Text("Associated Files (\(app.associatedFiles.count))")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                ForEach(app.associatedFiles) { file in
                    HStack(spacing: 6) {
                        Image(systemName: file.category.icon)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .frame(width: 14)
                        Text(file.category.displayName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(width: 100, alignment: .leading)
                        Text(file.path)
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Spacer()
                        Text(ByteFormatting.string(file.sizeBytes))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                Text("No associated files found.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .background(Color.primary.opacity(0.02))
    }

    // MARK: - States

    private var scanningState: some View {
        StyledCard {
            VStack(spacing: 16) {
                ProgressView()
                Text(appManagerViewModel.scanProgress)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                ForEach(0..<5, id: \.self) { _ in
                    SkeletonRow()
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var emptyState: some View {
        StyledCard {
            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color.orange.opacity(0.08))
                        .frame(width: 80, height: 80)
                    Image(systemName: "square.stack.3d.up")
                        .font(.system(size: 32))
                        .foregroundStyle(.orange)
                }
                Text("App Manager")
                    .font(.headline)
                Text("Scan installed applications to see their disk footprint.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 400)
                Button("Scan Apps") {
                    Task { await appManagerViewModel.scan() }
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
        }
    }
}
