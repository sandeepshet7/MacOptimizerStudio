import AppKit
import MacOptimizerStudioCore
import SwiftUI
import UniformTypeIdentifiers

struct FileShredderView: View {
    @EnvironmentObject private var viewModel: FileShredderViewModel
    @EnvironmentObject private var toastManager: ToastManager

    @State private var showShredConfirm = false
    @State private var isDragOver = false

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header

                    if viewModel.isShredding {
                        shreddingProgress
                    }

                    if viewModel.files.isEmpty && !viewModel.isShredding {
                        dropZone
                    } else {
                        fileList
                    }
                }
                .padding(20)
                .padding(.bottom, !viewModel.files.isEmpty && !viewModel.isShredding ? 70 : 0)
                .frame(maxWidth: 1200)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }

            if !viewModel.files.isEmpty && !viewModel.isShredding {
                floatingBar
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .onDrop(of: [.fileURL], isTargeted: $isDragOver) { providers in
            handleDrop(providers)
        }
        .sheet(isPresented: $showShredConfirm) {
            DoubleConfirmSheet(
                title: "Permanently Shred \(viewModel.files.count) File(s)?",
                warning: """
                You are about to securely shred \(viewModel.files.count) file(s) \
                (\(ByteFormatting.string(viewModel.totalBytes))).

                Each file will be overwritten 3 times with random data before deletion. \
                This action is PERMANENT and IRREVERSIBLE. Files cannot be recovered \
                from Trash or by any recovery tool.

                Files to shred:
                \(viewModel.files.prefix(8).map { "  - \($0.name) (\(ByteFormatting.string($0.sizeBytes)))" }.joined(separator: "\n"))
                \(viewModel.files.count > 8 ? "  ... and \(viewModel.files.count - 8) more" : "")
                """,
                confirmLabel: "Shred Permanently",
                onCancel: {
                    showShredConfirm = false
                },
                onConfirm: {
                    let result = await viewModel.shredAll()
                    showShredConfirm = false
                    if result.success {
                        toastManager.show("Securely shredded \(result.shreddedCount) file(s)")
                    } else {
                        toastManager.show(
                            "Shredded \(result.shreddedCount) file(s) with \(result.errors.count) error(s)",
                            isError: true
                        )
                    }
                }
            )
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("File Shredder")
                        .font(.largeTitle.weight(.bold))
                    Text("Securely erase files by overwriting with random data before deletion.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    openFilePicker()
                } label: {
                    Label("Add Files", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                .disabled(viewModel.isShredding)
            }

            StyledCard {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.body)
                        .foregroundStyle(.red)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Permanent Deletion")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.red)
                        Text("Files added here will be overwritten 3 times with random data and then permanently deleted. This cannot be undone — files will NOT go to Trash and cannot be recovered by any tool.")
                            .font(.caption)
                            .foregroundStyle(.red.opacity(0.8))
                    }
                }
            }
        }
    }

    // MARK: - Drop Zone

    private var dropZone: some View {
        Button {
            openFilePicker()
        } label: {
            StyledCard {
                VStack(spacing: 18) {
                    ZStack {
                        Circle()
                            .fill(Color.orange.opacity(isDragOver ? 0.2 : 0.08))
                            .frame(width: 80, height: 80)
                        Image(systemName: "doc.zipper")
                            .font(.system(size: 44))
                            .foregroundStyle(.orange.opacity(0.6))
                    }
                    VStack(spacing: 6) {
                        Text("Drop Files to Shred")
                            .font(.title3.weight(.semibold))
                        Text("Drag and drop files here, or click to browse. Files will be securely overwritten 3 times with random data before permanent deletion.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 440)
                    }
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle")
                            .font(.caption.weight(.semibold))
                        Text("Click to add files")
                            .font(.subheadline.weight(.medium))
                    }
                    .foregroundStyle(.orange)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 28)
            }
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(
                        isDragOver ? Color.orange : Color.clear,
                        style: StrokeStyle(lineWidth: 2, dash: [8])
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - File List

    private var fileList: some View {
        StyledCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    CardSectionHeader(icon: "doc.fill", title: "Files to Shred", color: .orange)
                    Text("\(viewModel.files.count)")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.orange.opacity(0.15))
                        .foregroundStyle(.orange)
                        .clipShape(Capsule())
                    Text(ByteFormatting.string(viewModel.totalBytes))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    if !viewModel.isShredding {
                        Button("Clear All") { viewModel.clearAll() }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                    }
                }

                Divider()

                LazyVStack(spacing: 0) {
                    ForEach(viewModel.files) { item in
                        fileRow(item)
                        if item.id != viewModel.files.last?.id {
                            Divider()
                        }
                    }
                }
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(
                    isDragOver ? Color.orange : Color.clear,
                    style: StrokeStyle(lineWidth: 2, dash: [8])
                )
        )
    }

    private func fileRow(_ item: ShredderFileItem) -> some View {
        HStack(spacing: 10) {
            Image(systemName: item.isDirectory ? "folder.fill" : "doc.fill")
                .foregroundStyle(.orange.opacity(0.7))
                .frame(width: 20)

            Text(item.name)
                .font(.subheadline)
                .lineLimit(1)
                .truncationMode(.middle)

            Text(item.path)
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(.tertiary)
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer()

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

            if !viewModel.isShredding {
                Button {
                    viewModel.removeFile(item)
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)
                .help("Remove from list")
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Shredding Progress

    private var shreddingProgress: some View {
        StyledCard {
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    ProgressView()
                        .controlSize(.small)
                    Text(viewModel.progressMessage)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(viewModel.shreddedCount)/\(viewModel.totalToShred)")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }

                ProgressView(
                    value: Double(viewModel.shreddedCount),
                    total: max(Double(viewModel.totalToShred), 1)
                )
                .tint(.orange)
            }
        }
    }

    // MARK: - Floating Bar

    private var floatingBar: some View {
        HStack(spacing: 16) {
            Text("\(viewModel.files.count) file(s)")
                .font(.subheadline.weight(.medium))
            Text(ByteFormatting.string(viewModel.totalBytes))
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Button {
                openFilePicker()
            } label: {
                Label("Add More", systemImage: "plus")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            Button {
                showShredConfirm = true
            } label: {
                Label("Shred All", systemImage: "flame.fill")
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) { Divider() }
    }

    // MARK: - Helpers

    private func openFilePicker() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = true
        panel.canChooseFiles = true
        panel.title = "Select Files to Shred"
        panel.prompt = "Add"

        if panel.runModal() == .OK {
            viewModel.addFiles(urls: panel.urls)
        }
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        var urls: [URL] = []
        let group = DispatchGroup()

        for provider in providers {
            group.enter()
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                if let url {
                    urls.append(url)
                }
                group.leave()
            }
        }

        group.notify(queue: .main) {
            viewModel.addFiles(urls: urls)
        }

        return true
    }
}
