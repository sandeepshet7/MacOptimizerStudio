import Foundation

public struct StartupTimeSnapshot: Codable, Sendable {
    public let firmwareTime: Double?
    public let loaderTime: Double?
    public let kernelTime: Double?
    public let totalBootTime: Double
    public let lastBootDate: Date?
    public let capturedAt: Date

    public init(
        firmwareTime: Double? = nil,
        loaderTime: Double? = nil,
        kernelTime: Double? = nil,
        totalBootTime: Double,
        lastBootDate: Date? = nil,
        capturedAt: Date = Date()
    ) {
        self.firmwareTime = firmwareTime
        self.loaderTime = loaderTime
        self.kernelTime = kernelTime
        self.totalBootTime = totalBootTime
        self.lastBootDate = lastBootDate
        self.capturedAt = capturedAt
    }
}

public enum StartupContributorSource: String, Codable, Sendable, CaseIterable {
    case loginItem
    case launchAgent
    case launchDaemon
    case kernel
}

public struct StartupContributor: Identifiable, Codable, Sendable {
    public let id: UUID
    public let name: String
    public let timeSeconds: Double
    public let source: StartupContributorSource

    public init(
        id: UUID = UUID(),
        name: String,
        timeSeconds: Double,
        source: StartupContributorSource
    ) {
        self.id = id
        self.name = name
        self.timeSeconds = timeSeconds
        self.source = source
    }
}
