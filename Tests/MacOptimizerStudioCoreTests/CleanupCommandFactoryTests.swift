@testable import MacOptimizerStudioCore

#if canImport(Testing)
import Testing

struct CleanupCommandFactoryTests {
    @Test
    func rendersSafeQuotedTrashCommand() {
        let entry = TargetEntry(
            kind: .venv,
            path: "/Users/test/My Project/.venv",
            sizeBytes: 2048,
            projectRoot: "/Users/test/My Project"
        )

        let commands = CleanupCommandFactory().commands(for: entry)
        let trash = commands.first { $0.title == "Move to Trash" }

        #expect(trash != nil)
        #expect(trash?.riskLevel == .safe)
        #expect(trash?.requiresWarning == false)
        #expect(trash?.command == "mv '/Users/test/My Project/.venv' ~/.Trash/")
    }

    @Test
    func marksGitDeleteAsDangerAndWarningGated() {
        let entry = TargetEntry(
            kind: .git,
            path: "/Users/test/repo/.git",
            sizeBytes: 100,
            projectRoot: "/Users/test/repo"
        )

        let commands = CleanupCommandFactory().commands(for: entry)
        let delete = commands.first { $0.title.contains("Delete .git") }

        #expect(delete != nil)
        #expect(delete?.riskLevel == .danger)
        #expect(delete?.requiresWarning == true)
        #expect(delete?.command == "rm -rf '/Users/test/repo/.git'")
    }
}

#elseif canImport(XCTest)
import XCTest

final class CleanupCommandFactoryTests: XCTestCase {
    func testRendersSafeQuotedTrashCommand() {
        let entry = TargetEntry(
            kind: .venv,
            path: "/Users/test/My Project/.venv",
            sizeBytes: 2048,
            projectRoot: "/Users/test/My Project"
        )

        let commands = CleanupCommandFactory().commands(for: entry)
        let trash = commands.first { $0.title == "Move to Trash" }

        XCTAssertNotNil(trash)
        XCTAssertEqual(trash?.riskLevel, .safe)
        XCTAssertEqual(trash?.requiresWarning, false)
        XCTAssertEqual(trash?.command, "mv '/Users/test/My Project/.venv' ~/.Trash/")
    }

    func testMarksGitDeleteAsDangerAndWarningGated() {
        let entry = TargetEntry(
            kind: .git,
            path: "/Users/test/repo/.git",
            sizeBytes: 100,
            projectRoot: "/Users/test/repo"
        )

        let commands = CleanupCommandFactory().commands(for: entry)
        let delete = commands.first { $0.title.contains("Delete .git") }

        XCTAssertNotNil(delete)
        XCTAssertEqual(delete?.riskLevel, .danger)
        XCTAssertEqual(delete?.requiresWarning, true)
        XCTAssertEqual(delete?.command, "rm -rf '/Users/test/repo/.git'")
    }
}

#else
struct CleanupCommandFactoryTests {}
#endif
