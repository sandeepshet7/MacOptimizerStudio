import Foundation
@testable import MacOptimizerStudioCore

#if canImport(Testing)
import Testing

struct ExecutionRiskTests {
    @Test
    func rawValues() {
        #expect(ExecutionRisk.safe.rawValue == "safe")
        #expect(ExecutionRisk.moderate.rawValue == "moderate")
        #expect(ExecutionRisk.danger.rawValue == "danger")
    }
}

struct ExecutionItemTests {
    @Test
    func creation() {
        let item = ExecutionItem(label: "node_modules", path: "/proj/node_modules", sizeBytes: 50_000)
        #expect(item.label == "node_modules")
        #expect(item.path == "/proj/node_modules")
        #expect(item.sizeBytes == 50_000)
    }

    @Test
    func uniqueIDs() {
        let a = ExecutionItem(label: "a", path: "/a", sizeBytes: 1)
        let b = ExecutionItem(label: "a", path: "/a", sizeBytes: 1)
        #expect(a.id != b.id)
    }
}

struct ExecutionRequestTests {
    @Test
    func creationWithDefaults() {
        let items = [ExecutionItem(label: "test", path: "/test", sizeBytes: 100)]
        let req = ExecutionRequest(
            title: "Cleanup",
            warningMessage: "Warning!",
            items: items,
            commands: ["rm -rf '/test'"]
        )
        #expect(req.title == "Cleanup")
        #expect(req.warningMessage == "Warning!")
        #expect(req.risk == .moderate)
        #expect(req.items.count == 1)
        #expect(req.commands.count == 1)
        #expect(req.confirmationWord == "CONFIRM")
    }

    @Test
    func creationWithCustomRiskAndConfirmation() {
        let req = ExecutionRequest(
            title: "Danger Zone",
            warningMessage: "Careful!",
            risk: .danger,
            items: [],
            commands: [],
            confirmationWord: "DELETE"
        )
        #expect(req.risk == .danger)
        #expect(req.confirmationWord == "DELETE")
    }

    @Test
    func uniqueIDs() {
        let a = ExecutionRequest(title: "A", warningMessage: "w", items: [], commands: [])
        let b = ExecutionRequest(title: "A", warningMessage: "w", items: [], commands: [])
        #expect(a.id != b.id)
    }
}

struct ExecutionResultTests {
    @Test
    func successfulResult() {
        let result = ExecutionResult(
            success: true,
            freedBytes: 1_000_000,
            itemsProcessed: 5,
            errors: [],
            duration: 2.5
        )
        #expect(result.success == true)
        #expect(result.freedBytes == 1_000_000)
        #expect(result.itemsProcessed == 5)
        #expect(result.errors.isEmpty)
        #expect(result.duration == 2.5)
    }

    @Test
    func failedResult() {
        let result = ExecutionResult(
            success: false,
            freedBytes: 0,
            itemsProcessed: 0,
            errors: ["Permission denied", "File not found"],
            duration: 0.1
        )
        #expect(result.success == false)
        #expect(result.errors.count == 2)
    }
}

#elseif canImport(XCTest)
import XCTest

final class ExecutionRiskTests: XCTestCase {
    func testRawValues() {
        XCTAssertEqual(ExecutionRisk.safe.rawValue, "safe")
        XCTAssertEqual(ExecutionRisk.moderate.rawValue, "moderate")
        XCTAssertEqual(ExecutionRisk.danger.rawValue, "danger")
    }
}

final class ExecutionItemTests: XCTestCase {
    func testCreation() {
        let item = ExecutionItem(label: "node_modules", path: "/proj/node_modules", sizeBytes: 50_000)
        XCTAssertEqual(item.label, "node_modules")
        XCTAssertEqual(item.path, "/proj/node_modules")
        XCTAssertEqual(item.sizeBytes, 50_000)
    }

    func testUniqueIDs() {
        let a = ExecutionItem(label: "a", path: "/a", sizeBytes: 1)
        let b = ExecutionItem(label: "a", path: "/a", sizeBytes: 1)
        XCTAssertNotEqual(a.id, b.id)
    }
}

final class ExecutionRequestTests: XCTestCase {
    func testCreationWithDefaults() {
        let req = ExecutionRequest(title: "Cleanup", warningMessage: "Warning!", items: [], commands: [])
        XCTAssertEqual(req.risk, .moderate)
        XCTAssertEqual(req.confirmationWord, "CONFIRM")
    }

    func testCreationWithCustomValues() {
        let req = ExecutionRequest(title: "X", warningMessage: "w", risk: .danger, items: [], commands: [], confirmationWord: "DELETE")
        XCTAssertEqual(req.risk, .danger)
        XCTAssertEqual(req.confirmationWord, "DELETE")
    }
}

final class ExecutionResultTests: XCTestCase {
    func testSuccessfulResult() {
        let result = ExecutionResult(success: true, freedBytes: 1_000_000, itemsProcessed: 5, errors: [], duration: 2.5)
        XCTAssertTrue(result.success)
        XCTAssertEqual(result.freedBytes, 1_000_000)
        XCTAssertTrue(result.errors.isEmpty)
    }

    func testFailedResult() {
        let result = ExecutionResult(success: false, freedBytes: 0, itemsProcessed: 0, errors: ["err"], duration: 0.1)
        XCTAssertFalse(result.success)
        XCTAssertEqual(result.errors.count, 1)
    }
}

#else
struct ExecutionRiskTests {}
struct ExecutionItemTests {}
struct ExecutionRequestTests {}
struct ExecutionResultTests {}
#endif
