import MacOptimizerStudioCore
import SwiftUI

struct NetworkView: View {
    @EnvironmentObject private var viewModel: NetworkViewModel
    @EnvironmentObject private var toastManager: ToastManager

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                if let snapshot = viewModel.snapshot {
                    speedCards(snapshot)
                    sparklineCard
                    connectionsSection
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
        .onAppear {
            viewModel.startPolling(interval: 2.0)
        }
        .onDisappear {
            viewModel.stopPolling()
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Network Monitor")
                    .font(.title.weight(.semibold))
                if let snapshot = viewModel.snapshot {
                    Text("Last updated: \(snapshot.capturedAt.formatted(date: .omitted, time: .standard))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Button("Refresh") {
                viewModel.refresh()
            }
            .buttonStyle(.borderedProminent)
        }
    }

    // MARK: - Speed Cards

    private func speedCards(_ snapshot: NetworkSnapshot) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 12)], spacing: 12) {
            speedCard(
                title: "Download",
                arrow: "\u{2193}",
                speed: viewModel.downloadSpeedFormatted,
                total: ByteFormatting.string(snapshot.bytesIn),
                color: .blue
            )
            speedCard(
                title: "Upload",
                arrow: "\u{2191}",
                speed: viewModel.uploadSpeedFormatted,
                total: ByteFormatting.string(snapshot.bytesOut),
                color: .orange
            )
            summaryCard(
                title: "Active Connections",
                value: "\(snapshot.activeConnections)",
                detail: "TCP connections"
            )
            summaryCard(
                title: "Total Transferred",
                value: ByteFormatting.string(snapshot.bytesIn + snapshot.bytesOut),
                detail: "Since interface start"
            )
        }
    }

    private func speedCard(title: String, arrow: String, speed: String, total: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text(arrow)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(color)
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Text(speed)
                .font(.title.weight(.semibold))
                .animation(.easeInOut(duration: 0.4), value: speed)
            Text("Total: \(total)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func summaryCard(title: String, value: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title2.weight(.semibold))
                .animation(.easeInOut(duration: 0.4), value: value)
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Sparkline

    private var sparklineCard: some View {
        GroupBox("Bandwidth History") {
            if viewModel.history.count < 2 {
                Text("Collecting data...")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 100, alignment: .center)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 16) {
                        HStack(spacing: 4) {
                            Circle().fill(.blue).frame(width: 8, height: 8)
                            Text("Download").font(.caption).foregroundStyle(.secondary)
                        }
                        HStack(spacing: 4) {
                            Circle().fill(.orange).frame(width: 8, height: 8)
                            Text("Upload").font(.caption).foregroundStyle(.secondary)
                        }
                    }

                    GeometryReader { geo in
                        let width = geo.size.width
                        let height = geo.size.height

                        let allValues = viewModel.history.flatMap { [$0.1, $0.2] }
                        let maxVal = max(allValues.max() ?? 1, 1)

                        // Download line
                        Path { path in
                            let points = viewModel.history.enumerated().map { (i, entry) -> CGPoint in
                                let x = width * CGFloat(i) / CGFloat(max(viewModel.history.count - 1, 1))
                                let y = height - (height * CGFloat(entry.1) / CGFloat(maxVal))
                                return CGPoint(x: x, y: y)
                            }
                            guard let first = points.first else { return }
                            path.move(to: first)
                            for point in points.dropFirst() {
                                path.addLine(to: point)
                            }
                        }
                        .stroke(.blue, lineWidth: 2)

                        // Upload line
                        Path { path in
                            let points = viewModel.history.enumerated().map { (i, entry) -> CGPoint in
                                let x = width * CGFloat(i) / CGFloat(max(viewModel.history.count - 1, 1))
                                let y = height - (height * CGFloat(entry.2) / CGFloat(maxVal))
                                return CGPoint(x: x, y: y)
                            }
                            guard let first = points.first else { return }
                            path.move(to: first)
                            for point in points.dropFirst() {
                                path.addLine(to: point)
                            }
                        }
                        .stroke(.orange, lineWidth: 2)
                    }
                    .frame(height: 120)
                }
                .padding(.vertical, 4)
            }
        }
    }

    // MARK: - Connections

    private var connectionsSection: some View {
        GroupBox("Active Connections (\(viewModel.connections.count))") {
            if viewModel.connections.isEmpty {
                Text("No active connections detected.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 24)
            } else {
                LazyVStack(spacing: 0) {
                    connectionHeader
                    Divider()
                    ForEach(viewModel.connections.prefix(100)) { conn in
                        connectionRow(conn)
                        Divider()
                    }
                    if viewModel.connections.count > 100 {
                        Text("\(viewModel.connections.count - 100) more connections not shown")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(8)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    private var connectionHeader: some View {
        HStack(spacing: 0) {
            Text("Protocol")
                .frame(width: 70, alignment: .leading)
            Text("Local Address")
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("Remote Address")
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("State")
                .frame(width: 120, alignment: .leading)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.primary.opacity(0.03))
    }

    private func connectionRow(_ conn: NetworkConnection) -> some View {
        HStack(spacing: 0) {
            Text(conn.networkProtocol)
                .frame(width: 70, alignment: .leading)
            Text(conn.localAddress)
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineLimit(1)
                .truncationMode(.middle)
            Text(conn.remoteAddress)
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineLimit(1)
                .truncationMode(.middle)
            Text(conn.state)
                .frame(width: 120, alignment: .leading)
                .foregroundStyle(stateColor(conn.state))
        }
        .font(.subheadline.monospaced())
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    private func stateColor(_ state: String) -> Color {
        switch state.uppercased() {
        case "ESTABLISHED": return .green
        case "LISTEN": return .blue
        case "TIME_WAIT", "CLOSE_WAIT": return .orange
        case "CLOSED": return .red
        default: return .secondary
        }
    }

    // MARK: - States

    private var loadingState: some View {
        VStack(spacing: 12) {
            SkeletonCard(height: 80)
            SkeletonCard(height: 80)
            SkeletonCard(height: 120)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "network.slash")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text("No network data available")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("Network monitoring will begin automatically.")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
