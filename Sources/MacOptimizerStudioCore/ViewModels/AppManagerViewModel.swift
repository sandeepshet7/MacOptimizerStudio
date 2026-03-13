import Foundation

@MainActor
public final class AppManagerViewModel: ObservableObject {
    @Published public private(set) var apps: [InstalledApp] = []
    @Published public private(set) var isScanning = false
    @Published public private(set) var scanProgress = ""
    @Published public var searchQuery = ""

    private let service: AppManagerService
    private let auditLog: AuditLogService

    public init(service: AppManagerService = AppManagerService(), auditLog: AuditLogService = AuditLogService()) {
        self.service = service
        self.auditLog = auditLog
    }

    public func scan() async {
        isScanning = true
        scanProgress = "Starting..."

        let svc = service
        let result = await Task.detached(priority: .userInitiated) { [weak self] in
            svc.scanInstalledApps { progress in
                Task { @MainActor in
                    self?.scanProgress = progress
                }
            }
        }.value

        apps = result
        isScanning = false
    }

    public func uninstall(app: InstalledApp) async -> (success: Bool, errors: [String]) {
        let svc = service
        let associatedPaths = app.associatedFiles.map(\.path)
        let appPath = app.path

        let result = await Task.detached(priority: .userInitiated) {
            svc.moveToTrash(appPath: appPath, associatedPaths: associatedPaths)
        }.value

        if result.success {
            let log = auditLog
            let allPaths = [appPath] + associatedPaths
            Task.detached { log.log(AuditLogEntry(action: .appUninstalled, details: "Uninstalled \(app.name)", paths: allPaths, totalBytes: app.totalFootprint, itemCount: allPaths.count)) }
            apps.removeAll { $0.id == app.id }
        }

        return result
    }

    public func resetApp(_ app: InstalledApp) async -> (success: Bool, bytesFreed: UInt64, errors: [String]) {
        guard let bundleId = app.bundleId else {
            return (false, 0, ["No bundle ID found for \(app.name)"])
        }

        let svc = service
        let appName = app.name
        let result = await Task.detached(priority: .userInitiated) {
            svc.resetApp(bundleId: bundleId, appName: appName)
        }.value

        // Re-scan to update associated file sizes
        if result.success {
            let log = auditLog
            let name = app.name
            let freed = result.bytesFreed
            Task.detached { log.log(AuditLogEntry(action: .appDataReset, details: "Reset data for \(name)", totalBytes: freed)) }
            await scan()
        }

        return result
    }

    public var filteredApps: [InstalledApp] {
        if searchQuery.isEmpty { return apps }
        let needle = searchQuery.lowercased()
        return apps.filter {
            $0.name.lowercased().contains(needle)
            || ($0.bundleId?.lowercased().contains(needle) ?? false)
        }
    }

    public var totalFootprint: UInt64 {
        apps.reduce(0) { $0 + $1.totalFootprint }
    }

    public var totalAssociatedBytes: UInt64 {
        apps.reduce(0) { $0 + $1.totalAssociatedBytes }
    }
}
