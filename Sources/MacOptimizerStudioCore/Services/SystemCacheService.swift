import Foundation

public struct SystemCacheService: Sendable {
    public init() {}

    public func scan() -> CacheScanReport {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        var entries: [CacheEntry] = []

        entries.append(contentsOf: scanAppCaches(home: home))
        entries.append(contentsOf: scanSystemLogs(home: home))
        entries.append(contentsOf: scanXcodeData(home: home))
        entries.append(contentsOf: scanPackageManagers(home: home))
        entries.append(contentsOf: scanBrowserCaches(home: home))
        entries.append(contentsOf: scanContainers(home: home))
        entries.append(contentsOf: scanTemporaryFiles())
        entries.append(contentsOf: scanLanguageFiles(home: home))
        entries.append(contentsOf: scanMailAttachments(home: home))
        entries.append(contentsOf: scanIOSBackups(home: home))
        entries.append(contentsOf: scanBrokenPreferences(home: home))

        entries.sort { $0.sizeBytes > $1.sizeBytes }

        let totalBytes = entries.reduce(UInt64(0)) { $0 + $1.sizeBytes }
        var categoryTotals: [CacheCategory: UInt64] = [:]
        for entry in entries {
            categoryTotals[entry.category, default: 0] += entry.sizeBytes
        }

        return CacheScanReport(
            scannedAt: Date(),
            entries: entries,
            totalBytes: totalBytes,
            categoryTotals: categoryTotals
        )
    }

    // MARK: - App Caches

    private func scanAppCaches(home: String) -> [CacheEntry] {
        let cachesDir = "\(home)/Library/Caches"
        return scanSubdirectories(at: cachesDir, category: .appCaches, risk: .safe, description: "Application cache")
    }

    // MARK: - System Logs

    private func scanSystemLogs(home: String) -> [CacheEntry] {
        var entries: [CacheEntry] = []

        let userLogs = "\(home)/Library/Logs"
        entries.append(contentsOf: scanSubdirectories(at: userLogs, category: .systemLogs, risk: .safe, description: "Application log"))

        if let entry = measureDirectory(at: "/private/var/log", name: "System Logs", category: .systemLogs, risk: .moderate, description: "System-level log files (may need sudo)") {
            entries.append(entry)
        }

        return entries
    }

    // MARK: - Xcode Data

    private func scanXcodeData(home: String) -> [CacheEntry] {
        var entries: [CacheEntry] = []

        let derivedData = "\(home)/Library/Developer/Xcode/DerivedData"
        if let entry = measureDirectory(at: derivedData, name: "Xcode DerivedData", category: .xcodeData, risk: .safe, description: "Build artifacts — safe to delete, rebuilds automatically") {
            entries.append(entry)
        }

        let simulators = "\(home)/Library/Developer/CoreSimulator/Devices"
        if let entry = measureDirectory(at: simulators, name: "iOS Simulators", category: .xcodeData, risk: .moderate, description: "Simulator device data — delete unused simulators to save space") {
            entries.append(entry)
        }

        let archives = "\(home)/Library/Developer/Xcode/Archives"
        if let entry = measureDirectory(at: archives, name: "Xcode Archives", category: .xcodeData, risk: .moderate, description: "App Store submission archives") {
            entries.append(entry)
        }

        let xcodeCache = "\(home)/Library/Caches/com.apple.dt.Xcode"
        if let entry = measureDirectory(at: xcodeCache, name: "Xcode Cache", category: .xcodeData, risk: .safe, description: "Xcode internal cache — safe to delete") {
            entries.append(entry)
        }

        return entries
    }

    // MARK: - Package Managers

    private func scanPackageManagers(home: String) -> [CacheEntry] {
        var entries: [CacheEntry] = []

        let locations: [(String, String, String)] = [
            ("\(home)/Library/Caches/Homebrew", "Homebrew Cache", "Downloaded package archives"),
            ("\(home)/.npm/_cacache", "npm Cache", "npm package download cache"),
            ("\(home)/Library/Caches/pip", "pip Cache", "Python pip download cache"),
            ("\(home)/Library/Caches/CocoaPods", "CocoaPods Cache", "CocoaPods spec and pod cache"),
            ("\(home)/Library/Caches/org.carthage.CarthageKit", "Carthage Cache", "Carthage dependency cache"),
            ("\(home)/.cargo/registry", "Cargo Registry Cache", "Rust crate download cache"),
            ("\(home)/.gradle/caches", "Gradle Caches", "Gradle build and dependency caches"),
            ("\(home)/.cache/yarn", "Yarn Cache", "Yarn package download cache"),
            ("\(home)/Library/Caches/pnpm", "pnpm Cache", "pnpm package download cache"),
            ("\(home)/.pub-cache", "Dart Pub Cache", "Flutter/Dart package cache"),
            ("\(home)/.cache/go-build", "Go Build Cache", "Go compilation cache"),
        ]

        for (path, name, desc) in locations {
            if let entry = measureDirectory(at: path, name: name, category: .packageManager, risk: .safe, description: desc) {
                entries.append(entry)
            }
        }

        return entries
    }

