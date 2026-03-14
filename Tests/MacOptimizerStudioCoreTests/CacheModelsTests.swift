import Foundation
@testable import MacOptimizerStudioCore

#if canImport(Testing)
import Testing

struct CacheCategoryTests {
    @Test
    func allCasesHaveDisplayNames() {
        for category in CacheCategory.allCases {
            #expect(!category.displayName.isEmpty, "displayName should not be empty for \(category)")
        }
    }

    @Test
    func displayNameMapping() {
        #expect(CacheCategory.appCaches.displayName == "App Caches")
        #expect(CacheCategory.systemLogs.displayName == "System & App Logs")
        #expect(CacheCategory.xcodeData.displayName == "Xcode Data")
        #expect(CacheCategory.packageManager.displayName == "Package Managers")
        #expect(CacheCategory.browserData.displayName == "Browser Caches")
        #expect(CacheCategory.containerData.displayName == "Containers & VMs")
        #expect(CacheCategory.temporaryFiles.displayName == "Temporary Files")
        #expect(CacheCategory.languageFiles.displayName == "Language Files")
        #expect(CacheCategory.mailAttachments.displayName == "Mail Attachments")
        #expect(CacheCategory.iOSBackups.displayName == "iOS Backups")
        #expect(CacheCategory.brokenPreferences.displayName == "Broken Preferences")
    }

    @Test
    func allCasesHaveIcons() {
        for category in CacheCategory.allCases {
            #expect(!category.icon.isEmpty, "icon should not be empty for \(category)")
        }
    }

    @Test
    func allCasesHaveDescriptions() {
        for category in CacheCategory.allCases {
            #expect(!category.description.isEmpty, "description should not be empty for \(category)")
        }
    }

    @Test
    func allCasesHaveWhatBreaksIfDeleted() {
        for category in CacheCategory.allCases {
            #expect(!category.whatBreaksIfDeleted.isEmpty, "whatBreaksIfDeleted should not be empty for \(category)")
        }
    }

    @Test
    func willRegenerateForRegeneratingCategories() {
        let regenerating: [CacheCategory] = [.appCaches, .systemLogs, .xcodeData, .packageManager, .temporaryFiles, .brokenPreferences]
        for category in regenerating {
            #expect(category.willRegenerate == true, "\(category) should regenerate")
        }
    }

    @Test
    func willNotRegenerateForNonRegeneratingCategories() {
        let nonRegenerating: [CacheCategory] = [.browserData, .containerData, .languageFiles, .mailAttachments, .iOSBackups]
        for category in nonRegenerating {
            #expect(category.willRegenerate == false, "\(category) should not regenerate")
        }
    }

    @Test
    func idMatchesRawValue() {
        for category in CacheCategory.allCases {
            #expect(category.id == category.rawValue)
        }
    }

    @Test
    func allCasesCovered() {
        #expect(CacheCategory.allCases.count == 11)
    }
}

struct CacheRiskLevelTests {
    @Test
    func displayNames() {
        #expect(CacheRiskLevel.safe.displayName == "Safe")
        #expect(CacheRiskLevel.moderate.displayName == "Moderate")
        #expect(CacheRiskLevel.caution.displayName == "Caution")
    }

    @Test
    func deletionImpactSummaries() {
        #expect(CacheRiskLevel.safe.deletionImpactSummary.contains("recreated"))
        #expect(CacheRiskLevel.moderate.deletionImpactSummary.contains("re-login"))
        #expect(CacheRiskLevel.caution.deletionImpactSummary.contains("cannot be recovered"))
    }

    @Test
    func rawValues() {
        #expect(CacheRiskLevel.safe.rawValue == "safe")
        #expect(CacheRiskLevel.moderate.rawValue == "moderate")
        #expect(CacheRiskLevel.caution.rawValue == "caution")
    }
}

struct CacheEntryTests {
    @Test
    func creation() {
        let entry = CacheEntry(
            category: .appCaches,
            name: "TestApp",
            path: "/Users/test/Library/Caches/TestApp",
            sizeBytes: 1024,
            riskLevel: .safe,
            itemDescription: "Test app cache"
        )

        #expect(entry.category == .appCaches)
        #expect(entry.name == "TestApp")
        #expect(entry.path == "/Users/test/Library/Caches/TestApp")
        #expect(entry.sizeBytes == 1024)
        #expect(entry.riskLevel == .safe)
        #expect(entry.itemDescription == "Test app cache")
    }

    @Test
    func idIsPath() {
        let entry = CacheEntry(
            category: .appCaches,
            name: "TestApp",
            path: "/some/unique/path",
            sizeBytes: 512,
            riskLevel: .moderate,
            itemDescription: "desc"
        )
        #expect(entry.id == "/some/unique/path")
    }

