import Foundation
@testable import MacOptimizerStudioCore

#if canImport(Testing)
import Testing

struct TargetCategoryTests {
    @Test
    func displayNames() {
        #expect(TargetCategory.dependencies.displayName == "Dependencies")
        #expect(TargetCategory.buildOutput.displayName == "Build Output")
        #expect(TargetCategory.cache.displayName == "Caches")
        #expect(TargetCategory.vcs.displayName == "Version Control")
    }

    @Test
    func allCasesHaveIcons() {
        for category in TargetCategory.allCases {
            #expect(!category.icon.isEmpty)
        }
    }

    @Test
    func allCasesHaveTints() {
        for category in TargetCategory.allCases {
            #expect(!category.tint.isEmpty)
        }
    }

    @Test
    func caseCount() {
        #expect(TargetCategory.allCases.count == 4)
    }
}

struct TargetKindTests {
    @Test
    func displayNames() {
        #expect(TargetKind.venv.displayName == ".venv")
        #expect(TargetKind.nodeModules.displayName == "node_modules")
        #expect(TargetKind.git.displayName == ".git")
        #expect(TargetKind.pycache.displayName == "__pycache__")
        #expect(TargetKind.swiftBuild.displayName == ".build")
        #expect(TargetKind.next.displayName == ".next")
        #expect(TargetKind.vendor.displayName == "vendor")
    }

    @Test
    func folderNameMatchesDisplayName() {
        for kind in TargetKind.allCases {
            #expect(kind.folderName == kind.displayName)
        }
    }

    @Test
    func dependenciesCategory() {
        let deps: [TargetKind] = [.venv, .nodeModules, .vendor]
        for kind in deps {
            #expect(kind.category == .dependencies, "\(kind) should be dependencies")
        }
    }

    @Test
    func buildOutputCategory() {
        let builds: [TargetKind] = [.target, .next, .swiftBuild, .elixirBuild, .distNewstyle]
        for kind in builds {
            #expect(kind.category == .buildOutput, "\(kind) should be buildOutput")
        }
    }

    @Test
    func cacheCategory() {
        let caches: [TargetKind] = [.pycache, .pytestCache, .dartTool, .gradle, .terraform, .stackWork]
        for kind in caches {
            #expect(kind.category == .cache, "\(kind) should be cache")
        }
    }

    @Test
    func vcsCategory() {
        #expect(TargetKind.git.category == .vcs)
    }

    @Test
    func allCasesHaveEcosystems() {
        for kind in TargetKind.allCases {
            #expect(!kind.ecosystem.isEmpty, "\(kind) should have an ecosystem")
        }
    }

    @Test
    func allCasesHaveRestoreHints() {
        for kind in TargetKind.allCases {
            #expect(!kind.restoreHint.isEmpty, "\(kind) should have a restore hint")
        }
    }

    @Test
    func kindsForCategoryFilterCorrectly() {
        let deps = TargetKind.kinds(for: .dependencies)
        #expect(deps.contains(.venv))
        #expect(deps.contains(.nodeModules))
        #expect(deps.contains(.vendor))
        #expect(!deps.contains(.git))
        #expect(!deps.contains(.pycache))
    }

    @Test
    func kindsForCategoryCoversAllCases() {
        var all: [TargetKind] = []
        for category in TargetCategory.allCases {
            all.append(contentsOf: TargetKind.kinds(for: category))
        }
        #expect(Set(all).count == TargetKind.allCases.count)
    }

    @Test
    func rawValues() {
        #expect(TargetKind.nodeModules.rawValue == "node_modules")
        #expect(TargetKind.pycache.rawValue == "__pycache__")
        #expect(TargetKind.swiftBuild.rawValue == "swift_build")
        #expect(TargetKind.elixirBuild.rawValue == "elixir_build")
    }

    @Test
    func caseCount() {
        #expect(TargetKind.allCases.count == 14)
    }
}