    // MARK: - Browser Caches

    private func scanBrowserCaches(home: String) -> [CacheEntry] {
        var entries: [CacheEntry] = []

        let locations: [(String, String, String)] = [
            ("\(home)/Library/Caches/Google/Chrome", "Chrome Cache", "Google Chrome browser cache"),
            ("\(home)/Library/Caches/com.apple.Safari", "Safari Cache", "Safari browser cache"),
            ("\(home)/Library/Caches/Firefox", "Firefox Cache", "Firefox browser cache"),
            ("\(home)/Library/Caches/com.microsoft.edgemac", "Edge Cache", "Microsoft Edge browser cache"),
            ("\(home)/Library/Caches/com.brave.Browser", "Brave Cache", "Brave browser cache"),
            ("\(home)/Library/Caches/com.operasoftware.Opera", "Opera Cache", "Opera browser cache"),
        ]

        for (path, name, desc) in locations {
            if let entry = measureDirectory(at: path, name: name, category: .browserData, risk: .safe, description: desc) {
                entries.append(entry)
            }
        }

        return entries
    }

    // MARK: - Containers

    private func scanContainers(home: String) -> [CacheEntry] {
        var entries: [CacheEntry] = []

        let dockerData = "\(home)/Library/Containers/com.docker.docker/Data"
        if let entry = measureDirectory(at: dockerData, name: "Docker Data", category: .containerData, risk: .caution, description: "Docker images, containers, and volumes — may contain important data") {
            entries.append(entry)
        }

        let dockerDesktop = "\(home)/.docker"
        if let entry = measureDirectory(at: dockerDesktop, name: "Docker Config", category: .containerData, risk: .caution, description: "Docker configuration and credentials") {
            entries.append(entry)
        }

        return entries
    }

    // MARK: - Temporary Files

    private func scanTemporaryFiles() -> [CacheEntry] {
        var entries: [CacheEntry] = []

        if let entry = measureDirectory(at: NSTemporaryDirectory(), name: "User Temp", category: .temporaryFiles, risk: .safe, description: "Current user temporary files") {
            entries.append(entry)
        }

        if let entry = measureDirectory(at: "/private/tmp", name: "System Temp (/tmp)", category: .temporaryFiles, risk: .moderate, description: "Shared temporary directory") {
            entries.append(entry)
        }

        return entries
    }

    // MARK: - Language Files

    private func scanLanguageFiles(home: String) -> [CacheEntry] {
        let fm = FileManager.default
        let appsDir = "/Applications"
        guard let apps = try? fm.contentsOfDirectory(atPath: appsDir) else { return [] }

        let currentLocale: String
        if #available(macOS 13, *) {
            currentLocale = Locale.current.language.languageCode?.identifier ?? "en"
        } else {
            currentLocale = Locale.current.languageCode ?? "en"
        }
        let keepLprojs: Set<String> = ["en.lproj", "Base.lproj", "\(currentLocale).lproj"]

        var entries: [CacheEntry] = []

        for app in apps where app.hasSuffix(".app") {
            let resourcesPath = "\(appsDir)/\(app)/Contents/Resources"
            guard let resources = try? fm.contentsOfDirectory(atPath: resourcesPath) else { continue }

            var totalSize: UInt64 = 0
            var lprojPaths: [String] = []

            for item in resources where item.hasSuffix(".lproj") {
                if keepLprojs.contains(item) { continue }
                let lprojPath = "\(resourcesPath)/\(item)"
                let size = directorySize(at: lprojPath)
                totalSize += size
                lprojPaths.append(lprojPath)
            }

            if totalSize > 512 * 1024 {
                let appName = String(app.dropLast(4)) // Remove .app
                entries.append(CacheEntry(
                    category: .languageFiles,
                    name: "\(appName) Languages",
                    path: resourcesPath,
                    sizeBytes: totalSize,
                    riskLevel: .safe,
                    itemDescription: "Unused localizations in \(appName) (\(lprojPaths.count) languages)"
                ))
            }
        }

