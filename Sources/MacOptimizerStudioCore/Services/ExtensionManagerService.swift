import Foundation

public struct ExtensionManagerService: Sendable {
    public init() {}

    public func scanExtensions() -> [SystemExtension] {
        var extensions: [SystemExtension] = []
        let home = FileManager.default.homeDirectoryForCurrentUser.path

        // Safari Extensions - scan ~/Library/Safari/Extensions
        extensions.append(contentsOf: scanDirectory("\(home)/Library/Safari/Extensions", type: .safariExtension))

        // Spotlight Plugins
        extensions.append(contentsOf: scanDirectory("/Library/Spotlight", type: .spotlightPlugin))
        extensions.append(contentsOf: scanDirectory("\(home)/Library/Spotlight", type: .spotlightPlugin))

        // QuickLook Plugins
        extensions.append(contentsOf: scanDirectory("/Library/QuickLook", type: .quickLookPlugin))
        extensions.append(contentsOf: scanDirectory("\(home)/Library/QuickLook", type: .quickLookPlugin))

        // Preference Panes
        extensions.append(contentsOf: scanDirectory("/Library/PreferencePanes", type: .preferencePanes))
        extensions.append(contentsOf: scanDirectory("\(home)/Library/PreferencePanes", type: .preferencePanes))

        // Input Methods
        extensions.append(contentsOf: scanDirectory("/Library/Input Methods", type: .inputMethod))
        extensions.append(contentsOf: scanDirectory("\(home)/Library/Input Methods", type: .inputMethod))

        // Screen Savers
        extensions.append(contentsOf: scanDirectory("/Library/Screen Savers", type: .screenSaver))
        extensions.append(contentsOf: scanDirectory("\(home)/Library/Screen Savers", type: .screenSaver))

        return extensions.sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
    }

    private func scanDirectory(_ path: String, type: ExtensionType) -> [SystemExtension] {
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(atPath: path) else { return [] }

        var results: [SystemExtension] = []
        for item in contents {
            let fullPath = "\(path)/\(item)"
            let name = (item as NSString).deletingPathExtension
            let bundleId = Bundle(path: fullPath)?.bundleIdentifier ?? name
            let size = directorySize(fullPath)

            results.append(SystemExtension(
                name: name,
                bundleId: bundleId,
                path: fullPath,
                type: type,
                sizeBytes: size
            ))
        }
        return results
    }

    private func directorySize(_ path: String) -> UInt64 {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(atPath: path) else {
            // Single file
            let attrs = try? fm.attributesOfItem(atPath: path)
            return (attrs?[.size] as? UInt64) ?? 0
        }
        var total: UInt64 = 0
        while let file = enumerator.nextObject() as? String {
            let full = "\(path)/\(file)"
            if let attrs = try? fm.attributesOfItem(atPath: full),
               let size = attrs[.size] as? UInt64 {
                total += size
            }
        }
        return total
    }

    public func removeExtension(at path: String) throws {
        try FileManager.default.trashItem(at: URL(fileURLWithPath: path), resultingItemURL: nil)
    }
}
