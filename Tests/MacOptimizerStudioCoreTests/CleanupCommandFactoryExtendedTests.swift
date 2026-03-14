import Foundation
@testable import MacOptimizerStudioCore

#if canImport(Testing)
import Testing

struct CleanupCommandFactoryExtendedTests {
    let factory = CleanupCommandFactory()

    @Test
    func nodeModulesHasOptimizeCommand() {
        let entry = TargetEntry(kind: .nodeModules, path: "/proj/node_modules", sizeBytes: 1000, projectRoot: "/proj")
        let cmds = factory.commands(for: entry)
        let optimize = cmds.first { $0.title == "npm prune" }
        #expect(optimize != nil)
        #expect(optimize?.riskLevel == .safe)
        #expect(optimize?.command.contains("npm prune") == true)
    }

    @Test
    func venvHasOptimizeCommand() {
        let entry = TargetEntry(kind: .venv, path: "/proj/.venv", sizeBytes: 1000, projectRoot: "/proj")
        let optimize = factory.optimizeCommand(for: entry)
        #expect(optimize != nil)
        #expect(optimize?.title == "pip cache purge")
    }

    @Test
    func targetHasCargoCleanDoc() {
        let entry = TargetEntry(kind: .target, path: "/proj/target", sizeBytes: 1000, projectRoot: "/proj")
        let optimize = factory.optimizeCommand(for: entry)
        #expect(optimize != nil)
        #expect(optimize?.title == "cargo clean --doc")
    }

    @Test
    func swiftBuildHasPackageClean() {
        let entry = TargetEntry(kind: .swiftBuild, path: "/proj/.build", sizeBytes: 1000, projectRoot: "/proj")
        let optimize = factory.optimizeCommand(for: entry)
        #expect(optimize != nil)
        #expect(optimize?.title == "swift package clean")
    }

    @Test
    func gradleHasStopCommand() {
        let entry = TargetEntry(kind: .gradle, path: "/proj/.gradle", sizeBytes: 1000, projectRoot: "/proj")
        let optimize = factory.optimizeCommand(for: entry)
        #expect(optimize != nil)
        #expect(optimize?.title == "gradle --stop")
    }

    @Test
    func nextHasClearCacheCommand() {
        let entry = TargetEntry(kind: .next, path: "/proj/.next", sizeBytes: 1000, projectRoot: "/proj")
        let optimize = factory.optimizeCommand(for: entry)
        #expect(optimize != nil)
        #expect(optimize?.title == "Clear .next cache only")
    }

    @Test
    func terraformHasInitUpgrade() {
        let entry = TargetEntry(kind: .terraform, path: "/proj/.terraform", sizeBytes: 1000, projectRoot: "/proj")
        let optimize = factory.optimizeCommand(for: entry)
        #expect(optimize != nil)
        #expect(optimize?.title == "terraform init -upgrade")
    }

    @Test
    func pycacheHasNoOptimizeCommand() {
        let entry = TargetEntry(kind: .pycache, path: "/proj/__pycache__", sizeBytes: 1000, projectRoot: "/proj")
        let optimize = factory.optimizeCommand(for: entry)
        #expect(optimize == nil)
    }

    @Test
    func nonGitEntryHasMoveToTrashAndHardDelete() {
        let entry = TargetEntry(kind: .nodeModules, path: "/proj/node_modules", sizeBytes: 1000, projectRoot: "/proj")
        let cmds = factory.commands(for: entry)
        let trash = cmds.first { $0.title == "Move to Trash" }
        let hardDelete = cmds.first { $0.title == "Hard Delete" }
        #expect(trash != nil)
        #expect(hardDelete != nil)
        #expect(hardDelete?.command == "rm -rf '/proj/node_modules'")
    }

    @Test
    func gitEntryHasMultipleCommands() {
        let entry = TargetEntry(kind: .git, path: "/repo/.git", sizeBytes: 500, projectRoot: "/repo")
        let cmds = factory.commands(for: entry)
        #expect(cmds.count == 4)

        let gcCmd = cmds.first { $0.title.contains("git gc") }
        #expect(gcCmd != nil)
        #expect(gcCmd?.riskLevel == .safe)

        let repackCmd = cmds.first { $0.title.contains("git repack") }
        #expect(repackCmd != nil)

        let bundleCmd = cmds.first { $0.title.contains("Backup") }
        #expect(bundleCmd != nil)

        let deleteCmd = cmds.first { $0.title.contains("Delete .git") }
        #expect(deleteCmd != nil)
        #expect(deleteCmd?.riskLevel == .danger)
        #expect(deleteCmd?.requiresWarning == true)
    }

