import MacOptimizerStudioCore
import SwiftUI

struct CleanupHistoryView: View {
    @EnvironmentObject private var viewModel: CleanupHistoryViewModel
    @EnvironmentObject private var toastManager: ToastManager

    @State private var showClearConfirm = false

    private let formatter = ByteCountFormatter()
    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header

                if viewModel.records.isEmpty {
                    emptyState
                } else {
                    summaryCards
                    historyList
                }
            }
            .padding(20)
            .frame(maxWidth: 1200)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .background(DesignTokens.pageBackground)
        .sheet(isPresented: $showClearConfirm) {
            DoubleConfirmSheet(
                title: "Clear Cleanup History?",
                warning: "This will permanently delete all cleanup history records. This cannot be undone.",
                confirmLabel: "Clear History"
            ) {
                showClearConfirm = false
            } onConfirm: {
                viewModel.clearHistory()
                toastManager.show("Cleanup history cleared")
                showClearConfirm = false
            }
        }
        .onAppear { viewModel.reload() }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Cleanup History")
                    .font(.largeTitle.weight(.bold))
                Text("Track all cleanup operations performed by MacOptimizer Studio.")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if !viewModel.records.isEmpty {
                Button {
                    showClearConfirm = true
                } label: {
                    Label("Clear History", systemImage: "trash")
                }
                .buttonStyle(.bordered)
                .tint(.red)
            }
        }
    }

    private var summaryCards: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 12)], spacing: 12) {
            StatCard(
                icon: "arrow.up.trash.fill",
                title: "Total Freed",
                value: formatter.string(fromByteCount: Int64(viewModel.totalBytesFreed)),
                tint: .green
            )
            StatCard(
                icon: "list.bullet.clipboard",
                title: "Operations",
                value: "\(viewModel.records.count)",
                tint: .blue
            )
        }
    }

    private var historyList: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(viewModel.recordsByMonth, id: \.0) { month, records in
                VStack(alignment: .leading, spacing: 8) {
                    Text(month)
                        .font(.headline)
                        .padding(.leading, 4)

                    StyledCard {
                        VStack(spacing: 0) {
                            ForEach(records) { record in
                                recordRow(record)
                                if record.id != records.last?.id {
                                    Divider()
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private func recordRow(_ record: CleanupRecord) -> some View {
        HStack(spacing: 12) {
            Image(systemName: iconForCategory(record.category))
                .font(.title3)
                .foregroundStyle(.orange)
                .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(record.category)
                    .font(.body.weight(.medium))
                Text(record.details)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(formatter.string(fromByteCount: Int64(record.bytesFreed)))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.green)
                Text("\(record.itemCount) items")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Text(dateFormatter.string(from: record.date))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 6)
    }

    private func iconForCategory(_ category: String) -> String {
        switch category.lowercased() {
        case let c where c.contains("cache"): return "archivebox"
        case let c where c.contains("disk"): return "externaldrive"
        case let c where c.contains("docker"): return "shippingbox"
        case let c where c.contains("photo"): return "photo"
        case let c where c.contains("privacy"): return "hand.raised.fill"
        case let c where c.contains("shred"): return "flame"
        case let c where c.contains("app"): return "square.stack.3d.up"
        default: return "trash"
        }
    }

    private var emptyState: some View {
        StyledCard {
            VStack(spacing: 18) {
                ZStack {
                    Circle()
                        .fill(Color.secondary.opacity(0.08))
                        .frame(width: 80, height: 80)
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 44))
                        .foregroundStyle(.secondary.opacity(0.6))
                }
                VStack(spacing: 6) {
                    Text("No Cleanup History")
                        .font(.title3.weight(.semibold))
                    Text("Cleanup operations you perform will be recorded here for reference.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 380)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 28)
        }
    }
}
