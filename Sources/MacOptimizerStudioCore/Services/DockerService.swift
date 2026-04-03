import Foundation

public struct DockerService: Sendable {
    public init() {}

    public func isDockerInstalled() -> Bool {
        FileManager.default.fileExists(atPath: "/usr/local/bin/docker")
            || FileManager.default.fileExists(atPath: "/opt/homebrew/bin/docker")
            || FileManager.default.fileExists(atPath: "/Applications/Docker.app")
    }

    public func isDockerRunning() -> Bool {
        let output = runCommand("docker", arguments: ["info", "--format", "{{.ServerVersion}}"])
        return output != nil && !output!.isEmpty
    }

    public func fetchSnapshot() -> DockerSnapshot {
        let installed = isDockerInstalled()
        guard installed else {
            return DockerSnapshot(capturedAt: Date(), isInstalled: false, isRunning: false, images: [], volumes: [], containers: [], diskUsage: nil)
        }

        let running = isDockerRunning()
        guard running else {
            return DockerSnapshot(capturedAt: Date(), isInstalled: true, isRunning: false, images: [], volumes: [], containers: [], diskUsage: nil)
        }

        let images = fetchImages()
        let volumes = fetchVolumes()
        let containers = fetchContainers()
        let diskUsage = fetchDiskUsage()

        return DockerSnapshot(
            capturedAt: Date(),
            isInstalled: true,
            isRunning: true,
            images: images,
            volumes: volumes,
            containers: containers,
            diskUsage: diskUsage
        )
    }

    public func removeImage(id: String) -> Bool {
        // "--" terminates flag parsing so a crafted id like "--all-tags" is not
        // interpreted as a Docker flag (argument injection / flag injection).
        let output = runCommand("docker", arguments: ["rmi", "--force", "--", id])
        return output != nil
    }

    public func removeVolume(name: String) -> Bool {
        let output = runCommand("docker", arguments: ["volume", "rm", "--", name])
        return output != nil
    }

    public func removeContainer(id: String, force: Bool = false) -> Bool {
        var args = ["rm"]
        if force { args.append("-f") }
        args.append("--")
        args.append(id)
        let output = runCommand("docker", arguments: args)
        return output != nil
    }

    public func pruneImages() -> String? {
        runCommand("docker", arguments: ["image", "prune", "-a", "-f"])
    }

    public func pruneVolumes() -> String? {
        runCommand("docker", arguments: ["volume", "prune", "-f"])
    }

    public func pruneSystem() -> String? {
        runCommand("docker", arguments: ["system", "prune", "-a", "-f"])
    }

    // MARK: - Private

    private func fetchImages() -> [DockerImage] {
        guard let output = runCommand("docker", arguments: ["images", "--format", "{{.Repository}}\\t{{.Tag}}\\t{{.ID}}\\t{{.Size}}\\t{{.CreatedSince}}"]) else {
            return []
        }

        return output.split(separator: "\n").compactMap { line in
            let parts = line.split(separator: "\t", omittingEmptySubsequences: false)
            guard parts.count >= 5 else { return nil }
            let repo = String(parts[0])
            let tag = String(parts[1])
            let imageId = String(parts[2])
            let sizeStr = String(parts[3])
            let created = String(parts[4])
            let sizeBytes = parseDockerSize(sizeStr)

            return DockerImage(repository: repo, tag: tag, imageId: imageId, sizeBytes: sizeBytes, created: created)
        }
    }

    private func fetchVolumes() -> [DockerVolume] {
        guard let output = runCommand("docker", arguments: ["volume", "ls", "--format", "{{.Name}}\\t{{.Driver}}\\t{{.Mountpoint}}"]) else {
            return []
        }

        return output.split(separator: "\n").compactMap { line in
            let parts = line.split(separator: "\t", omittingEmptySubsequences: false)
            guard parts.count >= 3 else { return nil }
            let name = String(parts[0])
            let driver = String(parts[1])
            let mountpoint = String(parts[2])

            // Get individual volume size
            let sizeBytes = volumeSize(name: name)

            return DockerVolume(name: name, driver: driver, mountpoint: mountpoint, sizeBytes: sizeBytes)
        }
    }

