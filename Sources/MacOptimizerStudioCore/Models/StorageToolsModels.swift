import Foundation

// MARK: - Space Lens

public struct FolderNode: Identifiable, Sendable {
    public let id: String
    public let name: String
    public let sizeBytes: UInt64
    public let children: [FolderNode]
    public let fileCount: Int
    public let isDirectory: Bool

    public init(id: String, name: String, sizeBytes: UInt64, children: [FolderNode], fileCount: Int, isDirectory: Bool) {
        self.id = id
        self.name = name
        self.sizeBytes = sizeBytes
        self.children = children
        self.fileCount = fileCount
        self.isDirectory = isDirectory
    }

    public var sortedChildren: [FolderNode] {
        children.sorted { $0.sizeBytes > $1.sizeBytes }
    }
}

// MARK: - Duplicate Finder

public struct DuplicateGroup: Identifiable, Sendable {
    public let id: String
    public let fileSize: UInt64
    public let paths: [String]

    public init(id: String, fileSize: UInt64, paths: [String]) {
        self.id = id
        self.fileSize = fileSize
        self.paths = paths
    }

    public var wastedBytes: UInt64 {
        fileSize * UInt64(max(paths.count - 1, 0))
    }

    public var fileName: String {
        (paths.first as NSString?)?.lastPathComponent ?? "Unknown"
    }
}

// MARK: - Large & Old Files

public struct LargeFile: Identifiable, Sendable {
    public let id: String
    public let name: String
    public let path: String
    public let sizeBytes: UInt64
    public let lastAccessed: Date?
    public let lastModified: Date?

    public init(path: String, name: String, sizeBytes: UInt64, lastAccessed: Date?, lastModified: Date?) {
        self.id = path
        self.name = name
        self.path = path
        self.sizeBytes = sizeBytes
        self.lastAccessed = lastAccessed
        self.lastModified = lastModified
    }

    public var daysSinceAccess: Int? {
        guard let lastAccessed else { return nil }
        return Calendar.current.dateComponents([.day], from: lastAccessed, to: Date()).day
    }

    public var daysSinceModified: Int? {
        guard let lastModified else { return nil }
        return Calendar.current.dateComponents([.day], from: lastModified, to: Date()).day
    }
}

// MARK: - Purgeable Space

public struct PurgeableInfo: Sendable {
    public let purgeableBytes: UInt64
    public let totalBytes: UInt64
    public let freeBytes: UInt64
    public let availableBytes: UInt64

    public init(purgeableBytes: UInt64, totalBytes: UInt64, freeBytes: UInt64, availableBytes: UInt64) {
        self.purgeableBytes = purgeableBytes
        self.totalBytes = totalBytes
        self.freeBytes = freeBytes
        self.availableBytes = availableBytes
    }

    public var freeWithPurgeable: UInt64 {
        freeBytes + purgeableBytes
    }
}
