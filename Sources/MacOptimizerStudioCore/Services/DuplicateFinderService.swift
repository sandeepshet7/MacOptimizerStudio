import CryptoKit
import Foundation

public struct DuplicateScanReport: Sendable {
    public let scannedAt: Date
    public let groups: [DuplicateGroup]
    public let totalFiles: Int
    public let totalWastedBytes: UInt64
    public let scanDurationSeconds: Double
}

public struct DuplicateFinderService: Sendable {
    public init() {}

    /// Scan directories for duplicate files
    public func scan(roots: [String], minFileSize: UInt64 = 1024 * 100) async -> DuplicateScanReport {
        let startTime = Date()

        // Phase 1: Walk all roots, collect files with their sizes
        var filesBySize: [UInt64: [String]] = [:]
        var totalFiles = 0
        let fm = FileManager.default

        let skipPrefixes = ["/System", "/Library"]
        let skipComponents: Set<String> = [".Trash", ".Trashes"]

        for root in roots {
            guard let enumerator = fm.enumerator(
                at: URL(fileURLWithPath: root),
                includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey, .isSymbolicLinkKey],
                options: [.skipsHiddenFiles]
            ) else { continue }

            while let url = enumerator.nextObject() as? URL {
                // Skip symlinks
                guard let resourceValues = try? url.resourceValues(
                    forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey]
                ) else { continue }

                if resourceValues.isSymbolicLink == true { continue }
                guard resourceValues.isRegularFile == true else { continue }

                let path = url.path

                // Skip system directories
                if skipPrefixes.contains(where: { path.hasPrefix($0) }) { continue }
                if url.pathComponents.contains(where: { skipComponents.contains($0) }) { continue }

                let size = UInt64(resourceValues.fileSize ?? 0)
                guard size >= minFileSize else { continue }

                totalFiles += 1
                filesBySize[size, default: []].append(path)
            }

            // Yield periodically to avoid blocking
            await Task.yield()
        }

        // Phase 2: Filter to sizes with 2+ files
        let sizeGroups = filesBySize.filter { $0.value.count >= 2 }

        // Phase 3: Compute partial hashes (first 8KB + last 8KB)
        var filesByPartialHash: [String: [String]] = [:]

        for (_, paths) in sizeGroups {
            for path in paths {
                guard let partialHash = partialHashOfFile(atPath: path) else { continue }
                filesByPartialHash[partialHash, default: []].append(path)
            }
            await Task.yield()
        }

        // Phase 4: For partial hash groups with 2+ files, compute full hash
        var filesByFullHash: [String: (size: UInt64, paths: [String])] = [:]
        let partialHashGroups = filesByPartialHash.filter { $0.value.count >= 2 }

        for (_, paths) in partialHashGroups {
            for path in paths {
                guard let fullHash = fullHashOfFile(atPath: path) else { continue }
                let size = (try? fm.attributesOfItem(atPath: path)[.size] as? UInt64) ?? 0
                var entry = filesByFullHash[fullHash] ?? (size: size, paths: [])
                entry.paths.append(path)
                filesByFullHash[fullHash] = entry
            }
            await Task.yield()
        }

        // Phase 5: Build groups sorted by wasted bytes descending
        let groups: [DuplicateGroup] = filesByFullHash
            .filter { $0.value.paths.count >= 2 }
            .map { hash, entry in
                // Sort paths so oldest file is first (the "original")
                let sortedPaths = entry.paths.sorted { path1, path2 in
                    let date1 = (try? fm.attributesOfItem(atPath: path1)[.creationDate] as? Date) ?? Date.distantFuture
                    let date2 = (try? fm.attributesOfItem(atPath: path2)[.creationDate] as? Date) ?? Date.distantFuture
                    return date1 < date2
                }
                return DuplicateGroup(
                    id: hash,
                    fileSize: entry.size,
                    paths: sortedPaths
                )
            }
            .sorted { $0.wastedBytes > $1.wastedBytes }

        let totalWasted = groups.reduce(UInt64(0)) { $0 + $1.wastedBytes }
        let duration = Date().timeIntervalSince(startTime)

        return DuplicateScanReport(
            scannedAt: Date(),
            groups: groups,
            totalFiles: totalFiles,
            totalWastedBytes: totalWasted,
            scanDurationSeconds: duration
        )
    }

    // MARK: - Hashing Helpers

    private func partialHashOfFile(atPath path: String) -> String? {
        guard let handle = FileHandle(forReadingAtPath: path) else { return nil }
        defer { try? handle.close() }

        let chunkSize = 8 * 1024 // 8KB

        let frontData: Data
        if #available(macOS 10.15.4, *) {
            guard let data = try? handle.read(upToCount: chunkSize) else { return nil }
            frontData = data
        } else {
            frontData = handle.readData(ofLength: chunkSize)
        }

        // Get file size
        if #available(macOS 10.15.4, *) {
            guard let endOffset = try? handle.seekToEnd() else { return nil }
            let fileSize = endOffset

            if fileSize <= UInt64(chunkSize * 2) {
                // File is small enough — hash the whole thing from frontData
                // Re-read entire file
                try? handle.seek(toOffset: 0)
                if let allData = try? handle.read(upToCount: Int(fileSize)) {
                    let digest = SHA256.hash(data: allData)
                    return digest.map { String(format: "%02x", $0) }.joined()
                }
                return nil
            }

            // Read last 8KB
            let tailOffset = fileSize - UInt64(chunkSize)
            try? handle.seek(toOffset: tailOffset)
            guard let backData = try? handle.read(upToCount: chunkSize) else { return nil }

            var combined = frontData
            combined.append(backData)
            let digest = SHA256.hash(data: combined)
            return digest.map { String(format: "%02x", $0) }.joined()
        } else {
            handle.seekToEndOfFile()
            let fileSize = handle.offsetInFile

            if fileSize <= UInt64(chunkSize * 2) {
                handle.seek(toFileOffset: 0)
                let allData = handle.readData(ofLength: Int(fileSize))
                let digest = SHA256.hash(data: allData)
                return digest.map { String(format: "%02x", $0) }.joined()
            }

            let tailOffset = fileSize - UInt64(chunkSize)
            handle.seek(toFileOffset: tailOffset)
            let backData = handle.readData(ofLength: chunkSize)

            var combined = frontData
            combined.append(backData)
            let digest = SHA256.hash(data: combined)
            return digest.map { String(format: "%02x", $0) }.joined()
        }
    }

    private func fullHashOfFile(atPath path: String) -> String? {
        guard let handle = FileHandle(forReadingAtPath: path) else { return nil }
        defer { try? handle.close() }

        var hasher = SHA256()
        let bufferSize = 64 * 1024 // 64KB chunks

        while true {
            let chunk: Data
            if #available(macOS 10.15.4, *) {
                guard let data = try? handle.read(upToCount: bufferSize) else { return nil }
                chunk = data
            } else {
                chunk = handle.readData(ofLength: bufferSize)
            }
            if chunk.isEmpty { break }
            hasher.update(data: chunk)
        }

        let digest = hasher.finalize()
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
