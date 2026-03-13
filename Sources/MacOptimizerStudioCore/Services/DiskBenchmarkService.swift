import Foundation

public struct DiskBenchmarkService: Sendable {
    public init() {}

    public func runBenchmark(
        at path: String,
        fileSizeMB: Int = 256,
        progress: @Sendable (BenchmarkProgress) -> Void
    ) async -> BenchmarkResult {
        let fm = FileManager.default
        let testFile = (path as NSString).appendingPathComponent("macopt_benchmark_\(UUID().uuidString).tmp")
        let totalBytes = fileSizeMB * 1024 * 1024
        let chunkSize = 1024 * 1024 // 1 MB per chunk

        defer {
            try? fm.removeItem(atPath: testFile)
        }

        // MARK: - Sequential Write

        progress(BenchmarkProgress(phase: "Sequential Write", percent: 0))

        let writeStart = CFAbsoluteTimeGetCurrent()

        do {
            fm.createFile(atPath: testFile, contents: nil)
            guard let fh = FileHandle(forWritingAtPath: testFile) else {
                return errorResult(testPath: path, fileSizeMB: fileSizeMB)
            }

            // Disable disk cache for accurate results
            let fd = fh.fileDescriptor
            _ = fcntl(fd, F_NOCACHE, 1)

            let chunk = Data(repeating: 0xAA, count: chunkSize)
            var written = 0
            while written < totalBytes {
                let remaining = totalBytes - written
                let toWrite = min(chunkSize, remaining)
                if toWrite < chunkSize {
                    fh.write(chunk.prefix(toWrite))
                } else {
                    fh.write(chunk)
                }
                written += toWrite
                let pct = Double(written) / Double(totalBytes)
                progress(BenchmarkProgress(phase: "Sequential Write", percent: pct))
            }

            try fh.synchronize()
            fh.closeFile()
        } catch {
            return errorResult(testPath: path, fileSizeMB: fileSizeMB)
        }

        let writeEnd = CFAbsoluteTimeGetCurrent()
        let writeDuration = writeEnd - writeStart
        let writeMBps = writeDuration > 0 ? Double(fileSizeMB) / writeDuration : 0

        // MARK: - Sequential Read

        progress(BenchmarkProgress(phase: "Sequential Read", percent: 0))

        let readStart = CFAbsoluteTimeGetCurrent()

        do {
            guard let fh = FileHandle(forReadingAtPath: testFile) else {
                return errorResult(testPath: path, fileSizeMB: fileSizeMB)
            }

            let fd = fh.fileDescriptor
            _ = fcntl(fd, F_NOCACHE, 1)

            var totalRead = 0
            while totalRead < totalBytes {
                let remaining = totalBytes - totalRead
                let toRead = min(chunkSize, remaining)
                guard let data = try fh.read(upToCount: toRead), !data.isEmpty else { break }
                totalRead += data.count
                let pct = Double(totalRead) / Double(totalBytes)
                progress(BenchmarkProgress(phase: "Sequential Read", percent: pct))
            }

            fh.closeFile()
        } catch {
            return errorResult(testPath: path, fileSizeMB: fileSizeMB)
        }

        let readEnd = CFAbsoluteTimeGetCurrent()
        let readDuration = readEnd - readStart
        let readMBps = readDuration > 0 ? Double(fileSizeMB) / readDuration : 0

        // MARK: - Random Read IOPS

        progress(BenchmarkProgress(phase: "Random Read IOPS", percent: 0))

        let randomReadIOPS = measureRandomReadIOPS(
            filePath: testFile,
            fileSize: totalBytes,
            iterations: 1000,
            progress: progress
        )

        // MARK: - Random Write IOPS

        progress(BenchmarkProgress(phase: "Random Write IOPS", percent: 0))

        let randomWriteIOPS = measureRandomWriteIOPS(
            filePath: testFile,
            fileSize: totalBytes,
            iterations: 1000,
            progress: progress
        )

        progress(BenchmarkProgress(phase: "Complete", percent: 1.0))

        return BenchmarkResult(
            sequentialReadMBps: readMBps,
            sequentialWriteMBps: writeMBps,
            randomReadIOPS: randomReadIOPS,
            randomWriteIOPS: randomWriteIOPS,
            testPath: path,
            fileSizeMB: fileSizeMB
        )
    }

    // MARK: - Private

    private func measureRandomReadIOPS(
        filePath: String,
        fileSize: Int,
        iterations: Int,
        progress: @Sendable (BenchmarkProgress) -> Void
    ) -> Double? {
        guard let fh = FileHandle(forReadingAtPath: filePath) else { return nil }
        let fd = fh.fileDescriptor
        _ = fcntl(fd, F_NOCACHE, 1)

        let blockSize = 4096
        let maxOffset = fileSize - blockSize
        guard maxOffset > 0 else { return nil }

        let start = CFAbsoluteTimeGetCurrent()
        for i in 0..<iterations {
            let offset = UInt64.random(in: 0...UInt64(maxOffset))
            let alignedOffset = offset & ~UInt64(blockSize - 1)
            fh.seek(toFileOffset: alignedOffset)
            _ = fh.readData(ofLength: blockSize)
            if i % 100 == 0 {
                progress(BenchmarkProgress(phase: "Random Read IOPS", percent: Double(i) / Double(iterations)))
            }
        }
        let duration = CFAbsoluteTimeGetCurrent() - start
        fh.closeFile()

        return duration > 0 ? Double(iterations) / duration : nil
    }

    private func measureRandomWriteIOPS(
        filePath: String,
        fileSize: Int,
        iterations: Int,
        progress: @Sendable (BenchmarkProgress) -> Void
    ) -> Double? {
        guard let fh = FileHandle(forWritingAtPath: filePath) else { return nil }
        let fd = fh.fileDescriptor
        _ = fcntl(fd, F_NOCACHE, 1)

        let blockSize = 4096
        let maxOffset = fileSize - blockSize
        guard maxOffset > 0 else { return nil }

        let writeBlock = Data(repeating: 0xBB, count: blockSize)

        let start = CFAbsoluteTimeGetCurrent()
        for i in 0..<iterations {
            let offset = UInt64.random(in: 0...UInt64(maxOffset))
            let alignedOffset = offset & ~UInt64(blockSize - 1)
            fh.seek(toFileOffset: alignedOffset)
            fh.write(writeBlock)
            if i % 100 == 0 {
                progress(BenchmarkProgress(phase: "Random Write IOPS", percent: Double(i) / Double(iterations)))
            }
        }
        try? fh.synchronize()
        let duration = CFAbsoluteTimeGetCurrent() - start
        fh.closeFile()

        return duration > 0 ? Double(iterations) / duration : nil
    }

    private func errorResult(testPath: String, fileSizeMB: Int) -> BenchmarkResult {
        BenchmarkResult(
            sequentialReadMBps: 0,
            sequentialWriteMBps: 0,
            testPath: testPath,
            fileSizeMB: fileSizeMB
        )
    }
}
