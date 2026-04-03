import Foundation

/// Safe resource bundle lookup that doesn't crash when the app is relocated.
/// SPM's auto-generated Bundle.module uses fatalError if the bundle isn't found
/// at the expected path, which breaks when the .app is moved to another machine.
enum ResourceBundle {
    static let bundle: Bundle? = {
        let bundleName = "MacOptimizerStudio_MacOptimizerStudio.bundle"

        // 1. SPM default: Bundle.main.bundleURL/<name>.bundle (works for swift run)
        let mainPath = Bundle.main.bundleURL.appendingPathComponent(bundleName)
        if let b = Bundle(path: mainPath.path) { return b }

        // 2. .app standard: Contents/Resources/<name>.bundle
        let resourcesPath = Bundle.main.bundleURL
            .appendingPathComponent("Contents/Resources")
            .appendingPathComponent(bundleName)
        if let b = Bundle(path: resourcesPath.path) { return b }

        // 3. Next to executable
        if let execURL = Bundle.main.executableURL {
            let sibling = execURL.deletingLastPathComponent()
                .appendingPathComponent(bundleName)
            if let b = Bundle(path: sibling.path) { return b }
        }

        return nil
    }()
}
