import AppKit
import MacOptimizerStudioCore
import SwiftUI

struct StorageToolsView: View {
    @EnvironmentObject private var storageToolsViewModel: StorageToolsViewModel
    @EnvironmentObject private var toastManager: ToastManager

    @State private var activeTab: StorageTab = .spaceLens
    @State private var expandedPaths: Set<String> = []
    @State private var pendingTrashFile: LargeFile?

    enum StorageTab: String, CaseIterable {
        case spaceLens = "Space Lens"
        case largeFiles = "Large Files"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                tabPicker
                switch activeTab {
                case .spaceLens: spaceLensContent
                case .largeFiles: largeFilesContent
                }
            }
            .padding(20)
            .frame(maxWidth: 1200)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .sheet(item: $pendingTrashFile) { file in
            DoubleConfirmSheet(
                title: "Move to Trash",
                warning: "Move this file to Trash?\n\n\(file.path)\nSize: \(ByteFormatting.string(file.sizeBytes))\n\nThis is safe — you can recover it from Trash later.",
                confirmLabel: "Move to Trash",
                onCancel: { pendingTrashFile = nil },
                onConfirm: {
                    do {
                        try FileManager.default.trashItem(at: URL(fileURLWithPath: file.path), resultingItemURL: nil)
                        toastManager.show("Moved to Trash: \(file.name)")
                    } catch {
                        toastManager.show("Failed: \(error.localizedDescription)", isError: true)
                    }
                    pendingTrashFile = nil
                }
            )
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Storage Tools")
                .font(.largeTitle.weight(.bold))
            Text("Visualize disk usage and locate large files taking up space.")
                .font(.body)
                .foregroundStyle(.secondary)
        }
    }

    private var tabPicker: some View {
        Picker("Tab", selection: $activeTab) {
            ForEach(StorageTab.allCases, id: \.self) { tab in
                Text(tab.rawValue).tag(tab)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .frame(maxWidth: 500)
    }

    // MARK: - Space Lens

    private var spaceLensContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let tree = storageToolsViewModel.folderTree {
                // Controls card
                StyledCard {
                    VStack(alignment: .leading, spacing: 14) {
                        CardSectionHeader(icon: "chart.bar.doc.horizontal", title: "Folder Breakdown", color: .blue)
                        Divider()
                        HStack {
                            Button("Choose Folder") {
                                pickFolder { url in
                                    Task { await storageToolsViewModel.scanFolderSizes(at: url) }
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.orange)

                            if let root = storageToolsViewModel.spaceLensRoot {
                                Text(root.path)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }

                            Spacer()

                            Text(ByteFormatting.string(tree.sizeBytes))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.orange)
                        }
                    }
                }

                // Tree card
                StyledCard {
                    VStack(spacing: 0) {
                        folderNodeView(tree, depth: 0)
                    }
                }
            } else if storageToolsViewModel.isScanningSizes {
                StyledCard {
                    VStack(alignment: .leading, spacing: 14) {
                        CardSectionHeader(icon: "chart.bar.doc.horizontal", title: "Space Lens", color: .blue)
                        Divider()
                        HStack {
                            ProgressView().controlSize(.small)
                            Text("Scanning folder sizes...").font(.subheadline).foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 8)
                        ForEach(0..<4, id: \.self) { _ in SkeletonCard(height: 24) }
                    }
                }
            } else {
                clickableEmptyState(icon: "chart.bar.doc.horizontal", title: "Space Lens", detail: "Choose a folder to visualize which subfolders use the most disk space. Click to drill down into any folder.") {
                    pickFolder { url in
                        Task { await storageToolsViewModel.scanFolderSizes(at: url) }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func folderNodeView(_ node: FolderNode, depth: Int) -> some View {
        let isExpanded = expandedPaths.contains(node.id)
        let parentSize = storageToolsViewModel.folderTree?.sizeBytes ?? node.sizeBytes
        let ratio = parentSize > 0 ? Double(node.sizeBytes) / Double(parentSize) : 0

        VStack(alignment: .leading, spacing: 0) {
            Button {
                if node.children.isEmpty { return }
                if isExpanded { expandedPaths.remove(node.id) }
                else { expandedPaths.insert(node.id) }
            } label: {
                HStack(spacing: 8) {
                    if !node.children.isEmpty {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .frame(width: 12)
                    } else {
                        Spacer().frame(width: 12)
                    }

                    Image(systemName: node.isDirectory ? "folder.fill" : "doc.fill")
                        .font(.caption)
                        .foregroundStyle(node.isDirectory ? .blue : .secondary)

                    Text(node.name)
                        .font(.subheadline)
                        .lineLimit(1)

                    Spacer()

                    GeometryReader { geo in
                        RoundedRectangle(cornerRadius: 3)
                            .fill(barColor(ratio: ratio))
                            .frame(width: geo.size.width * min(ratio, 1.0), height: 6)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(width: 120, height: 6)

                    Text(ByteFormatting.string(node.sizeBytes))
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 80, alignment: .trailing)

                    Text(String(format: "%.1f%%", ratio * 100))
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .frame(width: 50, alignment: .trailing)
                }
                .padding(.vertical, 4)
                .padding(.leading, CGFloat(depth * 16))
            }
            .buttonStyle(.plain)

            if isExpanded && depth < 6 {
                ForEach(node.sortedChildren.prefix(50)) { child in
                    AnyView(folderNodeView(child, depth: depth + 1))
                }
            }
        }
    }

    private func barColor(ratio: Double) -> Color {
        if ratio > 0.5 { return .red }
        if ratio > 0.2 { return .orange }
        return .blue
    }

    // MARK: - Large Files

    private var largeFilesContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Controls card
            StyledCard {
                VStack(alignment: .leading, spacing: 14) {
                    CardSectionHeader(icon: "doc.badge.ellipsis", title: "Scan Settings", color: .orange)
                    Divider()
                    HStack(spacing: 12) {
                        Button {
                            pickFolder { url in
                                storageToolsViewModel.addRoots([url])
                                Task { await storageToolsViewModel.findLargeFiles() }
                            }
                        } label: {
                            Label("Add Folder", systemImage: "folder.badge.plus")
                                .font(.body.weight(.medium))
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.orange)
                        .controlSize(.large)

                        if storageToolsViewModel.isScanningLargeFiles {
                            ProgressView().controlSize(.small)
                            Text(storageToolsViewModel.largeFilesProgress)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        HStack(spacing: 6) {
                            Text("Min size:")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Picker("Min Size", selection: $storageToolsViewModel.minFileSizeMB) {
                                Text("50 MB").tag(50.0)
                                Text("100 MB").tag(100.0)
                                Text("500 MB").tag(500.0)
                                Text("1 GB").tag(1024.0)
                            }
                            .labelsHidden()
                            .frame(width: 110)
                        }
                    }
                }
            }

            // Selected folders card
            if !storageToolsViewModel.scanRoots.isEmpty {
                StyledCard {
                    VStack(alignment: .leading, spacing: 14) {
                        CardSectionHeader(icon: "folder.fill", title: "Selected Folders", color: .orange)
                        Divider()
                        HStack(spacing: 8) {
                            ForEach(storageToolsViewModel.scanRoots, id: \.path) { root in
                                HStack(spacing: 6) {
                                    Image(systemName: "folder.fill")
                                        .font(.caption)
                                        .foregroundStyle(.orange)
                                    Text(root.lastPathComponent)
                                        .font(.subheadline)
                                        .lineLimit(1)
                                    Button {
                                        storageToolsViewModel.scanRoots.removeAll { $0 == root }
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.orange.opacity(0.1))
                                .clipShape(Capsule())
                            }

                            Button {
                                pickFolder { url in
                                    storageToolsViewModel.addRoots([url])
                                    Task { await storageToolsViewModel.findLargeFiles() }
                                }
                            } label: {
                                Image(systemName: "plus.circle")
                                    .font(.body)
                                    .foregroundStyle(.orange)
                            }
                            .buttonStyle(.plain)
                            .help("Add another folder")
                        }
                    }
                }
            }

            // Results
            if storageToolsViewModel.isScanningLargeFiles {
                StyledCard {
                    VStack(alignment: .leading, spacing: 14) {
                        CardSectionHeader(icon: "magnifyingglass", title: "Scanning", color: .blue)
                        Divider()
                        HStack(spacing: 8) {
                            ProgressView().controlSize(.regular)
                            Text("Scanning for large files...")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            if !storageToolsViewModel.largeFilesProgress.isEmpty {
                                Text(storageToolsViewModel.largeFilesProgress)
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .padding(.vertical, 4)
                        ForEach(0..<4, id: \.self) { _ in SkeletonCard(height: 28) }
                    }
                }
            } else if !storageToolsViewModel.largeFiles.isEmpty {
                // Summary stats row
                HStack(spacing: 12) {
                    StatCard(
                        icon: "doc.fill",
                        title: "Files Found",
                        value: "\(storageToolsViewModel.largeFiles.count)",
                        tint: .blue
                    )
                    StatCard(
                        icon: "internaldrive",
                        title: "Total Size",
                        value: ByteFormatting.string(storageToolsViewModel.totalLargeFilesSize),
                        tint: .orange
                    )
                }

                // Results table card
                StyledCard {
                    VStack(alignment: .leading, spacing: 0) {
                        CardSectionHeader(icon: "list.bullet", title: "Large Files", color: .orange)
                            .padding(.bottom, 14)
                        Divider()
                        largeFileHeader
                        Divider()
                        ForEach(storageToolsViewModel.largeFiles.prefix(200)) { file in
                            largeFileRow(file)
                            Divider()
                        }
                    }
                }
            } else if !storageToolsViewModel.scanRoots.isEmpty {
                // Folders added but no large files found
                StyledCard {
                    VStack(spacing: 10) {
                        Image(systemName: "checkmark.circle")
                            .font(.system(size: 28))
                            .foregroundStyle(.green)
                        Text("No large files found")
                            .font(.headline)
                        Text("No files above \(Int(storageToolsViewModel.minFileSizeMB)) MB in the selected folders.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text("Try lowering the minimum size or adding more folders.")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                }
            } else {
                clickableEmptyState(icon: "doc.badge.ellipsis", title: "Large & Old Files", detail: "Find files larger than your threshold that haven't been accessed recently. Great for finding forgotten downloads and old media files.") {
                    pickFolder { url in
                        storageToolsViewModel.addRoots([url])
                        Task { await storageToolsViewModel.findLargeFiles() }
                    }
                }
            }
        }
    }

    private var largeFileHeader: some View {
        HStack(spacing: 0) {
            Text("Name").frame(maxWidth: .infinity, alignment: .leading)
            Text("Size").frame(width: 90, alignment: .trailing)
            Text("Last Accessed").frame(width: 120, alignment: .trailing)
            Text("Actions").frame(width: 120, alignment: .center)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.primary.opacity(0.03))
    }

    private func largeFileRow(_ file: LargeFile) -> some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 1) {
                Text(file.name)
                    .font(.subheadline)
                    .lineLimit(1)
                Text(file.path)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(ByteFormatting.string(file.sizeBytes))
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .frame(width: 90, alignment: .trailing)

            Group {
                if let days = file.daysSinceAccess {
                    Text("\(days)d ago")
                        .foregroundStyle(days > 180 ? .orange : .secondary)
                } else {
                    Text("-").foregroundStyle(.tertiary)
                }
            }
            .font(.caption)
            .frame(width: 120, alignment: .trailing)

            HStack(spacing: 4) {
                Button {
                    NSWorkspace.shared.selectFile(file.path, inFileViewerRootedAtPath: (file.path as NSString).deletingLastPathComponent)
                } label: {
                    Image(systemName: "arrow.right.circle")
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)
                .help("Reveal in Finder")

                Button {
                    pendingTrashFile = file
                } label: {
                    Label("Move to Trash", systemImage: "trash")
                        .labelStyle(.iconOnly)
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)
                .tint(.orange)
                .help("Move to Trash (recoverable from Trash)")
            }
            .frame(width: 120, alignment: .center)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    // MARK: - Helpers

    private func emptyToolState(icon: String, title: String, detail: String) -> some View {
        StyledCard {
            VStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color.orange.opacity(0.08))
                        .frame(width: 70, height: 70)
                    Image(systemName: icon)
                        .font(.system(size: 28))
                        .foregroundStyle(.orange)
                }
                Text(title).font(.headline)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 400)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
        }
    }

    private func clickableEmptyState(icon: String, title: String, detail: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            StyledCard {
                VStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(Color.orange.opacity(0.08))
                            .frame(width: 70, height: 70)
                        Image(systemName: icon)
                            .font(.system(size: 28))
                            .foregroundStyle(.orange)
                    }
                    Text(title).font(.headline)
                    Text(detail)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 400)

                    HStack(spacing: 6) {
                        Image(systemName: "folder.badge.plus")
                        Text("Choose Folder")
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.orange)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            }
        }
        .buttonStyle(.plain)
    }

    private func pickFolder(_ completion: @escaping (URL) -> Void) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Select Folder"
        if panel.runModal() == .OK, let url = panel.url {
            completion(url)
        }
    }
}
