import Foundation

@MainActor
public final class ExtensionManagerViewModel: ObservableObject {
    @Published public private(set) var extensions: [SystemExtension] = []
    @Published public private(set) var isScanning = false
    @Published public private(set) var hasScanned = false
    @Published public var selectedFilter: ExtensionType? = nil

    private let service: ExtensionManagerService
    private let auditLog: AuditLogService

    public init(service: ExtensionManagerService = ExtensionManagerService(), auditLog: AuditLogService = AuditLogService()) {
        self.service = service
        self.auditLog = auditLog
    }

    public func scan() async {
        isScanning = true
        defer { isScanning = false; hasScanned = true }

        let svc = service
        let result = await Task.detached(priority: .userInitiated) {
            svc.scanExtensions()
        }.value
        extensions = result
    }

    public var filteredExtensions: [SystemExtension] {
        guard let filter = selectedFilter else { return extensions }
        return extensions.filter { $0.type == filter }
    }

    public var typeCounts: [(ExtensionType, Int)] {
        var counts: [ExtensionType: Int] = [:]
        for ext in extensions {
            counts[ext.type, default: 0] += 1
        }
        return ExtensionType.allCases.compactMap { type in
            guard let count = counts[type], count > 0 else { return nil }
            return (type, count)
        }
    }

    public func removeExtension(_ ext: SystemExtension) throws {
        try service.removeExtension(at: ext.path)
        let log = auditLog
        let name = ext.name
        let path = ext.path
        Task.detached { log.log(AuditLogEntry(action: .extensionRemoved, details: "Removed extension: \(name)", paths: [path])) }
        extensions.removeAll { $0.id == ext.id }
    }
}
