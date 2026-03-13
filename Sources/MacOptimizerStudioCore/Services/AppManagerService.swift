import AppKit
import Foundation

public struct AppManagerService: Sendable {
    public init() {}

    // MARK: - Scan Installed Apps

    public func scanInstalledApps(onProgress: @Sendable (String) -> Void) -> [InstalledApp] {
        let fm = FileManager.default
        let appDirs = ["/Applications", "\(fm.homeDirectoryForCurrentUser.path)/Applications"]
        var apps: [InstalledApp] = []

        for dir in appDirs {
            guard let contents = try? fm.contentsOfDirectory(atPath: dir) else { continue }
            for item in contents where item.hasSuffix(".app") {
                let appPath = "\(dir)/\(item)"
                onProgress("Scanning \(item)...")

                if let app = scanApp(at: appPath) {
                    apps.append(app)
                }
            }
        }

        apps.sort { $0.totalFootprint > $1.totalFootprint }
        return apps
    }

    private func scanApp(at path: String) -> InstalledApp? {
        let fm = FileManager.default
        guard fm.fileExists(atPath: path) else { return nil }

        let url = URL(fileURLWithPath: path)
        let name = url.deletingPathExtension().lastPathComponent

        // Read Info.plist
        let plistPath = "\(path)/Contents/Info.plist"
        let plist = NSDictionary(contentsOfFile: plistPath)
        let bundleId = plist?["CFBundleIdentifier"] as? String
        let version = plist?["CFBundleShortVersionString"] as? String

        let appSize = directorySize(at: url)
        let associatedFiles = bundleId.map { findAssociatedFiles(bundleId: $0, appName: name) } ?? []

        return InstalledApp(
            name: name,
            bundleId: bundleId,
            path: path,
            sizeBytes: appSize,
            version: version,
            icon: nil,
            associatedFiles: associatedFiles
        )
    }

    // MARK: - Find Associated Files

    private func findAssociatedFiles(bundleId: String, appName: String) -> [AppAssociatedFile] {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        var files: [AppAssociatedFile] = []

        let searches: [(String, AssociatedFileCategory)] = [
            ("\(home)/Library/Preferences", .preferences),
            ("\(home)/Library/Caches", .cache),
            ("\(home)/Library/Application Support", .applicationSupport),
            ("\(home)/Library/Containers", .containers),
            ("\(home)/Library/Logs", .logs),
            ("\(home)/Library/Saved Application State", .savedState),
            ("\(home)/Library/WebKit", .webKit),
            ("\(home)/Library/Logs/DiagnosticReports", .crashReports),
        ]

        for (dir, category) in searches {
            let matched = findMatchingEntries(in: dir, bundleId: bundleId, appName: appName)
            for path in matched {
                let size = sizeOfItem(at: path)
                if size > 0 {
                    files.append(AppAssociatedFile(path: path, category: category, sizeBytes: size))
                }
            }
        }

        return files
    }

    private func findMatchingEntries(in directory: String, bundleId: String, appName: String) -> [String] {
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(atPath: directory) else { return [] }

        let bundleParts = bundleId.lowercased()
        let nameLower = appName.lowercased()

        return contents.compactMap { item in
            let itemLower = item.lowercased()
            if itemLower.contains(bundleParts) || itemLower.contains(nameLower) {
                return "\(directory)/\(item)"
            }
            return nil
        }
    }

    // MARK: - Uninstall

    public func moveToTrash(appPath: String, associatedPaths: [String]) -> (success: Bool, errors: [String]) {
        var errors: [String] = []

        // Move app bundle to trash
        do {
            try FileManager.default.trashItem(at: URL(fileURLWithPath: appPath), resultingItemURL: nil)
        } catch {
            errors.append("Failed to trash \(appPath): \(error.localizedDescription)")
        }

        // Move associated files to trash
        for path in associatedPaths {
            do {
                if FileManager.default.fileExists(atPath: path) {
                    try FileManager.default.trashItem(at: URL(fileURLWithPath: path), resultingItemURL: nil)
                }
            } catch {
                errors.append("Failed to trash \(path): \(error.localizedDescription)")
            }
        }

        return (errors.isEmpty, errors)
    }

    // MARK: - Reset App

    public func resetApp(bundleId: String, appName: String) -> (success: Bool, bytesFreed: UInt64, errors: [String]) {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        var errors: [String] = []
        var bytesFreed: UInt64 = 0

        let resetDirs: [String] = [
            "\(home)/Library/Caches",
            "\(home)/Library/Preferences",
            "\(home)/Library/Application Support",
            "\(home)/Library/Containers",
            "\(home)/Library/Logs",
            "\(home)/Library/Saved Application State",
            "\(home)/Library/WebKit",
            "\(home)/Library/Logs/DiagnosticReports",
        ]

        for dir in resetDirs {
            let matched = findMatchingEntries(in: dir, bundleId: bundleId, appName: appName)
            for path in matched {
                let size = sizeOfItem(at: path)
                do {
                    if FileManager.default.fileExists(atPath: path) {
                        try FileManager.default.trashItem(at: URL(fileURLWithPath: path), resultingItemURL: nil)
                        bytesFreed += size
                    }
                } catch {
                    errors.append("Failed to trash \(path): \(error.localizedDescription)")
                }
            }
        }

        return (errors.isEmpty, bytesFreed, errors)
    }

    // MARK: - Helpers

    private func directorySize(at url: URL) -> UInt64 {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(at: url, includingPropertiesForKeys: [.totalFileAllocatedSizeKey], options: [.skipsHiddenFiles]) else { return 0 }

        var total: UInt64 = 0
        for case let fileURL as URL in enumerator {
            let values = try? fileURL.resourceValues(forKeys: [.totalFileAllocatedSizeKey])
            total += UInt64(values?.totalFileAllocatedSize ?? 0)
        }
        return total
    }

    private func sizeOfItem(at path: String) -> UInt64 {
        let fm = FileManager.default
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: path, isDirectory: &isDir) else { return 0 }

        if isDir.boolValue {
            return directorySize(at: URL(fileURLWithPath: path))
        } else {
            let attrs = try? fm.attributesOfItem(atPath: path)
            return attrs?[.size] as? UInt64 ?? 0
        }
    }
}
