import Foundation

public struct UpdaterService: Sendable {
    public init() {}

    // MARK: - Public API

    public func checkOutdated() -> [OutdatedApp] {
        var apps: [OutdatedApp] = []

        // Check outdated formulae
        if let json = runBrew(arguments: ["outdated", "--json"]) {
            apps.append(contentsOf: parseOutdatedJSON(json))
        }

        // Check outdated casks
        if let json = runBrew(arguments: ["outdated", "--cask", "--json"]) {
            apps.append(contentsOf: parseOutdatedCaskJSON(json))
        }

        return apps
    }

    public func updateApp(name: String) -> UpdateResult {
        // Validate formula/cask name to prevent argument injection
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_@/.+-"))
        guard !name.isEmpty, name.unicodeScalars.allSatisfy({ allowed.contains($0) }) else {
            return UpdateResult(appName: name, success: false, error: "Invalid formula name: \(name)")
        }

        let output = runBrew(arguments: ["upgrade", "--", name])
        if let output, !output.isEmpty {
            return UpdateResult(appName: name, success: true)
        }
        // Check if the command ran but produced no output (still success)
        let checkOutput = runBrew(arguments: ["info", "--", name])
        if checkOutput != nil {
            return UpdateResult(appName: name, success: true)
        }
        return UpdateResult(appName: name, success: false, error: "Failed to upgrade \(name)")
    }

    public func updateAll() -> [UpdateResult] {
        let output = runBrew(arguments: ["upgrade"])
        if output != nil {
            return [UpdateResult(appName: "all", success: true)]
        }
        return [UpdateResult(appName: "all", success: false, error: "Failed to run brew upgrade")]
    }

    public func isBrewInstalled() -> Bool {
        FileManager.default.fileExists(atPath: "/usr/local/bin/brew")
            || FileManager.default.fileExists(atPath: "/opt/homebrew/bin/brew")
    }

    // MARK: - Parsing

    private func parseOutdatedJSON(_ jsonString: String) -> [OutdatedApp] {
        guard let data = jsonString.data(using: .utf8) else { return [] }

        do {
            if let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let formulae = root["formulae"] as? [[String: Any]] {
                return formulae.compactMap { formula in
                    guard let name = formula["name"] as? String,
                          let installedVersions = formula["installed_versions"] as? [String],
                          let currentVersion = installedVersions.first,
                          let currentVersionObj = formula["current_version"] as? String else {
                        return nil
                    }
                    return OutdatedApp(
                        name: name,
                        currentVersion: currentVersion,
                        latestVersion: currentVersionObj,
                        isHomebrew: true
                    )
                }
            }

            // Fallback: try parsing as array of objects
            if let array = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                return array.compactMap { formula in
                    guard let name = formula["name"] as? String,
                          let installedVersions = formula["installed_versions"] as? [String],
                          let currentVersion = installedVersions.first,
                          let currentVersionObj = formula["current_version"] as? String else {
                        return nil
                    }
                    return OutdatedApp(
                        name: name,
                        currentVersion: currentVersion,
                        latestVersion: currentVersionObj,
                        isHomebrew: true
                    )
                }
            }
        } catch {
            // JSON parsing failed
        }

        return []
    }

    private func parseOutdatedCaskJSON(_ jsonString: String) -> [OutdatedApp] {
        guard let data = jsonString.data(using: .utf8) else { return [] }

        do {
            if let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let casks = root["casks"] as? [[String: Any]] {
                return parseCaskArray(casks)
            }

            if let array = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                return parseCaskArray(array)
            }
        } catch {
            // JSON parsing failed
        }

        return []
    }

    private func parseCaskArray(_ casks: [[String: Any]]) -> [OutdatedApp] {
        casks.compactMap { cask in
            guard let name = cask["name"] as? String ?? cask["token"] as? String,
                  let installedVersion = cask["installed_versions"] as? String ?? (cask["installed_versions"] as? [String])?.first ?? cask["current_version"] as? String else {
                return nil
            }
            let latestVersion = cask["current_version"] as? String ?? "latest"
            return OutdatedApp(
                name: name,
                currentVersion: installedVersion,
                latestVersion: latestVersion,
                isHomebrew: true
            )
        }
    }

    // MARK: - Shell

    private func runBrew(arguments: [String]) -> String? {
        let process = Process()

        let paths = ["/opt/homebrew/bin/brew", "/usr/local/bin/brew"]
        var found = false
        for path in paths {
            if FileManager.default.fileExists(atPath: path) {
                process.executableURL = URL(fileURLWithPath: path)
                found = true
                break
            }
        }

        guard found else { return nil }

        process.arguments = arguments

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        do {
            try process.run()
            process.waitUntilExit()

            guard process.terminationStatus == 0 else { return nil }

            let data = stdout.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            return nil
        }
    }
}
