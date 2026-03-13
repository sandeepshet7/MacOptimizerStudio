import Darwin
import Foundation

public struct SystemHealthService: Sendable {
    public init() {}

    public func captureSnapshot() -> SystemHealthSnapshot {
        let battery = gatherBatteryInfo()
        return SystemHealthSnapshot(
            capturedAt: Date(),
            hardware: gatherHardwareInfo(),
            diskUsage: gatherDiskUsage(),
            battery: battery,
            startupItems: gatherStartupItems(),
            thermal: gatherThermalInfo(batteryTemp: battery?.temperatureCelsius)
        )
    }

    // MARK: - Hardware

    private func gatherHardwareInfo() -> HardwareInfo {
        let cpuModel = sysctlString("machdep.cpu.brand_string") ?? "Unknown CPU"
        let cpuCoreCount = ProcessInfo.processInfo.processorCount
        let totalRAM = ProcessInfo.processInfo.physicalMemory

        let osVersion = ProcessInfo.processInfo.operatingSystemVersion
        let versionString = "\(osVersion.majorVersion).\(osVersion.minorVersion).\(osVersion.patchVersion)"

        let buildNumber = sysctlString("kern.osversion") ?? "Unknown"
        let uptime = ProcessInfo.processInfo.systemUptime
        let hostname = ProcessInfo.processInfo.hostName

        return HardwareInfo(
            cpuModel: cpuModel,
            cpuCoreCount: cpuCoreCount,
            totalRAMBytes: totalRAM,
            macOSVersion: versionString,
            macOSBuild: buildNumber,
            uptimeSeconds: uptime,
            hostname: hostname
        )
    }

    private func sysctlString(_ name: String) -> String? {
        var size: Int = 0
        sysctlbyname(name, nil, &size, nil, 0)
        guard size > 0 else { return nil }

        var buffer = [CChar](repeating: 0, count: size)
        let result = sysctlbyname(name, &buffer, &size, nil, 0)
        guard result == 0 else { return nil }

        let truncated = buffer.prefix(while: { $0 != 0 }).map { UInt8(bitPattern: $0) }
        return String(decoding: truncated, as: UTF8.self)
    }

    // MARK: - Disk Usage

    private func gatherDiskUsage() -> DiskUsageInfo {
        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser

        do {
            let values = try home.resourceValues(forKeys: [.volumeTotalCapacityKey, .volumeAvailableCapacityForImportantUsageKey])
            let total = UInt64(values.volumeTotalCapacity ?? 0)
            let available = UInt64(values.volumeAvailableCapacityForImportantUsage ?? 0)
            let used = total > available ? total - available : 0
            let percent = total > 0 ? Double(used) / Double(total) * 100.0 : 0

            return DiskUsageInfo(totalBytes: total, usedBytes: used, freeBytes: available, usagePercent: percent)
        } catch {
            return DiskUsageInfo(totalBytes: 0, usedBytes: 0, freeBytes: 0, usagePercent: 0)
        }
    }

    // MARK: - Battery

    private func gatherBatteryInfo() -> BatteryInfo? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/ioreg")
        process.arguments = ["-r", "-c", "AppleSmartBattery", "-w", "0"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return nil
        }

        guard process.terminationStatus == 0 else { return nil }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else { return nil }

        guard output.contains("AppleSmartBattery") else { return nil }

        // Use top-level keys (format: "Key" = Value with spaces around =)
        let currentCapacityPct = extractTopLevelInt(from: output, key: "CurrentCapacity") ?? 0
        let maxCapacityPct = extractTopLevelInt(from: output, key: "MaxCapacity") ?? 0

        // Use Raw values for mAh
        let rawCurrentCapacity = extractTopLevelInt(from: output, key: "AppleRawCurrentCapacity") ?? 0
        let rawMaxCapacity = extractTopLevelInt(from: output, key: "AppleRawMaxCapacity")
            ?? extractTopLevelInt(from: output, key: "NominalChargeCapacity") ?? 0
        let designCapacity = extractTopLevelInt(from: output, key: "DesignCapacity") ?? rawMaxCapacity
        let cycleCount = extractTopLevelInt(from: output, key: "CycleCount") ?? 0
        let isCharging = output.contains("\"IsCharging\" = Yes")

        if rawMaxCapacity <= 0 && designCapacity <= 0 && cycleCount == 0 && maxCapacityPct <= 0 {
            return nil
        }

        let healthPercent: Double
        if designCapacity > 0 && rawMaxCapacity > 0 {
            healthPercent = Double(rawMaxCapacity) / Double(designCapacity) * 100.0
        } else {
            healthPercent = Double(maxCapacityPct)
        }

        // Temperature is in centi-Celsius (divide by 100)
        let tempRaw = extractTopLevelInt(from: output, key: "Temperature")
        let temperature: Double? = tempRaw.map { Double($0) / 100.0 }

