import AppKit
import MacOptimizerStudioCore
import SwiftUI

struct ExtensionManagerView: View {
    @EnvironmentObject private var viewModel: ExtensionManagerViewModel
    @EnvironmentObject private var toastManager: ToastManager

    @State private var pendingRemoval: SystemExtension?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header

                if viewModel.isScanning {
                    loadingState
                } else if viewModel.hasScanned && viewModel.extensions.isEmpty {
                    emptyState
                } else if viewModel.hasScanned {
                    filterBar
                    extensionList
                } else {
                    scanPrompt
                }
            }
            .padding(20)
            .frame(maxWidth: 1200)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .sheet(item: $pendingRemoval) { ext in
            DoubleConfirmSheet(
                title: "Remove \"\(ext.name)\"?",
                warning: "This will move the extension to Trash:\n\n\(ext.path)\n\nYou can restore it from Trash if needed.",
                confirmLabel: "Move to Trash"
            ) {
                pendingRemoval = nil
            } onConfirm: {
                do {
                    try viewModel.removeExtension(ext)
                    toastManager.show("Removed \(ext.name)")
                } catch {
                    toastManager.show("Failed to remove: \(error.localizedDescription)", isError: true)
                }
                pendingRemoval = nil
            }
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Extensions")
                    .font(.largeTitle.weight(.bold))
                Text("Manage system extensions, plugins, and preference panes.")
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

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                filterChip(label: "All (\(viewModel.extensions.count))", isActive: viewModel.selectedFilter == nil) {
                    viewModel.selectedFilter = nil
                }
                ForEach(viewModel.typeCounts, id: \.0) { type, count in
                    filterChip(label: "\(type.rawValue) (\(count))", isActive: viewModel.selectedFilter == type) {
                        viewModel.selectedFilter = type
                    }
                }
            }
        }
    }

    private func filterChip(label: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.caption.weight(.medium))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(isActive ? Color.orange.opacity(0.15) : Color.primary.opacity(0.05))
                .foregroundStyle(isActive ? .orange : .primary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private var extensionList: some View {
        LazyVStack(spacing: 0) {
            ForEach(viewModel.filteredExtensions) { ext in
                extensionRow(ext)
                if ext.id != viewModel.filteredExtensions.last?.id {
                    Divider().padding(.leading, 52)
                }
            }
        }
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func extensionRow(_ ext: SystemExtension) -> some View {
        HStack(spacing: 12) {
            Image(systemName: ext.type.icon)
                .font(.title2)
                .foregroundStyle(colorForType(ext.type))
                .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(ext.name)
                    .font(.body.weight(.medium))
                Text(ext.type.rawValue)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(ByteFormatting.string(ext.sizeBytes))
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)

            Button {
                NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: (ext.path as NSString).deletingLastPathComponent)
            } label: {
                Image(systemName: "folder")
                    .font(.caption)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .help("Reveal in Finder")

            Button {
                pendingRemoval = ext
            } label: {
                Image(systemName: "trash")
                    .font(.caption)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .tint(.red)
            .help("Remove extension")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private func colorForType(_ type: ExtensionType) -> Color {
        switch type {
        case .safariExtension: return .blue
        case .spotlightPlugin: return .purple
        case .quickLookPlugin: return .cyan
        case .preferencePanes: return .gray
        case .inputMethod: return .green
        case .screenSaver: return .indigo
        }
    }

    // MARK: - States

    private var loadingState: some View {
        VStack(spacing: 12) {
            ForEach(0..<4, id: \.self) { _ in
                SkeletonRow()
            }
        }
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var emptyState: some View {
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
                Text("No Extensions Found")
                    .font(.title3.weight(.semibold))
                Text("No third-party system extensions, plugins, or preference panes detected.")
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
                    Image(systemName: "puzzlepiece.extension.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(.orange.opacity(0.6))
                }
                VStack(spacing: 6) {
                    Text("Scan Extensions")
                        .font(.title3.weight(.semibold))
                    Text("Find Safari extensions, QuickLook plugins, preference panes, and more.")
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
