import MacOptimizerStudioCore
import SwiftUI

struct DiskHealthView: View {
    @EnvironmentObject private var viewModel: DiskHealthViewModel
    @EnvironmentObject private var toastManager: ToastManager

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                if let snapshot = viewModel.snapshot {
                    healthStatusCard(snapshot)
                    diskInfoGrid(snapshot)
                    if snapshot.powerOnHours != nil || snapshot.temperature != nil || snapshot.wearLevel != nil {
                        metricsSection(snapshot)
                    }
                    if !snapshot.attributes.isEmpty {
                        smartAttributesTable(snapshot)
                    }
                    smartctlNote
                } else if viewModel.isLoading {
                    loadingState
                } else {
                    emptyState
                }
            }
            .padding(20)
            .frame(maxWidth: 1200)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .task {
            await viewModel.refresh()
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Disk Health")
                    .font(.title.weight(.semibold))
                if let snapshot = viewModel.snapshot {
                    Text("Last checked: \(snapshot.capturedAt.formatted(date: .omitted, time: .standard))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Button("Refresh") {
                Task { await viewModel.refresh() }
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.isLoading)
        }
    }

    // MARK: - Health Status

    private func healthStatusCard(_ snapshot: DiskHealthSnapshot) -> some View {
        StyledCard {
            HStack(spacing: 16) {
                statusIcon(for: snapshot.smartStatus)

                VStack(alignment: .leading, spacing: 4) {
                    Text("S.M.A.R.T. Status")
                        .font(.headline)
                    Text(snapshot.smartStatus)
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(statusColor(for: snapshot.smartStatus))
                    Text(statusDescription(for: snapshot.smartStatus))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
        }
    }

    @ViewBuilder
    private func statusIcon(for status: String) -> some View {
        let normalized = status.lowercased()
        if normalized.contains("verified") || normalized.contains("passed") || normalized.contains("ok") {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.green)
        } else if normalized.contains("failing") || normalized.contains("fail") {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.red)
        } else {
            Image(systemName: "questionmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.orange)
        }
    }

    private func statusColor(for status: String) -> Color {
        let normalized = status.lowercased()
        if normalized.contains("verified") || normalized.contains("passed") || normalized.contains("ok") {
            return .green
        } else if normalized.contains("failing") || normalized.contains("fail") {
            return .red
        }
        return .orange
    }

    private func statusDescription(for status: String) -> String {
        let normalized = status.lowercased()
        if normalized.contains("verified") || normalized.contains("passed") || normalized.contains("ok") {
            return "Your disk is healthy and operating normally."
        } else if normalized.contains("failing") || normalized.contains("fail") {
            return "Your disk may be failing. Back up your data immediately."
        }
        return "Unable to determine disk health status."
    }

    // MARK: - Disk Info Grid

    private func diskInfoGrid(_ snapshot: DiskHealthSnapshot) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 200), spacing: 12)], spacing: 12) {
            StatCard(icon: "internaldrive", title: "Disk Name", value: snapshot.diskName, tint: .blue)
            StatCard(icon: "cpu", title: "Model", value: snapshot.diskModel, tint: .purple)
            StatCard(icon: "number", title: "Serial / UUID", value: snapshot.serialNumber, tint: .orange)
            StatCard(icon: "opticaldisc", title: "Media Type", value: snapshot.mediaType, tint: .green)
        }
    }

    // MARK: - Metrics

    private func metricsSection(_ snapshot: DiskHealthSnapshot) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 200), spacing: 12)], spacing: 12) {
            if let hours = snapshot.powerOnHours {
                StyledCard {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: "clock.fill")
                                .foregroundStyle(hours > 40000 ? .orange : .blue)
                            Text("Power-On Hours")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Text(formatHours(hours))
                            .font(.title3.weight(.semibold))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            if let temp = snapshot.temperature {
                temperatureGauge(temp)
            }
            if let wear = snapshot.wearLevel {
                wearLevelCard(wear)
            }
        }
    }

    private func temperatureGauge(_ temp: Double) -> some View {
        let color: Color = temp > 70 ? .red : (temp > 50 ? .orange : .green)

        return StyledCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "thermometer.medium")
                        .foregroundStyle(color)
                    Text("Temperature")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text(String(format: "%.0f\u{00B0}C", temp))
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(color)

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.primary.opacity(0.1))
                        RoundedRectangle(cornerRadius: 4)
                            .fill(color)
                            .frame(width: geo.size.width * min(CGFloat(temp) / 100.0, 1.0))
                    }
                }
                .frame(height: 8)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func wearLevelCard(_ wear: Double) -> some View {
        let remaining = max(100 - wear, 0)
        let color: Color = remaining < 20 ? .red : (remaining < 50 ? .orange : .green)

        return StyledCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "internaldrive.fill")
                        .foregroundStyle(color)
                    Text("Wear Level")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text(String(format: "%.0f%% remaining", remaining))
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(color)

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.primary.opacity(0.1))
                        RoundedRectangle(cornerRadius: 4)
                            .fill(color)
                            .frame(width: geo.size.width * CGFloat(remaining / 100.0))
                    }
                }
                .frame(height: 8)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - SMART Attributes Table

    private func smartAttributesTable(_ snapshot: DiskHealthSnapshot) -> some View {
        StyledCard {
            VStack(alignment: .leading, spacing: 10) {
                CardSectionHeader(icon: "list.bullet.rectangle", title: "S.M.A.R.T. Attributes", color: .blue)

                Divider()

                LazyVStack(spacing: 0) {
                    attributeHeader
                    Divider()
                    ForEach(snapshot.attributes) { attr in
                        attributeRow(attr)
                        Divider()
                    }
                }
            }
        }
    }

    private var attributeHeader: some View {
        HStack(spacing: 0) {
            Text("ID")
                .frame(width: 50, alignment: .leading)
            Text("Attribute")
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("Value")
                .frame(width: 120, alignment: .trailing)
            Text("Threshold")
                .frame(width: 90, alignment: .trailing)
            Text("Status")
                .frame(width: 80, alignment: .center)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)
        .padding(.vertical, 6)
    }

    private func attributeRow(_ attr: SmartAttribute) -> some View {
        HStack(spacing: 0) {
            Text(attr.id)
                .frame(width: 50, alignment: .leading)
                .foregroundStyle(.secondary)
            Text(attr.name)
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineLimit(1)
            Text(attr.rawValue)
                .frame(width: 120, alignment: .trailing)
            Text(attr.threshold ?? "-")
                .frame(width: 90, alignment: .trailing)
                .foregroundStyle(.secondary)
            attributeStatusBadge(attr.status)
                .frame(width: 80, alignment: .center)
        }
        .font(.subheadline.monospaced())
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func attributeStatusBadge(_ status: SmartAttributeStatus) -> some View {
        switch status {
        case .ok:
            Text("OK")
                .font(.caption2.weight(.semibold))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.green.opacity(0.15))
                .foregroundStyle(.green)
                .clipShape(Capsule())
        case .warning:
            Text("WARN")
                .font(.caption2.weight(.semibold))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.orange.opacity(0.15))
                .foregroundStyle(.orange)
                .clipShape(Capsule())
        case .critical:
            Text("FAIL")
                .font(.caption2.weight(.semibold))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.red.opacity(0.15))
                .foregroundStyle(.red)
                .clipShape(Capsule())
        }
    }

    // MARK: - Note

    private var smartctlNote: some View {
        StyledCard {
            HStack(spacing: 8) {
                Image(systemName: "info.circle")
                    .foregroundStyle(.blue)
                Text("Install smartmontools via Homebrew for detailed S.M.A.R.T. data: ")
                    .font(.caption)
                    .foregroundColor(.secondary)
                + Text("brew install smartmontools")
                    .font(.caption.monospaced())
                    .foregroundColor(.primary)
            }
        }
    }

    // MARK: - States

    private var loadingState: some View {
        VStack(spacing: 12) {
            SkeletonCard(height: 100)
            SkeletonCard(height: 80)
            SkeletonCard(height: 120)
        }
    }

    private var emptyState: some View {
        StyledCard {
            VStack(spacing: 12) {
                Image(systemName: "internaldrive.trianglebadge.exclamationmark")
                    .font(.system(size: 40))
                    .foregroundStyle(.secondary)
                Text("No disk health data available")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Text("Click Refresh to scan your disk.")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, minHeight: 200)
        }
    }

    // MARK: - Helpers

    private func formatHours(_ hours: Int) -> String {
        let days = hours / 24
        if days > 365 {
            let years = Double(days) / 365.25
            return String(format: "%.1f years (%,d hrs)", years, hours)
        }
        return "\(days) days (\(hours) hrs)"
    }
}
