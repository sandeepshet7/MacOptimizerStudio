import AppKit
import MacOptimizerStudioCore
import SwiftUI

struct ScreenshotOrganizerView: View {
    @EnvironmentObject private var viewModel: ScreenshotOrganizerViewModel
    @EnvironmentObject private var toastManager: ToastManager

    @State private var showOrganizeConfirm = false

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header

                if viewModel.isScanning {
                    loadingState
                } else if viewModel.isOrganizing {
                    organizingState
                } else if let result = viewModel.result {
                    if result.files.isEmpty {
                        cleanState
                    } else {
                        summaryBar(result)
                        destinationPicker
                        folderPreview
                        monthSections(result)
                    }
                } else {
                    scanPrompt
                }
            }
            .padding(20)
            .frame(maxWidth: 1200)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .task {
            if viewModel.result == nil {
                await viewModel.scan()
            }
        }
        .sheet(isPresented: $showOrganizeConfirm) {
            organizeConfirmSheet
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Screenshot Organizer")
                    .font(.largeTitle.weight(.bold))
                Text("Find screenshots on Desktop and Downloads, then organize them into date-based folders.")
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
            .disabled(viewModel.isScanning || viewModel.isOrganizing)
        }
    }

    // MARK: - Summary Bar

    private func summaryBar(_ result: ScreenshotScanResult) -> some View {
        StyledCard {
            HStack(spacing: 20) {
                summaryItem(
                    label: "Total Screenshots",
                    value: "\(result.files.count)",
                    icon: "camera.viewfinder"
                )
                Divider().frame(height: 32)
                summaryItem(
                    label: "Total Size",
                    value: ByteFormatting.string(result.totalBytes),
                    icon: "internaldrive"
                )
                Divider().frame(height: 32)
                summaryItem(
                    label: "Months",
                    value: "\(result.byMonth.count)",
                    icon: "calendar"
                )
                Spacer()
                Button {
                    showOrganizeConfirm = true
                } label: {
                    Label("Organize All", systemImage: "folder.badge.gearshape")
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                .disabled(viewModel.destinationURL == nil)
            }
        }
    }

    private func summaryItem(label: String, value: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(.orange)
                .font(.title3)
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.headline)
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Destination Picker

    private var destinationPicker: some View {
        StyledCard {
            HStack(spacing: 10) {
                Image(systemName: "folder.fill")
                    .foregroundStyle(.orange)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Destination Folder")
                        .font(.subheadline.weight(.medium))
                    if let url = viewModel.destinationURL {
                        Text(url.path)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.head)
                    } else {
                        Text("No folder selected")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                Spacer()
                Button("Choose...") {
                    chooseDestination()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
    }

    private func chooseDestination() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.title = "Choose Destination Folder"
        panel.prompt = "Select"

        if panel.runModal() == .OK, let url = panel.url {
            viewModel.destinationURL = url
        }
    }

    // MARK: - Folder Preview

    private var folderPreview: some View {
        StyledCard {
            VStack(alignment: .leading, spacing: 8) {
                CardSectionHeader(icon: "folder.badge.questionmark", title: "Folder Structure Preview", color: .blue)

                let preview = viewModel.folderPreview
                if !preview.isEmpty, let dest = viewModel.destinationURL {
                    Divider()

                    HStack(spacing: 6) {
                        Image(systemName: "folder.fill")
                            .foregroundStyle(.orange)
                        Text(dest.lastPathComponent)
                            .font(.subheadline.weight(.medium))
                    }
                    .padding(.vertical, 4)

                    ForEach(Array(preview.enumerated()), id: \.offset) { _, item in
                        HStack(spacing: 6) {
                            Image(systemName: "folder")
                                .foregroundStyle(.secondary)
                            Text(item.folderName)
                                .font(.caption)
                            Spacer()
                            Text("\(item.count) files")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(ByteFormatting.string(item.totalBytes))
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.leading, 20)
                    }
                }
            }
        }
    }

    // MARK: - Month Sections

    private func monthSections(_ result: ScreenshotScanResult) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(result.sortedMonthKeys, id: \.self) { monthKey in
                if let files = result.byMonth[monthKey] {
                    monthSection(monthKey: monthKey, files: files)
                }
            }
        }
    }

    private func monthSection(monthKey: String, files: [ScreenshotFile]) -> some View {
        let totalBytes = files.reduce(0 as UInt64) { $0 + $1.sizeBytes }

        return StyledCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    CardSectionHeader(icon: "calendar", title: displayMonthName(monthKey), color: .orange)
                    Text("\(files.count)")
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
                }

                Divider()

                VStack(spacing: 0) {
                    ForEach(files) { file in
                        fileRow(file)
                        if file.id != files.last?.id {
                            Divider()
                        }
                    }
                }
            }
        }
    }

    private func fileRow(_ file: ScreenshotFile) -> some View {
        HStack(spacing: 10) {
            fileIcon(for: file)

            Text(file.name)
                .font(.subheadline)
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer()

            Text(Self.dateFormatter.string(from: file.createdDate))
                .font(.caption)
                .foregroundStyle(.tertiary)

            Text(ByteFormatting.string(file.sizeBytes))
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .frame(width: 70, alignment: .trailing)

            Button {
                NSWorkspace.shared.selectFile(file.path, inFileViewerRootedAtPath: "")
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

    private func fileIcon(for file: ScreenshotFile) -> some View {
        let ext = (file.name as NSString).pathExtension.lowercased()
        let iconName: String
        if ext == "mov" || ext == "mp4" {
            iconName = "video.fill"
        } else {
            iconName = "camera.viewfinder"
        }
        return Image(systemName: iconName)
            .foregroundStyle(.secondary)
            .frame(width: 20)
    }

    // MARK: - Organize Confirm

    private var organizeConfirmSheet: some View {
        DoubleConfirmSheet(
            title: "Organize \(viewModel.result?.files.count ?? 0) Screenshots?",
            warning: """
            This will move \(viewModel.result?.files.count ?? 0) screenshots \
            (\(ByteFormatting.string(viewModel.result?.totalBytes ?? 0))) \
            into date-based subfolders at:

            \(viewModel.destinationURL?.path ?? "Unknown")

            Files will be moved, not copied. The originals will no longer be \
            in their current locations.
            """,
            confirmLabel: "Organize",
            onCancel: {
                showOrganizeConfirm = false
            },
            onConfirm: {
                showOrganizeConfirm = false
                let result = await viewModel.organize()
                if result.errors.isEmpty {
                    toastManager.show("Organized \(result.moved) screenshots into folders")
                } else {
                    toastManager.show(
                        "Moved \(result.moved) files with \(result.errors.count) errors",
                        isError: true
                    )
                }
            }
        )
    }

    // MARK: - Month Display

    private func displayMonthName(_ monthKey: String) -> String {
        let parts = monthKey.split(separator: "-")
        guard parts.count == 2,
              let year = Int(parts[0]),
              let month = Int(parts[1])
        else {
            return monthKey
        }

        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = 1

        guard let date = Calendar.current.date(from: components) else {
            return monthKey
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
    }

    // MARK: - States

    private var loadingState: some View {
        StyledCard {
            VStack(spacing: 12) {
                ForEach(0..<4, id: \.self) { _ in SkeletonRow() }
            }
        }
    }

    private var organizingState: some View {
        StyledCard {
            VStack(spacing: 18) {
                ProgressView()
                    .controlSize(.large)
                Text("Organizing screenshots...")
                    .font(.title3.weight(.semibold))
                Text("Moving files into date-based folders.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 28)
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
                    Text("No Screenshots Found")
                        .font(.title3.weight(.semibold))
                    Text("No screenshots or screen recordings found on Desktop or Downloads.")
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
                        Image(systemName: "camera.viewfinder")
                            .font(.system(size: 44))
                            .foregroundStyle(.orange.opacity(0.6))
                    }
                    VStack(spacing: 6) {
                        Text("Scan for Screenshots")
                            .font(.title3.weight(.semibold))
                        Text("Find screenshots and screen recordings on Desktop and Downloads.")
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
