import AppKit
import MacOptimizerStudioCore
import SwiftUI

struct PhotoJunkView: View {
    @EnvironmentObject private var viewModel: PhotoJunkViewModel
    @EnvironmentObject private var toastManager: ToastManager

    @State private var showTrashConfirm = false

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header

                    if viewModel.isScanning {
                        loadingState
                    } else if let report = viewModel.report {
                        if report.totalCount == 0 {
                            cleanState
                        } else {
                            if !report.screenshots.isEmpty {
                                sectionView(
                                    title: "Screenshots",
                                    items: report.screenshots,
                                    totalBytes: report.totalScreenshotBytes,
                                    selectAll: viewModel.selectAllScreenshots
                                )
                            }
                            if !report.largePhotos.isEmpty {
                                sectionView(
                                    title: "Large Photos (>5 MB)",
                                    items: report.largePhotos,
                                    totalBytes: report.totalLargePhotoBytes,
                                    selectAll: viewModel.selectAllLargePhotos
                                )
                            }
                        }
                    } else {
                        scanPrompt
                    }
                }
                .padding(20)
                .padding(.bottom, viewModel.selectedCount > 0 ? 70 : 0)
                .frame(maxWidth: 1200)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }

            if viewModel.selectedCount > 0 {
                floatingBar
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .sheet(isPresented: $showTrashConfirm) {
            DoubleConfirmSheet(
                title: "Move \(viewModel.selectedCount) Items to Trash?",
                warning: """
                This will move \(viewModel.selectedCount) photos/screenshots \
                (\(ByteFormatting.string(viewModel.selectedTotalBytes))) to Trash.

                You can restore them from Trash if needed.
                """,
                confirmLabel: "Move to Trash",
                items: viewModel.selectedItems.map { ($0.name, ByteFormatting.string($0.sizeBytes)) },
                onCancel: {
                    showTrashConfirm = false
                },
                onConfirm: {
                    let result = viewModel.moveSelectedToTrash()
                    if result.success {
                        toastManager.show("Moved \(result.trashedCount) items to Trash")
                    } else {
                        toastManager.show(
                            "Trashed \(result.trashedCount) items with \(result.errors.count) errors",
                            isError: true
                        )
                    }
                    showTrashConfirm = false
                }
            )
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Photo Junk")
                    .font(.largeTitle.weight(.bold))
                Text("Find screenshots and oversized photos taking up disk space.")
                    .font(.body)
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
            .disabled(viewModel.isScanning)
        }
    }

    // MARK: - Section

    private func sectionView(
        title: String,
        items: [PhotoJunkItem],
        totalBytes: UInt64,
        selectAll: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title)
                    .font(.headline)
                Text("\(items.count)")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.orange.opacity(0.15))
                    .foregroundStyle(.orange)
                    .clipShape(Capsule())
                Text(ByteFormatting.string(totalBytes))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Select All") { selectAll() }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }

            VStack(spacing: 0) {
                ForEach(items) { item in
                    itemRow(item)
                    if item.id != items.last?.id {
                        Divider().padding(.leading, 44)
                    }
                }
            }
            .background(.thinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Item Row

    private func itemRow(_ item: PhotoJunkItem) -> some View {
        let isSelected = viewModel.selectedPaths.contains(item.path)
        return HStack(spacing: 10) {
            Button { viewModel.toggleSelection(item) } label: {
                Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                    .foregroundStyle(isSelected ? .orange : .secondary)
                    .font(.body)
            }
            .buttonStyle(.plain)

            Image(systemName: item.isScreenshot ? "camera.viewfinder" : "photo")
                .foregroundStyle(.secondary)
                .frame(width: 20)

            Text(item.name)
                .font(.subheadline)
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer()

            if let date = item.createdDate {
                Text(Self.dateFormatter.string(from: date))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Text(ByteFormatting.string(item.sizeBytes))
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .frame(width: 70, alignment: .trailing)

            Button {
                NSWorkspace.shared.selectFile(item.path, inFileViewerRootedAtPath: "")
            } label: {
                Image(systemName: "folder")
                    .font(.caption)
            }
            .buttonStyle(.bordered)
            .controlSize(.mini)
            .help("Reveal in Finder")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    // MARK: - Floating Bar

    private var floatingBar: some View {
        HStack(spacing: 16) {
            Text("\(viewModel.selectedCount) selected")
                .font(.subheadline.weight(.medium))
            Text(ByteFormatting.string(viewModel.selectedTotalBytes))
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Button("Deselect All") { viewModel.deselectAll() }
                .buttonStyle(.bordered)
                .controlSize(.small)
            Button {
                showTrashConfirm = true
            } label: {
                Label("Move to Trash", systemImage: "trash")
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) { Divider() }
    }

    // MARK: - States

    private var loadingState: some View {
        VStack(spacing: 12) {
            ForEach(0..<4, id: \.self) { _ in SkeletonRow() }
        }
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var cleanState: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.08))
                    .frame(width: 80, height: 80)
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(.green.opacity(0.7))
            }
            VStack(spacing: 6) {
                Text("No Photo Junk Found")
                    .font(.title3.weight(.semibold))
                Text("No screenshots or large photos found on your Desktop or Downloads.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 380)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 44)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var scanPrompt: some View {
        Button {
            Task { await viewModel.scan() }
        } label: {
            VStack(spacing: 18) {
                ZStack {
                    Circle()
                        .fill(Color.orange.opacity(0.08))
                        .frame(width: 80, height: 80)
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 44))
                        .foregroundStyle(.orange.opacity(0.6))
                }
                VStack(spacing: 6) {
                    Text("Scan for Photo Junk")
                        .font(.title3.weight(.semibold))
                    Text("Find screenshots and large photos on Desktop and Downloads.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 380)
                }
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.caption.weight(.semibold))
                    Text("Click to scan")
                        .font(.subheadline.weight(.medium))
                }
                .foregroundStyle(.orange)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 44)
            .background(.thinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}
