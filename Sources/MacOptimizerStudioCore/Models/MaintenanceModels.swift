import Foundation

public struct MaintenanceTask: Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let description: String
    public let icon: String
    public let command: String
    public let requiresSudo: Bool
    public let estimatedDuration: String

    public init(id: String, name: String, description: String, icon: String, command: String, requiresSudo: Bool = false, estimatedDuration: String = "A few seconds") {
        self.id = id
        self.name = name
        self.description = description
        self.icon = icon
        self.command = command
        self.requiresSudo = requiresSudo
        self.estimatedDuration = estimatedDuration
    }
}

public struct MaintenanceResult: Sendable {
    public let taskId: String
    public let success: Bool
    public let output: String
    public let duration: TimeInterval

    public init(taskId: String, success: Bool, output: String, duration: TimeInterval) {
        self.taskId = taskId
        self.success = success
        self.output = output
        self.duration = duration
    }
}