    @Test
    func equalityByPath() {
        let entry1 = CacheEntry(
            category: .appCaches,
            name: "App1",
            path: "/same/path",
            sizeBytes: 100,
            riskLevel: .safe,
            itemDescription: "desc1"
        )
        let entry2 = CacheEntry(
            category: .browserData,
            name: "App2",
            path: "/same/path",
            sizeBytes: 999,
            riskLevel: .caution,
            itemDescription: "desc2"
        )
        #expect(entry1 == entry2)
    }

    @Test
    func inequalityByPath() {
        let entry1 = CacheEntry(
            category: .appCaches,
            name: "App1",
            path: "/path/a",
            sizeBytes: 100,
            riskLevel: .safe,
            itemDescription: "desc"
        )
        let entry2 = CacheEntry(
            category: .appCaches,
            name: "App1",
            path: "/path/b",
            sizeBytes: 100,
            riskLevel: .safe,
            itemDescription: "desc"
        )
        #expect(entry1 != entry2)
    }

    @Test
    func hashingConsistentWithEquality() {
        let entry1 = CacheEntry(
            category: .appCaches,
            name: "App1",
            path: "/same/path",
            sizeBytes: 100,
            riskLevel: .safe,
            itemDescription: "desc1"
        )
        let entry2 = CacheEntry(
            category: .browserData,
            name: "App2",
            path: "/same/path",
            sizeBytes: 999,
            riskLevel: .caution,
            itemDescription: "desc2"
        )
        #expect(entry1.hashValue == entry2.hashValue)

        var set: Set<CacheEntry> = [entry1, entry2]
        #expect(set.count == 1)
    }
}

struct CacheScanReportTests {
    @Test
    func creation() {
        let now = Date()
        let entries = [
            CacheEntry(category: .appCaches, name: "A", path: "/a", sizeBytes: 100, riskLevel: .safe, itemDescription: "a"),
            CacheEntry(category: .systemLogs, name: "B", path: "/b", sizeBytes: 200, riskLevel: .moderate, itemDescription: "b"),
        ]
        let report = CacheScanReport(
            scannedAt: now,
            entries: entries,
            totalBytes: 300,
            categoryTotals: [.appCaches: 100, .systemLogs: 200]
        )

        #expect(report.scannedAt == now)
        #expect(report.entries.count == 2)
        #expect(report.totalBytes == 300)
        #expect(report.categoryTotals[.appCaches] == 100)
        #expect(report.categoryTotals[.systemLogs] == 200)
    }
}

#elseif canImport(XCTest)
import XCTest

final class CacheCategoryTests: XCTestCase {
    func testAllCasesHaveDisplayNames() {
        for category in CacheCategory.allCases {
            XCTAssertFalse(category.displayName.isEmpty, "displayName should not be empty for \(category)")
        }
    }

    func testDisplayNameMapping() {
        XCTAssertEqual(CacheCategory.appCaches.displayName, "App Caches")
        XCTAssertEqual(CacheCategory.systemLogs.displayName, "System & App Logs")
        XCTAssertEqual(CacheCategory.xcodeData.displayName, "Xcode Data")
        XCTAssertEqual(CacheCategory.packageManager.displayName, "Package Managers")
        XCTAssertEqual(CacheCategory.browserData.displayName, "Browser Caches")
        XCTAssertEqual(CacheCategory.containerData.displayName, "Containers & VMs")
        XCTAssertEqual(CacheCategory.temporaryFiles.displayName, "Temporary Files")
        XCTAssertEqual(CacheCategory.languageFiles.displayName, "Language Files")
        XCTAssertEqual(CacheCategory.mailAttachments.displayName, "Mail Attachments")
        XCTAssertEqual(CacheCategory.iOSBackups.displayName, "iOS Backups")
        XCTAssertEqual(CacheCategory.brokenPreferences.displayName, "Broken Preferences")
    }

    func testAllCasesHaveIcons() {
        for category in CacheCategory.allCases {
            XCTAssertFalse(category.icon.isEmpty, "icon should not be empty for \(category)")
        }
    }

    func testAllCasesHaveDescriptions() {
        for category in CacheCategory.allCases {
            XCTAssertFalse(category.description.isEmpty, "description should not be empty for \(category)")
        }
    }

    func testWillRegenerateForRegeneratingCategories() {
        let regenerating: [CacheCategory] = [.appCaches, .systemLogs, .xcodeData, .packageManager, .temporaryFiles, .brokenPreferences]
        for category in regenerating {
            XCTAssertTrue(category.willRegenerate, "\(category) should regenerate")
        }
    }

    func testWillNotRegenerateForNonRegeneratingCategories() {
        let nonRegenerating: [CacheCategory] = [.browserData, .containerData, .languageFiles, .mailAttachments, .iOSBackups]
        for category in nonRegenerating {
            XCTAssertFalse(category.willRegenerate, "\(category) should not regenerate")
        }
    }

