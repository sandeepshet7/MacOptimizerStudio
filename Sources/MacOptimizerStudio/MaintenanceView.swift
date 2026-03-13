import MacOptimizerStudioCore
import SwiftUI

struct MaintenanceView: View {
    @EnvironmentObject private var maintenanceViewModel: MaintenanceViewModel
    @EnvironmentObject private var toastManager: ToastManager

    @State private var expandedResults: Set<String> = []
    @State private var pendingSudoTask: MaintenanceTask?
    @State private var pendingSudoBatch: [MaintenanceTask]?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                toolbar
                taskGrid
                if maintenanceViewModel.completedCount > 0 {
                    summaryBar
                }
            }
            .padding(20)
            .frame(maxWidth: 1200)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .sheet(item: $pendingSudoTask) { task in
            DoubleConfirmSheet(
                title: "Run \"\(task.name)\"?",
                warning: "This task requires elevated privileges (sudo). Command:\n\n\(task.command)\n\nEstimated duration: \(task.estimatedDuration)",
                confirmLabel: "Run Task",
                items: [(task.name, task.command)]
            ) {
                pendingSudoTask = nil
            } onConfirm: {
                pendingSudoTask = nil
                await maintenanceViewModel.runTask(task)
                toastManager.show(
                    maintenanceViewModel.result(for: task.id)?.success == true
                        ? "\(task.name) completed successfully"
                        : "\(task.name) finished with errors",
                    isError: maintenanceViewModel.result(for: task.id)?.success != true
                )
            }
        }
        .sheet(item: Binding(
            get: { pendingSudoBatch.map { BatchWrapper(tasks: $0) } },
            set: { wrapper in pendingSudoBatch = wrapper?.tasks }
        )) { wrapper in
            DoubleConfirmSheet(
                title: "Run \(wrapper.tasks.count) Selected Tasks?",
                warning: "Some selected tasks require elevated privileges (sudo). The following will be executed sequentially.",
                confirmLabel: "Run All",
                items: wrapper.tasks.map { ($0.name, $0.command) }
            ) {
                pendingSudoBatch = nil
            } onConfirm: {
                let tasksToRun = wrapper.tasks
                pendingSudoBatch = nil
                for task in tasksToRun {
                    await maintenanceViewModel.runTask(task)
                }
                toastManager.show(
                    "\(maintenanceViewModel.successCount) of \(maintenanceViewModel.completedCount) tasks completed successfully"
                )
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Maintenance")
                .font(.largeTitle.weight(.bold))
            Text("Run system maintenance scripts to keep your Mac running smoothly.")
                .font(.body)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack(spacing: 12) {
            Button {
                if maintenanceViewModel.selectedTasks.count == maintenanceViewModel.tasks.count {
                    maintenanceViewModel.deselectAll()
                } else {
                    maintenanceViewModel.selectAll()
                }
            } label: {
                Label(
                    maintenanceViewModel.selectedTasks.count == maintenanceViewModel.tasks.count
                        ? "Deselect All" : "Select All",
                    systemImage: maintenanceViewModel.selectedTasks.count == maintenanceViewModel.tasks.count
                        ? "checklist.unchecked" : "checklist.checked"
                )
            }
            .buttonStyle(.bordered)

            if !maintenanceViewModel.selectedTasks.isEmpty {
                Text("\(maintenanceViewModel.selectedTasks.count) selected")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                runSelectedTasks()
            } label: {
                Label(
                    maintenanceViewModel.anyRunning ? "Running..." : "Run Selected",
                    systemImage: "play.fill"
                )
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
            .disabled(maintenanceViewModel.selectedTasks.isEmpty || maintenanceViewModel.anyRunning)
        }
    }

    // MARK: - Task Grid

    private var taskGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: 14),
            GridItem(.flexible(), spacing: 14),
        ], spacing: 14) {
            ForEach(maintenanceViewModel.tasks) { task in
                taskCard(task)
            }
        }
    }

    // MARK: - Task Card

    private func taskCard(_ task: MaintenanceTask) -> some View {
        let isSelected = maintenanceViewModel.selectedTasks.contains(task.id)
        let isRunning = maintenanceViewModel.isRunning(task.id)
        let result = maintenanceViewModel.result(for: task.id)
        let isExpanded = expandedResults.contains(task.id)

        return VStack(alignment: .leading, spacing: 10) {
            // Top row: checkbox, icon, name, badges, run button
            HStack(alignment: .top, spacing: 10) {
                Button {
                    maintenanceViewModel.toggleSelection(task.id)
                } label: {
                    Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                        .font(.title3)
                        .foregroundStyle(isSelected ? .orange : .secondary)
                }
                .buttonStyle(.plain)

                Image(systemName: task.icon)
                    .font(.title2)
                    .foregroundStyle(.orange)
                    .frame(width: 28, height: 28)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(task.name)
                            .font(.headline)

                        if task.requiresSudo {
                            sudoBadge
                        }

                        statusIndicator(isRunning: isRunning, result: result)
                    }

                    Text(task.estimatedDuration)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }

                Spacer()

                Button {
                    runSingleTask(task)
                } label: {
                    Label("Run", systemImage: "play.fill")
                        .font(.subheadline)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(isRunning)
            }

            // Description
            Text(task.description)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(isExpanded ? nil : 2)

            // Result output (expandable)
            if let result {
                Divider()

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Image(systemName: result.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundStyle(result.success ? .green : .red)
                            .font(.subheadline)

                        Text(result.success ? "Completed" : "Failed")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(result.success ? .green : .red)

                        Text(String(format: "%.1fs", result.duration))
                            .font(.caption)
                            .foregroundStyle(.tertiary)

                        Spacer()

                        if !result.output.isEmpty {
                            Button {
                                toggleExpanded(task.id)
                            } label: {
                                Label(
                                    isExpanded ? "Hide Output" : "Show Output",
                                    systemImage: isExpanded ? "chevron.up" : "chevron.down"
                                )
                                .font(.caption)
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.secondary)
                        }
                    }

                    if isExpanded, !result.output.isEmpty {
                        ScrollView(.horizontal, showsIndicators: true) {
                            Text(result.output)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                        }
                        .frame(maxHeight: 120)
                        .padding(8)
                        .background(Color.primary.opacity(0.04))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                }
            }
        }
        .padding(14)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? Color.orange.opacity(0.5) : Color.clear, lineWidth: 1.5)
        )
        .help(task.description)
    }

    // MARK: - Components

    private var sudoBadge: some View {
        Text("SUDO")
            .font(.system(size: 9, weight: .bold, design: .monospaced))
            .foregroundStyle(.red)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(Color.red.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    @ViewBuilder
    private func statusIndicator(isRunning: Bool, result: MaintenanceResult?) -> some View {
        if isRunning {
            ProgressView()
                .controlSize(.mini)
        } else if let result {
            Image(systemName: result.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(result.success ? .green : .red)
                .font(.subheadline)
        }
    }

    // MARK: - Summary Bar

    private var summaryBar: some View {
        HStack(spacing: 16) {
            Label(
                "\(maintenanceViewModel.completedCount) completed",
                systemImage: "checkmark.circle"
            )
            .font(.subheadline)
            .foregroundStyle(.secondary)

            Label(
                "\(maintenanceViewModel.successCount) succeeded",
                systemImage: "checkmark.circle.fill"
            )
            .font(.subheadline)
            .foregroundStyle(.green)

            let failCount = maintenanceViewModel.completedCount - maintenanceViewModel.successCount
            if failCount > 0 {
                Label(
                    "\(failCount) failed",
                    systemImage: "xmark.circle.fill"
                )
                .font(.subheadline)
                .foregroundStyle(.red)
            }

            Spacer()
        }
        .padding(12)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Actions

    private func toggleExpanded(_ taskId: String) {
        if expandedResults.contains(taskId) {
            expandedResults.remove(taskId)
        } else {
            expandedResults.insert(taskId)
        }
    }

    private func runSingleTask(_ task: MaintenanceTask) {
        if task.requiresSudo {
            pendingSudoTask = task
        } else {
            Task {
                await maintenanceViewModel.runTask(task)
                toastManager.show(
                    maintenanceViewModel.result(for: task.id)?.success == true
                        ? "\(task.name) completed successfully"
                        : "\(task.name) finished with errors",
                    isError: maintenanceViewModel.result(for: task.id)?.success != true
                )
            }
        }
    }

    private func runSelectedTasks() {
        let selected = maintenanceViewModel.tasks.filter {
            maintenanceViewModel.selectedTasks.contains($0.id)
        }
        let hasSudo = selected.contains { $0.requiresSudo }

        if hasSudo {
            pendingSudoBatch = selected
        } else {
            Task {
                for task in selected {
                    await maintenanceViewModel.runTask(task)
                }
                toastManager.show(
                    "\(maintenanceViewModel.successCount) of \(maintenanceViewModel.completedCount) tasks completed successfully"
                )
            }
        }
    }
}

// MARK: - Helpers

private struct BatchWrapper: Identifiable {
    let id = UUID()
    let tasks: [MaintenanceTask]
}
