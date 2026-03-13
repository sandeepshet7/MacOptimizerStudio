import MacOptimizerStudioCore
import SwiftUI

struct DockerView: View {
    @EnvironmentObject private var dockerViewModel: DockerViewModel
    @EnvironmentObject private var toastManager: ToastManager

    @State private var pendingDeleteImage: DockerImage?
    @State private var pendingDeleteVolume: DockerVolume?
    @State private var pendingDeleteContainer: DockerContainer?
    @State private var pendingPruneType: PruneType?
    @State private var filterText = ""

    private enum PruneType: Identifiable {
        case images, system
        var id: String {
            switch self {
            case .images: return "images"
            case .system: return "system"
            }
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                if let snapshot = dockerViewModel.snapshot {
                    if !snapshot.isInstalled {
                        notInstalledState
                    } else if !snapshot.isRunning {
                        notRunningState
                    } else {
                        diskUsageCards
                        if !filteredContainers.isEmpty { containersSection(filteredContainers) }
                        imagesSection(filteredImages)
                        volumesSection(filteredVolumes)
                    }
                } else if dockerViewModel.isLoading {
                    loadingState
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
            if dockerViewModel.snapshot == nil {
                await dockerViewModel.refresh()
            }
        }
        .sheet(item: $pendingDeleteImage) { image in
            deleteImageSheet(image)
        }
        .sheet(item: $pendingDeleteVolume) { volume in
            deleteVolumeSheet(volume)
        }
        .sheet(item: $pendingDeleteContainer) { container in
            deleteContainerSheet(container)
        }
        .sheet(item: $pendingPruneType) { pruneType in
            pruneSheet(pruneType)
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Docker")
                        .font(.largeTitle.weight(.bold))
                    Text("Manage images, volumes, containers, and disk usage.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    Task { await dockerViewModel.refresh() }
                } label: {
                    Label(dockerViewModel.isLoading ? "Refreshing..." : "Refresh", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                .disabled(dockerViewModel.isLoading)

                TextField("Filter", text: $filterText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 160)
            }
        }
    }

    // MARK: - States

    private var notInstalledState: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(Color.secondary.opacity(0.08))
                    .frame(width: 80, height: 80)
                Image(systemName: "shippingbox.circle.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(.secondary.opacity(0.6))
            }
            VStack(spacing: 6) {
                Text("Docker Not Installed")
                    .font(.title3.weight(.semibold))
                Text("Install Docker Desktop to manage containers, images, and volumes.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 380)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 44)
        .background(panelFill)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var notRunningState: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.08))
                    .frame(width: 80, height: 80)
                Image(systemName: "power.circle.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(.orange.opacity(0.7))
            }
            VStack(spacing: 6) {
                Text("Docker Not Running")
                    .font(.title3.weight(.semibold))
                Text("Start Docker Desktop to view and manage your Docker resources.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 380)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 44)
        .background(panelFill)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var loadingState: some View {
        VStack(spacing: 12) {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 12)], spacing: 12) {
                ForEach(0..<5, id: \.self) { _ in
                    SkeletonCard(height: 70)
                }
            }
            ForEach(0..<2, id: \.self) { _ in
                VStack(spacing: 0) {
                    SkeletonRow()
                    Divider()
                    SkeletonRow()
                    Divider()
                    SkeletonRow()
                }
                .background(.thinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    private var emptyState: some View {
        Button {
            Task { await dockerViewModel.refresh() }
        } label: {
            VStack(spacing: 18) {
                ZStack {
                    Circle()
                        .fill(Color.indigo.opacity(0.08))
                        .frame(width: 80, height: 80)
                    Image(systemName: "shippingbox.circle.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(.indigo.opacity(0.6))
                }
                VStack(spacing: 6) {
                    Text("Load Docker Data")
                        .font(.title3.weight(.semibold))
                    Text("Check images, volumes, containers, and disk usage.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 380)
                }
                HStack(spacing: 6) {
                    Image(systemName: "arrow.clockwise")
                        .font(.caption.weight(.semibold))
                    Text("Click to refresh")
                        .font(.subheadline.weight(.medium))
                }
                .foregroundStyle(.orange)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 44)
            .background(panelFill)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Disk Usage Cards

    private var diskUsageCards: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Disk Usage")
                    .font(.headline)
                Spacer()

                Button {
                    pendingPruneType = .images
                } label: {
                    Label("Prune Images", systemImage: "trash")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button {
                    pendingPruneType = .system
                } label: {
                    Label("Prune All", systemImage: "trash.fill")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .tint(.red)
            }

            if let usage = dockerViewModel.snapshot?.diskUsage {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 12)], spacing: 12) {
                    usageCard(title: "Total", bytes: usage.totalBytes, tint: .orange, icon: "shippingbox.fill")
                    usageCard(title: "Images", bytes: usage.imagesTotalBytes, tint: .blue, icon: "square.stack.3d.up.fill")
                    usageCard(title: "Containers", bytes: usage.containersTotalBytes, tint: .green, icon: "cube.fill")
                    usageCard(title: "Volumes", bytes: usage.volumesTotalBytes, tint: .purple, icon: "externaldrive.fill")
                    usageCard(title: "Build Cache", bytes: usage.buildCacheTotalBytes, tint: .cyan, icon: "hammer.fill")
                }
            }
        }
    }

    private func usageCard(title: String, bytes: UInt64, tint: Color, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .foregroundStyle(tint)
                Text(title)
                    .font(.caption.weight(.semibold))
            }
            Text(ByteFormatting.string(bytes))
                .font(.title3.weight(.bold))
                .animation(.easeInOut(duration: 0.4), value: bytes)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(panelFill)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(tint.opacity(0.15), lineWidth: 1)
        )
    }

    // MARK: - Containers

    private func containersSection(_ containers: [DockerContainer]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Containers")
                    .font(.headline)
                Text("\(containers.count)")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.green.opacity(0.15))
                    .foregroundStyle(.green)
                    .clipShape(Capsule())
                Spacer()
            }

            VStack(spacing: 0) {
                containerHeader
                Divider()
                ForEach(containers) { container in
                    containerRow(container)
                    Divider()
                }
            }
            .background(panelFill)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    private var containerHeader: some View {
        HStack(spacing: 0) {
            Text("Name").frame(maxWidth: .infinity, alignment: .leading)
            Text("Image").frame(width: 180, alignment: .leading)
            Text("Status").frame(width: 120, alignment: .leading)
            Text("Size").frame(width: 80, alignment: .trailing)
            Text("Actions").frame(width: 80, alignment: .center)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.primary.opacity(0.03))
    }

    private func containerRow(_ container: DockerContainer) -> some View {
        HStack(spacing: 0) {
            HStack(spacing: 6) {
                Circle()
                    .fill(container.isRunning ? .green : .secondary.opacity(0.4))
                    .frame(width: 7, height: 7)
                Text(container.name)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(container.image)
                .font(.caption)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(width: 180, alignment: .leading)
                .foregroundStyle(.secondary)

            Text(container.isRunning ? "Running" : "Stopped")
                .font(.caption)
                .foregroundStyle(container.isRunning ? .green : .secondary)
                .frame(width: 120, alignment: .leading)

            Text(ByteFormatting.string(container.sizeBytes))
                .frame(width: 80, alignment: .trailing)
                .foregroundStyle(.secondary)

            Button {
                pendingDeleteContainer = container
            } label: {
                Image(systemName: "trash")
                    .foregroundStyle(.red)
            }
            .buttonStyle(.plain)
            .frame(width: 80, alignment: .center)
            .disabled(container.isRunning)
        }
        .font(.subheadline)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    // MARK: - Images

    private func imagesSection(_ images: [DockerImage]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Images")
                    .font(.headline)
                Text("\(images.count)")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.blue.opacity(0.15))
                    .foregroundStyle(.blue)
                    .clipShape(Capsule())
                Spacer()
            }

            if images.isEmpty {
                Text("No Docker images found.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 12)
            } else {
                VStack(spacing: 0) {
                    imageHeader
                    Divider()
                    ForEach(images) { image in
                        imageRow(image)
                        Divider()
                    }
                }
                .background(panelFill)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    private var imageHeader: some View {
        HStack(spacing: 0) {
            Text("Repository:Tag").frame(maxWidth: .infinity, alignment: .leading)
            Text("Image ID").frame(width: 100, alignment: .leading)
            Text("Created").frame(width: 120, alignment: .leading)
            Text("Size").frame(width: 80, alignment: .trailing)
            Text("Actions").frame(width: 80, alignment: .center)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.primary.opacity(0.03))
    }

    private func imageRow(_ image: DockerImage) -> some View {
        HStack(spacing: 0) {
            Text(image.displayName)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(image.imageId.prefix(12))
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 100, alignment: .leading)

            Text(image.created)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .frame(width: 120, alignment: .leading)

            Text(ByteFormatting.string(image.sizeBytes))
                .font(.subheadline.weight(.medium))
                .foregroundStyle(image.sizeBytes > 1_000_000_000 ? .orange : .primary)
                .frame(width: 80, alignment: .trailing)

            Button {
                pendingDeleteImage = image
            } label: {
                Image(systemName: "trash")
                    .foregroundStyle(.red)
            }
            .buttonStyle(.plain)
            .frame(width: 80, alignment: .center)
        }
        .font(.subheadline)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    // MARK: - Volumes

    private func volumesSection(_ volumes: [DockerVolume]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Volumes")
                    .font(.headline)
                Text("\(volumes.count)")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.purple.opacity(0.15))
                    .foregroundStyle(.purple)
                    .clipShape(Capsule())
                Spacer()
            }

            if volumes.isEmpty {
                Text("No Docker volumes found.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 12)
            } else {
                VStack(spacing: 0) {
                    volumeHeader
                    Divider()
                    ForEach(volumes) { volume in
                        volumeRow(volume)
                        Divider()
                    }
                }
                .background(panelFill)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    private var volumeHeader: some View {
        HStack(spacing: 0) {
            Text("Volume Name").frame(maxWidth: .infinity, alignment: .leading)
            Text("Driver").frame(width: 80, alignment: .leading)
            Text("Size").frame(width: 80, alignment: .trailing)
            Text("Actions").frame(width: 80, alignment: .center)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.primary.opacity(0.03))
    }

    private func volumeRow(_ volume: DockerVolume) -> some View {
        HStack(spacing: 0) {
            Text(volume.name)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(volume.driver)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 80, alignment: .leading)

            Text(volume.sizeBytes > 0 ? ByteFormatting.string(volume.sizeBytes) : "-")
                .foregroundStyle(.secondary)
                .frame(width: 80, alignment: .trailing)

            Button {
                pendingDeleteVolume = volume
            } label: {
                Image(systemName: "trash")
                    .foregroundStyle(.red)
            }
            .buttonStyle(.plain)
            .frame(width: 80, alignment: .center)
        }
        .font(.subheadline)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    // MARK: - Delete Sheets (Double Confirmation)

    private func deleteImageSheet(_ image: DockerImage) -> some View {
        DoubleConfirmSheet(
            title: "Delete Docker Image",
            warning: "You are about to permanently delete this Docker image. Any containers using it must be removed first.",
            confirmLabel: "Delete Image",
            items: [(image.displayName, "ID: \(image.imageId) — \(ByteFormatting.string(image.sizeBytes))")],
            onCancel: { pendingDeleteImage = nil },
            onConfirm: {
                let success = await dockerViewModel.removeImage(image)
                toastManager.show(success ? "Removed image \(image.displayName)" : "Failed to remove image", isError: !success)
                pendingDeleteImage = nil
            }
        )
    }

    private func deleteVolumeSheet(_ volume: DockerVolume) -> some View {
        DoubleConfirmSheet(
            title: "Delete Docker Volume",
            warning: "Data stored in this volume will be permanently lost. This action cannot be undone.",
            confirmLabel: "Delete Volume",
            items: [(volume.name, "Driver: \(volume.driver) — \(ByteFormatting.string(volume.sizeBytes))")],
            onCancel: { pendingDeleteVolume = nil },
            onConfirm: {
                let success = await dockerViewModel.removeVolume(volume)
                toastManager.show(success ? "Removed volume \(volume.name)" : "Failed to remove volume", isError: !success)
                pendingDeleteVolume = nil
            }
        )
    }

    private func deleteContainerSheet(_ container: DockerContainer) -> some View {
        DoubleConfirmSheet(
            title: "Remove Docker Container",
            warning: "You are about to remove this container. Any unsaved data inside the container will be lost.",
            confirmLabel: "Remove Container",
            items: [(container.name, "Image: \(container.image) — Status: \(container.status)")],
            onCancel: { pendingDeleteContainer = nil },
            onConfirm: {
                let success = await dockerViewModel.removeContainer(container)
                toastManager.show(success ? "Removed container \(container.name)" : "Failed to remove container", isError: !success)
                pendingDeleteContainer = nil
            }
        )
    }

    private func pruneSheet(_ pruneType: PruneType) -> some View {
        let title = pruneType == .images ? "Prune All Unused Images" : "Prune Entire Docker System"
        let warning = pruneType == .images
            ? "This will remove all unused Docker images. Images in use by containers will not be affected."
            : "This will remove ALL unused containers, images, volumes, networks, and build cache. This action is IRREVERSIBLE."

        return DoubleConfirmSheet(
            title: title,
            warning: warning,
            confirmLabel: pruneType == .images ? "Prune Images" : "Prune System",
            onCancel: { pendingPruneType = nil },
            onConfirm: {
                let result: String?
                if pruneType == .images {
                    result = await dockerViewModel.pruneImages()
                } else {
                    result = await dockerViewModel.pruneSystem()
                }
                toastManager.show(result != nil ? "Prune completed successfully" : "Prune failed", isError: result == nil)
                pendingPruneType = nil
            }
        )
    }

    // MARK: - Filtering

    private var filteredImages: [DockerImage] {
        guard let images = dockerViewModel.snapshot?.images else { return [] }
        if filterText.isEmpty { return images }
        let needle = filterText.lowercased()
        return images.filter { $0.displayName.lowercased().contains(needle) }
    }

    private var filteredVolumes: [DockerVolume] {
        guard let volumes = dockerViewModel.snapshot?.volumes else { return [] }
        if filterText.isEmpty { return volumes }
        let needle = filterText.lowercased()
        return volumes.filter { $0.name.lowercased().contains(needle) }
    }

    private var filteredContainers: [DockerContainer] {
        guard let containers = dockerViewModel.snapshot?.containers else { return [] }
        if filterText.isEmpty { return containers }
        let needle = filterText.lowercased()
        return containers.filter { $0.name.lowercased().contains(needle) || $0.image.lowercased().contains(needle) }
    }

    private var panelFill: some ShapeStyle {
        .thinMaterial
    }
}