    @Test
    func findCommandFormatsCorrectly() {
        let cmd = factory.findCommand(roots: ["/home/user/work"], kind: .nodeModules)
        #expect(cmd.contains("find"))
        #expect(cmd.contains("'/home/user/work'"))
        #expect(cmd.contains("'node_modules'"))
    }

    @Test
    func findCommandMultipleRoots() {
        let cmd = factory.findCommand(roots: ["/root1", "/root2"], kind: .venv)
        #expect(cmd.contains("'/root1'"))
        #expect(cmd.contains("'/root2'"))
    }

    @Test
    func hardDeleteCommandFormatsCorrectly() {
        let cmd = factory.hardDeleteCommand(roots: ["/work"], kind: .pycache)
        #expect(cmd.contains("rm -rf"))
        #expect(cmd.contains("'__pycache__'"))
    }

    @Test
    func safeTrashCommandFormatsCorrectly() {
        let cmd = factory.safeTrashCommand(roots: ["/work"], kind: .nodeModules)
        #expect(cmd.contains("mkdir -p"))
        #expect(cmd.contains("mv"))
        #expect(cmd.contains("'node_modules'"))
    }

    @Test
    func safeBundleCommandWithNoEntriesReturnsComment() {
        let cmd = factory.safeBundleCommand(roots: ["/work"], kinds: [.nodeModules], entries: [:])
        #expect(cmd == "# No cleanup targets found")
    }

    @Test
    func safeBundleCommandWithEntries() {
        let entry = TargetEntry(kind: .nodeModules, path: "/work/proj/node_modules", sizeBytes: 1000, projectRoot: "/work/proj")
        let cmd = factory.safeBundleCommand(roots: ["/work"], kinds: [.nodeModules], entries: [.nodeModules: [entry]])
        #expect(cmd.contains("mkdir -p"))
        #expect(cmd.contains("mv '/work/proj/node_modules'"))
    }

    @Test
    func safeBundleCommandWithGitUsesOptimize() {
        let entry = TargetEntry(kind: .git, path: "/work/repo/.git", sizeBytes: 500, projectRoot: "/work/repo")
        let cmd = factory.safeBundleCommand(roots: ["/work"], kinds: [.git], entries: [.git: [entry]])
        #expect(cmd.contains("git"))
        #expect(cmd.contains("gc --aggressive"))
    }

    @Test
    func pathsWithSpacesAreQuoted() {
        let entry = TargetEntry(kind: .nodeModules, path: "/My Projects/app/node_modules", sizeBytes: 1000, projectRoot: "/My Projects/app")
        let cmds = factory.commands(for: entry)
        let hardDelete = cmds.first { $0.title == "Hard Delete" }
        #expect(hardDelete?.command == "rm -rf '/My Projects/app/node_modules'")
    }
}

#elseif canImport(XCTest)
import XCTest

final class CleanupCommandFactoryExtendedTests: XCTestCase {
    let factory = CleanupCommandFactory()

    func testNodeModulesHasOptimizeCommand() {
        let entry = TargetEntry(kind: .nodeModules, path: "/proj/node_modules", sizeBytes: 1000, projectRoot: "/proj")
        let cmds = factory.commands(for: entry)
        let optimize = cmds.first { $0.title == "npm prune" }
        XCTAssertNotNil(optimize)
    }

    func testPycacheHasNoOptimizeCommand() {
        let entry = TargetEntry(kind: .pycache, path: "/proj/__pycache__", sizeBytes: 1000, projectRoot: "/proj")
        XCTAssertNil(factory.optimizeCommand(for: entry))
    }

    func testGitEntryHasMultipleCommands() {
        let entry = TargetEntry(kind: .git, path: "/repo/.git", sizeBytes: 500, projectRoot: "/repo")
        let cmds = factory.commands(for: entry)
        XCTAssertEqual(cmds.count, 4)
    }

    func testFindCommandFormatsCorrectly() {
        let cmd = factory.findCommand(roots: ["/work"], kind: .nodeModules)
        XCTAssertTrue(cmd.contains("find"))
        XCTAssertTrue(cmd.contains("'node_modules'"))
    }

    func testSafeBundleCommandWithNoEntriesReturnsComment() {
        let cmd = factory.safeBundleCommand(roots: ["/work"], kinds: [.nodeModules], entries: [:])
        XCTAssertEqual(cmd, "# No cleanup targets found")
    }

    func testPathsWithSpacesAreQuoted() {
        let entry = TargetEntry(kind: .nodeModules, path: "/My Projects/app/node_modules", sizeBytes: 1000, projectRoot: "/My Projects/app")
        let cmds = factory.commands(for: entry)
        let hardDelete = cmds.first { $0.title == "Hard Delete" }
        XCTAssertEqual(hardDelete?.command, "rm -rf '/My Projects/app/node_modules'")
    }
}

#else
struct CleanupCommandFactoryExtendedTests {}
#endif
