import AppKit
import MacOptimizerStudioCore
import SwiftUI

struct DuplicateFinderView: View {
    @EnvironmentObject private var viewModel: DuplicateFinderViewModel
    @EnvironmentObject private var toastManager: ToastManager
    @EnvironmentObject private var auditLogViewModel: AuditLogViewModel

    @State private var confirmDelete = false

    private let fileSizeOptions: [(String, UInt64)] = [
        ("1 KB", 1024),
        ("10 KB", 10 * 1024),
        ("100 KB", 100 * 1024),
        ("1 MB", 1024 * 1024),
        ("10 MB", 10 * 1024 * 1024),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                headerSection
                scanRootsSection
                configSection

                if viewModel.isScanning {
                    scanningState
                } else if let report = viewModel.report {
                    if report.groups.isEmpty {
                        noResultsState
                    } else {
                        summaryCards(report)
                        resultsSection(report)
                    }
                } else if let error = viewModel.errorMessage {
                    errorBanner(error)
                } else {
                    emptyState
                }
            }
            .padding(20)
            .frame(maxWidth: 1280)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .safeAreaInset(edge: .bottom) {
            if let report = viewModel.report, !report.groups.isEmpty {
                floatingActionBar
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .alert("Delete Selected Files?", isPresented: $confirmDelete) {
            Button("Cancel", role: .cancel) {}
            Button("Move to Trash", role: .destructive) {
                let count = viewModel.selectedCount
                let bytes = viewModel.selectedBytes
                Task {
                    await viewModel.deleteSelected()
                    let service = AuditLogService()
                    service.log(AuditLogEntry(
                        action: .diskCleanup,
                        details: "Duplicate Finder: trashed \(count) duplicate files (\(ByteFormatting.string(bytes)))",
                        totalBytes: bytes,
                        itemCount: count
                    ))
                    await auditLogViewModel.load()
                    toastManager.show("Moved \(count) duplicates to Trash")
                }
            }
        } message: {
            Text("This will move \(viewModel.selectedCount) files (\(ByteFormatting.string(viewModel.selectedBytes))) to Trash. You can restore them from Trash if needed.")
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Duplicate Finder")
                    .font(.title2.weight(.bold))
                Text("Find and remove duplicate files to free up disk space")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                Task { await viewModel.scan() }
            } label: {
                Label(viewModel.isScanning ? "Scanning..." : "Scan", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
            .disabled(viewModel.isScanning || viewModel.roots.isEmpty)
            .controlSize(.large)
        }
    }

    // MARK: - Scan Roots

    private var scanRootsSection: some View {
        StyledCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    CardSectionHeader(icon: "folder.fill", title: "Scan Roots", color: .orange)
                    Spacer()
                    Button {
                        addFolder()
                    } label: {
                        Label("Add Folder", systemImage: "folder.badge.plus")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                if viewModel.roots.isEmpty {
                    Text("No folders selected. Add folders to scan for duplicates.")
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 6)
                } else {
                    ForEach(Array(viewModel.roots.enumerated()), id: \.element.path) { index, root in
                        if index > 0 {
                            Divider()
                        }
                        HStack {
                            Image(systemName: "folder")
                                .foregroundColor(.orange)
                            Text(root.path)
                                .lineLimit(1)
                                .truncationMode(.middle)
                                .font(.subheadline)

                            Spacer()

                            Button {
                                revealInFinder(path: root.path)
                            } label: {
                                Image(systemName: "arrow.right.circle")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                            .help("Reveal in Finder")

                            Button("Remove") {
                                viewModel.removeRoot(root)
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Config

    private var configSection: some View {
        StyledCard {
            HStack {
                CardSectionHeader(icon: "slider.horizontal.3", title: "Settings", color: .blue)
                Spacer()
                Text("Min file size:")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Picker("", selection: $viewModel.minFileSize) {
                    ForEach(fileSizeOptions, id: \.1) { label, value in
                        Text(label).tag(value)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 120)
                .labelsHidden()
            }
        }
    }

    // MARK: - States

    private var scanningState: some View {
        StyledCard {
            VStack(spacing: 16) {
                ProgressView()
                    .controlSize(.large)
                Text("Scanning for duplicates...")
                    .font(.title3.weight(.semibold))
                Text(viewModel.scanProgress)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 28)
        }
    }

    private var emptyState: some View {
        StyledCard {
            VStack(spacing: 18) {
                ZStack {
                    Circle()
                        .fill(Color.orange.opacity(0.08))
                        .frame(width: 80, height: 80)
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 38))
                        .foregroundStyle(.orange.opacity(0.7))
                }
                VStack(spacing: 6) {
                    Text("Find duplicate files")
                        .font(.title3.weight(.semibold))
                    Text("Add folders and run a scan to find duplicate files wasting disk space.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 400)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 28)
        }
    }

    private var noResultsState: some View {
        StyledCard {
            VStack(spacing: 16) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(.green)
                Text("No Duplicates Found")
                    .font(.title3.weight(.semibold))
                Text("No duplicate files were found in the scanned directories.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 28)
        }
    }

    private func errorBanner(_ message: String) -> some View {
        StyledCard {
            VStack(spacing: 14) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(.orange)
                Text("Error")
                    .font(.title3.weight(.semibold))
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 500)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 28)
        }
    }

    // MARK: - Summary Cards

    private func summaryCards(_ report: DuplicateScanReport) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 10)], spacing: 10) {
            StatCard(
                icon: "doc.on.doc.fill",
                title: "Duplicate Groups",
                value: "\(report.groups.count)",
                tint: .orange
            )
            StatCard(
                icon: "externaldrive.fill",
                title: "Wasted Space",
                value: ByteFormatting.string(report.totalWastedBytes),
                tint: .red
            )
            StatCard(
                icon: "doc.fill",
                title: "Files Scanned",
                value: "\(report.totalFiles)",
                tint: .blue
            )
            StatCard(
                icon: "clock.fill",
                title: "Scan Time",
                value: String(format: "%.1fs", report.scanDurationSeconds),
                tint: .green
            )
        }
    }

    // MARK: - Results

    private func resultsSection(_ report: DuplicateScanReport) -> some View {
        StyledCard {
            VStack(alignment: .leading, spacing: 14) {
                CardSectionHeader(
                    icon: "doc.on.doc.fill",
                    title: "Duplicate Groups (\(report.groups.count))",
                    color: .orange
                )

                ForEach(Array(report.groups.enumerated()), id: \.element.id) { index, group in
                    if index > 0 {
                        Divider()
                    }
                    duplicateGroupRow(group)
                }
            }
        }
    }

    private func duplicateGroupRow(_ group: DuplicateGroup) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // File info header
            HStack(spacing: 8) {
                Image(systemName: "doc.fill")
                    .foregroundStyle(.orange)
                Text(fileName(from: group.paths.first ?? ""))
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Spacer()
                Text(ByteFormatting.string(group.fileSize))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                Text("\(group.paths.count) copies")
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.orange.opacity(0.15))
                    .foregroundStyle(.orange)
                    .clipShape(Capsule())
            }

            // Path list
            ForEach(Array(group.paths.enumerated()), id: \.element) { index, path in
                HStack(spacing: 8) {
                    if index == 0 {
                        // Original — don't allow selection
                        Image(systemName: "lock.fill")
                            .font(.caption)
                            .foregroundStyle(.green)
                            .frame(width: 18)
                    } else {
                        Button {
                            viewModel.toggleSelection(path)
                        } label: {
                            Image(systemName: viewModel.selectedPaths.contains(path)
                                  ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(viewModel.selectedPaths.contains(path) ? .orange : .secondary)
                        }
                        .buttonStyle(.plain)
                        .frame(width: 18)
                    }

                    Text(path)
                        .font(.system(.caption, design: .monospaced))
                        .lineLimit(1)
                        .truncationMode(.middle)

                    if index == 0 {
                        Text("Original")
                            .font(.system(size: 9, weight: .semibold))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Color.green.opacity(0.12))
                            .foregroundStyle(.green)
                            .clipShape(Capsule())
                    }

                    Spacer()

                    Button {
                        revealInFinder(path: path)
                    } label: {
                        Image(systemName: "arrow.right.circle")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Reveal in Finder")
                }
                .padding(.leading, 8)
            }

            // Wasted space indicator
            HStack(spacing: 4) {
                Image(systemName: "exclamationmark.circle")
                    .font(.caption2)
                    .foregroundStyle(.orange)
                Text("Wasting \(ByteFormatting.string(group.wastedBytes))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.leading, 26)
        }
        .padding(8)
        .background(Color.orange.opacity(0.02))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Floating Action Bar

    private var floatingActionBar: some View {
        HStack(spacing: 10) {
            Button("Select All Duplicates") {
                viewModel.selectAllDuplicates()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            if !viewModel.selectedPaths.isEmpty {
                Button("Deselect All") {
                    viewModel.deselectAll()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            Spacer()

            if viewModel.selectedCount > 0 {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.orange)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("\(viewModel.selectedCount) selected")
                            .font(.subheadline.weight(.semibold))
                        Text(ByteFormatting.string(viewModel.selectedBytes))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Button {
                    confirmDelete = true
                } label: {
                    Label("Delete Selected", systemImage: "trash")
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                .controlSize(.small)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) { Divider() }
    }

    // MARK: - Helpers

    private func addFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.canCreateDirectories = false
        panel.prompt = "Add Roots"
        if panel.runModal() == .OK, !panel.urls.isEmpty {
            viewModel.addRoots(panel.urls)
        }
    }

    private func revealInFinder(path: String) {
        NSWorkspace.shared.selectFile(path, inFileViewerRootedAtPath: (path as NSString).deletingLastPathComponent)
    }

    private func fileName(from path: String) -> String {
        (path as NSString).lastPathComponent
    }
}
