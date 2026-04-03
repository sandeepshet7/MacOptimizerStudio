import Foundation
import Security

public struct FileShredderService: Sendable {
    public init() {}

    /// Securely erase a file by overwriting with random data 3 times, then deleting.
    ///
    /// Uses O_NOFOLLOW to prevent TOCTOU symlink substitution attacks and fstat()
    /// to verify the opened descriptor refers to a regular file.
    public func shredFile(at path: String) -> (success: Bool, error: String?) {
        // Open with O_NOFOLLOW to atomically refuse symlinks — prevents TOCTOU race
        // where an attacker substitutes a symlink between an existence check and open.
        let fd = open(path, O_WRONLY | O_NOFOLLOW)
        guard fd >= 0 else {
            let code = errno
            if code == ELOOP {
                return (false, "Refusing to follow symlink")
            } else if code == ENOENT {
                return (false, "File not found")
            }
            return (false, "Cannot open file (errno \(code))")
        }
        // Immediately close after validation — we reopen per pass via FileHandle(fileDescriptor:)
        // but first verify this is a regular file via fstat on the open descriptor.
        var statBuf = stat()
        guard fstat(fd, &statBuf) == 0 else {
            close(fd)
            return (false, "Cannot stat file descriptor")
        }
        guard (statBuf.st_mode & S_IFMT) == S_IFREG else {
            close(fd)
            return (false, "Not a regular file — refusing to shred")
        }

        let fileSize = UInt64(statBuf.st_size)

        // Overwrite 3 passes with random data, reusing the validated file descriptor
        for pass in 0..<3 {
            // For the first pass we already have the fd; for subsequent passes reopen
            // with the same O_NOFOLLOW protection.
            let writeFd: Int32
            if pass == 0 {
                writeFd = fd
            } else {
                writeFd = open(path, O_WRONLY | O_NOFOLLOW)
                guard writeFd >= 0 else {
                    return (false, "Cannot reopen file for pass \(pass + 1)")
                }
                // Re-verify inode hasn't changed (same device + inode)
                var recheckStat = stat()
                guard fstat(writeFd, &recheckStat) == 0,
                      recheckStat.st_dev == statBuf.st_dev,
                      recheckStat.st_ino == statBuf.st_ino else {
                    close(writeFd)
                    return (false, "File identity changed between passes — aborting")
                }
            }

            let handle = FileHandle(fileDescriptor: writeFd, closeOnDealloc: true)
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
            // FileHandle closes the fd on dealloc via closeOnDealloc: true
        }

        // Delete the file
        do {
            try FileManager.default.removeItem(atPath: path)
            return (true, nil)
        } catch {
            return (false, error.localizedDescription)
        }
    }

    /// Shred a directory recursively.
    ///
    /// Resolves symlinks on the directory path before enumeration to prevent
    /// directory traversal attacks.
    public func shredDirectory(at path: String, onProgress: @Sendable (String) -> Void) -> (success: Bool, errors: [String]) {
        let fm = FileManager.default
        var errors: [String] = []

        // Resolve symlinks on the directory itself to prevent traversal attacks
        let resolvedPath = (path as NSString).resolvingSymlinksInPath

        guard let enumerator = fm.enumerator(atPath: resolvedPath) else {
            return (false, ["Cannot enumerate directory"])
        }

        // Collect all files first (not directories)
        var files: [String] = []
        while let item = enumerator.nextObject() as? String {
            let fullPath = (resolvedPath as NSString).appendingPathComponent(item)
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
            try fm.removeItem(atPath: resolvedPath)
        } catch {
            errors.append("Failed to remove directory: \(error.localizedDescription)")
        }

        return (errors.isEmpty, errors)
    }
}
