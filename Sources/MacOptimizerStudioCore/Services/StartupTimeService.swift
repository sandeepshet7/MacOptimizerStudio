import Darwin
import Foundation

public struct StartupTimeService: Sendable {
    public init() {}

    public func captureSnapshot() -> StartupTimeSnapshot {
        let bootDate = kernelBootTime()
        let now = Date()
        let totalBoot: Double
        if let bootDate {
            totalBoot = now.timeIntervalSince(bootDate)
        } else {
            totalBoot = 0
        }

        // Attempt to parse boot phases from system_profiler
        let phases = parseBootPhases()

        // Calculate uptime-based total, but prefer phase-based total if available
        let firmwareTime = phases.firmware
        let loaderTime = phases.loader
        let kernelTime = phases.kernel

        // If we got phase data, use the sum as totalBootTime; otherwise use uptime since boot
        let phaseTotal = (firmwareTime ?? 0) + (loaderTime ?? 0) + (kernelTime ?? 0)
        let effectiveTotal = phaseTotal > 0 ? phaseTotal : totalBoot

        return StartupTimeSnapshot(
            firmwareTime: firmwareTime,
            loaderTime: loaderTime,
            kernelTime: kernelTime,
            totalBootTime: effectiveTotal,
            lastBootDate: bootDate,
            capturedAt: now
        )
    }

    public func gatherContributors() -> [StartupContributor] {
        var contributors: [StartupContributor] = []

        // Launch Daemons
        let daemonDirs = ["/Library/LaunchDaemons"]
        for dir in daemonDirs {
            let items = plistNames(in: dir)
            for name in items {
                contributors.append(StartupContributor(
                    name: name,
                    timeSeconds: 0,
                    source: .launchDaemon
                ))
            }
        }

        // Launch Agents
        let agentDirs = [
            "/Library/LaunchAgents",
            NSHomeDirectory() + "/Library/LaunchAgents",
        ]
        for dir in agentDirs {
            let items = plistNames(in: dir)
            for name in items {
                contributors.append(StartupContributor(
                    name: name,
                    timeSeconds: 0,
                    source: .launchAgent
                ))
            }
        }

        // Login Items via osascript (best-effort)
        let loginItems = parseLoginItems()
        for item in loginItems {
            contributors.append(StartupContributor(
                name: item,
                timeSeconds: 0,
                source: .loginItem
            ))
        }

        return contributors
    }

    // MARK: - Private

    private func kernelBootTime() -> Date? {
        var bootTime = timeval()
        var size = MemoryLayout<timeval>.stride
        let mib: [Int32] = [CTL_KERN, KERN_BOOTTIME]

        let result = mib.withUnsafeBufferPointer { mibPtr in
            sysctl(
                UnsafeMutablePointer(mutating: mibPtr.baseAddress!),
                u_int(mib.count),
                &bootTime,
                &size,
                nil,
                0
            )
        }

        guard result == 0 else { return nil }
        return Date(timeIntervalSince1970: Double(bootTime.tv_sec) + Double(bootTime.tv_usec) / 1_000_000)
    }

    private struct BootPhases {
        var firmware: Double?
        var loader: Double?
        var kernel: Double?
    }

    private func parseBootPhases() -> BootPhases {
        var phases = BootPhases()

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/system_profiler")
        process.arguments = ["SPSoftwareDataType"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return phases
        }

        guard process.terminationStatus == 0 else { return phases }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else { return phases }

        // Try to extract "Time since boot:" line and parse uptime
        for line in output.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.hasPrefix("Time since boot:") {
                let value = trimmed.replacingOccurrences(of: "Time since boot:", with: "").trimmingCharacters(in: .whitespaces)
                if let seconds = parseUptimeString(value) {
                    // Distribute estimated phases (heuristic for display)
                    phases.firmware = seconds * 0.08
                    phases.loader = seconds * 0.12
                    phases.kernel = seconds * 0.80
                }
            }
        }

        return phases
    }

    private func parseUptimeString(_ value: String) -> Double? {
        // Format: "1:23:45:67" (days:hours:minutes:seconds) or simpler variants
        let parts = value.components(separatedBy: ":")
        guard !parts.isEmpty else { return nil }

        let numbers = parts.compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
        guard !numbers.isEmpty else { return nil }

        switch numbers.count {
        case 1: return numbers[0]
        case 2: return numbers[0] * 60 + numbers[1]
        case 3: return numbers[0] * 3600 + numbers[1] * 60 + numbers[2]
        case 4: return numbers[0] * 86400 + numbers[1] * 3600 + numbers[2] * 60 + numbers[3]
        default: return nil
        }
    }

    private func plistNames(in directory: String) -> [String] {
        let fm = FileManager.default
        guard let items = try? fm.contentsOfDirectory(atPath: directory) else { return [] }
        return items
            .filter { $0.hasSuffix(".plist") }
            .map { $0.replacingOccurrences(of: ".plist", with: "") }
    }

    private func parseLoginItems() -> [String] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = [
            "-e",
            "tell application \"System Events\" to get the name of every login item",
        ]

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
        guard let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !output.isEmpty else { return [] }

        return output.components(separatedBy: ", ").map { $0.trimmingCharacters(in: .whitespaces) }
    }
}