        let chargePercent = Double(currentCapacityPct)

        return BatteryInfo(
            isPresent: true,
            currentCapacity: rawCurrentCapacity,
            maxCapacity: rawMaxCapacity,
            designCapacity: designCapacity,
            cycleCount: cycleCount,
            isCharging: isCharging,
            healthPercent: healthPercent,
            temperatureCelsius: temperature,
            chargePercent: chargePercent
        )
    }

    private func extractInt(from text: String, key: String) -> Int? {
        guard let range = text.range(of: key) else { return nil }
        let afterKey = text[range.upperBound...]
        guard let eqRange = afterKey.range(of: "= ") else { return nil }
        let afterEq = afterKey[eqRange.upperBound...]
        let numberStr = afterEq.prefix(while: { $0.isNumber })
        return Int(numberStr)
    }

    /// Extract integer from top-level ioreg output only (lines matching `"Key" = Value`)
    /// This avoids matching keys inside nested BatteryData dict which uses `"Key"=Value` (no spaces)
    private func extractTopLevelInt(from text: String, key: String) -> Int? {
        let pattern = "\"\(key)\" = "
        for line in text.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("\"\(key)\" = ") else { continue }
            let afterEq = trimmed.dropFirst(pattern.count)
            let numberStr = afterEq.prefix(while: { $0.isNumber })
            if let value = Int(numberStr) {
                return value
            }
        }
        return nil
    }

    // MARK: - Startup Items

    private func gatherStartupItems() -> [StartupItem] {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        var items: [StartupItem] = []

        items.append(contentsOf: scanLaunchDirectory("\(home)/Library/LaunchAgents", source: .userAgent))
        items.append(contentsOf: scanLaunchDirectory("/Library/LaunchAgents", source: .globalAgent))
        items.append(contentsOf: scanLaunchDirectory("/Library/LaunchDaemons", source: .globalDaemon))

        items.sort { $0.name.localizedCompare($1.name) == .orderedAscending }
        return items
    }

    private func scanLaunchDirectory(_ path: String, source: StartupSource) -> [StartupItem] {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(atPath: path) else { return [] }

        var items: [StartupItem] = []
        for file in files where file.hasSuffix(".plist") {
            let fullPath = "\(path)/\(file)"
            let label = plistLabel(at: fullPath) ?? file.replacingOccurrences(of: ".plist", with: "")
            let isDisabled = plistDisabledValue(at: fullPath)

            items.append(StartupItem(
                name: label,
                path: fullPath,
                source: source,
                isEnabled: !isDisabled
            ))
        }
        return items
    }

    private func plistLabel(at path: String) -> String? {
        guard let dict = NSDictionary(contentsOfFile: path) else { return nil }
        return dict["Label"] as? String
    }

    private func plistDisabledValue(at path: String) -> Bool {
        guard let dict = NSDictionary(contentsOfFile: path) else { return false }
        return dict["Disabled"] as? Bool ?? false
    }

    // MARK: - Thermal / Fan

    private func gatherThermalInfo(batteryTemp: Double?) -> ThermalInfo? {
        let fans = gatherFanSpeeds()
        if fans.isEmpty && batteryTemp == nil { return nil }
        return ThermalInfo(fans: fans, batteryTemperatureCelsius: batteryTemp)
    }

    private func gatherFanSpeeds() -> [FanInfo] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/ioreg")
        process.arguments = ["-r", "-c", "AppleSMCFan", "-w", "0"]

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
        guard let output = String(data: data, encoding: .utf8), !output.isEmpty else { return [] }

        var fans: [FanInfo] = []
        // Parse fan entries — look for ActualSpeed, MinSpeed, MaxSpeed
        let sections = output.components(separatedBy: "+-o ")
        for (index, section) in sections.enumerated() where section.contains("ActualSpeed") || section.contains("CurrentSpeed") {
            let rpm = extractInt(from: section, key: "\"ActualSpeed\"")
                ?? extractInt(from: section, key: "\"CurrentSpeed\"")
                ?? 0
            let minRPM = extractInt(from: section, key: "\"MinSpeed\"")
            let maxRPM = extractInt(from: section, key: "\"MaxSpeed\"")

            let fanName: String
            if let nameRange = section.range(of: "\"Description\" = \"") {
                let after = section[nameRange.upperBound...]
                fanName = String(after.prefix(while: { $0 != "\"" }))
            } else {
                fanName = "Fan \(index)"
            }

            if rpm > 0 || minRPM != nil {
                fans.append(FanInfo(id: fans.count, name: fanName, currentRPM: rpm, minRPM: minRPM, maxRPM: maxRPM))
            }
        }

        return fans
    }
}
