import MacOptimizerStudioCore
import SwiftUI

@main
struct MacOptimizerStudioApp: App {
    @StateObject private var diskViewModel = DiskViewModel()
    @StateObject private var memoryViewModel = MemoryViewModel()
    @StateObject private var cacheViewModel = CacheViewModel()
    @StateObject private var systemHealthViewModel = SystemHealthViewModel()
    @StateObject private var dockerViewModel = DockerViewModel()
    @StateObject private var maintenanceViewModel = MaintenanceViewModel()
    @StateObject private var storageToolsViewModel = StorageToolsViewModel()
    @StateObject private var privacyViewModel = PrivacyViewModel()
    @StateObject private var appManagerViewModel = AppManagerViewModel()
    @StateObject private var photoJunkViewModel = PhotoJunkViewModel()
    @StateObject private var updaterViewModel = UpdaterViewModel()
    @StateObject private var extensionManagerViewModel = ExtensionManagerViewModel()
    @StateObject private var fileShredderViewModel = FileShredderViewModel()
    @StateObject private var networkViewModel = NetworkViewModel()
    @StateObject private var diskHealthViewModel = DiskHealthViewModel()
    @StateObject private var startupTimeViewModel = StartupTimeViewModel()
    @StateObject private var diskBenchmarkViewModel = DiskBenchmarkViewModel()
    @StateObject private var brokenDownloadsViewModel = BrokenDownloadsViewModel()
    @StateObject private var screenshotOrganizerViewModel = ScreenshotOrganizerViewModel()
    @StateObject private var auditLogViewModel = AuditLogViewModel()
    @StateObject private var toastManager = ToastManager()
    @StateObject private var alertManager = AlertManager()

    @AppStorage("default_scan_preset") private var defaultScanPreset = "balanced"
    @AppStorage("auto_scan_on_launch") private var autoScanOnLaunch = false

    var body: some Scene {
        WindowGroup("MacOptimizer Studio") {
            ContentView()
                .environmentObject(diskViewModel)
                .environmentObject(memoryViewModel)
                .environmentObject(cacheViewModel)
                .environmentObject(systemHealthViewModel)
                .environmentObject(dockerViewModel)
                .environmentObject(maintenanceViewModel)
                .environmentObject(storageToolsViewModel)
                .environmentObject(privacyViewModel)
                .environmentObject(appManagerViewModel)
                .environmentObject(photoJunkViewModel)
                .environmentObject(updaterViewModel)
                .environmentObject(extensionManagerViewModel)
                .environmentObject(fileShredderViewModel)
                .environmentObject(networkViewModel)
                .environmentObject(diskHealthViewModel)
                .environmentObject(startupTimeViewModel)
                .environmentObject(diskBenchmarkViewModel)
                .environmentObject(brokenDownloadsViewModel)
                .environmentObject(screenshotOrganizerViewModel)
                .environmentObject(auditLogViewModel)
                .environmentObject(toastManager)
                .environmentObject(alertManager)
                .frame(minWidth: 940, minHeight: 640)
                .task {
                    await auditLogViewModel.load()
                    alertManager.toastManager = toastManager
                    alertManager.setup()
                    if autoScanOnLaunch && !diskViewModel.roots.isEmpty {
                        let preset = ScanPreset(rawValue: defaultScanPreset) ?? .balanced
                        await diskViewModel.scan(maxDepth: preset.maxDepth, top: preset.top)
                    }
                }
        }

        Settings {
            SettingsView()
                .environmentObject(systemHealthViewModel)
                .environmentObject(auditLogViewModel)
        }

        if #available(macOS 13, *) {
            MenuBarExtra("MacOptimizer", systemImage: "bolt.shield.fill") {
                MenuBarView()
                    .environmentObject(memoryViewModel)
                    .environmentObject(systemHealthViewModel)
                    .environmentObject(dockerViewModel)
            }
        }
    }
}
