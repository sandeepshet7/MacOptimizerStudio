import CommonCrypto
import Foundation

public struct StorageToolsService: Sendable {
    public init() {}

    // MARK: - Space Lens

    public func scanFolderSizes(at url: URL, maxDepth: Int = 3) -> FolderNode {
        let fm = FileManager.default
        let name = url.lastPathComponent
        let path = url.path

        guard maxDepth > 0 else {
            let size = directorySize(at: url)
            return FolderNode(id: path, name: name, sizeBytes: size, children: [], fileCount: 0, isDirectory: true)
        }

        var children: [FolderNode] = []
        var totalSize: UInt64 = 0
        var fileCount = 0

        guard let contents = try? fm.contentsOfDirectory(at: url, includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey, .totalFileAllocatedSizeKey], options: [.skipsHiddenFiles]) else {
            return FolderNode(id: path, name: name, sizeBytes: 0, children: [], fileCount: 0, isDirectory: true)
        }

        for item in contents {
            let isDir = (try? item.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
            if isDir {
                let child = scanFolderSizes(at: item, maxDepth: maxDepth - 1)
                totalSize += child.sizeBytes
                fileCount += child.fileCount
                children.append(child)
            } else {
                let values = try? item.resourceValues(forKeys: [.totalFileAllocatedSizeKey, .fileSizeKey])
                let size = UInt64(values?.totalFileAllocatedSize ?? values?.fileSize ?? 0)
                totalSize += size
                fileCount += 1
            }
        }

        children.sort { $0.sizeBytes > $1.sizeBytes }
        return FolderNode(id: path, name: name, sizeBytes: totalSize, children: children, fileCount: fileCount, isDirectory: true)
    }

    private func directorySize(at url: URL) -> UInt64 {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(at: url, includingPropertiesForKeys: [.totalFileAllocatedSizeKey], options: [.skipsHiddenFiles]) else { return 0 }

        var total: UInt64 = 0
        for case let fileURL as URL in enumerator {
            let values = try? fileURL.resourceValues(forKeys: [.totalFileAllocatedSizeKey])
            total += UInt64(values?.totalFileAllocatedSize ?? 0)
        }
        return total
    }

    // MARK: - Duplicate Finder

    /// Max file size for full hashing (500 MB) — files larger than this use partial hash + size match only
    private static let maxFullHashSize: UInt64 = 500 * 1024 * 1024

    public func findDuplicates(in urls: [URL], minSize: UInt64 = 1024, onProgress: @Sendable (String) -> Void) -> [DuplicateGroup] {
        onProgress("Scanning files...")
        var filesBySize: [UInt64: [URL]] = [:]
        let fm = FileManager.default

        for root in urls {
            guard let enumerator = fm.enumerator(at: root, includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey, .isRegularFileKey], options: [.skipsHiddenFiles]) else { continue }

            for case let fileURL as URL in enumerator {
                let values = try? fileURL.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
                guard values?.isRegularFile == true else { continue }
                let size = UInt64(values?.fileSize ?? 0)
                guard size >= minSize else { continue }
                filesBySize[size, default: []].append(fileURL)
            }
        }

        // Filter to sizes with multiple files
        let candidates = filesBySize.filter { $0.value.count > 1 }
        onProgress("Comparing \(candidates.count) size groups...")

        var groups: [DuplicateGroup] = []

        for (size, files) in candidates {
            // Hash first 4KB for quick comparison
            var byPartialHash: [String: [URL]] = [:]
            for file in files {
                if let hash = partialHash(of: file) {
                    byPartialHash[hash, default: []].append(file)
                }
            }

            for (partialKey, matched) in byPartialHash where matched.count > 1 {
                if size > Self.maxFullHashSize {
                    // For very large files, partial hash + same size is sufficient
                    let paths = matched.map(\.path)
                    groups.append(DuplicateGroup(id: "\(partialKey)-\(size)", fileSize: size, paths: paths))
                } else {
                    // Full hash to confirm
                    var byFullHash: [String: [String]] = [:]
                    for file in matched {
                        if let hash = fullHash(of: file) {
                            byFullHash[hash, default: []].append(file.path)
                        }
                    }

                    for (hash, paths) in byFullHash where paths.count > 1 {
                        groups.append(DuplicateGroup(id: hash, fileSize: size, paths: paths))
                    }
                }
            }
        }

