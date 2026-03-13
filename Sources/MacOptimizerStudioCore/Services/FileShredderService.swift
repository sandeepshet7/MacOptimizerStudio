import Foundation
import Security

public struct FileShredderService: Sendable {
    public init() {}

    /// Securely erase a file by overwriting with random data 3 times, then deleting
    public func shredFile(at path: String) -> (success: Bool, error: String?) {
        let fm = FileManager.default
        guard fm.fileExists(atPath: path) else {
            return (false, "File not found")
        }

        // Get file size
        guard let attrs = try? fm.attributesOfItem(atPath: path),
              let fileSize = attrs[.size] as? UInt64 else {
            return (false, "Cannot read file attributes")
        }

        // Overwrite 3 passes with random data
        for _ in 0..<3 {
            guard let handle = FileHandle(forWritingAtPath: path) else {
                return (false, "Cannot open file for writing")
            }
            defer { handle.closeFile() }

            handle.seek(toFileOffset: 0)
            var remaining = fileSize
            while remaining > 0 {
                let chunkSize = min(remaining, 65536)
                var randomBytes = [UInt8](repeating: 0, count: Int(chunkSize))
                _ = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
                handle.write(Data(randomBytes))
                remaining -= chunkSize
            }
            handle.synchronizeFile()
        }

        // Delete the file
        do {
            try fm.removeItem(atPath: path)
            return (true, nil)
        } catch {
            return (false, error.localizedDescription)
        }
    }

    /// Shred a directory recursively
    public func shredDirectory(at path: String, onProgress: @Sendable (String) -> Void) -> (success: Bool, errors: [String]) {
        let fm = FileManager.default
        var errors: [String] = []

        guard let enumerator = fm.enumerator(atPath: path) else {
            return (false, ["Cannot enumerate directory"])
        }

        // Collect all files first (not directories)
        var files: [String] = []
        while let item = enumerator.nextObject() as? String {
            let fullPath = "\(path)/\(item)"
            var isDir: ObjCBool = false
            if fm.fileExists(atPath: fullPath, isDirectory: &isDir), !isDir.boolValue {
                files.append(fullPath)
            }
        }

        for (index, file) in files.enumerated() {
            onProgress("Shredding \(index + 1)/\(files.count)...")
            let result = shredFile(at: file)
            if !result.success {
                errors.append("\(file): \(result.error ?? "Unknown error")")
            }
        }

        // Remove empty directories
        do {
            try fm.removeItem(atPath: path)
        } catch {
            errors.append("Failed to remove directory: \(error.localizedDescription)")
        }

        return (errors.isEmpty, errors)
    }
}