        return entries
    }

    // MARK: - Mail Attachments

    private func scanMailAttachments(home: String) -> [CacheEntry] {
        var entries: [CacheEntry] = []

        let paths: [(String, String)] = [
            ("\(home)/Library/Mail Downloads", "Mail Downloads"),
            ("\(home)/Library/Containers/com.apple.mail/Data/Library/Mail Downloads", "Mail Container Downloads"),
        ]

        for (path, name) in paths {
            if let entry = measureDirectory(
                at: path,
                name: name,
                category: .mailAttachments,
                risk: .moderate,
                description: "Locally cached email attachments"
            ) {
                entries.append(entry)
            }
        }

        return entries
    }

    // MARK: - iOS Backups

    private func scanIOSBackups(home: String) -> [CacheEntry] {
        let fm = FileManager.default
        let backupsDir = "\(home)/Library/Application Support/MobileSync/Backup"
        guard let contents = try? fm.contentsOfDirectory(atPath: backupsDir) else { return [] }

        var entries: [CacheEntry] = []

        for item in contents {
            let fullPath = "\(backupsDir)/\(item)"
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: fullPath, isDirectory: &isDir), isDir.boolValue else { continue }

            let size = directorySize(at: fullPath)
            guard size > 0 else { continue }

            // Try to read device name from Info.plist
            var deviceName = "iOS Backup"
            let infoPlist = "\(fullPath)/Info.plist"
            if let dict = NSDictionary(contentsOfFile: infoPlist),
               let name = dict["Device Name"] as? String {
                deviceName = name
            }

            entries.append(CacheEntry(
                category: .iOSBackups,
                name: deviceName,
                path: fullPath,
                sizeBytes: size,
                riskLevel: .caution,
                itemDescription: "iPhone/iPad backup — \(item)"
            ))
        }

        return entries
    }

    // MARK: - Broken Preferences

    private func scanBrokenPreferences(home: String) -> [CacheEntry] {
        let fm = FileManager.default
        let prefsDir = "\(home)/Library/Preferences"
        guard let contents = try? fm.contentsOfDirectory(atPath: prefsDir) else { return [] }

        var entries: [CacheEntry] = []

        for item in contents where item.hasSuffix(".plist") {
            let fullPath = "\(prefsDir)/\(item)"

            // Skip directories
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: fullPath, isDirectory: &isDir), !isDir.boolValue else { continue }

            // Try to parse the plist
            if NSDictionary(contentsOfFile: fullPath) == nil {
                // Also try as array plist
                if NSArray(contentsOfFile: fullPath) == nil {
                    if let attrs = try? fm.attributesOfItem(atPath: fullPath),
                       let fileSize = attrs[.size] as? UInt64 {
                        entries.append(CacheEntry(
                            category: .brokenPreferences,
                            name: item,
                            path: fullPath,
                            sizeBytes: fileSize,
                            riskLevel: .moderate,
                            itemDescription: "Corrupted or unreadable preference file"
                        ))
                    }
                }
            }
        }

        return entries
    }

    // MARK: - Helpers

    private func scanSubdirectories(at basePath: String, category: CacheCategory, risk: CacheRiskLevel, description: String) -> [CacheEntry] {
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(atPath: basePath) else { return [] }

        var entries: [CacheEntry] = []
        for item in contents {
            let fullPath = "\(basePath)/\(item)"
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: fullPath, isDirectory: &isDir), isDir.boolValue else { continue }

            let size = directorySize(at: fullPath)
            if size > 1024 * 1024 {
                let name = appNameFromBundleId(item)
                entries.append(CacheEntry(
                    category: category,
                    name: name,
                    path: fullPath,
                    sizeBytes: size,
                    riskLevel: risk,
                    itemDescription: "\(description) — \(item)"
                ))
            }
        }
        return entries
    }

    private func measureDirectory(at path: String, name: String, category: CacheCategory, risk: CacheRiskLevel, description: String) -> CacheEntry? {
        let fm = FileManager.default
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: path, isDirectory: &isDir), isDir.boolValue else { return nil }

        let size = directorySize(at: path)
        guard size > 512 * 1024 else { return nil }

        return CacheEntry(
            category: category,
            name: name,
            path: path,
            sizeBytes: size,
            riskLevel: risk,
            itemDescription: description
        )
    }

    private func directorySize(at path: String) -> UInt64 {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(atPath: path) else { return 0 }

        var total: UInt64 = 0
        while let file = enumerator.nextObject() as? String {
            let fullPath = "\(path)/\(file)"
            if let attrs = try? fm.attributesOfItem(atPath: fullPath),
               let fileSize = attrs[.size] as? UInt64 {
                total += fileSize
            }
        }
        return total
    }

    private func appNameFromBundleId(_ bundleId: String) -> String {
        if let displayName = bundleIdToName[bundleId] {
            return displayName
        }

        let parts = bundleId.split(separator: ".")
        if let last = parts.last {
            return String(last)
        }
        return bundleId
    }

    private let bundleIdToName: [String: String] = [
        "com.apple.Safari": "Safari",
        "com.apple.dt.Xcode": "Xcode",
        "com.google.Chrome": "Chrome",
        "com.spotify.client": "Spotify",
        "com.microsoft.VSCode": "VS Code",
        "com.apple.Music": "Music",
        "com.apple.mail": "Mail",
        "com.slack.Slack": "Slack",
        "com.tinyspeck.slackmacgap": "Slack",
        "com.microsoft.Word": "Word",
        "com.microsoft.Excel": "Excel",
        "com.figma.Desktop": "Figma",
        "com.docker.docker": "Docker",
        "com.brave.Browser": "Brave",
        "com.operasoftware.Opera": "Opera",
        "org.mozilla.firefox": "Firefox",
        "com.microsoft.edgemac": "Edge",
        "com.apple.finder": "Finder",
    ]
}