struct FolderTotalTests {
    @Test
    func creation() {
        let ft = FolderTotal(path: "/Users/test/work", sizeBytes: 12345)
        #expect(ft.path == "/Users/test/work")
        #expect(ft.sizeBytes == 12345)
        #expect(ft.id == "/Users/test/work")
    }

    @Test
    func codable() throws {
        let json = """
        {"path": "/test/folder", "size_bytes": 999}
        """
        let decoded = try JSONDecoder().decode(FolderTotal.self, from: Data(json.utf8))
        #expect(decoded.path == "/test/folder")
        #expect(decoded.sizeBytes == 999)
    }

    @Test
    func hashable() {
        let a = FolderTotal(path: "/a", sizeBytes: 100)
        let b = FolderTotal(path: "/a", sizeBytes: 200)
        let c = FolderTotal(path: "/b", sizeBytes: 100)
        #expect(a == b)
        #expect(a != c)
    }
}

struct TargetEntryTests {
    @Test
    func creation() {
        let entry = TargetEntry(
            kind: .nodeModules,
            path: "/proj/node_modules",
            sizeBytes: 5000,
            projectRoot: "/proj"
        )
        #expect(entry.kind == .nodeModules)
        #expect(entry.path == "/proj/node_modules")
        #expect(entry.sizeBytes == 5000)
        #expect(entry.projectRoot == "/proj")
        #expect(entry.lastActivityEpoch == nil)
        #expect(entry.id == "/proj/node_modules")
    }

    @Test
    func lastActivityDateNilWhenNoEpoch() {
        let entry = TargetEntry(kind: .venv, path: "/p/.venv", sizeBytes: 1, projectRoot: "/p")
        #expect(entry.lastActivityDate == nil)
        #expect(entry.inactiveDays == nil)
        #expect(entry.stalenessLabel == nil)
        #expect(entry.isStale == false)
    }

    @Test
    func lastActivityDateFromEpoch() {
        let epoch = UInt64(Date(timeIntervalSinceNow: -86400 * 60).timeIntervalSince1970)
        let entry = TargetEntry(kind: .venv, path: "/p/.venv", sizeBytes: 1, projectRoot: "/p", lastActivityEpoch: epoch)
        #expect(entry.lastActivityDate != nil)
        #expect(entry.inactiveDays != nil)
        #expect(entry.isStale == true)
    }

    @Test
    func stalenessLabelForRecentActivity() {
        // 3 days ago — should be nil (under 7 days)
        let epoch = UInt64(Date(timeIntervalSinceNow: -86400 * 3).timeIntervalSince1970)
        let entry = TargetEntry(kind: .venv, path: "/p/.venv", sizeBytes: 1, projectRoot: "/p", lastActivityEpoch: epoch)
        #expect(entry.stalenessLabel == nil)
        #expect(entry.isStale == false)
    }

    @Test
    func stalenessLabelForWeeksInactive() {
        // 14 days ago
        let epoch = UInt64(Date(timeIntervalSinceNow: -86400 * 14).timeIntervalSince1970)
        let entry = TargetEntry(kind: .venv, path: "/p/.venv", sizeBytes: 1, projectRoot: "/p", lastActivityEpoch: epoch)
        let label = entry.stalenessLabel
        #expect(label != nil)
        #expect(label?.contains("d inactive") == true)
        #expect(entry.isStale == false)  // isStale requires >= 30 days
    }

    @Test
    func stalenessLabelForMonthsInactive() {
        // 90 days ago
        let epoch = UInt64(Date(timeIntervalSinceNow: -86400 * 90).timeIntervalSince1970)
        let entry = TargetEntry(kind: .venv, path: "/p/.venv", sizeBytes: 1, projectRoot: "/p", lastActivityEpoch: epoch)
        let label = entry.stalenessLabel
        #expect(label != nil)
        #expect(label?.contains("mo inactive") == true)
        #expect(entry.isStale == true)
    }

