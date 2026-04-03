import AppKit
import Foundation

public struct PrivacyService: Sendable {
    public init() {}

    // MARK: - Privacy Scan

    public func scanPrivacyItems() -> PrivacyScanReport {
        var items: [PrivacyItem] = []
        let home = FileManager.default.homeDirectoryForCurrentUser.path

        // Browser Caches
        let browserCaches: [(String, String)] = [
            ("Safari Cache", "\(home)/Library/Caches/com.apple.Safari"),
            ("Chrome Cache", "\(home)/Library/Caches/Google/Chrome"),
            ("Firefox Cache", "\(home)/Library/Caches/Firefox"),
            ("Edge Cache", "\(home)/Library/Caches/com.microsoft.edgemac"),
            ("Brave Cache", "\(home)/Library/Caches/BraveSoftware/Brave-Browser"),
            ("Arc Cache", "\(home)/Library/Caches/company.thebrowser.Browser"),
        ]

        for (name, path) in browserCaches {
            if let info = directoryInfo(at: path) {
                items.append(PrivacyItem(category: .browserCache, name: name, path: path, sizeBytes: info.size, itemCount: info.count))
            }
        }

        // Browser Data (cookies, local storage)
        let browserData: [(String, String)] = [
            ("Safari Cookies", "\(home)/Library/Cookies"),
            ("Safari LocalStorage", "\(home)/Library/WebKit"),
            ("Chrome Data", "\(home)/Library/Application Support/Google/Chrome/Default/Local Storage"),
            ("Firefox Data", "\(home)/Library/Application Support/Firefox/Profiles"),
        ]

        for (name, path) in browserData {
            if let info = directoryInfo(at: path) {
                items.append(PrivacyItem(category: .browserHistory, name: name, path: path, sizeBytes: info.size, itemCount: info.count))
            }
        }

        // Recent Files
        let recentPaths: [(String, String)] = [
            ("Recent Documents", "\(home)/Library/Application Support/com.apple.sharedfilelist"),
            ("Finder Recents", "\(home)/Library/Application Support/com.apple.finder"),
        ]

        for (name, path) in recentPaths {
            if let info = directoryInfo(at: path) {
                items.append(PrivacyItem(category: .recentFiles, name: name, path: path, sizeBytes: info.size, itemCount: info.count))
            }
        }

        // Downloads
        let downloadsPath = "\(home)/Downloads"
        if let info = directoryInfo(at: downloadsPath) {
            items.append(PrivacyItem(category: .downloads, name: "Downloads", path: downloadsPath, sizeBytes: info.size, itemCount: info.count))
        }

        // Trash
        let trashPath = "\(home)/.Trash"
        if let info = directoryInfo(at: trashPath) {
            items.append(PrivacyItem(category: .trash, name: "Trash", path: trashPath, sizeBytes: info.size, itemCount: info.count))
        }

        items.sort { $0.sizeBytes > $1.sizeBytes }
        return PrivacyScanReport(capturedAt: Date(), items: items)
    }

    // MARK: - App Permissions (TCC)

    public func scanAppPermissions() -> [AppPermission] {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let tccPath = "\(home)/Library/Application Support/com.apple.TCC/TCC.db"

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/sqlite3")
        process.arguments = [tccPath, "SELECT client, service, auth_value FROM access;"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return []
        }

        guard process.terminationStatus == 0 else { return [] }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else { return [] }

        var permissions: [AppPermission] = []
        let lines = output.components(separatedBy: "\n").filter { !$0.isEmpty }

        for line in lines {
            let parts = line.components(separatedBy: "|")
            guard parts.count >= 3 else { continue }

            let bundleId = parts[0]
            let serviceKey = parts[1]
            let authValue = Int(parts[2]) ?? 0

            guard let permType = PermissionType(rawValue: serviceKey) else { continue }

            let appName = appNameFromBundleId(bundleId)
            let isAllowed = authValue == 2

            permissions.append(AppPermission(
                bundleId: bundleId,
                appName: appName,
                permission: permType,
                isAllowed: isAllowed
            ))
        }

        permissions.sort { $0.appName.localizedCompare($1.appName) == .orderedAscending }
        return permissions
    }

    // MARK: - Cleanup

    public func cleanItems(_ paths: [String]) -> (success: Bool, errors: [String]) {
        var errors: [String] = []
        let fm = FileManager.default

        for path in paths {
            do {
                if fm.fileExists(atPath: path) {
                    try fm.trashItem(at: URL(fileURLWithPath: path), resultingItemURL: nil)
                }
            } catch {
                errors.append("Failed to move to Trash \(path): \(error.localizedDescription)")
            }
        }

        return (errors.isEmpty, errors)
    }

    // MARK: - Helpers

    private func directoryInfo(at path: String) -> (size: UInt64, count: Int)? {
        let fm = FileManager.default
        guard fm.fileExists(atPath: path) else { return nil }

        let url = URL(fileURLWithPath: path)
        guard let enumerator = fm.enumerator(at: url, includingPropertiesForKeys: [.totalFileAllocatedSizeKey], options: []) else {
            return nil
        }

        var totalSize: UInt64 = 0
        var count = 0

        for case let fileURL as URL in enumerator {
            let values = try? fileURL.resourceValues(forKeys: [.totalFileAllocatedSizeKey])
            totalSize += UInt64(values?.totalFileAllocatedSize ?? 0)
            count += 1
        }

        return count > 0 ? (totalSize, count) : nil
    }

    private func appNameFromBundleId(_ bundleId: String) -> String {
        // Try to find the app name from the bundle ID
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
            return url.deletingPathExtension().lastPathComponent
        }
        // Fallback: extract readable name from bundle ID
        let parts = bundleId.components(separatedBy: ".")
        return parts.last ?? bundleId
    }
}