    func testIdMatchesRawValue() {
        for category in CacheCategory.allCases {
            XCTAssertEqual(category.id, category.rawValue)
        }
    }

    func testAllCasesCovered() {
        XCTAssertEqual(CacheCategory.allCases.count, 11)
    }
}

final class CacheRiskLevelTests: XCTestCase {
    func testDisplayNames() {
        XCTAssertEqual(CacheRiskLevel.safe.displayName, "Safe")
        XCTAssertEqual(CacheRiskLevel.moderate.displayName, "Moderate")
        XCTAssertEqual(CacheRiskLevel.caution.displayName, "Caution")
    }

    func testDeletionImpactSummaries() {
        XCTAssertTrue(CacheRiskLevel.safe.deletionImpactSummary.contains("recreated"))
        XCTAssertTrue(CacheRiskLevel.moderate.deletionImpactSummary.contains("re-login"))
        XCTAssertTrue(CacheRiskLevel.caution.deletionImpactSummary.contains("cannot be recovered"))
    }

    func testRawValues() {
        XCTAssertEqual(CacheRiskLevel.safe.rawValue, "safe")
        XCTAssertEqual(CacheRiskLevel.moderate.rawValue, "moderate")
        XCTAssertEqual(CacheRiskLevel.caution.rawValue, "caution")
    }
}

final class CacheEntryTests: XCTestCase {
    func testCreation() {
        let entry = CacheEntry(
            category: .appCaches,
            name: "TestApp",
            path: "/Users/test/Library/Caches/TestApp",
            sizeBytes: 1024,
            riskLevel: .safe,
            itemDescription: "Test app cache"
        )

        XCTAssertEqual(entry.category, .appCaches)
        XCTAssertEqual(entry.name, "TestApp")
        XCTAssertEqual(entry.path, "/Users/test/Library/Caches/TestApp")
        XCTAssertEqual(entry.sizeBytes, 1024)
        XCTAssertEqual(entry.riskLevel, .safe)
        XCTAssertEqual(entry.itemDescription, "Test app cache")
    }

    func testIdIsPath() {
        let entry = CacheEntry(
            category: .appCaches,
            name: "TestApp",
            path: "/some/unique/path",
            sizeBytes: 512,
            riskLevel: .moderate,
            itemDescription: "desc"
        )
        XCTAssertEqual(entry.id, "/some/unique/path")
    }

    func testEqualityByPath() {
        let entry1 = CacheEntry(category: .appCaches, name: "App1", path: "/same/path", sizeBytes: 100, riskLevel: .safe, itemDescription: "desc1")
        let entry2 = CacheEntry(category: .browserData, name: "App2", path: "/same/path", sizeBytes: 999, riskLevel: .caution, itemDescription: "desc2")
        XCTAssertEqual(entry1, entry2)
    }

    func testInequalityByPath() {
        let entry1 = CacheEntry(category: .appCaches, name: "App1", path: "/path/a", sizeBytes: 100, riskLevel: .safe, itemDescription: "desc")
        let entry2 = CacheEntry(category: .appCaches, name: "App1", path: "/path/b", sizeBytes: 100, riskLevel: .safe, itemDescription: "desc")
        XCTAssertNotEqual(entry1, entry2)
    }

    func testHashingConsistentWithEquality() {
        let entry1 = CacheEntry(category: .appCaches, name: "App1", path: "/same/path", sizeBytes: 100, riskLevel: .safe, itemDescription: "desc1")
        let entry2 = CacheEntry(category: .browserData, name: "App2", path: "/same/path", sizeBytes: 999, riskLevel: .caution, itemDescription: "desc2")
        XCTAssertEqual(entry1.hashValue, entry2.hashValue)
        let set: Set<CacheEntry> = [entry1, entry2]
        XCTAssertEqual(set.count, 1)
    }
}

final class CacheScanReportTests: XCTestCase {
    func testCreation() {
        let now = Date()
        let entries = [
            CacheEntry(category: .appCaches, name: "A", path: "/a", sizeBytes: 100, riskLevel: .safe, itemDescription: "a"),
            CacheEntry(category: .systemLogs, name: "B", path: "/b", sizeBytes: 200, riskLevel: .moderate, itemDescription: "b"),
        ]
        let report = CacheScanReport(scannedAt: now, entries: entries, totalBytes: 300, categoryTotals: [.appCaches: 100, .systemLogs: 200])

        XCTAssertEqual(report.scannedAt, now)
        XCTAssertEqual(report.entries.count, 2)
        XCTAssertEqual(report.totalBytes, 300)
        XCTAssertEqual(report.categoryTotals[.appCaches], 100)
        XCTAssertEqual(report.categoryTotals[.systemLogs], 200)
    }
}

#else
struct CacheCategoryTests {}
struct CacheRiskLevelTests {}
struct CacheEntryTests {}
struct CacheScanReportTests {}
#endif
