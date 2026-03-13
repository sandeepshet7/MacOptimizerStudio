import Foundation

public struct SafeExecutor: Sendable {
    public init() {}

    public static let defaultTimeout: TimeInterval = 120

    public func execute(commands: [String], timeout: TimeInterval = SafeExecutor.defaultTimeout, onProgress: @Sendable (Int, Int) -> Void) -> ExecutionResult {
        let startTime = Date()
        var errors: [String] = []
        var processed = 0

        for (index, command) in commands.enumerated() {
            onProgress(index, commands.count)

            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/zsh")
            process.arguments = ["-c", command]

            let stderrPipe = Pipe()
            process.standardError = stderrPipe
            process.standardOutput = Pipe()

            do {
                try process.run()

                let deadline = DispatchTime.now() + timeout
                let sema = DispatchSemaphore(value: 0)
                process.terminationHandler = { _ in sema.signal() }
                let timedOut = sema.wait(timeout: deadline) == .timedOut

                if timedOut {
                    process.terminate()
                    errors.append("Command timed out after \(Int(timeout))s: \(command)")
                    continue
                }

                if process.terminationStatus != 0 {
                    let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                    let stderrText = String(data: stderrData, encoding: .utf8) ?? "Unknown error"
                    errors.append("Command failed (exit \(process.terminationStatus)): \(command)\n\(stderrText)")
                } else {
                    processed += 1
                }
            } catch {
                errors.append("Failed to start: \(command)\n\(error.localizedDescription)")
            }
        }

        onProgress(commands.count, commands.count)

        for error in errors {
            ErrorCollector.shared.record(source: "Cleanup", message: error)
        }

        let duration = Date().timeIntervalSince(startTime)
        return ExecutionResult(
            success: errors.isEmpty,
            freedBytes: 0,
            itemsProcessed: processed,
            errors: errors,
            duration: duration
        )
    }

    public func sendSignal(_ signal: Int32, toPid pid: pid_t) -> Bool {
        kill(pid, signal) == 0
    }
}
