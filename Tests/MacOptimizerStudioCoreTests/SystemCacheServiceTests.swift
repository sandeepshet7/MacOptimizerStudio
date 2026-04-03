@testable import MacOptimizerStudioCore
import Foundation

#if canImport(Testing)
import Testing

struct SystemCacheServiceTests {
    let service = SystemCacheService()

    @Test
    func scanDoesNotCrash() {
        // Basic smoke test — scan should complete without crashing
        let report = service.scan()
        #expect(report.entries.count >= 0)
    }

    @Test
    func scanReturnsValidTimestamp() {
        let before = Date()
        let report = service.scan()
        let after = Date()
        #expect(report.scannedAt >= before)
        #expect(report.scannedAt <= after)
    }

    @Test
    func categoryTotalsAreConsistent() {
        let report = service.scan()
        // Category totals should match the sum of entries in each category
        for (category, total) in report.categoryTotals {
            let entriesTotal = report.entries
                .filter { $0.category == category }
                .reduce(0 as UInt64) { $0 + $1.sizeBytes }
            #expect(total == entriesTotal, "Category \(category) total mismatch: \(total) vs \(entriesTotal)")
        }
    }

    @Test
    func entriesHaveValidFields() {
        let report = service.scan()
        for entry in report.entries {
            #expect(!entry.name.isEmpty, "Entry name should not be empty")
            #expect(!entry.path.isEmpty, "Entry path should not be empty")
            // Path should be absolute
            #expect(entry.path.hasPrefix("/"), "Entry path should be absolute: \(entry.path)")
        }
    }

    @Test
    func entriesHaveRecognizedRiskLevels() {
        let report = service.scan()
        for entry in report.entries {
            // Risk level should be one of the known values
            let validRisks: [CacheRiskLevel] = [.safe, .caution]
            #expect(validRisks.contains(entry.riskLevel), "Unexpected risk level for \(entry.name)")
        }
    }
}

#elseif canImport(XCTest)
import XCTest

final class SystemCacheServiceTests: XCTestCase {
    let service = SystemCacheService()

    func testScanDoesNotCrash() {
        let report = service.scan()
        XCTAssertTrue(report.entries.count >= 0)
    }

    func testScanReturnsValidTimestamp() {
        let before = Date()
        let report = service.scan()
        let after = Date()
        XCTAssertGreaterThanOrEqual(report.scannedAt, before)
        XCTAssertLessThanOrEqual(report.scannedAt, after)
    }

    func testEntriesHaveValidFields() {
        let report = service.scan()
        for entry in report.entries {
            XCTAssertFalse(entry.name.isEmpty)
            XCTAssertFalse(entry.path.isEmpty)
            XCTAssertTrue(entry.path.hasPrefix("/"))
        }
    }
}

#else
struct SystemCacheServiceTests {}
#endif
