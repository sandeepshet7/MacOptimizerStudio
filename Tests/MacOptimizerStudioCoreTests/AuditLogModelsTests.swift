import Foundation
@testable import MacOptimizerStudioCore

#if canImport(Testing)
import Testing

struct AuditActionTests {
    @Test
    func allCasesHaveLabels() {
        for action in AuditAction.allCases {
            #expect(!action.label.isEmpty, "\(action) should have a label")
        }
    }

    @Test
    func allCasesHaveIcons() {
        for action in AuditAction.allCases {
            #expect(!action.icon.isEmpty, "\(action) should have an icon")
        }
    }

    @Test
    func labelValues() {
        #expect(AuditAction.fileShredded.label == "File Shredded")
        #expect(AuditAction.cacheCleanup.label == "Cache Cleanup")
        #expect(AuditAction.brokenDownloadsTrashed.label == "Downloads Cleaned")
        #expect(AuditAction.screenshotsMoved.label == "Screenshots Organized")
        #expect(AuditAction.processKilled.label == "Process Quit")
        #expect(AuditAction.processForceKilled.label == "Process Force Quit")
        #expect(AuditAction.diskCleanup.label == "Disk Cleanup")
        #expect(AuditAction.dockerPrune.label == "Docker Prune")
        #expect(AuditAction.appUninstalled.label == "App Uninstalled")
        #expect(AuditAction.maintenanceTaskRun.label == "Maintenance Task")
    }

    @Test
    func destructiveSeverity() {
        let destructive: [AuditAction] = [.fileShredded, .processForceKilled, .appUninstalled]
        for action in destructive {
            #expect(action.severity == .destructive, "\(action) should be destructive")
        }
    }

    @Test
    func warningSeverity() {
        let warnings: [AuditAction] = [
            .cacheCleanup, .brokenDownloadsTrashed, .diskCleanup, .processKilled,
            .dockerImageRemoved, .dockerVolumeRemoved, .dockerContainerRemoved, .dockerPrune,
            .appDataReset, .extensionRemoved, .photoJunkTrashed, .privacyDataCleaned
        ]
        for action in warnings {
            #expect(action.severity == .warning, "\(action) should be warning")
        }
    }

    @Test
    func infoSeverity() {
        let info: [AuditAction] = [.screenshotsMoved, .maintenanceTaskRun]
        for action in info {
            #expect(action.severity == .info, "\(action) should be info")
        }
    }

    @Test
    func allSeveritiesCovered() {
        // Every action should map to exactly one severity
        let destructiveCount = AuditAction.allCases.filter { $0.severity == .destructive }.count
        let warningCount = AuditAction.allCases.filter { $0.severity == .warning }.count
        let infoCount = AuditAction.allCases.filter { $0.severity == .info }.count
        #expect(destructiveCount + warningCount + infoCount == AuditAction.allCases.count)
    }

    @Test
    func caseCount() {
        #expect(AuditAction.allCases.count == 16)
    }
}

struct AuditSeverityTests {
    @Test
    func rawValues() {
        #expect(AuditSeverity.info.rawValue == "info")
        #expect(AuditSeverity.warning.rawValue == "warning")
        #expect(AuditSeverity.destructive.rawValue == "destructive")
    }
}

struct AuditLogEntryTests {
    @Test
    func creationWithDefaults() {
        let entry = AuditLogEntry(
            action: .cacheCleanup,
            details: "Cleaned 5 items"
        )
        #expect(entry.action == .cacheCleanup)
        #expect(entry.details == "Cleaned 5 items")
        #expect(entry.paths.isEmpty)
        #expect(entry.totalBytes == nil)
        #expect(entry.itemCount == 1)
        #expect(entry.userConfirmed == true)
    }

