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

            let stdoutPipe = Pipe()
            let stderrPipe = Pipe()
            process.standardOutput = stdoutPipe
            process.standardError = stderrPipe

            do {
                try process.run()

                // Read pipes asynchronously BEFORE waiting for termination
                // to avoid deadlock when child writes more than the pipe buffer (~64KB).
                let stderrData = UnsafeMutablePointer<Data>.allocate(capacity: 1)
                stderrData.initialize(to: Data())
                let stdoutData = UnsafeMutablePointer<Data>.allocate(capacity: 1)
                stdoutData.initialize(to: Data())

                let readGroup = DispatchGroup()

                readGroup.enter()
                DispatchQueue.global(qos: .utility).async {
                    stdoutData.pointee = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                    readGroup.leave()
                }

                readGroup.enter()
                DispatchQueue.global(qos: .utility).async {
                    stderrData.pointee = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                    readGroup.leave()
                }

                let deadline = DispatchTime.now() + timeout
                let sema = DispatchSemaphore(value: 0)
                process.terminationHandler = { _ in sema.signal() }
                let timedOut = sema.wait(timeout: deadline) == .timedOut

                // Wait for pipe reads to finish (they will complete once the process
                // closes its end of the pipes, which happens at or before exit).
                readGroup.wait()

                let collectedStderr = stderrData.pointee
                stderrData.deinitialize(count: 1)
                stderrData.deallocate()
                stdoutData.deinitialize(count: 1)
                stdoutData.deallocate()

                if timedOut {
                    process.terminate()
                    errors.append("Command timed out after \(Int(timeout))s: \(command)")
                    continue
                }

                if process.terminationStatus != 0 {
                    let stderrText = String(data: collectedStderr, encoding: .utf8) ?? "Unknown error"
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
        // Prevent catastrophic signals: PID 0 kills all user processes, PID 1 is launchd.
        guard pid > 1 else { return false }
        // Never allow signaling our own process.
        guard pid != pid_t(ProcessInfo.processInfo.processIdentifier) else { return false }
        return kill(pid, signal) == 0
    }
}
