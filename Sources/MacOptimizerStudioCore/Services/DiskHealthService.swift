import Foundation

public struct DiskHealthService: Sendable {
    public init() {}

    public func captureSnapshot() -> DiskHealthSnapshot {
        let diskInfo = parseDiskutilInfo()
        let smartctlResult = parseSmartctl()
        let systemProfilerFallback = smartctlResult == nil ? parseSystemProfiler() : nil

        let diskName = diskInfo["Volume Name"] ?? diskInfo["Device Node"] ?? "Macintosh HD"
        let diskModel = diskInfo["Device / Media Name"]
            ?? systemProfilerFallback?.model
            ?? "Unknown"
        let serialNumber = diskInfo["Disk / Partition UUID"]
            ?? systemProfilerFallback?.serial
            ?? "N/A"
        let mediaType = diskInfo["Solid State"]?.lowercased() == "yes" ? "SSD"
            : (diskInfo["Solid State"]?.lowercased() == "no" ? "HDD"
               : (systemProfilerFallback?.mediaType ?? "Unknown"))
        let smartStatus = diskInfo["SMART Status"] ?? smartctlResult?.status ?? "Unknown"

        var attributes: [SmartAttribute] = smartctlResult?.attributes ?? []
        let powerOnHours = smartctlResult?.powerOnHours
        let temperature = smartctlResult?.temperature
        let wearLevel = smartctlResult?.wearLevel

        // If no smartctl data, add basic attributes from diskutil
        if attributes.isEmpty {
            if let proto = diskInfo["Protocol"] {
                attributes.append(SmartAttribute(id: "protocol", name: "Protocol", rawValue: proto))
            }
            if let diskSize = diskInfo["Disk Size"] {
                attributes.append(SmartAttribute(id: "disk_size", name: "Disk Size", rawValue: diskSize))
            }
            if let containerFree = diskInfo["Container Free Space"] {
                attributes.append(SmartAttribute(id: "free_space", name: "Free Space", rawValue: containerFree))
            }
            if let fileSystem = diskInfo["Type (Bundle)"] {
                attributes.append(SmartAttribute(id: "filesystem", name: "File System", rawValue: fileSystem))
            }
        }

        return DiskHealthSnapshot(
            diskName: diskName,
            diskModel: diskModel,
            serialNumber: serialNumber,
            mediaType: mediaType,
            smartStatus: smartStatus,
            powerOnHours: powerOnHours,
            temperature: temperature,
            wearLevel: wearLevel,
            capturedAt: Date(),
            attributes: attributes
        )
    }

    // MARK: - diskutil info /

    private func parseDiskutilInfo() -> [String: String] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/diskutil")
        process.arguments = ["info", "/"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return [:]
        }

        guard process.terminationStatus == 0 else { return [:] }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else { return [:] }

        var info: [String: String] = [:]
        for line in output.split(separator: "\n") {
            let parts = line.split(separator: ":", maxSplits: 1)
            guard parts.count == 2 else { continue }
            let key = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
            let value = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
            info[key] = value
        }
        return info
    }

    // MARK: - smartctl

    private struct SmartctlResult {
        var status: String = "Unknown"
        var attributes: [SmartAttribute] = []
        var powerOnHours: Int?
        var temperature: Double?
        var wearLevel: Double?
    }

    private func parseSmartctl() -> SmartctlResult? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/local/bin/smartctl")
        process.arguments = ["-a", "/dev/disk0"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            // smartctl not installed — try /opt/homebrew path
            return parseSmartctlAt(path: "/opt/homebrew/bin/smartctl")
        }

        return parseSmartctlOutput(pipe: pipe)
    }

    private func parseSmartctlAt(path: String) -> SmartctlResult? {
        guard FileManager.default.fileExists(atPath: path) else { return nil }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = ["-a", "/dev/disk0"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return nil
        }

        return parseSmartctlOutput(pipe: pipe)
    }

    private func parseSmartctlOutput(pipe: Pipe) -> SmartctlResult? {
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8), !output.isEmpty else { return nil }

        var result = SmartctlResult()

        for line in output.split(separator: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)

            if trimmed.hasPrefix("SMART overall-health") || trimmed.hasPrefix("SMART Health Status") {
                if trimmed.contains("PASSED") || trimmed.contains("OK") {
                    result.status = "Verified"
                } else {
                    result.status = "Failing"
                }
            }

            if trimmed.contains("Power_On_Hours") || trimmed.contains("Power On Hours") {
                let parts = trimmed.split(whereSeparator: { $0 == " " || $0 == "\t" })
                if let last = parts.last, let hours = Int(last) {
                    result.powerOnHours = hours
                }
            }

            if trimmed.contains("Temperature_Celsius") || trimmed.contains("Temperature:") {
                let parts = trimmed.split(whereSeparator: { $0 == " " || $0 == "\t" })
                for part in parts.reversed() {
                    if let temp = Double(part) {
                        result.temperature = temp
                        break
                    }
                }
            }

            if trimmed.contains("Wear_Leveling_Count") || trimmed.contains("Percentage Used") {
                let parts = trimmed.split(whereSeparator: { $0 == " " || $0 == "\t" })
                for part in parts.reversed() {
                    let cleaned = part.replacingOccurrences(of: "%", with: "")
                    if let wear = Double(cleaned), wear >= 0, wear <= 100 {
                        result.wearLevel = wear
                        break
                    }
                }
            }

            // Parse attribute table rows (ID# ATTRIBUTE_NAME ... RAW_VALUE)
            if trimmed.first?.isNumber == true {
                let fields = trimmed.split(whereSeparator: { $0 == " " || $0 == "\t" })
                    .map(String.init)
                if fields.count >= 10 {
                    let attrId = fields[0]
                    let attrName = fields[1]
                    let rawVal = fields.last ?? ""
                    let thresh = fields.count >= 6 ? fields[5] : nil
                    let statusStr: SmartAttributeStatus = {
                        if fields.count >= 9 {
                            let flag = fields[8].lowercased()
                            if flag.contains("fail") { return .critical }
                            if flag.contains("warn") { return .warning }
                        }
                        return .ok
                    }()

                    result.attributes.append(SmartAttribute(
                        id: attrId,
                        name: attrName.replacingOccurrences(of: "_", with: " "),
                        rawValue: rawVal,
                        threshold: thresh,
                        status: statusStr
                    ))
                }
            }
        }

        return result
    }

    // MARK: - system_profiler fallback

    private struct SystemProfilerInfo {
        var model: String?
        var serial: String?
        var mediaType: String?
    }

    private func parseSystemProfiler() -> SystemProfilerInfo? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/system_profiler")
        process.arguments = ["SPStorageDataType", "-json"]

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
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let items = json["SPStorageDataType"] as? [[String: Any]],
              let first = items.first else {
            return nil
        }

        var info = SystemProfilerInfo()
        info.model = first["physical_drive_media_name"] as? String
            ?? first["device_name"] as? String
        info.serial = first["device_serial"] as? String
        let medium = first["medium_type"] as? String ?? ""
        if medium.lowercased().contains("ssd") || medium.lowercased().contains("solid") {
            info.mediaType = "SSD"
        } else if medium.lowercased().contains("hdd") || medium.lowercased().contains("rotational") {
            info.mediaType = "HDD"
        } else {
            info.mediaType = medium.isEmpty ? "Unknown" : medium
        }

        return info
    }
}
