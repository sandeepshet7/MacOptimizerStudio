import AppKit
import MacOptimizerStudioCore
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate, @unchecked Sendable {
    func applicationWillFinishLaunching(_ notification: Notification) {
        if let bundle = ResourceBundle.bundle,
           let iconURL = bundle.url(forResource: "app_icon", withExtension: "png"),
           let iconImage = NSImage(contentsOf: iconURL) {
            NSApplication.shared.applicationIconImage = iconImage
        }
    }
}

@main
struct MacOptimizerStudioApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
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
    @StateObject private var duplicateFinderViewModel = DuplicateFinderViewModel()
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
                .environmentObject(duplicateFinderViewModel)
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
            MenuBarExtra {
                MenuBarView()
                    .environmentObject(memoryViewModel)
                    .environmentObject(systemHealthViewModel)
                    .environmentObject(dockerViewModel)
            } label: {
                if let iconURL = ResourceBundle.bundle?.url(forResource: "app_icon", withExtension: "png"),
                   let nsImage = NSImage(contentsOf: iconURL) {
                    let resized = { () -> NSImage in
                        let img = NSImage(size: NSSize(width: 18, height: 18))
                        img.addRepresentation({
                            let rep = NSBitmapImageRep(
                                bitmapDataPlanes: nil, pixelsWide: 18, pixelsHigh: 18,
                                bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                isPlanar: false, colorSpaceName: .deviceRGB,
                                bytesPerRow: 0, bitsPerPixel: 0)!
                            NSGraphicsContext.saveGraphicsState()
                            NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
                            nsImage.draw(in: NSRect(x: 0, y: 0, width: 18, height: 18))
                            NSGraphicsContext.restoreGraphicsState()
                            return rep
                        }())
                        return img
                    }()
                    Image(nsImage: resized)
                } else {
                    Image(systemName: "gauge.medium")
                }
            }
        }
    }
}