    @Test
    func creationWithAllParameters() {
        let fixedID = UUID()
        let fixedDate = Date(timeIntervalSince1970: 1700000000)
        let entry = AuditLogEntry(
            id: fixedID,
            timestamp: fixedDate,
            action: .diskCleanup,
            details: "Deleted node_modules",
            paths: ["/proj/node_modules", "/proj2/node_modules"],
            totalBytes: 5_000_000,
            itemCount: 2,
            userConfirmed: true
        )
        #expect(entry.id == fixedID)
        #expect(entry.timestamp == fixedDate)
        #expect(entry.action == .diskCleanup)
        #expect(entry.details == "Deleted node_modules")
        #expect(entry.paths.count == 2)
        #expect(entry.totalBytes == 5_000_000)
        #expect(entry.itemCount == 2)
        #expect(entry.userConfirmed == true)
    }

    @Test
    func codableRoundtrip() throws {
        let original = AuditLogEntry(
            action: .fileShredded,
            details: "Shredded secret.txt",
            paths: ["/tmp/secret.txt"],
            totalBytes: 1024,
            itemCount: 1,
            userConfirmed: true
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)
        let decoded = try JSONDecoder().decode(AuditLogEntry.self, from: data)

        #expect(decoded.id == original.id)
        #expect(decoded.action == original.action)
        #expect(decoded.details == original.details)
        #expect(decoded.paths == original.paths)
        #expect(decoded.totalBytes == original.totalBytes)
        #expect(decoded.itemCount == original.itemCount)
        #expect(decoded.userConfirmed == original.userConfirmed)
    }

    @Test
    func uniqueIDsGenerated() {
        let entry1 = AuditLogEntry(action: .cacheCleanup, details: "a")
        let entry2 = AuditLogEntry(action: .cacheCleanup, details: "a")
        #expect(entry1.id != entry2.id)
    }
}

#elseif canImport(XCTest)
import XCTest

final class AuditActionTests: XCTestCase {
    func testAllCasesHaveLabels() {
        for action in AuditAction.allCases {
            XCTAssertFalse(action.label.isEmpty, "\(action) should have a label")
        }
    }

    func testAllCasesHaveIcons() {
        for action in AuditAction.allCases {
            XCTAssertFalse(action.icon.isEmpty, "\(action) should have an icon")
        }
    }

    func testDestructiveSeverity() {
        for action in [AuditAction.fileShredded, .processForceKilled, .appUninstalled] {
            XCTAssertEqual(action.severity, .destructive)
        }
    }

    func testInfoSeverity() {
        for action in [AuditAction.screenshotsMoved, .maintenanceTaskRun] {
            XCTAssertEqual(action.severity, .info)
        }
    }

    func testCaseCount() {
        XCTAssertEqual(AuditAction.allCases.count, 16)
    }
}

final class AuditSeverityTests: XCTestCase {
    func testRawValues() {
        XCTAssertEqual(AuditSeverity.info.rawValue, "info")
        XCTAssertEqual(AuditSeverity.warning.rawValue, "warning")
        XCTAssertEqual(AuditSeverity.destructive.rawValue, "destructive")
    }
}

final class AuditLogEntryTests: XCTestCase {
    func testCreationWithDefaults() {
        let entry = AuditLogEntry(action: .cacheCleanup, details: "Cleaned 5 items")
        XCTAssertEqual(entry.action, .cacheCleanup)
        XCTAssertEqual(entry.details, "Cleaned 5 items")
        XCTAssertTrue(entry.paths.isEmpty)
        XCTAssertNil(entry.totalBytes)
        XCTAssertEqual(entry.itemCount, 1)
        XCTAssertTrue(entry.userConfirmed)
    }

    func testCodableRoundtrip() throws {
        let original = AuditLogEntry(action: .fileShredded, details: "Shredded file", paths: ["/tmp/f"], totalBytes: 1024, itemCount: 1)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(AuditLogEntry.self, from: data)
        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.action, original.action)
        XCTAssertEqual(decoded.totalBytes, original.totalBytes)
    }

    func testUniqueIDsGenerated() {
        let e1 = AuditLogEntry(action: .cacheCleanup, details: "a")
        let e2 = AuditLogEntry(action: .cacheCleanup, details: "a")
        XCTAssertNotEqual(e1.id, e2.id)
    }
}

#else
struct AuditActionTests {}
struct AuditSeverityTests {}
struct AuditLogEntryTests {}
#endif
