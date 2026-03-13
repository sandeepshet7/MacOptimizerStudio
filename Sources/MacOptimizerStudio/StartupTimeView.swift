import MacOptimizerStudioCore
import SwiftUI

struct StartupTimeView: View {
    @EnvironmentObject private var viewModel: StartupTimeViewModel
    @EnvironmentObject private var toastManager: ToastManager

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                header
                if viewModel.isLoading {
                    loadingState
                } else if let snapshot = viewModel.snapshot {
                    totalBootCard(snapshot)
                    phaseBreakdown(snapshot)
                    contributorsSection
                    tipsSection
                } else {
                    emptyState
                }
            }
            .padding(16)
            .frame(maxWidth: 1180)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Startup Time")
                    .font(.title2.weight(.bold))
                Text("Measure and analyze your Mac's boot performance")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                Task { await viewModel.measure() }
            } label: {
                HStack(spacing: 6) {
                    if viewModel.isLoading {
                        ProgressView().controlSize(.mini)
                    }
                    Text("Measure")
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
            .disabled(viewModel.isLoading)
        }
    }

    // MARK: - Total Boot Time Card

    private func totalBootCard(_ snapshot: StartupTimeSnapshot) -> some View {
        VStack(spacing: 10) {
            Text("Total Boot Time")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(formatDuration(snapshot.totalBootTime))
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .foregroundStyle(bootTimeColor(snapshot.totalBootTime))
            if let bootDate = snapshot.lastBootDate {
                Text("Last boot: \(bootDate.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text("Captured: \(snapshot.capturedAt.formatted(date: .omitted, time: .standard))")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Phase Breakdown

    private func phaseBreakdown(_ snapshot: StartupTimeSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Boot Phases")
                .font(.headline)

            let total = snapshot.totalBootTime
            let phases: [(String, Double?, Color)] = [
                ("Firmware", snapshot.firmwareTime, .blue),
                ("Boot Loader", snapshot.loaderTime, .purple),
                ("Kernel & Services", snapshot.kernelTime, .orange),
            ]

            // Stacked bar
            GeometryReader { geo in
                HStack(spacing: 2) {
                    ForEach(Array(phases.enumerated()), id: \.offset) { _, phase in
                        let value = phase.1 ?? 0
                        let fraction = total > 0 ? value / total : 0
                        RoundedRectangle(cornerRadius: 4)
                            .fill(phase.2)
                            .frame(width: max(2, geo.size.width * fraction))
                    }
                }
            }
            .frame(height: 20)
            .clipShape(RoundedRectangle(cornerRadius: 4))

            // Legend
            ForEach(Array(phases.enumerated()), id: \.offset) { _, phase in
                HStack(spacing: 8) {
                    Circle()
                        .fill(phase.2)
                        .frame(width: 10, height: 10)
                    Text(phase.0)
                        .font(.subheadline)
                    Spacer()
                    if let seconds = phase.1 {
                        Text(formatDuration(seconds))
                            .font(.subheadline.weight(.semibold))
                            .monospacedDigit()
                    } else {
                        Text("N/A")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(12)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Contributors

    private var contributorsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Startup Contributors")
                .font(.headline)

            if viewModel.contributors.isEmpty {
                Text("No startup contributors found.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            } else {
                let maxTime = viewModel.contributors.map(\.timeSeconds).max() ?? 1

                ForEach(viewModel.contributors) { contributor in
                    HStack(spacing: 10) {
                        sourceBadge(contributor.source)
                        Text(contributor.name)
                            .font(.subheadline)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Spacer()
                        if contributor.timeSeconds > 0 {
                            GeometryReader { geo in
                                let fraction = maxTime > 0 ? contributor.timeSeconds / maxTime : 0
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color.orange)
                                    .frame(width: max(2, geo.size.width * fraction))
                                    .frame(maxHeight: .infinity, alignment: .center)
                            }
                            .frame(width: 80, height: 8)

                            Text(String(format: "%.1fs", contributor.timeSeconds))
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                                .frame(width: 50, alignment: .trailing)
                        } else {
                            Text("--")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(width: 50, alignment: .trailing)
                        }
                    }
                    .padding(.vertical, 4)
                    Divider()
                }
            }
        }
        .padding(12)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func sourceBadge(_ source: StartupContributorSource) -> some View {
        let label: String
        let color: Color
        switch source {
        case .loginItem:
            label = "Login"
            color = .green
        case .launchAgent:
            label = "Agent"
            color = .blue
        case .launchDaemon:
            label = "Daemon"
            color = .purple
        case .kernel:
            label = "Kernel"
            color = .orange
        }

        return Text(label)
            .font(.system(.caption2, design: .rounded).weight(.semibold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }

    // MARK: - Tips

    private var tipsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "lightbulb.fill")
                    .foregroundStyle(.yellow)
                Text("Tips to Speed Up Boot")
                    .font(.headline)
            }
            VStack(alignment: .leading, spacing: 6) {
                tipRow("Disable unused login items in System Settings > General > Login Items")
                tipRow("Remove unnecessary Launch Agents from ~/Library/LaunchAgents")
                tipRow("Keep your startup disk at least 15% free for optimal performance")
                tipRow("Consider using an SSD or upgrading to a faster drive")
                tipRow("Reset NVRAM/PRAM if firmware time is unusually high")
            }
        }
        .padding(12)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func tipRow(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "checkmark.circle")
                .foregroundStyle(.green)
                .font(.caption)
                .padding(.top, 2)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Empty & Loading States

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "timer")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text("No Startup Data")
                .font(.title3.weight(.semibold))
            Text("Tap \"Measure\" to analyze your Mac's boot performance.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    private var loadingState: some View {
        VStack(spacing: 12) {
            SkeletonCard(height: 120)
            SkeletonCard(height: 100)
            SkeletonCard(height: 80)
        }
    }

    // MARK: - Helpers

    private func formatDuration(_ seconds: Double) -> String {
        if seconds < 60 {
            return String(format: "%.1f seconds", seconds)
        }
        let mins = Int(seconds) / 60
        let secs = seconds.truncatingRemainder(dividingBy: 60)
        return String(format: "%dm %.1fs", mins, secs)
    }

    private func bootTimeColor(_ seconds: Double) -> Color {
        // For uptime display, these thresholds are generous
        if seconds < 30 { return .green }
        if seconds < 120 { return .orange }
        return .red
    }
}