    @Test
    func stalenessLabelForYearsInactive() {
        // 400 days ago
        let epoch = UInt64(Date(timeIntervalSinceNow: -86400 * 400).timeIntervalSince1970)
        let entry = TargetEntry(kind: .venv, path: "/p/.venv", sizeBytes: 1, projectRoot: "/p", lastActivityEpoch: epoch)
        let label = entry.stalenessLabel
        #expect(label != nil)
        #expect(label?.contains("y inactive") == true)
        #expect(entry.isStale == true)
    }

    @Test
    func codable() throws {
        let json = """
        {
          "kind": "node_modules",
          "path": "/proj/node_modules",
          "size_bytes": 5000,
          "project_root": "/proj"
        }
        """
        let decoded = try JSONDecoder().decode(TargetEntry.self, from: Data(json.utf8))
        #expect(decoded.kind == .nodeModules)
        #expect(decoded.sizeBytes == 5000)
        #expect(decoded.lastActivityEpoch == nil)
    }

    @Test
    func codableWithLastActivity() throws {
        let json = """
        {
          "kind": "venv",
          "path": "/p/.venv",
          "size_bytes": 100,
          "project_root": "/p",
          "last_activity_epoch": 1700000000
        }
        """
        let decoded = try JSONDecoder().decode(TargetEntry.self, from: Data(json.utf8))
        #expect(decoded.lastActivityEpoch == 1700000000)
        #expect(decoded.lastActivityDate != nil)
    }
}

struct ScanErrorEntryTests {
    @Test
    func creation() {
        let err = ScanErrorEntry(path: "/blocked", message: "Permission denied")
        #expect(err.path == "/blocked")
        #expect(err.message == "Permission denied")
        #expect(err.id == "/blocked::Permission denied")
    }

    @Test
    func codable() throws {
        let json = """
        {"path": "/blocked", "message": "Permission denied"}
        """
        let decoded = try JSONDecoder().decode(ScanErrorEntry.self, from: Data(json.utf8))
        #expect(decoded.path == "/blocked")
        #expect(decoded.message == "Permission denied")
    }
}

struct ScanReportCreationTests {
    @Test
    func creation() {
        let now = Date()
        let report = ScanReport(
            generatedAt: now,
            roots: ["/root1", "/root2"],
            folderTotals: [FolderTotal(path: "/root1", sizeBytes: 1000)],
            targets: [TargetEntry(kind: .nodeModules, path: "/root1/node_modules", sizeBytes: 500, projectRoot: "/root1")],
            errors: [ScanErrorEntry(path: "/fail", message: "err")]
        )
        #expect(report.roots.count == 2)
        #expect(report.folderTotals.count == 1)
        #expect(report.targets.count == 1)
        #expect(report.errors.count == 1)
    }
}

#elseif canImport(XCTest)
import XCTest

final class TargetCategoryTests: XCTestCase {
    func testDisplayNames() {
        XCTAssertEqual(TargetCategory.dependencies.displayName, "Dependencies")
        XCTAssertEqual(TargetCategory.buildOutput.displayName, "Build Output")
        XCTAssertEqual(TargetCategory.cache.displayName, "Caches")
        XCTAssertEqual(TargetCategory.vcs.displayName, "Version Control")
    }

    func testAllCasesHaveIcons() {
        for category in TargetCategory.allCases {
            XCTAssertFalse(category.icon.isEmpty)
        }
    }

    func testCaseCount() {
        XCTAssertEqual(TargetCategory.allCases.count, 4)
    }
}

final class TargetKindTests: XCTestCase {
    func testDependenciesCategory() {
        for kind in [TargetKind.venv, .nodeModules, .vendor] {
            XCTAssertEqual(kind.category, .dependencies)
        }
    }

    func testBuildOutputCategory() {
        for kind in [TargetKind.target, .next, .swiftBuild, .elixirBuild, .distNewstyle] {
            XCTAssertEqual(kind.category, .buildOutput)
        }
    }

    func testCacheCategory() {
        for kind in [TargetKind.pycache, .pytestCache, .dartTool, .gradle, .terraform, .stackWork] {
            XCTAssertEqual(kind.category, .cache)
        }
    }

