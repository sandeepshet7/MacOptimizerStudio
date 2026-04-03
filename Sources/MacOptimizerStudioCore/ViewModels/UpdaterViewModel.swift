import Foundation

@MainActor
public final class UpdaterViewModel: ObservableObject {
    @Published public private(set) var outdatedApps: [OutdatedApp] = []
    @Published public private(set) var isChecking = false
    @Published public private(set) var isUpdating = false
    @Published public private(set) var updateProgress: String?
    @Published public private(set) var lastError: String?
    @Published public private(set) var hasChecked = false
    @Published public private(set) var isBrewInstalled = true

    private let service: UpdaterService

    public init(service: UpdaterService = UpdaterService()) {
        self.service = service
    }

    public func checkForUpdates() async {
        isChecking = true
        lastError = nil
        defer {
            isChecking = false
            hasChecked = true
        }

        let svc = service
        let installed = await Task.detached {
            svc.isBrewInstalled()
        }.value

        isBrewInstalled = installed
        guard installed else {
            lastError = "Homebrew is not installed"
            ErrorCollector.shared.record(source: "Updater", message: "Homebrew is not installed")
            return
        }

        let result = await Task.detached(priority: .userInitiated) {
            svc.checkOutdated()
        }.value

        outdatedApps = result
    }

    public func updateApp(_ app: OutdatedApp) async -> UpdateResult {
        isUpdating = true
        updateProgress = "Updating \(app.name)..."
        defer {
            isUpdating = false
            updateProgress = nil
        }

        let svc = service
        let name = app.name
        let result = await Task.detached {
            svc.updateApp(name: name)
        }.value

        if result.success {
            outdatedApps.removeAll { $0.id == app.id }
        } else {
            lastError = result.error
        }

        return result
    }

    public func updateAll() async {
        isUpdating = true
        updateProgress = "Updating all packages..."
        defer {
            isUpdating = false
            updateProgress = nil
        }

        let svc = service
        let _ = await Task.detached {
            svc.updateAll()
        }.value

        // Re-check to see what's still outdated
        await checkForUpdates()
    }

    public var outdatedCount: Int {
        outdatedApps.count
    }
}
