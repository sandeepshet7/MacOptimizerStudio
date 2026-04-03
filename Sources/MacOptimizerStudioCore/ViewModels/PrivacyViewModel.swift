import Foundation

@MainActor
public final class PrivacyViewModel: ObservableObject {
    @Published public private(set) var report: PrivacyScanReport?
    @Published public private(set) var permissions: [AppPermission] = []
    @Published public private(set) var isScanning = false
    @Published public private(set) var isScanningPermissions = false
    @Published public var selectedPaths: Set<String> = []

    private let service: PrivacyService
    private let auditLog: AuditLogService

    public init(service: PrivacyService = PrivacyService(), auditLog: AuditLogService = AuditLogService()) {
        self.service = service
        self.auditLog = auditLog
    }

    public func scan() async {
        isScanning = true
        let svc = service
        let result = await Task.detached(priority: .userInitiated) {
            svc.scanPrivacyItems()
        }.value
        report = result
        isScanning = false
    }

    public func scanPermissions() async {
        isScanningPermissions = true
        let svc = service
        let result = await Task.detached(priority: .userInitiated) {
            svc.scanAppPermissions()
        }.value
        permissions = result
        isScanningPermissions = false
    }

    public func toggleSelection(_ path: String) {
        if selectedPaths.contains(path) {
            selectedPaths.remove(path)
        } else {
            selectedPaths.insert(path)
        }
    }

    public func selectAll(for category: PrivacyCategory) {
        guard let report else { return }
        for item in report.items(for: category) {
            selectedPaths.insert(item.path)
        }
    }

    public func deselectAll() {
        selectedPaths.removeAll()
    }

    public var selectedBytes: UInt64 {
        guard let report else { return 0 }
        return report.items.filter { selectedPaths.contains($0.path) }.reduce(0) { $0 + $1.sizeBytes }
    }

    public func cleanSelected() async -> (success: Bool, errors: [String]) {
        let paths = Array(selectedPaths)
        let svc = service
        let result = await Task.detached(priority: .userInitiated) {
            svc.cleanItems(paths)
        }.value
        if result.success {
            let log = auditLog
            let cleanedPaths = paths
            let bytes = selectedBytes
            let count = paths.count
            Task.detached { log.log(AuditLogEntry(action: .privacyDataCleaned, details: "Cleaned \(count) privacy item(s)", paths: cleanedPaths, totalBytes: bytes, itemCount: count)) }
            selectedPaths.removeAll()
        }
        await scan()
        return result
    }

    // MARK: - Permission helpers

    public var permissionsByApp: [String: [AppPermission]] {
        Dictionary(grouping: permissions, by: \.appName)
    }

    public var permissionsByType: [PermissionType: [AppPermission]] {
        Dictionary(grouping: permissions, by: \.permission)
    }

    public var uniqueAppCount: Int {
        Set(permissions.map(\.bundleId)).count
    }
}