    func testVcsCategory() {
        XCTAssertEqual(TargetKind.git.category, .vcs)
    }

    func testFolderNameMatchesDisplayName() {
        for kind in TargetKind.allCases {
            XCTAssertEqual(kind.folderName, kind.displayName)
        }
    }

    func testKindsForCategoryFilterCorrectly() {
        let deps = TargetKind.kinds(for: .dependencies)
        XCTAssertTrue(deps.contains(.venv))
        XCTAssertTrue(deps.contains(.nodeModules))
        XCTAssertFalse(deps.contains(.git))
    }

    func testKindsForCategoryCoversAllCases() {
        var all: [TargetKind] = []
        for category in TargetCategory.allCases {
            all.append(contentsOf: TargetKind.kinds(for: category))
        }
        XCTAssertEqual(Set(all).count, TargetKind.allCases.count)
    }

    func testCaseCount() {
        XCTAssertEqual(TargetKind.allCases.count, 14)
    }
}

final class FolderTotalTests: XCTestCase {
    func testCreation() {
        let ft = FolderTotal(path: "/test", sizeBytes: 12345)
        XCTAssertEqual(ft.path, "/test")
        XCTAssertEqual(ft.sizeBytes, 12345)
        XCTAssertEqual(ft.id, "/test")
    }

    func testCodable() throws {
        let json = """
        {"path": "/test/folder", "size_bytes": 999}
        """
        let decoded = try JSONDecoder().decode(FolderTotal.self, from: Data(json.utf8))
        XCTAssertEqual(decoded.path, "/test/folder")
        XCTAssertEqual(decoded.sizeBytes, 999)
    }
}

final class TargetEntryModelTests: XCTestCase {
    func testCreation() {
        let entry = TargetEntry(kind: .nodeModules, path: "/proj/node_modules", sizeBytes: 5000, projectRoot: "/proj")
        XCTAssertEqual(entry.kind, .nodeModules)
        XCTAssertEqual(entry.id, "/proj/node_modules")
        XCTAssertNil(entry.lastActivityEpoch)
    }

    func testStalenessNilWhenNoEpoch() {
        let entry = TargetEntry(kind: .venv, path: "/p/.venv", sizeBytes: 1, projectRoot: "/p")
        XCTAssertNil(entry.lastActivityDate)
        XCTAssertNil(entry.inactiveDays)
        XCTAssertNil(entry.stalenessLabel)
        XCTAssertFalse(entry.isStale)
    }

    func testIsStaleForOldEntries() {
        let epoch = UInt64(Date(timeIntervalSinceNow: -86400 * 60).timeIntervalSince1970)
        let entry = TargetEntry(kind: .venv, path: "/p/.venv", sizeBytes: 1, projectRoot: "/p", lastActivityEpoch: epoch)
        XCTAssertTrue(entry.isStale)
    }

    func testCodable() throws {
        let json = """
        {"kind": "node_modules", "path": "/proj/node_modules", "size_bytes": 5000, "project_root": "/proj"}
        """
        let decoded = try JSONDecoder().decode(TargetEntry.self, from: Data(json.utf8))
        XCTAssertEqual(decoded.kind, .nodeModules)
        XCTAssertEqual(decoded.sizeBytes, 5000)
    }
}

final class ScanErrorEntryTests: XCTestCase {
    func testCreation() {
        let err = ScanErrorEntry(path: "/blocked", message: "Permission denied")
        XCTAssertEqual(err.id, "/blocked::Permission denied")
    }

    func testCodable() throws {
        let json = """
        {"path": "/blocked", "message": "Permission denied"}
        """
        let decoded = try JSONDecoder().decode(ScanErrorEntry.self, from: Data(json.utf8))
        XCTAssertEqual(decoded.path, "/blocked")
    }
}

#else
struct TargetCategoryTests {}
struct TargetKindTests {}
struct FolderTotalTests {}
struct TargetEntryTests {}
struct ScanErrorEntryTests {}
struct ScanReportCreationTests {}
#endif