        groups.sort { $0.wastedBytes > $1.wastedBytes }
        onProgress("Found \(groups.count) duplicate groups")
        return groups
    }

    private func partialHash(of url: URL, bytes: Int = 4096) -> String? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { handle.closeFile() }
        let data = handle.readData(ofLength: bytes)
        return sha256(data)
    }

    private func fullHash(of url: URL) -> String? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { handle.closeFile() }

        var context = CC_SHA256_CTX()
        CC_SHA256_Init(&context)

        while autoreleasepool(invoking: {
            let chunk = handle.readData(ofLength: 65536)
            if chunk.isEmpty { return false }
            chunk.withUnsafeBytes { ptr in
                _ = CC_SHA256_Update(&context, ptr.baseAddress, CC_LONG(chunk.count))
            }
            return true
        }) {}

        var digest = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        CC_SHA256_Final(&digest, &context)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private func sha256(_ data: Data) -> String {
        var digest = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes { ptr in
            _ = CC_SHA256(ptr.baseAddress, CC_LONG(data.count), &digest)
        }
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    // MARK: - Large & Old Files

    public func findLargeOldFiles(in urls: [URL], minSizeBytes: UInt64 = 100 * 1024 * 1024, minAgeDays: Int? = nil, onProgress: @Sendable (String) -> Void) -> [LargeFile] {
        onProgress("Scanning for large files...")
        let fm = FileManager.default
        var results: [LargeFile] = []
        let keys: Set<URLResourceKey> = [.fileSizeKey, .isRegularFileKey, .contentAccessDateKey, .contentModificationDateKey, .nameKey]
        let cutoffDate: Date? = minAgeDays.map { Calendar.current.date(byAdding: .day, value: -$0, to: Date())! }

        for root in urls {
            guard let enumerator = fm.enumerator(at: root, includingPropertiesForKeys: Array(keys), options: [.skipsHiddenFiles]) else { continue }

            for case let fileURL as URL in enumerator {
                let values = try? fileURL.resourceValues(forKeys: keys)
                guard values?.isRegularFile == true else { continue }
                let size = UInt64(values?.fileSize ?? 0)
                guard size >= minSizeBytes else { continue }

                let accessed = values?.contentAccessDate
                let modified = values?.contentModificationDate

                if let cutoff = cutoffDate {
                    let relevantDate = accessed ?? modified ?? Date.distantPast
                    guard relevantDate < cutoff else { continue }
                }

                results.append(LargeFile(
                    path: fileURL.path,
                    name: fileURL.lastPathComponent,
                    sizeBytes: size,
                    lastAccessed: accessed,
                    lastModified: modified
                ))
            }
        }

        results.sort { $0.sizeBytes > $1.sizeBytes }
        onProgress("Found \(results.count) files")
        return results
    }

    // MARK: - Purgeable Space

    public func getPurgeableSpace() -> PurgeableInfo? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/diskutil")
        process.arguments = ["info", "/"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return nil
        }

        guard process.terminationStatus == 0 else { return nil }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else { return nil }

        let totalBytes = extractBytes(from: output, key: "Container Total Space")
            ?? extractBytes(from: output, key: "Total Size")
            ?? 0
        let freeBytes = extractBytes(from: output, key: "Container Free Space")
            ?? extractBytes(from: output, key: "Volume Free Space")
            ?? 0
        let purgeableBytes = extractBytes(from: output, key: "Purgeable Space")
            ?? extractBytes(from: output, key: "Volume Available Space") // fallback
            ?? 0
        let availableBytes = extractBytes(from: output, key: "Volume Available Space")
            ?? freeBytes

        return PurgeableInfo(
            purgeableBytes: purgeableBytes > freeBytes ? purgeableBytes - freeBytes : purgeableBytes,
            totalBytes: totalBytes,
            freeBytes: freeBytes,
            availableBytes: availableBytes
        )
    }

    private func extractBytes(from text: String, key: String) -> UInt64? {
        guard let line = text.components(separatedBy: "\n").first(where: { $0.contains(key) }) else { return nil }
        // Look for pattern like "(123456789 Bytes)" in parentheses
        if let openParen = line.range(of: "("),
           let closeParen = line.range(of: " Bytes)", range: openParen.upperBound..<line.endIndex) {
            let numStr = String(line[openParen.upperBound..<closeParen.lowerBound]).trimmingCharacters(in: .whitespaces)
            return UInt64(numStr)
        }
        return nil
    }
}
