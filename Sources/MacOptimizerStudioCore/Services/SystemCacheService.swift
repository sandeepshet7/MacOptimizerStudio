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
        entries.append(contentsOf: scanJetBrainsData(home: home))
        entries.append(contentsOf: scanVSCodeData(home: home))
        entries.append(contentsOf: scanCommunicationApps(home: home))
        entries.append(contentsOf: scanGameCaches(home: home))
        entries.append(contentsOf: scanAIModels(home: home))
        entries.append(contentsOf: scanInstallerPackages(home: home))
        entries.append(contentsOf: scanTimeMachine(home: home))

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
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(atPath: cachesDir) else { return [] }

        var entries: [CacheEntry] = []
        for item in contents {
            let fullPath = "\(cachesDir)/\(item)"
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: fullPath, isDirectory: &isDir), isDir.boolValue else { continue }

            let size = directorySize(at: fullPath)
            if size > 1024 * 1024 {
                let name = appNameFromBundleId(item)
                // Electron/session-storing apps get moderate risk; pure caches get safe
                let risk: CacheRiskLevel = electronBundleIds.contains(item) ? .moderate : .safe
                let desc = risk == .moderate
                    ? "App cache — may require re-login after deletion"
                    : "Application cache — safe to delete, auto-regenerates"
                entries.append(CacheEntry(
                    category: .appCaches,
                    name: name,
                    path: fullPath,
                    sizeBytes: size,
                    riskLevel: risk,
                    itemDescription: "\(desc) — \(item)"
                ))
            }
        }
        return entries
    }

    // Electron and session-storing apps — deleting cache may log user out
    private let electronBundleIds: Set<String> = [
        "com.hnc.Discord", "discord",
        "com.tinyspeck.slackmacgap", "com.slack.Slack",
        "com.microsoft.teams2", "com.microsoft.teams",
        "com.anthropic.claudefordesktop",
        "com.spotify.client",
        "com.figma.Desktop",
        "com.notion.id",
        "com.linear",
        "com.1password.1password",
        "com.bitwarden.desktop",
        "us.zoom.xos",
    ]

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
            ("\(home)/.conda/pkgs", "Conda Cache", "Conda package download cache"),
            ("\(home)/Library/Caches/org.swift.swiftpm", "Swift PM Cache", "Swift Package Manager cache"),
            ("\(home)/.cache/pip", "pip Cache (alt)", "Python pip download cache (alternate location)"),
            ("\(home)/.gem/cache", "Ruby Gems Cache", "Ruby gems download cache"),
            ("\(home)/.cache/pnpm", "pnpm Cache (alt)", "pnpm package cache (alternate location)"),
            ("\(home)/.bun/install/cache", "Bun Cache", "Bun package download cache"),
            ("\(home)/development/flutter/bin/cache", "Flutter SDK Cache", "Flutter SDK build cache"),
            ("\(home)/.flutter", "Flutter Config", "Flutter configuration data"),
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
            ("\(home)/Library/Caches/Google/Chrome", "Chrome Cache", "Google Chrome browser cache — logins and bookmarks are not affected"),
            ("\(home)/Library/Caches/com.apple.Safari", "Safari Cache", "Safari browser cache — logins and bookmarks are not affected"),
            ("\(home)/Library/Caches/Firefox", "Firefox Cache", "Firefox browser cache — logins and bookmarks are not affected"),
            ("\(home)/Library/Caches/com.microsoft.edgemac", "Edge Cache", "Microsoft Edge browser cache — logins and bookmarks are not affected"),
            ("\(home)/Library/Caches/com.brave.Browser", "Brave Cache", "Brave browser cache — logins and bookmarks are not affected"),
            ("\(home)/Library/Caches/com.operasoftware.Opera", "Opera Cache", "Opera browser cache — logins and bookmarks are not affected"),
        ]

        for (path, name, desc) in locations {
            if let entry = measureDirectory(at: path, name: name, category: .browserData, risk: .moderate, description: desc) {
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

        // Virtual machine data
        let vmLocations: [(String, String, String)] = [
            ("\(home)/Parallels", "Parallels Desktop VMs", "Parallels virtual machine disk images — may contain important data"),
            ("\(home)/Library/Application Support/VMware Fusion", "VMware Fusion VMs", "VMware virtual machine disk images — may contain important data"),
            ("\(home)/Library/Containers/com.utmapp.UTM/Data/Documents", "UTM VMs", "UTM virtual machine disk images — may contain important data"),
            ("\(home)/.local/share/virtualbuddy", "VirtualBuddy VMs", "VirtualBuddy virtual machine data — may contain important data"),
        ]

        for (path, name, desc) in vmLocations {
            if let entry = measureDirectory(at: path, name: name, category: .containerData, risk: .caution, description: desc) {
                entries.append(entry)
            }
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

    // MARK: - JetBrains IDEs

    private func scanJetBrainsData(home: String) -> [CacheEntry] {
        var entries: [CacheEntry] = []

        let jetbrainsCaches = "\(home)/Library/Caches/JetBrains"
        entries.append(contentsOf: scanSubdirectories(at: jetbrainsCaches, category: .jetbrainsData, risk: .safe, description: "JetBrains IDE cache"))

        let jetbrainsSupport = "\(home)/Library/Application Support/JetBrains"
        entries.append(contentsOf: scanSubdirectories(at: jetbrainsSupport, category: .jetbrainsData, risk: .moderate, description: "JetBrains IDE config/plugin data"))

        return entries
    }

    // MARK: - VS Code & Cursor

    private func scanVSCodeData(home: String) -> [CacheEntry] {
        var entries: [CacheEntry] = []

        let locations: [(String, String, CacheRiskLevel, String)] = [
            ("\(home)/Library/Application Support/Code/Cache", "VS Code Cache", .safe, "VS Code browser cache"),
            ("\(home)/Library/Application Support/Code/CachedData", "VS Code CachedData", .safe, "VS Code cached compilation data"),
            ("\(home)/Library/Application Support/Code/CachedExtensions", "VS Code CachedExtensions", .safe, "VS Code cached extension metadata"),
            ("\(home)/Library/Application Support/Code/CachedExtensionVSIXs", "VS Code CachedExtensionVSIXs", .safe, "VS Code cached extension packages"),
            ("\(home)/Library/Application Support/Cursor/Cache", "Cursor Cache", .safe, "Cursor editor browser cache"),
            ("\(home)/Library/Application Support/Cursor/CachedData", "Cursor CachedData", .safe, "Cursor editor cached compilation data"),
        ]

        for (path, name, risk, desc) in locations {
            if let entry = measureDirectory(at: path, name: name, category: .vsCodeData, risk: risk, description: desc) {
                entries.append(entry)
            }
        }

        return entries
    }

    // MARK: - Communication Apps

    private func scanCommunicationApps(home: String) -> [CacheEntry] {
        var entries: [CacheEntry] = []

        let locations: [(String, String, CacheRiskLevel, String)] = [
            ("\(home)/Library/Application Support/Slack/Cache", "Slack Cache", .moderate, "Slack media cache — may require re-login"),
            ("\(home)/Library/Application Support/Slack/Service Worker/CacheStorage", "Slack Service Worker Cache", .moderate, "Slack service worker cache"),
            ("\(home)/Library/Application Support/discord/Cache", "Discord Cache", .moderate, "Discord media cache — may require re-login"),
            ("\(home)/Library/Application Support/discord/Code Cache", "Discord Code Cache", .moderate, "Discord compiled code cache"),
            ("\(home)/Library/Containers/com.microsoft.teams2/Data/Library/Caches", "Teams Cache", .moderate, "Microsoft Teams cache — may require re-login"),
            ("\(home)/Library/Application Support/zoom.us/data", "Zoom Data", .caution, "Zoom recordings and data — may include saved recordings"),
            ("\(home)/Library/Caches/com.tinyspeck.slackmacgap", "Slack (App Store) Cache", .moderate, "Slack cache — may require re-login"),
        ]

        for (path, name, risk, desc) in locations {
            if let entry = measureDirectory(at: path, name: name, category: .communicationApps, risk: risk, description: desc) {
                entries.append(entry)
            }
        }

        return entries
    }

    // MARK: - Game Libraries

    private func scanGameCaches(home: String) -> [CacheEntry] {
        var entries: [CacheEntry] = []

        let steamApps = "\(home)/Library/Application Support/Steam/steamapps"
        if let entry = measureDirectory(at: steamApps, name: "Steam Games", category: .gameCaches, risk: .caution, description: "Steam game files — contains actual installed games") {
            entries.append(entry)
        }

        let steamWorkshop = "\(home)/Library/Application Support/Steam/steamapps/workshop"
        if let entry = measureDirectory(at: steamWorkshop, name: "Steam Workshop", category: .gameCaches, risk: .moderate, description: "Steam Workshop downloaded mods and content") {
            entries.append(entry)
        }

        let steamCache = "\(home)/Library/Caches/com.valvesoftware.steam"
        if let entry = measureDirectory(at: steamCache, name: "Steam Cache", category: .gameCaches, risk: .safe, description: "Steam client cache — safe to delete") {
            entries.append(entry)
        }

        let epicGames = "\(home)/Library/Application Support/Epic/EpicGamesLauncher"
        if let entry = measureDirectory(at: epicGames, name: "Epic Games Launcher", category: .gameCaches, risk: .moderate, description: "Epic Games Store launcher data and cache") {
            entries.append(entry)
        }

        return entries
    }

    // MARK: - AI & ML Models

    private func scanAIModels(home: String) -> [CacheEntry] {
        var entries: [CacheEntry] = []

        let locations: [(String, String, CacheRiskLevel, String)] = [
            ("\(home)/.ollama/models", "Ollama Models", .moderate, "Ollama LLM weights — can be 4-70GB each"),
            ("\(home)/.cache/huggingface", "Hugging Face Cache", .safe, "Hugging Face transformer models and datasets"),
            ("\(home)/.cache/lm-studio", "LM Studio Models", .moderate, "LM Studio GGUF/GGML model files"),
            ("\(home)/.cache/torch", "PyTorch Cache", .safe, "PyTorch pre-trained model caches"),
            ("\(home)/Library/Caches/com.apple.CoreML", "Core ML Cache", .safe, "Core ML compiled model cache"),
            ("\(home)/.cache/whisper", "Whisper Models", .safe, "Whisper speech recognition model files"),
        ]

        for (path, name, risk, desc) in locations {
            if let entry = measureDirectory(at: path, name: name, category: .aiModels, risk: risk, description: desc) {
                entries.append(entry)
            }
        }

        return entries
    }

    // MARK: - Installer Packages

    private func scanInstallerPackages(home: String) -> [CacheEntry] {
        let fm = FileManager.default
        let downloadsDir = "\(home)/Downloads"
        guard let contents = try? fm.contentsOfDirectory(atPath: downloadsDir) else { return [] }

        let installerExtensions: Set<String> = ["dmg", "pkg", "app"]
        var entries: [CacheEntry] = []

        for item in contents {
            let fullPath = "\(downloadsDir)/\(item)"
            let ext = (item as NSString).pathExtension.lowercased()
            guard installerExtensions.contains(ext) else { continue }

            // Skip .app directories for this scan — only include files
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: fullPath, isDirectory: &isDir) else { continue }

            // For .app, measure directory size; for .dmg/.pkg, measure file size
            let size: UInt64
            if isDir.boolValue {
                size = directorySize(at: fullPath)
            } else {
                guard let attrs = try? fm.attributesOfItem(atPath: fullPath),
                      let fileSize = attrs[.size] as? UInt64 else { continue }
                size = fileSize
            }

            // Only include files > 1MB
            guard size > 1024 * 1024 else { continue }

            entries.append(CacheEntry(
                category: .installerPackages,
                name: item,
                path: fullPath,
                sizeBytes: size,
                riskLevel: .safe,
                itemDescription: "Installer package in Downloads — \(ext.uppercased()) file"
            ))
        }

        return entries
    }

    // MARK: - Time Machine

    private func scanTimeMachine(home: String) -> [CacheEntry] {
        var entries: [CacheEntry] = []

        let mobileSync = "/Library/Application Support/MobileSync"
        if let entry = measureDirectory(at: mobileSync, name: "MobileSync Data", category: .timeMachineSnapshots, risk: .moderate, description: "Local sync and backup data — Time Machine local snapshots require tmutil to manage") {
            entries.append(entry)
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
        "com.jetbrains.intellij": "IntelliJ IDEA",
        "com.jetbrains.pycharm": "PyCharm",
        "com.jetbrains.WebStorm": "WebStorm",
        "com.microsoft.teams2": "Teams",
        "us.zoom.xos": "Zoom",
        "com.hnc.Discord": "Discord",
        "com.valvesoftware.steam": "Steam",
    ]
}
