import SwiftUI

/// A two-step confirmation sheet matching the style of MultiConfirmSheet.
struct DoubleConfirmSheet: View {
    let title: String
    let warning: String
    var confirmLabel: String = "Confirm"
    var items: [(name: String, detail: String)] = []
    let onCancel: () -> Void
    let onConfirm: () async -> Void

    @State private var step = 1
    @State private var isExecuting = false

    var body: some View {
        VStack(spacing: 0) {
            stepIndicator
            Divider()

            if step == 1 {
                reviewStep
            } else {
                confirmStep
            }
        }
        .frame(width: 560)
        .frame(minHeight: 300)
    }

    // MARK: - Step Indicator

    private var stepIndicator: some View {
        HStack(spacing: 0) {
            stepBadge(number: 1, label: "Review", isActive: step == 1, isDone: step > 1)
            stepConnector(isDone: step > 1)
            stepBadge(number: 2, label: "Confirm", isActive: step == 2, isDone: false)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
        .background(Color(nsColor: .windowBackgroundColor))
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
                Label(title, systemImage: "exclamationmark.triangle.fill")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.red)

                warningBox(warning)

                if !items.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Items to be affected:")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)

                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(Array(items.prefix(12).enumerated()), id: \.offset) { _, item in
                                HStack(spacing: 8) {
                                    Image(systemName: "minus.circle.fill")
                                        .font(.caption)
                                        .foregroundStyle(.red.opacity(0.7))
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(item.name)
                                            .font(.caption.weight(.medium))
                                            .lineLimit(1)
                                            .truncationMode(.middle)
                                        if !item.detail.isEmpty {
                                            Text(item.detail)
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                                .lineLimit(1)
                                                .truncationMode(.middle)
                                        }
                                    }
                                    Spacer()
                                }
                                .padding(.vertical, 4)
                                .padding(.horizontal, 8)
                            }

                            if items.count > 12 {
                                Text("... and \(items.count - 12) more")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                            }
                        }
                        .background(Color.primary.opacity(0.03))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                        )
                    }
                }

                HStack {
                    Button("Cancel") { onCancel() }
                        .keyboardShortcut(.cancelAction)
                    Spacer()
                    Button {
                        withAnimation { step = 2 }
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

            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "hand.raised.fill")
                    .foregroundStyle(.red)
                    .font(.title3)
                Text("This action cannot be undone. Click \"\(confirmLabel)\" to proceed permanently.")
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

            if isExecuting {
                HStack {
                    Spacer()
                    ProgressView()
                        .controlSize(.small)
                    Text("Executing...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.vertical, 4)
            }

            Spacer()

            HStack {
                Button("Back") {
                    withAnimation { step = 1 }
                }
                Button("Cancel") { onCancel() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button {
                    isExecuting = true
                    Task {
                        await onConfirm()
                        isExecuting = false
                    }
                } label: {
                    Label(confirmLabel, systemImage: "trash.fill")
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .disabled(isExecuting)
            }
        }
        .padding(24)
    }

    // MARK: - Warning Box

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
}
