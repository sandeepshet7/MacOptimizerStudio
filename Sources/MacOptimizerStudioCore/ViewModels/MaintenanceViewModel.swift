import Foundation

@MainActor
public final class MaintenanceViewModel: ObservableObject {
    @Published public private(set) var results: [String: MaintenanceResult] = [:]
    @Published public private(set) var runningTasks: Set<String> = []
    @Published public var selectedTasks: Set<String> = []

    private let service: MaintenanceService
    private let auditLog: AuditLogService

    public init(service: MaintenanceService = MaintenanceService(), auditLog: AuditLogService = AuditLogService()) {
        self.service = service
        self.auditLog = auditLog
    }

    public var tasks: [MaintenanceTask] {
        MaintenanceService.allTasks
    }

    public func runTask(_ task: MaintenanceTask) async {
        runningTasks.insert(task.id)
        let svc = service
        let result = await Task.detached(priority: .userInitiated) {
            svc.runTask(task)
        }.value
        results[task.id] = result
        let log = auditLog
        let taskName = task.name
        let success = result.success
        Task.detached { log.log(AuditLogEntry(action: .maintenanceTaskRun, details: "Ran maintenance: \(taskName)\(success ? "" : " (failed)")")) }
        runningTasks.remove(task.id)
    }

    public func runSelected() async {
        let tasksToRun = tasks.filter { selectedTasks.contains($0.id) }
        for task in tasksToRun {
            await runTask(task)
        }
    }

    public func isRunning(_ taskId: String) -> Bool {
        runningTasks.contains(taskId)
    }

    public func result(for taskId: String) -> MaintenanceResult? {
        results[taskId]
    }

    public func toggleSelection(_ taskId: String) {
        if selectedTasks.contains(taskId) {
            selectedTasks.remove(taskId)
        } else {
            selectedTasks.insert(taskId)
        }
    }

    public func selectAll() {
        selectedTasks = Set(tasks.map(\.id))
    }

    public func deselectAll() {
        selectedTasks.removeAll()
    }

    public var anyRunning: Bool {
        !runningTasks.isEmpty
    }

    public var completedCount: Int {
        results.count
    }

    public var successCount: Int {
        results.values.filter(\.success).count
    }
}
