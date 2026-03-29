import Foundation
@testable import MacOptimizerStudioCore

#if canImport(Testing)
import Testing

struct MaintenanceServiceTests {
    private let service = MaintenanceService()

    @Test
    func allTasksIsNonEmpty() {
        #expect(!MaintenanceService.allTasks.isEmpty)
    }

    @Test
    func eachTaskHasNonEmptyNameCommandAndDescription() {
        for task in MaintenanceService.allTasks {
            #expect(!task.name.isEmpty, "Task \(task.id) has empty name")
            #expect(!task.command.isEmpty, "Task \(task.id) has empty command")
            #expect(!task.description.isEmpty, "Task \(task.id) has empty description")
        }
    }

    @Test
    func eachTaskHasNonEmptyIdAndIcon() {
        for task in MaintenanceService.allTasks {
            #expect(!task.id.isEmpty, "Task has empty id")
            #expect(!task.icon.isEmpty, "Task \(task.id) has empty icon")
            #expect(!task.estimatedDuration.isEmpty, "Task \(task.id) has empty estimatedDuration")
        }
    }

    @Test
    func requiresSudoTasksHaveSudoInOriginalCommandOrNeedPrivilegeEscalation() {
        // Tasks marked requiresSudo should contain "sudo" in their command
        // OR be system-level commands that inherently need elevated privileges.
        let sudoTasks = MaintenanceService.allTasks.filter { $0.requiresSudo }
        #expect(!sudoTasks.isEmpty, "Expected at least one sudo task")

        // Verify the flush_dns task specifically contains sudo
        let flushDNS = MaintenanceService.allTasks.first { $0.id == "flush_dns" }
        #expect(flushDNS != nil)
        #expect(flushDNS!.requiresSudo)
        #expect(flushDNS!.command.contains("sudo"))
    }

    @Test
    func nonSudoTasksDoNotContainSudo() {
        let nonSudoTasks = MaintenanceService.allTasks.filter { !$0.requiresSudo }
        for task in nonSudoTasks {
            #expect(!task.command.contains("sudo"), "Non-sudo task \(task.id) contains 'sudo' in command")
        }
    }

    @Test
    func taskIdsAreUnique() {
        let ids = MaintenanceService.allTasks.map(\.id)
        let uniqueIds = Set(ids)
        #expect(ids.count == uniqueIds.count, "Duplicate task IDs found")
    }

    @Test
    func runTaskWithSimpleEchoCommand() {
        let echoTask = MaintenanceTask(
            id: "test_echo",
            name: "Test Echo",
            description: "A harmless echo command for testing",
            icon: "terminal",
            command: "echo 'maintenance test output'",
            requiresSudo: false,
            estimatedDuration: "instant"
        )

        let result = service.runTask(echoTask)
        #expect(result.success)
        #expect(result.taskId == "test_echo")
        #expect(result.output.contains("maintenance test output"))
        #expect(result.duration >= 0)
    }

    @Test
    func runTaskWithFailingCommand() {
        let failingTask = MaintenanceTask(
            id: "test_fail",
            name: "Test Fail",
            description: "A command that exits with non-zero",
            icon: "xmark",
            command: "exit 42",
            requiresSudo: false
        )

        let result = service.runTask(failingTask)
        #expect(!result.success)
        #expect(result.taskId == "test_fail")
    }

    @Test
    func runTaskDurationIsPositive() {
        let task = MaintenanceTask(
            id: "test_duration",
            name: "Test Duration",
            description: "Measures duration",
            icon: "clock",
            command: "echo done",
            requiresSudo: false
        )

        let result = service.runTask(task)
        #expect(result.duration >= 0)
    }
}

#elseif canImport(XCTest)
import XCTest

final class MaintenanceServiceTests: XCTestCase {
    private let service = MaintenanceService()

    func testAllTasksIsNonEmpty() {
        XCTAssertFalse(MaintenanceService.allTasks.isEmpty)
    }

    func testEachTaskHasNonEmptyFields() {
        for task in MaintenanceService.allTasks {
            XCTAssertFalse(task.name.isEmpty, "Task \(task.id) has empty name")
            XCTAssertFalse(task.command.isEmpty, "Task \(task.id) has empty command")
            XCTAssertFalse(task.description.isEmpty, "Task \(task.id) has empty description")
            XCTAssertFalse(task.id.isEmpty, "Task has empty id")
            XCTAssertFalse(task.icon.isEmpty, "Task \(task.id) has empty icon")
        }
    }

    func testRequiresSudoTasksHaveSudoInCommand() {
        let flushDNS = MaintenanceService.allTasks.first { $0.id == "flush_dns" }
        XCTAssertNotNil(flushDNS)
        XCTAssertTrue(flushDNS!.requiresSudo)
        XCTAssertTrue(flushDNS!.command.contains("sudo"))
    }

    func testTaskIdsAreUnique() {
        let ids = MaintenanceService.allTasks.map(\.id)
        XCTAssertEqual(ids.count, Set(ids).count)
    }

    func testRunTaskWithSimpleEchoCommand() {
        let echoTask = MaintenanceTask(
            id: "test_echo",
            name: "Test Echo",
            description: "Harmless echo",
            icon: "terminal",
            command: "echo 'maintenance test output'",
            requiresSudo: false
        )

        let result = service.runTask(echoTask)
        XCTAssertTrue(result.success)
        XCTAssertEqual(result.taskId, "test_echo")
        XCTAssertTrue(result.output.contains("maintenance test output"))
    }

    func testRunTaskWithFailingCommand() {
        let failingTask = MaintenanceTask(
            id: "test_fail",
            name: "Test Fail",
            description: "Fails",
            icon: "xmark",
            command: "exit 42",
            requiresSudo: false
        )

        let result = service.runTask(failingTask)
        XCTAssertFalse(result.success)
        XCTAssertEqual(result.taskId, "test_fail")
    }
}

#else
struct MaintenanceServiceTests {}
#endif
