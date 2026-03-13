import Foundation

public struct MaintenanceService: Sendable {
    public init() {}

    public static let allTasks: [MaintenanceTask] = [
        MaintenanceTask(
            id: "flush_dns",
            name: "Flush DNS Cache",
            description: "Clear the DNS resolver cache. Fixes issues with websites not loading or resolving to old IP addresses. macOS rebuilds the cache automatically.",
            icon: "network",
            command: "dscacheutil -flushcache && sudo killall -HUP mDNSResponder",
            requiresSudo: true,
            estimatedDuration: "1-2 seconds"
        ),
        MaintenanceTask(
            id: "reindex_spotlight",
            name: "Reindex Spotlight",
            description: "Rebuild the Spotlight search index from scratch. Fixes slow or inaccurate search results. Takes several minutes to complete in the background.",
            icon: "magnifyingglass",
            command: "mdutil -E /",
            requiresSudo: true,
            estimatedDuration: "Starts instantly, indexing runs in background for 10-30 min"
        ),
        MaintenanceTask(
            id: "repair_permissions",
            name: "Repair Disk Permissions",
            description: "Verify and repair file permissions on the startup volume. Fixes apps that won't open, preference issues, and access errors.",
            icon: "lock.shield",
            command: "diskutil verifyVolume / && diskutil repairVolume /",
            requiresSudo: false,
            estimatedDuration: "1-5 minutes"
        ),
        MaintenanceTask(
            id: "speed_up_mail",
            name: "Speed Up Mail",
            description: "Vacuum and reindex the Mail database. Fixes slow search and laggy message loading in Apple Mail.",
            icon: "envelope",
            command: "sqlite3 ~/Library/Mail/V*/MailData/Envelope\\ Index vacuum",
            requiresSudo: false,
            estimatedDuration: "10-60 seconds"
        ),
        MaintenanceTask(
            id: "rebuild_launch_services",
            name: "Rebuild Launch Services",
            description: "Rebuild the Launch Services database. Fixes duplicate entries in 'Open With' menus and incorrect app associations.",
            icon: "arrow.triangle.2.circlepath",
            command: "/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -kill -r -domain local -domain system -domain user",
            requiresSudo: false,
            estimatedDuration: "30-90 seconds"
        ),
        MaintenanceTask(
            id: "run_maintenance_scripts",
            name: "Run Maintenance Scripts",
            description: "Execute macOS daily, weekly, and monthly maintenance scripts. Rotates logs, cleans temp files, and rebuilds system databases.",
            icon: "terminal",
            command: "periodic daily weekly monthly",
            requiresSudo: true,
            estimatedDuration: "1-3 minutes"
        ),
        MaintenanceTask(
            id: "verify_startup_disk",
            name: "Verify Startup Disk",
            description: "Check the file system structure of your startup disk for errors. Reports any issues found without modifying the disk.",
            icon: "externaldrive.badge.checkmark",
            command: "diskutil verifyVolume /",
            requiresSudo: false,
            estimatedDuration: "1-5 minutes"
        ),
        MaintenanceTask(
            id: "free_purgeable",
            name: "Free Purgeable Space",
            description: "Thin local Time Machine snapshots to reclaim purgeable disk space immediately rather than waiting for macOS to do it automatically.",
            icon: "arrow.3.trianglepath",
            command: "tmutil thinlocalsnapshots / 99999999999 4",
            requiresSudo: true,
            estimatedDuration: "10-60 seconds"
        ),
        MaintenanceTask(
            id: "clear_font_cache",
            name: "Clear Font Cache",
            description: "Reset the font cache database. Fixes font rendering issues, missing fonts, and font-related app crashes.",
            icon: "textformat",
            command: "atsutil databases -remove",
            requiresSudo: true,
            estimatedDuration: "A few seconds"
        ),
        MaintenanceTask(
            id: "flush_icon_cache",
            name: "Flush Icon Cache",
            description: "Clear the icon cache. Fixes generic white icons, wrong app icons, and icon display issues in Finder.",
            icon: "photo",
            command: "rm -rf /Library/Caches/com.apple.iconservices.store && killall Dock",
            requiresSudo: true,
            estimatedDuration: "A few seconds"
        ),
    ]

    public func runTask(_ task: MaintenanceTask) -> MaintenanceResult {
        let startTime = Date()

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-c", task.command]

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return MaintenanceResult(
                taskId: task.id,
                success: false,
                output: "Failed to start: \(error.localizedDescription)",
                duration: Date().timeIntervalSince(startTime)
            )
        }

        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: outputData, encoding: .utf8) ?? ""
        let errorOutput = String(data: errorData, encoding: .utf8) ?? ""

        let success = process.terminationStatus == 0
        let combinedOutput = output + (errorOutput.isEmpty ? "" : "\n\(errorOutput)")

        return MaintenanceResult(
            taskId: task.id,
            success: success,
            output: combinedOutput.trimmingCharacters(in: .whitespacesAndNewlines),
            duration: Date().timeIntervalSince(startTime)
        )
    }
}
