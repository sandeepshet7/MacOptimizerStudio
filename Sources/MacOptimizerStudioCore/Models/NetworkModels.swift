import Foundation

public struct NetworkSnapshot: Codable, Sendable {
    public let bytesIn: UInt64
    public let bytesOut: UInt64
    public let bytesInPerSec: Double
    public let bytesOutPerSec: Double
    public let capturedAt: Date
    public let activeConnections: Int

    public init(
        bytesIn: UInt64,
        bytesOut: UInt64,
        bytesInPerSec: Double,
        bytesOutPerSec: Double,
        capturedAt: Date,
        activeConnections: Int
    ) {
        self.bytesIn = bytesIn
        self.bytesOut = bytesOut
        self.bytesInPerSec = bytesInPerSec
        self.bytesOutPerSec = bytesOutPerSec
        self.capturedAt = capturedAt
        self.activeConnections = activeConnections
    }
}

public struct NetworkConnection: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public let processName: String
    public let localAddress: String
    public let remoteAddress: String
    public let networkProtocol: String
    public let state: String

    public init(
        id: UUID = UUID(),
        processName: String,
        localAddress: String,
        remoteAddress: String,
        networkProtocol: String,
        state: String
    ) {
        self.id = id
        self.processName = processName
        self.localAddress = localAddress
        self.remoteAddress = remoteAddress
        self.networkProtocol = networkProtocol
        self.state = state
    }
}
