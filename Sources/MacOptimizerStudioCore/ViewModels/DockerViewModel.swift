import Foundation

@MainActor
public final class DockerViewModel: ObservableObject {
    @Published public private(set) var snapshot: DockerSnapshot?
    @Published public private(set) var isLoading = false
    @Published public private(set) var lastError: String?
    @Published public var selectedImageIds: Set<String> = []
    @Published public var selectedVolumeNames: Set<String> = []

    private let service: DockerService
    private let auditLog: AuditLogService

    public init(service: DockerService = DockerService(), auditLog: AuditLogService = AuditLogService()) {
        self.service = service
        self.auditLog = auditLog
    }

    public func refresh() async {
        isLoading = true
        lastError = nil
        defer { isLoading = false }

        let svc = service
        let result = await Task.detached(priority: .userInitiated) {
            svc.fetchSnapshot()
        }.value

        snapshot = result
    }

    public func removeImage(_ image: DockerImage) async -> Bool {
        let svc = service
        let success = await Task.detached {
            svc.removeImage(id: image.imageId)
        }.value
        if success {
            let log = auditLog
            Task.detached { log.log(AuditLogEntry(action: .dockerImageRemoved, details: "Removed image \(image.displayName) (\(image.imageId))", paths: [image.imageId], totalBytes: image.sizeBytes)) }
            await refresh()
        } else {
            lastError = "Failed to remove image \(image.displayName)"
            ErrorCollector.shared.record(source: "Docker", message: "Failed to remove image \(image.displayName)")
        }
        return success
    }

    public func removeVolume(_ volume: DockerVolume) async -> Bool {
        let svc = service
        let success = await Task.detached {
            svc.removeVolume(name: volume.name)
        }.value
        if success {
            let log = auditLog
            Task.detached { log.log(AuditLogEntry(action: .dockerVolumeRemoved, details: "Removed volume \(volume.name)", paths: [volume.name], totalBytes: volume.sizeBytes)) }
            await refresh()
        } else {
            lastError = "Failed to remove volume \(volume.name)"
            ErrorCollector.shared.record(source: "Docker", message: "Failed to remove volume \(volume.name)")
        }
        return success
    }

    public func removeContainer(_ container: DockerContainer, force: Bool = false) async -> Bool {
        let svc = service
        let success = await Task.detached {
            svc.removeContainer(id: container.containerId, force: force)
        }.value
        if success {
            let log = auditLog
            Task.detached { log.log(AuditLogEntry(action: .dockerContainerRemoved, details: "Removed container \(container.name) (image: \(container.image))\(force ? " [forced]" : "")", paths: [container.containerId], totalBytes: container.sizeBytes)) }
            await refresh()
        } else {
            lastError = "Failed to remove container \(container.name)"
            ErrorCollector.shared.record(source: "Docker", message: "Failed to remove container \(container.name)")
        }
        return success
    }

    public func pruneImages() async -> String? {
        let svc = service
        let result = await Task.detached {
            svc.pruneImages()
        }.value
        if result != nil {
            let log = auditLog
            Task.detached { log.log(AuditLogEntry(action: .dockerPrune, details: "Pruned all unused Docker images")) }
        }
        await refresh()
        return result
    }

    public func pruneSystem() async -> String? {
        let svc = service
        let result = await Task.detached {
            svc.pruneSystem()
        }.value
        if result != nil {
            let log = auditLog
            Task.detached { log.log(AuditLogEntry(action: .dockerPrune, details: "Pruned entire Docker system (images, containers, volumes, build cache)")) }
        }
        await refresh()
        return result
    }

    public var totalDiskUsage: UInt64 {
        snapshot?.diskUsage?.totalBytes ?? 0
    }

    public var imageCount: Int {
        snapshot?.images.count ?? 0
    }

    public var volumeCount: Int {
        snapshot?.volumes.count ?? 0
    }

    public var containerCount: Int {
        snapshot?.containers.count ?? 0
    }

    public var runningContainerCount: Int {
        snapshot?.containers.filter(\.isRunning).count ?? 0
    }
}
