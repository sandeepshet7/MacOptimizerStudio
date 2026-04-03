import Foundation

public struct DiskHealthSnapshot: Codable, Sendable {
    public let diskName: String
    public let diskModel: String
    public let serialNumber: String
    public let mediaType: String
    public let smartStatus: String
    public let powerOnHours: Int?
    public let temperature: Double?
    public let wearLevel: Double?
    public let capturedAt: Date
    public let attributes: [SmartAttribute]

    public init(
        diskName: String,
        diskModel: String,
        serialNumber: String,
        mediaType: String,
        smartStatus: String,
        powerOnHours: Int? = nil,
        temperature: Double? = nil,
        wearLevel: Double? = nil,
        capturedAt: Date = Date(),
        attributes: [SmartAttribute] = []
    ) {
        self.diskName = diskName
        self.diskModel = diskModel
        self.serialNumber = serialNumber
        self.mediaType = mediaType
        self.smartStatus = smartStatus
        self.powerOnHours = powerOnHours
        self.temperature = temperature
        self.wearLevel = wearLevel
        self.capturedAt = capturedAt
        self.attributes = attributes
    }
}

public struct SmartAttribute: Identifiable, Codable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let rawValue: String
    public let threshold: String?
    public let status: SmartAttributeStatus

    public init(
        id: String,
        name: String,
        rawValue: String,
        threshold: String? = nil,
        status: SmartAttributeStatus = .ok
    ) {
        self.id = id
        self.name = name
        self.rawValue = rawValue
        self.threshold = threshold
        self.status = status
    }
}

public enum SmartAttributeStatus: String, Codable, Sendable {
    case ok
    case warning
    case critical
}
