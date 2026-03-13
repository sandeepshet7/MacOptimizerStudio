import Foundation

public enum ExtensionType: String, CaseIterable, Sendable, Hashable {
    case safariExtension = "Safari Extension"
    case spotlightPlugin = "Spotlight Plugin"
    case quickLookPlugin = "Quick Look Plugin"
    case preferencePanes = "Preference Pane"
    case inputMethod = "Input Method"
    case screenSaver = "Screen Saver"

    public var icon: String {
        switch self {
        case .safariExtension: return "safari"
        case .spotlightPlugin: return "magnifyingglass"
        case .quickLookPlugin: return "eye"
        case .preferencePanes: return "gearshape"
        case .inputMethod: return "keyboard"
        case .screenSaver: return "tv"
        }
    }

    public var tint: String {
        switch self {
        case .safariExtension: return "blue"
        case .spotlightPlugin: return "purple"
        case .quickLookPlugin: return "cyan"
        case .preferencePanes: return "gray"
        case .inputMethod: return "green"
        case .screenSaver: return "indigo"
        }
    }
}

public struct SystemExtension: Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let bundleId: String
    public let path: String
    public let type: ExtensionType
    public let sizeBytes: UInt64

    public init(id: String = UUID().uuidString, name: String, bundleId: String, path: String, type: ExtensionType, sizeBytes: UInt64) {
        self.id = id
        self.name = name
        self.bundleId = bundleId
        self.path = path
        self.type = type
        self.sizeBytes = sizeBytes
    }
}
