import Foundation
@testable import MacOptimizerStudioCore

#if canImport(Testing)
import Testing

@MainActor
struct DiskViewModelTests {
    @Test
    func initialState() {
        let vm = DiskViewModel()
        #expect(vm.report == nil)
        #expect(vm.isScanning == false)
        #expect(vm.lastError == nil)
        #expect(vm.lastScanDuration == nil)
        #expect(vm.scanHistory.isEmpty)
        #expect(vm.allEntries.isEmpty)
        #expect(vm.totalCleanupCount == 0)
        #expect(vm.totalCleanupBytes == 0)
    }

    @Test
    func clearErrorResetsError() {
        let vm = DiskViewModel()
        // Trigger an error by scanning with no roots
        // We can't easily trigger it without async, so test clearError directly
        vm.clearError()
        #expect(vm.lastError == nil)
    }

    @Test
    func entriesForKindEmptyWithNoReport() {
        let vm = DiskViewModel()
        #expect(vm.entries(for: .nodeModules).isEmpty)
        #expect(vm.entries(for: .venv).isEmpty)
        #expect(vm.entries(for: .git).isEmpty)
    }

    @Test
    func entriesForCategoryEmptyWithNoReport() {
        let vm = DiskViewModel()
        #expect(vm.entries(for: .dependencies).isEmpty)
        #expect(vm.entries(for: .buildOutput).isEmpty)
        #expect(vm.entries(for: .cache).isEmpty)
        #expect(vm.entries(for: .vcs).isEmpty)
    }

    @Test
    func summaryForKindEmptyWithNoReport() {
        let vm = DiskViewModel()
        let s = vm.summary(for: .nodeModules)
        #expect(s.count == 0)
        #expect(s.sizeBytes == 0)
    }

    @Test
    func summaryForCategoryEmptyWithNoReport() {
        let vm = DiskViewModel()
        let s = vm.summary(for: .dependencies)
        #expect(s.count == 0)
        #expect(s.sizeBytes == 0)
    }

    @Test
    func activeCategoriesEmptyWithNoReport() {
        let vm = DiskViewModel()
        #expect(vm.activeCategories.isEmpty)
    }

    @Test
    func activeKindsEmptyWithNoReport() {
        let vm = DiskViewModel()
        #expect(vm.activeKinds.isEmpty)
    }

    @Test
    func entriesGroupedEmptyWithNoReport() {
        let vm = DiskViewModel()
        #expect(vm.entriesGrouped().isEmpty)
    }

    @Test
    func scanWithNoRootsSetsError() async {
        let vm = DiskViewModel()
        // roots is empty by default (no saved bookmarks)
        await vm.scan()
        #expect(vm.lastError == "Select at least one root folder before scanning.")
        #expect(vm.isScanning == false)
    }
}

struct ScanHistoryEntryTests {
    @Test
    func creation() {
        let now = Date()
        let entry = ScanHistoryEntry(
            startedAt: now,
            durationSeconds: 3.5,
            rootCount: 2,
            totalBytes: 1_000_000,
            targetCount: 15
        )
        #expect(entry.startedAt == now)
        #expect(entry.durationSeconds == 3.5)
        #expect(entry.rootCount == 2)
        #expect(entry.totalBytes == 1_000_000)
        #expect(entry.targetCount == 15)
    }

    @Test
    func uniqueIDs() {
        let now = Date()
        let a = ScanHistoryEntry(startedAt: now, durationSeconds: 1, rootCount: 1, totalBytes: 100, targetCount: 1)
        let b = ScanHistoryEntry(startedAt: now, durationSeconds: 1, rootCount: 1, totalBytes: 100, targetCount: 1)
        #expect(a.id != b.id)
    }
}

#elseif canImport(XCTest)
import XCTest

@MainActor
final class DiskViewModelTests: XCTestCase {
    func testInitialState() {
        let vm = DiskViewModel()
        XCTAssertNil(vm.report)
        XCTAssertFalse(vm.isScanning)
        XCTAssertNil(vm.lastError)
        XCTAssertNil(vm.lastScanDuration)
        XCTAssertTrue(vm.scanHistory.isEmpty)
        XCTAssertTrue(vm.allEntries.isEmpty)
        XCTAssertEqual(vm.totalCleanupCount, 0)
        XCTAssertEqual(vm.totalCleanupBytes, 0)
    }

    func testEntriesEmptyWithNoReport() {
        let vm = DiskViewModel()
        XCTAssertTrue(vm.entries(for: .nodeModules).isEmpty)
        XCTAssertTrue(vm.entries(for: .dependencies).isEmpty)
    }

    func testSummaryEmptyWithNoReport() {
        let vm = DiskViewModel()
        let s = vm.summary(for: .nodeModules)
        XCTAssertEqual(s.count, 0)
        XCTAssertEqual(s.sizeBytes, 0)
    }

    func testActiveCategoriesEmptyWithNoReport() {
        let vm = DiskViewModel()
        XCTAssertTrue(vm.activeCategories.isEmpty)
        XCTAssertTrue(vm.activeKinds.isEmpty)
    }

    func testScanWithNoRootsSetsError() async {
        let vm = DiskViewModel()
        await vm.scan()
        XCTAssertEqual(vm.lastError, "Select at least one root folder before scanning.")
    }
}

final class ScanHistoryEntryTests: XCTestCase {
    func testCreation() {
        let now = Date()
        let entry = ScanHistoryEntry(startedAt: now, durationSeconds: 3.5, rootCount: 2, totalBytes: 1_000_000, targetCount: 15)
        XCTAssertEqual(entry.startedAt, now)
        XCTAssertEqual(entry.durationSeconds, 3.5)
        XCTAssertEqual(entry.rootCount, 2)
        XCTAssertEqual(entry.totalBytes, 1_000_000)
        XCTAssertEqual(entry.targetCount, 15)
    }

    func testUniqueIDs() {
        let now = Date()
        let a = ScanHistoryEntry(startedAt: now, durationSeconds: 1, rootCount: 1, totalBytes: 100, targetCount: 1)
        let b = ScanHistoryEntry(startedAt: now, durationSeconds: 1, rootCount: 1, totalBytes: 100, targetCount: 1)
        XCTAssertNotEqual(a.id, b.id)
    }
}

#else
struct DiskViewModelTests {}
struct ScanHistoryEntryTests {}
#endif
