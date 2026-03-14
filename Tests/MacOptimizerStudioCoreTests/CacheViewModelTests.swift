import Foundation
@testable import MacOptimizerStudioCore

#if canImport(Testing)
import Testing

@MainActor
struct CacheViewModelTests {
    // Helper to create a CacheViewModel and inject a report without scanning
    private func makeViewModelWithReport(entries: [CacheEntry], categoryTotals: [CacheCategory: UInt64]? = nil) -> CacheViewModel {
        let vm = CacheViewModel()

        // We can't easily inject a report since scan() hits the filesystem,
        // so we test the pure logic methods by simulating selected paths.
        // The ViewModel exposes selectedPaths as a writable published property.
        return vm
    }

    private func sampleEntries() -> [CacheEntry] {
        [
            CacheEntry(category: .appCaches, name: "App1", path: "/cache/app1", sizeBytes: 1000, riskLevel: .safe, itemDescription: "App1 cache"),
            CacheEntry(category: .appCaches, name: "App2", path: "/cache/app2", sizeBytes: 2000, riskLevel: .moderate, itemDescription: "App2 cache"),
            CacheEntry(category: .browserData, name: "Chrome", path: "/cache/chrome", sizeBytes: 5000, riskLevel: .caution, itemDescription: "Chrome cache"),
            CacheEntry(category: .systemLogs, name: "Logs", path: "/cache/logs", sizeBytes: 500, riskLevel: .safe, itemDescription: "System logs"),
        ]
    }

    @Test
    func initialState() {
        let vm = CacheViewModel()
        #expect(vm.report == nil)
        #expect(vm.isScanning == false)
        #expect(vm.selectedPaths.isEmpty)
        #expect(vm.entriesByCategory.isEmpty)
        #expect(vm.safeTotalBytes == 0)
        #expect(vm.safeEntryCount == 0)
        #expect(vm.topOffenders.isEmpty)
    }

    @Test
    func selectedEntriesEmptyWithNoReport() {
        let vm = CacheViewModel()
        vm.selectedPaths = ["/some/path"]
        // No report, so selectedEntries should be empty
        #expect(vm.selectedEntries.isEmpty)
        #expect(vm.selectedTotalBytes == 0)
    }

    @Test
    func toggleSelectionAddsAndRemoves() {
        let vm = CacheViewModel()
        let entry = CacheEntry(category: .appCaches, name: "App1", path: "/cache/app1", sizeBytes: 1000, riskLevel: .safe, itemDescription: "desc")

        vm.toggleSelection(entry)
        #expect(vm.selectedPaths.contains("/cache/app1"))

        vm.toggleSelection(entry)
        #expect(!vm.selectedPaths.contains("/cache/app1"))
    }

    @Test
    func selectAllForCategoryWithNoReport() {
        let vm = CacheViewModel()
        // With no report, entries(for:) returns empty, so selectAll is a no-op
        vm.selectAll(for: .appCaches)
        #expect(vm.selectedPaths.isEmpty)
    }

    @Test
    func deselectAllClearsEverything() {
        let vm = CacheViewModel()
        vm.selectedPaths = ["/a", "/b", "/c"]
        vm.deselectAll()
        #expect(vm.selectedPaths.isEmpty)
    }

    @Test
    func cleanupCommandsEmptyWhenNoReport() {
        let vm = CacheViewModel()
        vm.selectedPaths = ["/some/path"]
        // No report means selectedEntries is empty
        let cmds = vm.cleanupCommands()
        #expect(cmds.isEmpty)
    }

    @Test
    func categoryTotalZeroWithNoReport() {
        let vm = CacheViewModel()
        #expect(vm.categoryTotal(.appCaches) == 0)
        #expect(vm.categoryCount(.appCaches) == 0)
    }

    @Test
    func entriesForCategoryEmptyWithNoReport() {
        let vm = CacheViewModel()
        #expect(vm.entries(for: .appCaches).isEmpty)
        #expect(vm.entries(for: .browserData).isEmpty)
    }
}

#elseif canImport(XCTest)
import XCTest

@MainActor
final class CacheViewModelTests: XCTestCase {
    func testInitialState() {
        let vm = CacheViewModel()
        XCTAssertNil(vm.report)
        XCTAssertFalse(vm.isScanning)
        XCTAssertTrue(vm.selectedPaths.isEmpty)
        XCTAssertTrue(vm.entriesByCategory.isEmpty)
        XCTAssertEqual(vm.safeTotalBytes, 0)
        XCTAssertEqual(vm.safeEntryCount, 0)
        XCTAssertTrue(vm.topOffenders.isEmpty)
    }

    func testSelectedEntriesEmptyWithNoReport() {
        let vm = CacheViewModel()
        vm.selectedPaths = ["/some/path"]
        XCTAssertTrue(vm.selectedEntries.isEmpty)
        XCTAssertEqual(vm.selectedTotalBytes, 0)
    }

    func testToggleSelection() {
        let vm = CacheViewModel()
        let entry = CacheEntry(category: .appCaches, name: "App1", path: "/cache/app1", sizeBytes: 1000, riskLevel: .safe, itemDescription: "desc")
        vm.toggleSelection(entry)
        XCTAssertTrue(vm.selectedPaths.contains("/cache/app1"))
        vm.toggleSelection(entry)
        XCTAssertFalse(vm.selectedPaths.contains("/cache/app1"))
    }

    func testDeselectAllClearsEverything() {
        let vm = CacheViewModel()
        vm.selectedPaths = ["/a", "/b", "/c"]
        vm.deselectAll()
        XCTAssertTrue(vm.selectedPaths.isEmpty)
    }

    func testCleanupCommandsEmptyWhenNoReport() {
        let vm = CacheViewModel()
        vm.selectedPaths = ["/some/path"]
        XCTAssertTrue(vm.cleanupCommands().isEmpty)
    }

    func testCategoryTotalZeroWithNoReport() {
        let vm = CacheViewModel()
        XCTAssertEqual(vm.categoryTotal(.appCaches), 0)
        XCTAssertEqual(vm.categoryCount(.appCaches), 0)
    }
}

#else
struct CacheViewModelTests {}
#endif
