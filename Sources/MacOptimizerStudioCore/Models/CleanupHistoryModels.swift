import Foundation

public struct CleanupRecord: Identifiable, Codable, Sendable {
    public let id: String
    public let date: Date
    public let category: String
    public let itemCount: Int
    public let bytesFreed: UInt64
    public let details: String

    public init(date: Date, category: String, itemCount: Int, bytesFreed: UInt64, details: String) {
        self.id = UUID().uuidString
        self.date = date
        self.category = category
        self.itemCount = itemCount
        self.bytesFreed = bytesFreed
        self.details = details
    }
}
