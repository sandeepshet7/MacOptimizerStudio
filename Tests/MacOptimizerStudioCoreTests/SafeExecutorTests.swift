import Foundation
@testable import MacOptimizerStudioCore

#if canImport(Testing)
import Testing

struct SafeExecutorTests {
    private let executor = SafeExecutor()

    @Test
    func executeSimpleCommandSucceeds() {
        let result = executor.execute(commands: ["echo hello"], timeout: 10) { _, _ in }
        #expect(result.success)
        #expect(result.itemsProcessed == 1)
        #expect(result.errors.isEmpty)
    }

    @Test
    func executeFailingCommandReportsError() {
        let result = executor.execute(commands: ["false"], timeout: 10) { _, _ in }
        #expect(!result.success)
        #expect(result.itemsProcessed == 0)
        #expect(result.errors.count == 1)
        #expect(result.errors[0].contains("exit"))
    }

    @Test
    func executeTimesOut() {
        let result = executor.execute(commands: ["sleep 10"], timeout: 1) { _, _ in }
        #expect(!result.success)
        #expect(result.errors.count == 1)
        #expect(result.errors[0].contains("timed out"))
    }

    @Test
    func sendSignalRejectsPidZero() {
        let rejected = executor.sendSignal(SIGTERM, toPid: 0)
        #expect(!rejected)
    }

    @Test
    func sendSignalRejectsPidOne() {
        let rejected = executor.sendSignal(SIGTERM, toPid: 1)
        #expect(!rejected)
    }

    @Test
    func sendSignalRejectsOwnPid() {
        let ownPid = pid_t(ProcessInfo.processInfo.processIdentifier)
        let rejected = executor.sendSignal(SIGTERM, toPid: ownPid)
        #expect(!rejected)
    }

    @Test
    func multipleCommandsExecuteInOrder() {
        let tmpFile = FileManager.default.temporaryDirectory
            .appendingPathComponent("safe_executor_order_\(UUID().uuidString).txt").path
        defer { try? FileManager.default.removeItem(atPath: tmpFile) }

        let commands = [
            "echo first > '\(tmpFile)'",
            "echo second >> '\(tmpFile)'",
            "echo third >> '\(tmpFile)'",
        ]
        let result = executor.execute(commands: commands, timeout: 10) { _, _ in }
        #expect(result.success)
        #expect(result.itemsProcessed == 3)

        let contents = (try? String(contentsOfFile: tmpFile, encoding: .utf8)) ?? ""
        let lines = contents.trimmingCharacters(in: .whitespacesAndNewlines).components(separatedBy: "\n")
        #expect(lines == ["first", "second", "third"])
    }

    @Test
    func shellEscapingWithSpecialCharactersInPath() {
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("safe exec test (special)")
        let tmpFile = tmpDir.appendingPathComponent("file with spaces.txt")
        try? FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let escapedPath = tmpFile.path.replacingOccurrences(of: "'", with: "'\\''")
        let result = executor.execute(commands: ["echo ok > '\(escapedPath)'"], timeout: 10) { _, _ in }
        #expect(result.success)
        #expect(FileManager.default.fileExists(atPath: tmpFile.path))
    }

    @Test
    func progressCallbackFires() {
        var progressSteps: [(Int, Int)] = []
        let result = executor.execute(commands: ["echo a", "echo b"]) { current, total in
            progressSteps.append((current, total))
        }
        #expect(result.success)
        // Should have 3 progress calls: (0,2), (1,2), (2,2)
        #expect(progressSteps.count == 3)
        #expect(progressSteps.last?.0 == 2)
        #expect(progressSteps.last?.1 == 2)
    }

    @Test
    func durationIsPositive() {
        let result = executor.execute(commands: ["echo hello"]) { _, _ in }
        #expect(result.duration > 0)
    }
}

#elseif canImport(XCTest)
import XCTest

final class SafeExecutorTests: XCTestCase {
    private let executor = SafeExecutor()

    func testExecuteSimpleCommandSucceeds() {
        let result = executor.execute(commands: ["echo hello"], timeout: 10) { _, _ in }
        XCTAssertTrue(result.success)
        XCTAssertEqual(result.itemsProcessed, 1)
        XCTAssertTrue(result.errors.isEmpty)
    }

    func testExecuteFailingCommandReportsError() {
        let result = executor.execute(commands: ["false"], timeout: 10) { _, _ in }
        XCTAssertFalse(result.success)
        XCTAssertEqual(result.itemsProcessed, 0)
        XCTAssertEqual(result.errors.count, 1)
    }

    func testExecuteTimesOut() {
        let result = executor.execute(commands: ["sleep 10"], timeout: 1) { _, _ in }
        XCTAssertFalse(result.success)
        XCTAssertTrue(result.errors[0].contains("timed out"))
    }

    func testSendSignalRejectsPidZero() {
        XCTAssertFalse(executor.sendSignal(SIGTERM, toPid: 0))
    }

    func testSendSignalRejectsPidOne() {
        XCTAssertFalse(executor.sendSignal(SIGTERM, toPid: 1))
    }

    func testSendSignalRejectsOwnPid() {
        let ownPid = pid_t(ProcessInfo.processInfo.processIdentifier)
        XCTAssertFalse(executor.sendSignal(SIGTERM, toPid: ownPid))
    }

    func testMultipleCommandsExecuteInOrder() {
        let tmpFile = FileManager.default.temporaryDirectory
            .appendingPathComponent("safe_executor_order_\(UUID().uuidString).txt").path
        defer { try? FileManager.default.removeItem(atPath: tmpFile) }

        let commands = [
            "echo first > '\(tmpFile)'",
            "echo second >> '\(tmpFile)'",
            "echo third >> '\(tmpFile)'",
        ]
        let result = executor.execute(commands: commands, timeout: 10) { _, _ in }
        XCTAssertTrue(result.success)

        let contents = (try? String(contentsOfFile: tmpFile, encoding: .utf8)) ?? ""
        let lines = contents.trimmingCharacters(in: .whitespacesAndNewlines).components(separatedBy: "\n")
        XCTAssertEqual(lines, ["first", "second", "third"])
    }

    func testDurationIsPositive() {
        let result = executor.execute(commands: ["echo hello"]) { _, _ in }
        XCTAssertGreaterThan(result.duration, 0)
    }
}

#else
struct SafeExecutorTests {}
#endif
