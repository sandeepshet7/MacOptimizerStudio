import Foundation

public struct RustScannerService: Sendable {
    public enum ScannerError: Error, LocalizedError {
        case scannerBinaryNotFound
        case invalidUTF8Output
        case processFailed(code: Int32, stderr: String)

        public var errorDescription: String? {
            switch self {
            case .scannerBinaryNotFound:
                return "Disk scanner binary not found. Run scripts/build_rust_scanner.sh to build it, or set MACOPT_SCANNER_PATH."
            case .invalidUTF8Output:
                return "Rust scanner produced invalid UTF-8 output."
            case .processFailed(let code, let stderr):
                return "Rust scanner failed (exit \(code)): \(stderr)"
            }
        }
    }

    public init() {}

    public func scan(roots: [URL], maxDepth: Int = 6, top: Int = 200) throws -> ScanReport {
        let binary = try locateScannerBinary()

        let process = Process()
        process.executableURL = binary

        var args = ["scan", "--max-depth", String(maxDepth), "--top", String(top), "--json", "--roots"]
        args.append(contentsOf: roots.map { $0.path })
        process.arguments = args

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        try process.run()
        process.waitUntilExit()

        let outputData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        let errData = stderrPipe.fileHandleForReading.readDataToEndOfFile()

        guard process.terminationStatus == 0 else {
            let stderr = String(data: errData, encoding: .utf8) ?? "Unknown scanner error"
            throw ScannerError.processFailed(code: process.terminationStatus, stderr: stderr)
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        do {
            return try decoder.decode(ScanReport.self, from: outputData)
        } catch {
            if String(data: outputData, encoding: .utf8) == nil {
                throw ScannerError.invalidUTF8Output
            }
            throw error
        }
    }

    private func locateScannerBinary() throws -> URL {
        let fileManager = FileManager.default

        if let envPath = ProcessInfo.processInfo.environment["MACOPT_SCANNER_PATH"],
           fileManager.isExecutableFile(atPath: envPath) {
            return URL(fileURLWithPath: envPath)
        }

        if let bundleScanner = Bundle.main.url(forResource: "macopt-scanner", withExtension: nil),
           fileManager.isExecutableFile(atPath: bundleScanner.path) {
            return bundleScanner
        }

        let cwd = fileManager.currentDirectoryPath
        let localPath = URL(fileURLWithPath: cwd)
            .appendingPathComponent("rust")
            .appendingPathComponent("macopt-scanner")
            .appendingPathComponent("target")
            .appendingPathComponent("debug")
            .appendingPathComponent("macopt-scanner")

        if fileManager.isExecutableFile(atPath: localPath.path) {
            return localPath
        }

        throw ScannerError.scannerBinaryNotFound
    }
}
