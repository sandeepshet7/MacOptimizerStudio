import MacOptimizerStudioCore
import SwiftUI

enum ConfirmStep {
    case review
    case confirm
    case executing
    case complete
}

struct MultiConfirmSheet: View {
    let request: ExecutionRequest
    let onDismiss: (Bool) -> Void

    @State private var step: ConfirmStep = .review
    @State private var executionResult: ExecutionResult?
    @State private var progressCurrent = 0
    @State private var progressTotal = 0

    private let executor = SafeExecutor()

    var body: some View {
        VStack(spacing: 0) {
            stepIndicator
            Divider()

            switch step {
            case .review:
                reviewStep
            case .confirm:
                confirmStep
            case .executing:
                executingStep
            case .complete:
                completeStep
            }
        }
        .frame(width: 620)
        .frame(minHeight: 400)
    }

    // MARK: - Step Indicator

    private var stepIndicator: some View {
        HStack(spacing: 0) {
            stepBadge(number: 1, label: "Review", isActive: step == .review, isDone: step != .review)
            stepConnector(isDone: step != .review)
            stepBadge(number: 2, label: "Confirm", isActive: step == .confirm, isDone: step == .executing || step == .complete)
            stepConnector(isDone: step == .executing || step == .complete)
            stepBadge(number: 3, label: "Result", isActive: step == .executing || step == .complete, isDone: step == .complete)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
        .background(DesignTokens.pageBackground)
    }

    private func stepBadge(number: Int, label: String, isActive: Bool, isDone: Bool) -> some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(isDone ? Color.green : (isActive ? Color.red : Color.gray.opacity(0.3)))
                    .frame(width: 28, height: 28)
                if isDone {
                    Image(systemName: "checkmark")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                } else {
                    Text("\(number)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(isActive ? .white : .secondary)
                }
            }
            Text(label)
                .font(.caption2)
                .foregroundStyle(isActive ? .primary : .secondary)
        }
    }

    private func stepConnector(isDone: Bool) -> some View {
        Rectangle()
            .fill(isDone ? Color.green : Color.gray.opacity(0.3))
            .frame(height: 2)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 8)
            .padding(.bottom, 16)
    }

    // MARK: - Step 1: Review

    private var reviewStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Label(request.title, systemImage: "exclamationmark.triangle.fill")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.red)

                warningBox(request.warningMessage)

                if !request.items.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Affected Items")
                                .font(.headline)
                            Spacer()
                            Text("\(request.items.count) items · \(ByteFormatting.string(totalSize))")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        ForEach(request.items) { item in
                            HStack(spacing: 8) {
                                Image(systemName: "folder.fill")
                                    .foregroundStyle(.red.opacity(0.6))
                                    .font(.caption)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(item.label)
                                        .font(.subheadline)
                                    Text(item.path)
                                        .font(.system(.caption2, design: .monospaced))
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                }
                                Spacer()
                                Text(ByteFormatting.string(item.sizeBytes))
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                    .padding(12)
                    .background(Color.red.opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }

                HStack {
                    Button("Cancel") { onDismiss(false) }
                        .keyboardShortcut(.cancelAction)

                    Spacer()

                    Button {
                        withAnimation { step = .confirm }
                    } label: {
                        Label("I Understand, Continue", systemImage: "arrow.right")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                }
            }
            .padding(24)
        }
    }

    // MARK: - Step 2: Final Confirmation

    private var confirmStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("FINAL CONFIRMATION")
                .font(.title2.weight(.heavy))
                .foregroundStyle(.red)

            warningBox("This action CANNOT be undone. \(request.items.count) item(s) totaling \(ByteFormatting.string(totalSize)) will be permanently deleted.")

            VStack(alignment: .leading, spacing: 8) {
                Text("Commands that will execute:")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.red)

                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(request.commands.prefix(8).enumerated()), id: \.offset) { _, cmd in
                        Text(cmd)
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                            .lineLimit(2)
                    }
                    if request.commands.count > 8 {
                        Text("... and \(request.commands.count - 8) more")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(Color.primary.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            Spacer()

            HStack {
                Button("Back") {
                    withAnimation { step = .review }
                }

                Button("Cancel") { onDismiss(false) }
                    .keyboardShortcut(.cancelAction)

                Spacer()

                Button {
                    startExecution()
                } label: {
                    Label("Delete Now", systemImage: "trash.fill")
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
            }
        }
        .padding(24)
    }

    // MARK: - Step 3: Executing

    private var totalEstimatedBytes: UInt64 {
        request.items.reduce(0) { $0 + $1.sizeBytes }
    }

    private var estimatedBytesFreed: UInt64 {
        guard progressTotal > 0 else { return 0 }
        let fraction = Double(progressCurrent) / Double(progressTotal)
        return UInt64(Double(totalEstimatedBytes) * fraction)
    }

    private var executingStep: some View {
        VStack(spacing: 20) {
            Spacer()

            // Animated cleaning icon
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.1))
                    .frame(width: 80, height: 80)
                Image(systemName: "sparkles")
                    .font(.system(size: 32))
                    .foregroundStyle(.orange)
            }

            Text("Cleaning...")
                .font(.headline)

            // Bytes freed counter
            if totalEstimatedBytes > 0 {
                Text(ByteFormatting.string(estimatedBytesFreed))
                    .font(.system(.title, design: .rounded).weight(.bold))
                    .foregroundStyle(.orange)
                    .animation(.easeInOut(duration: 0.3), value: progressCurrent)

                Text("freed")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if progressTotal > 0 {
                ProgressView(value: Double(progressCurrent), total: Double(progressTotal))
                    .tint(.orange)
                    .frame(width: 300)
                Text("\(progressCurrent) / \(progressTotal) commands")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text("Do not close this window.")
                .font(.caption)
                .foregroundStyle(.red)

            Spacer()
        }
        .padding(24)
    }

    // MARK: - Step 4: Complete

    private var completeStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let result = executionResult {
                    if result.success {
                        HStack(spacing: 12) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 36))
                                .foregroundStyle(.green)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Cleanup Complete")
                                    .font(.title2.weight(.bold))
                                if totalEstimatedBytes > 0 {
                                    Text("\(ByteFormatting.string(totalEstimatedBytes)) freed")
                                        .font(.title3.weight(.semibold))
                                        .foregroundStyle(.orange)
                                }
                            }
                        }
                    } else {
                        Label("Completed with errors", systemImage: "exclamationmark.circle.fill")
                            .font(.title2.weight(.bold))
                            .foregroundStyle(.orange)
                    }

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 12)], spacing: 12) {
                        resultCard(title: "Processed", value: "\(result.itemsProcessed)")
                        resultCard(title: "Duration", value: String(format: "%.1fs", result.duration))
                        resultCard(title: "Errors", value: "\(result.errors.count)")
                    }

                    if !result.errors.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Errors:")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.red)
                            ForEach(Array(result.errors.prefix(5).enumerated()), id: \.offset) { _, error in
                                Text(error)
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundStyle(.red)
                                    .lineLimit(3)
                            }
                        }
                        .padding(10)
                        .background(Color.red.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }

                HStack {
                    Spacer()
                    Button("Done") { onDismiss(executionResult?.success ?? false) }
                        .buttonStyle(.borderedProminent)
                        .keyboardShortcut(.defaultAction)
                }
            }
            .padding(24)
        }
    }

    // MARK: - Helpers

    private func warningBox(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
                .font(.title3)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.red)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.red.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.red.opacity(0.3), lineWidth: 1)
        )
    }

    private func resultCard(title: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2.weight(.semibold))
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(DesignTokens.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var totalSize: UInt64 {
        request.items.reduce(0) { $0 + $1.sizeBytes }
    }

    private func startExecution() {
        withAnimation { step = .executing }

        let commands = request.commands
        let exec = executor

        Task.detached {
            let result = exec.execute(commands: commands) { current, total in
                Task { @MainActor in
                    progressCurrent = current
                    progressTotal = total
                }
            }

            await MainActor.run {
                executionResult = result
                withAnimation { step = .complete }
            }
        }
    }
}
