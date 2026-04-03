import Foundation

public struct DockerImage: Identifiable, Hashable, Sendable {
    public let id: String
    public let repository: String
    public let tag: String
    public let imageId: String
    public let sizeBytes: UInt64
    public let created: String

    public init(id: String = UUID().uuidString, repository: String, tag: String, imageId: String, sizeBytes: UInt64, created: String) {
        self.id = id
        self.repository = repository
        self.tag = tag
        self.imageId = imageId
        self.sizeBytes = sizeBytes
        self.created = created
    }

    public var displayName: String {
        tag == "<none>" ? repository : "\(repository):\(tag)"
    }
}

public struct DockerVolume: Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let driver: String
    public let mountpoint: String
    public let sizeBytes: UInt64

    public init(id: String = UUID().uuidString, name: String, driver: String, mountpoint: String, sizeBytes: UInt64) {
        self.id = id
        self.name = name
        self.driver = driver
        self.mountpoint = mountpoint
        self.sizeBytes = sizeBytes
    }
}

public struct DockerContainer: Identifiable, Hashable, Sendable {
    public let id: String
    public let containerId: String
    public let name: String
    public let image: String
    public let status: String
    public let sizeBytes: UInt64

    public init(id: String = UUID().uuidString, containerId: String, name: String, image: String, status: String, sizeBytes: UInt64) {
        self.id = id
        self.containerId = containerId
        self.name = name
        self.image = image
        self.status = status
        self.sizeBytes = sizeBytes
    }

    public var isRunning: Bool {
        status.lowercased().contains("up")
    }
}

public struct DockerDiskUsage: Sendable {
    public let imagesTotalBytes: UInt64
    public let containersTotalBytes: UInt64
    public let volumesTotalBytes: UInt64
    public let buildCacheTotalBytes: UInt64
    public let totalBytes: UInt64

    public init(imagesTotalBytes: UInt64, containersTotalBytes: UInt64, volumesTotalBytes: UInt64, buildCacheTotalBytes: UInt64) {
        self.imagesTotalBytes = imagesTotalBytes
        self.containersTotalBytes = containersTotalBytes
        self.volumesTotalBytes = volumesTotalBytes
        self.buildCacheTotalBytes = buildCacheTotalBytes
        self.totalBytes = imagesTotalBytes + containersTotalBytes + volumesTotalBytes + buildCacheTotalBytes
    }
}

public struct DockerSnapshot: Sendable {
    public let capturedAt: Date
    public let isInstalled: Bool
    public let isRunning: Bool
    public let images: [DockerImage]
    public let volumes: [DockerVolume]
    public let containers: [DockerContainer]
    public let diskUsage: DockerDiskUsage?

    public init(capturedAt: Date, isInstalled: Bool, isRunning: Bool, images: [DockerImage], volumes: [DockerVolume], containers: [DockerContainer], diskUsage: DockerDiskUsage?) {
        self.capturedAt = capturedAt
        self.isInstalled = isInstalled
        self.isRunning = isRunning
        self.images = images
        self.volumes = volumes
        self.containers = containers
        self.diskUsage = diskUsage
    }
}