    private func volumeSize(name: String) -> UInt64 {
        guard let output = runCommand("docker", arguments: ["volume", "inspect", "--format", "{{.UsageData.Size}}", "--", name]) else {
            return 0
        }
        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed == "-1" || trimmed.isEmpty { return 0 }
        return UInt64(trimmed) ?? 0
    }

    private func fetchContainers() -> [DockerContainer] {
        guard let output = runCommand("docker", arguments: ["ps", "-a", "--format", "{{.ID}}\\t{{.Names}}\\t{{.Image}}\\t{{.Status}}\\t{{.Size}}"]) else {
            return []
        }

        return output.split(separator: "\n").compactMap { line in
            let parts = line.split(separator: "\t", omittingEmptySubsequences: false)
            guard parts.count >= 5 else { return nil }
            let containerId = String(parts[0])
            let name = String(parts[1])
            let image = String(parts[2])
            let status = String(parts[3])
            let sizeStr = String(parts[4])
            let sizeBytes = parseDockerSize(sizeStr)

            return DockerContainer(containerId: containerId, name: name, image: image, status: status, sizeBytes: sizeBytes)
        }
    }

    private func fetchDiskUsage() -> DockerDiskUsage? {
        guard let output = runCommand("docker", arguments: ["system", "df", "--format", "{{.Type}}\\t{{.Size}}"]) else {
            return nil
        }

        var imagesTotalBytes: UInt64 = 0
        var containersTotalBytes: UInt64 = 0
        var volumesTotalBytes: UInt64 = 0
        var buildCacheBytes: UInt64 = 0

        for line in output.split(separator: "\n") {
            let parts = line.split(separator: "\t", omittingEmptySubsequences: false)
            guard parts.count >= 2 else { continue }
            let typeName = String(parts[0]).lowercased()
            let size = parseDockerSize(String(parts[1]))

            if typeName.contains("image") {
                imagesTotalBytes = size
            } else if typeName.contains("container") {
                containersTotalBytes = size
            } else if typeName.contains("volume") || typeName.contains("local volume") {
                volumesTotalBytes = size
            } else if typeName.contains("build") {
                buildCacheBytes = size
            }
        }

        return DockerDiskUsage(
            imagesTotalBytes: imagesTotalBytes,
            containersTotalBytes: containersTotalBytes,
            volumesTotalBytes: volumesTotalBytes,
            buildCacheTotalBytes: buildCacheBytes
        )
    }

    private func parseDockerSize(_ sizeStr: String) -> UInt64 {
        let cleaned = sizeStr.trimmingCharacters(in: .whitespaces)
        // Handle formats like "1.23GB", "456MB", "789kB", "12B"
        // Also handle "1.23GB (virtual 4.56GB)" — take only the first part
        let primary = cleaned.split(separator: " ").first.map(String.init) ?? cleaned
        let upper = primary.uppercased()

        // Extract number and unit from strings like "1.23GB", "456MB", "789KB", "12B"
        var numberStr = ""
        var unitStr = ""
        for ch in upper {
            if ch.isNumber || ch == "." {
                numberStr.append(ch)
            } else {
                unitStr.append(ch)
            }
        }

        guard let number = Double(numberStr) else { return 0 }

        switch unitStr {
        case "TB": return UInt64(number * 1_000_000_000_000)
        case "GB": return UInt64(number * 1_000_000_000)
        case "MB": return UInt64(number * 1_000_000)
        case "KB": return UInt64(number * 1_000)
        case "B": return UInt64(number)
        default: return 0
        }
    }

    private func runCommand(_ executable: String, arguments: [String]) -> String? {
        let process = Process()

        // Try multiple paths for docker
        let paths = ["/usr/local/bin/\(executable)", "/opt/homebrew/bin/\(executable)", "/usr/bin/\(executable)"]
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

            // Read stdout before waitUntilExit to prevent pipe buffer deadlock
            let data = stdout.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()

            guard process.terminationStatus == 0 else { return nil }
            return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            return nil
        }
    }
}
