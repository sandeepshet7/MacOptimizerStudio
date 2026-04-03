import Foundation

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
