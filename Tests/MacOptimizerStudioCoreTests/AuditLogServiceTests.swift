import Foundation
@testable import MacOptimizerStudioCore

#if canImport(Testing)
import Testing

struct AuditLogServiceTests {
    /// The service writes to ~/Library/Application Support/MacOptimizerStudio/audit_log.json.
    /// We back up the existing file before each test and restore it afterwards to avoid
    /// polluting real data.
    private let service = AuditLogService()

    private var logFileURL: URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return support.appendingPathComponent("MacOptimizerStudio/audit_log.json")
    }

    private func withCleanLog(_ body: () throws -> Void) rethrows {
        let fm = FileManager.default
        let url = logFileURL
        let backupURL = url.appendingPathExtension("test_backup")

        // Back up existing log
        if fm.fileExists(atPath: url.path) {
            try? fm.copyItem(at: url, to: backupURL)
            try? fm.removeItem(at: url)
        }

        defer {
            // Restore backup
            try? fm.removeItem(at: url)
            if fm.fileExists(atPath: backupURL.path) {
                try? fm.moveItem(at: backupURL, to: url)
            }
        }

        try body()
    }

    /// Wait for async dispatch queue write to complete.
    private func waitForWrite() {
        Thread.sleep(forTimeInterval: 0.2)
    }

    @Test
    func logAddsEntryThatAppearsInLoadAll() {
        withCleanLog {
            let entry = AuditLogEntry(
                action: .cacheCleanup,
                details: "Test entry",
                paths: ["/tmp/test"],
                totalBytes: 1024,
                itemCount: 1
            )
            service.log(entry)
            waitForWrite()

            let loaded = service.loadAll()
            #expect(loaded.count == 1)
            #expect(loaded[0].id == entry.id)
            #expect(loaded[0].action == .cacheCleanup)
            #expect(loaded[0].details == "Test entry")
        }
    }

    @Test
    func multipleLogCallsMaintainNewestFirstOrder() {
        withCleanLog {
            let entry1 = AuditLogEntry(action: .cacheCleanup, details: "First")
            service.log(entry1)
            waitForWrite()

            let entry2 = AuditLogEntry(action: .diskCleanup, details: "Second")
            service.log(entry2)
            waitForWrite()

            let loaded = service.loadAll()
            #expect(loaded.count == 2)
            // Newest first
            #expect(loaded[0].details == "Second")
            #expect(loaded[1].details == "First")
        }
    }

    @Test
    func roundTripFieldsMatch() {
        withCleanLog {
            let id = UUID()
            let now = Date()
            let entry = AuditLogEntry(
                id: id,
                timestamp: now,
                action: .fileShredded,
                details: "Shredded important file",
                paths: ["/Users/test/secret.txt", "/Users/test/other.txt"],
                totalBytes: 999_999,
                itemCount: 2,
                userConfirmed: true
            )
            service.log(entry)
            waitForWrite()

            let loaded = service.loadAll()
            #expect(loaded.count == 1)
            let roundTripped = loaded[0]
            #expect(roundTripped.id == id)
            #expect(roundTripped.action == .fileShredded)
            #expect(roundTripped.details == "Shredded important file")
            #expect(roundTripped.paths == ["/Users/test/secret.txt", "/Users/test/other.txt"])
            #expect(roundTripped.totalBytes == 999_999)
            #expect(roundTripped.itemCount == 2)
            #expect(roundTripped.userConfirmed == true)
            // ISO 8601 round-trip loses sub-second precision, so compare to nearest second
            #expect(abs(roundTripped.timestamp.timeIntervalSince(now)) < 1.0)
        }
    }

    @Test
    func exportAsTextProducesNonEmptyStringWithEntries() {
        withCleanLog {
            let entry = AuditLogEntry(action: .maintenanceTaskRun, details: "Ran flush DNS")
            service.log(entry)
            waitForWrite()

            let text = service.exportAsText()
            #expect(!text.isEmpty)
            #expect(text.contains("MacOptimizer Studio"))
            #expect(text.contains("Maintenance Task"))
            #expect(text.contains("Ran flush DNS"))
        }
    }

    @Test
    func exportAsTextReturnsPlaceholderWhenEmpty() {
        withCleanLog {
            let text = service.exportAsText()
            #expect(text == "No audit log entries.")
        }
    }

    @Test
    func loadAllReturnsEmptyWhenNoLogFile() {
        withCleanLog {
            let loaded = service.loadAll()
            #expect(loaded.isEmpty)
        }
    }

    @Test
    func insertOrderIsNewestFirst() {
        withCleanLog {
            for i in 0..<5 {
                let entry = AuditLogEntry(action: .cacheCleanup, details: "Entry \(i)")
                service.log(entry)
                waitForWrite()
            }

            let loaded = service.loadAll()
            #expect(loaded.count == 5)
            // The last logged should be first in the list
            #expect(loaded[0].details == "Entry 4")
            #expect(loaded[4].details == "Entry 0")
        }
    }
}

#elseif canImport(XCTest)
import XCTest

final class AuditLogServiceTests: XCTestCase {
    private let service = AuditLogService()

    private var logFileURL: URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return support.appendingPathComponent("MacOptimizerStudio/audit_log.json")
    }

    private func withCleanLog(_ body: () throws -> Void) rethrows {
        let fm = FileManager.default
        let url = logFileURL
        let backupURL = url.appendingPathExtension("test_backup")

        if fm.fileExists(atPath: url.path) {
            try? fm.copyItem(at: url, to: backupURL)
            try? fm.removeItem(at: url)
        }

        defer {
            try? fm.removeItem(at: url)
            if fm.fileExists(atPath: backupURL.path) {
                try? fm.moveItem(at: backupURL, to: url)
            }
        }

        try body()
    }

    private func waitForWrite() {
        Thread.sleep(forTimeInterval: 0.2)
    }

    func testLogAddsEntryThatAppearsInLoadAll() {
        withCleanLog {
            let entry = AuditLogEntry(action: .cacheCleanup, details: "Test entry")
            service.log(entry)
            waitForWrite()

            let loaded = service.loadAll()
            XCTAssertEqual(loaded.count, 1)
            XCTAssertEqual(loaded[0].id, entry.id)
        }
    }

    func testMultipleLogCallsMaintainNewestFirstOrder() {
        withCleanLog {
            service.log(AuditLogEntry(action: .cacheCleanup, details: "First"))
            waitForWrite()
            service.log(AuditLogEntry(action: .diskCleanup, details: "Second"))
            waitForWrite()

            let loaded = service.loadAll()
            XCTAssertEqual(loaded.count, 2)
            XCTAssertEqual(loaded[0].details, "Second")
            XCTAssertEqual(loaded[1].details, "First")
        }
    }

    func testExportAsTextProducesNonEmptyString() {
        withCleanLog {
            service.log(AuditLogEntry(action: .maintenanceTaskRun, details: "Ran flush DNS"))
            waitForWrite()

            let text = service.exportAsText()
            XCTAssertTrue(text.contains("MacOptimizer Studio"))
            XCTAssertTrue(text.contains("Ran flush DNS"))
        }
    }

    func testLoadAllReturnsEmptyWhenNoLogFile() {
        withCleanLog {
            XCTAssertTrue(service.loadAll().isEmpty)
        }
    }
}

#else
struct AuditLogServiceTests {}
#endif
