import Foundation

public enum CleanupRiskLevel: String, Codable, Sendable {
    case safe
    case danger
}

public struct CleanupCommand: Identifiable, Hashable, Sendable {
    public let id = UUID()
    public let title: String
    public let riskLevel: CleanupRiskLevel
    public let command: String
    public let requiresWarning: Bool

    public init(title: String, riskLevel: CleanupRiskLevel, command: String, requiresWarning: Bool) {
        self.title = title
        self.riskLevel = riskLevel
        self.command = command
        self.requiresWarning = requiresWarning
    }
}
