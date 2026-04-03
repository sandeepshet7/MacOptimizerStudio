import Foundation

public struct ShredderFileItem: Identifiable, Hashable, Sendable {
    public let id: String
    public let path: String
    public let name: String
    public let sizeBytes: UInt64
    public let isDirectory: Bool

    public init(url: URL) {
        self.id = url.path
        self.path = url.path
        self.name = url.lastPathComponent
        self.isDirectory = (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
        self.sizeBytes = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? UInt64) ?? 0
    }
}

@MainActor
public final class FileShredderViewModel: ObservableObject {
    @Published public private(set) var files: [ShredderFileItem] = []
    @Published public private(set) var isShredding = false
    @Published public private(set) var progressMessage = ""
    @Published public private(set) var shreddedCount = 0
    @Published public private(set) var totalToShred = 0

    private let service: FileShredderService
    private let auditLog: AuditLogService

    public init(service: FileShredderService = FileShredderService(), auditLog: AuditLogService = AuditLogService()) {
        self.service = service
        self.auditLog = auditLog
    }

    // MARK: - File Management

    public func addFiles(urls: [URL]) {
        for url in urls {
            let item = ShredderFileItem(url: url)
            if !files.contains(where: { $0.path == item.path }) {
                files.append(item)
            }
        }
    }

    public func removeFile(_ item: ShredderFileItem) {
        files.removeAll { $0.id == item.id }
    }

    public func clearAll() {
        files.removeAll()
    }

    public var totalBytes: UInt64 {
        files.reduce(0) { $0 + $1.sizeBytes }
    }

    // MARK: - Shredding

    public func shredAll() async -> (success: Bool, shreddedCount: Int, errors: [String]) {
        isShredding = true
        shreddedCount = 0
        totalToShred = files.count
        var allErrors: [String] = []
        var totalShredded = 0

        let filesToShred = files
        let svc = service

        for (index, file) in filesToShred.enumerated() {
            progressMessage = "Shredding \(index + 1)/\(filesToShred.count): \(file.name)"

            if file.isDirectory {
                let result = await Task.detached(priority: .userInitiated) {
                    svc.shredDirectory(at: file.path) { _ in }
                }.value
                if result.success {
                    totalShredded += 1
                } else {
                    allErrors.append(contentsOf: result.errors)
                }
            } else {
                let result = await Task.detached(priority: .userInitiated) {
                    svc.shredFile(at: file.path)
                }.value
                if result.success {
                    totalShredded += 1
                } else if let error = result.error {
                    allErrors.append("\(file.name): \(error)")
                }
            }

            shreddedCount = totalShredded
        }

        // Remove successfully shredded files from the list
        let remainingPaths = Set(allErrors.compactMap { error -> String? in
            // Keep files that had errors
            filesToShred.first { error.hasPrefix($0.name) }?.path
        })
        files = files.filter { remainingPaths.contains($0.path) }

        // Audit log
        if totalShredded > 0 {
            let log = auditLog
            let paths = filesToShred.map(\.path)
            let totalSize = filesToShred.reduce(UInt64(0)) { $0 + $1.sizeBytes }
            let entry = AuditLogEntry(
                action: .fileShredded,
                details: "Securely shredded \(totalShredded) file(s)",
                paths: paths,
                totalBytes: totalSize,
                itemCount: totalShredded,
                userConfirmed: true
            )
            Task.detached { log.log(entry) }
        }

        progressMessage = ""
        isShredding = false
        return (allErrors.isEmpty, totalShredded, allErrors)
    }
}
