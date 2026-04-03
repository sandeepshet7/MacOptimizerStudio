import Foundation

public struct OutdatedApp: Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let currentVersion: String
    public let latestVersion: String
    public let isHomebrew: Bool

    public init(id: String = UUID().uuidString, name: String, currentVersion: String, latestVersion: String, isHomebrew: Bool) {
        self.id = id
        self.name = name
        self.currentVersion = currentVersion
        self.latestVersion = latestVersion
        self.isHomebrew = isHomebrew
    }
}

public struct UpdateResult: Sendable {
    public let appName: String
    public let success: Bool
    public let error: String?

    public init(appName: String, success: Bool, error: String? = nil) {
        self.appName = appName
        self.success = success
        self.error = error
    }
}
