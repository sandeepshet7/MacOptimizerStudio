import Foundation

public enum ExecutionRisk: String, Sendable {
    case safe
    case moderate
    case danger
}

public struct ExecutionItem: Identifiable, Sendable {
    public let id = UUID()
    public let label: String
    public let path: String
    public let sizeBytes: UInt64

    public init(label: String, path: String, sizeBytes: UInt64) {
        self.label = label
        self.path = path
        self.sizeBytes = sizeBytes
    }
}

public struct ExecutionRequest: Identifiable, Sendable {
    public let id = UUID()
    public let title: String
    public let warningMessage: String
    public let risk: ExecutionRisk
    public let items: [ExecutionItem]
    public let commands: [String]
    public let confirmationWord: String

    public init(
        title: String,
        warningMessage: String,
        risk: ExecutionRisk = .moderate,
        items: [ExecutionItem],
        commands: [String],
        confirmationWord: String = "CONFIRM"
    ) {
        self.title = title
        self.warningMessage = warningMessage
        self.risk = risk
        self.items = items
        self.commands = commands
        self.confirmationWord = confirmationWord
    }
}

public struct ExecutionResult: Sendable {
    public let success: Bool
    public let freedBytes: UInt64
    public let itemsProcessed: Int
    public let errors: [String]
    public let duration: TimeInterval

    public init(success: Bool, freedBytes: UInt64, itemsProcessed: Int, errors: [String], duration: TimeInterval) {
        self.success = success
        self.freedBytes = freedBytes
        self.itemsProcessed = itemsProcessed
        self.errors = errors
        self.duration = duration
    }
}
