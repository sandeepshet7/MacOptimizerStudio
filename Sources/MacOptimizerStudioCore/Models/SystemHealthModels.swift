import Foundation

public struct DiskUsageInfo: Sendable {
    public let totalBytes: UInt64
    public let usedBytes: UInt64
    public let freeBytes: UInt64
    public let usagePercent: Double

    public init(totalBytes: UInt64, usedBytes: UInt64, freeBytes: UInt64, usagePercent: Double) {
        self.totalBytes = totalBytes
        self.usedBytes = usedBytes
        self.freeBytes = freeBytes
        self.usagePercent = usagePercent
    }
}

public struct HardwareInfo: Sendable {
    public let cpuModel: String
    public let cpuCoreCount: Int
    public let totalRAMBytes: UInt64
    public let macOSVersion: String
    public let macOSBuild: String
    public let uptimeSeconds: TimeInterval
    public let hostname: String

    public init(cpuModel: String, cpuCoreCount: Int, totalRAMBytes: UInt64, macOSVersion: String, macOSBuild: String, uptimeSeconds: TimeInterval, hostname: String) {
        self.cpuModel = cpuModel
        self.cpuCoreCount = cpuCoreCount
        self.totalRAMBytes = totalRAMBytes
        self.macOSVersion = macOSVersion
        self.macOSBuild = macOSBuild
        self.uptimeSeconds = uptimeSeconds
        self.hostname = hostname
    }
}

public struct BatteryInfo: Sendable {
    public let isPresent: Bool
    public let currentCapacity: Int
    public let maxCapacity: Int
    public let designCapacity: Int
    public let cycleCount: Int
    public let isCharging: Bool
    public let healthPercent: Double
    public let temperatureCelsius: Double?
    public let chargePercent: Double

    public init(isPresent: Bool, currentCapacity: Int, maxCapacity: Int, designCapacity: Int, cycleCount: Int, isCharging: Bool, healthPercent: Double, temperatureCelsius: Double? = nil, chargePercent: Double = 0) {
        self.isPresent = isPresent
        self.currentCapacity = currentCapacity
        self.maxCapacity = maxCapacity
        self.designCapacity = designCapacity
        self.cycleCount = cycleCount
        self.isCharging = isCharging
        self.healthPercent = healthPercent
        self.temperatureCelsius = temperatureCelsius
        self.chargePercent = chargePercent
    }
}

public struct FanInfo: Identifiable, Sendable {
    public let id: Int
    public let name: String
    public let currentRPM: Int
    public let minRPM: Int?
    public let maxRPM: Int?

    public init(id: Int, name: String, currentRPM: Int, minRPM: Int? = nil, maxRPM: Int? = nil) {
        self.id = id
        self.name = name
        self.currentRPM = currentRPM
        self.minRPM = minRPM
        self.maxRPM = maxRPM
    }
}

public struct ThermalInfo: Sendable {
    public let fans: [FanInfo]
    public let batteryTemperatureCelsius: Double?

    public init(fans: [FanInfo], batteryTemperatureCelsius: Double? = nil) {
        self.fans = fans
        self.batteryTemperatureCelsius = batteryTemperatureCelsius
    }

    public var hasFans: Bool { !fans.isEmpty }
    public var hasAnyData: Bool { hasFans || batteryTemperatureCelsius != nil }
}

public struct StartupItem: Identifiable, Sendable {
    public let id: String
    public let name: String
    public let path: String
    public let source: StartupSource
    public let isEnabled: Bool

    public init(name: String, path: String, source: StartupSource, isEnabled: Bool) {
        self.id = path
        self.name = name
        self.path = path
        self.source = source
        self.isEnabled = isEnabled
    }
}

public enum StartupSource: String, Sendable {
    case userAgent
    case globalAgent
    case globalDaemon

    public var displayName: String {
        switch self {
        case .userAgent: return "User Agent"
        case .globalAgent: return "Global Agent"
        case .globalDaemon: return "Global Daemon"
        }
    }

    public var icon: String {
        switch self {
        case .userAgent: return "person.fill"
        case .globalAgent: return "globe"
        case .globalDaemon: return "gearshape.fill"
        }
    }
}

public struct SystemHealthSnapshot: Sendable {
    public let capturedAt: Date
    public let hardware: HardwareInfo
    public let diskUsage: DiskUsageInfo
    public let battery: BatteryInfo?
    public let startupItems: [StartupItem]
    public let thermal: ThermalInfo?

    public init(capturedAt: Date, hardware: HardwareInfo, diskUsage: DiskUsageInfo, battery: BatteryInfo?, startupItems: [StartupItem], thermal: ThermalInfo? = nil) {
        self.capturedAt = capturedAt
        self.hardware = hardware
        self.diskUsage = diskUsage
        self.battery = battery
        self.startupItems = startupItems
        self.thermal = thermal
    }
}
