import Foundation

public enum MemoryPressureLevel: String, Codable, CaseIterable, Sendable {
    case normal
    case warning
    case critical
    case unknown
}

public struct ProcessMemoryEntry: Identifiable, Codable, Hashable, Sendable {
    public var id: Int32 { pid }
    public let pid: Int32
    public let name: String
    public let rssBytes: UInt64
    public let compressedBytes: UInt64?
    public let cpuPercent: Double?

    public init(
        pid: Int32,
        name: String,
        rssBytes: UInt64,
        compressedBytes: UInt64? = nil,
        cpuPercent: Double? = nil
    ) {
        self.pid = pid
        self.name = name
        self.rssBytes = rssBytes
        self.compressedBytes = compressedBytes
        self.cpuPercent = cpuPercent
    }
}

public struct SystemMemoryStats: Codable, Sendable {
    public let totalBytes: UInt64
    public let usedBytes: UInt64
    public let wiredBytes: UInt64
    public let compressedBytes: UInt64
    public let appBytes: UInt64
    public let freeBytes: UInt64
    public let swapUsedBytes: UInt64

    public init(totalBytes: UInt64, usedBytes: UInt64, wiredBytes: UInt64, compressedBytes: UInt64, appBytes: UInt64, freeBytes: UInt64, swapUsedBytes: UInt64) {
        self.totalBytes = totalBytes
        self.usedBytes = usedBytes
        self.wiredBytes = wiredBytes
        self.compressedBytes = compressedBytes
        self.appBytes = appBytes
        self.freeBytes = freeBytes
        self.swapUsedBytes = swapUsedBytes
    }
}

public struct MemorySnapshot: Codable, Sendable {
    public let capturedAt: Date
    public let systemMemoryPressure: MemoryPressureLevel
    public let processes: [ProcessMemoryEntry]
    public let memoryStats: SystemMemoryStats?

    public init(capturedAt: Date, systemMemoryPressure: MemoryPressureLevel, processes: [ProcessMemoryEntry], memoryStats: SystemMemoryStats? = nil) {
        self.capturedAt = capturedAt
        self.systemMemoryPressure = systemMemoryPressure
        self.processes = processes
        self.memoryStats = memoryStats
    }
}
