import Foundation

public struct BenchmarkResult: Codable, Sendable {
    public let sequentialReadMBps: Double
    public let sequentialWriteMBps: Double
    public let randomReadIOPS: Double?
    public let randomWriteIOPS: Double?
    public let testPath: String
    public let fileSizeMB: Int
    public let capturedAt: Date

    public init(
        sequentialReadMBps: Double,
        sequentialWriteMBps: Double,
        randomReadIOPS: Double? = nil,
        randomWriteIOPS: Double? = nil,
        testPath: String,
        fileSizeMB: Int,
        capturedAt: Date = Date()
    ) {
        self.sequentialReadMBps = sequentialReadMBps
        self.sequentialWriteMBps = sequentialWriteMBps
        self.randomReadIOPS = randomReadIOPS
        self.randomWriteIOPS = randomWriteIOPS
        self.testPath = testPath
        self.fileSizeMB = fileSizeMB
        self.capturedAt = capturedAt
    }
}

public struct BenchmarkProgress: Sendable {
    public let phase: String
    public let percent: Double

    public init(phase: String, percent: Double) {
        self.phase = phase
        self.percent = percent
    }
}
