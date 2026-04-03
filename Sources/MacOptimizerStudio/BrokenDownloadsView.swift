import AppKit
import MacOptimizerStudioCore
import SwiftUI

struct BrokenDownloadsView: View {
    @EnvironmentObject private var viewModel: BrokenDownloadsViewModel
    @EnvironmentObject private var toastManager: ToastManager

    @State private var showTrashConfirm = false

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header

                    if viewModel.isScanning {
                        loadingState
                    } else if let result = viewModel.result {
                        if result.files.isEmpty {
                            cleanState
                        } else {
                            resultsList(result)
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
        .background(DesignTokens.pageBackground)
        .sheet(isPresented: $showTrashConfirm) {
            DoubleConfirmSheet(
                title: "Move \(viewModel.selectedCount) Broken Downloads to Trash?",
                warning: """
                This will move \(viewModel.selectedCount) broken/incomplete download files \
                (\(ByteFormatting.string(viewModel.selectedTotalBytes))) to Trash.

                You can restore them from Trash if needed.
                """,
                confirmLabel: "Move to Trash",
                items: viewModel.selectedItems.map { ($0.name, "\($0.path) — \(ByteFormatting.string($0.sizeBytes))") },
                onCancel: {
                    showTrashConfirm = false
                },
                onConfirm: {
                    let result = viewModel.trashSelected()
                    if result.errors.isEmpty {
                        toastManager.show("Moved \(result.trashed) items to Trash")
                    } else {
                        toastManager.show(
                            "Trashed \(result.trashed) items with \(result.errors.count) errors",
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
                Text("Broken Downloads")
                    .font(.largeTitle.weight(.bold))
                Text("Find and remove incomplete or broken download files.")
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

    // MARK: - Results List

    private func resultsList(_ result: BrokenDownloadsScanResult) -> some View {
        StyledCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    CardSectionHeader(icon: "arrow.down.circle.dotted", title: "Broken Downloads", color: .orange)
                    Text("\(result.files.count)")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.orange.opacity(0.15))
                        .foregroundStyle(.orange)
                        .clipShape(Capsule())
                    Text(ByteFormatting.string(result.totalBytes))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Select All") { viewModel.selectAll() }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                }

                Divider()

                VStack(spacing: 0) {
                    ForEach(result.files) { item in
                        itemRow(item)
                        if item.id != result.files.last?.id {
                            Divider()
                        }
                    }
                }
            }
        }
    }

    // MARK: - Item Row

    private func itemRow(_ item: BrokenDownload) -> some View {
        let isSelected = viewModel.selectedPaths.contains(item.path)
        return HStack(spacing: 10) {
            Button { viewModel.toggleSelection(item) } label: {
                Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                    .foregroundStyle(isSelected ? .orange : .secondary)
                    .font(.body)
            }
            .buttonStyle(.plain)

            Image(systemName: "arrow.down.circle.dotted")
                .foregroundStyle(.secondary)
                .frame(width: 20)

            Text(item.name)
                .font(.subheadline)
                .lineLimit(1)
                .truncationMode(.middle)

            Text(item.downloadType.label)
                .font(.caption2.weight(.semibold))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.orange.opacity(0.12))
                .foregroundStyle(.orange)
                .clipShape(Capsule())

            Spacer()

            if let date = item.modifiedDate {
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
        .padding(.vertical, 4)
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
                Label("Clean Selected", systemImage: "trash")
                    .font(.headline)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .controlSize(.large)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) { Divider() }
    }

    // MARK: - States

    private var loadingState: some View {
        StyledCard {
            VStack(spacing: 12) {
                ForEach(0..<4, id: \.self) { _ in SkeletonRow() }
            }
        }
    }

    private var cleanState: some View {
        StyledCard {
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
                    Text("No Broken Downloads Found")
                        .font(.title3.weight(.semibold))
                    Text("Your Downloads folder is clean - no incomplete or broken download files were found.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 380)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 28)
        }
    }

    private var scanPrompt: some View {
        Button {
            Task { await viewModel.scan() }
        } label: {
            StyledCard {
                VStack(spacing: 18) {
                    ZStack {
                        Circle()
                            .fill(Color.orange.opacity(0.08))
                            .frame(width: 80, height: 80)
                        Image(systemName: "arrow.down.circle.dotted")
                            .font(.system(size: 44))
                            .foregroundStyle(.orange.opacity(0.6))
                    }
                    VStack(spacing: 6) {
                        Text("Scan for Broken Downloads")
                            .font(.title3.weight(.semibold))
                        Text("Find incomplete .crdownload, .part, .tmp, and other broken download files in your Downloads folder.")
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
                .padding(.vertical, 28)
            }
        }
        .buttonStyle(.plain)
    }
}
