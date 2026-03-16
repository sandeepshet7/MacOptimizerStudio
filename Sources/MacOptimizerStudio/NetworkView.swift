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
            viewModel.startPolling(interval: 10.0)
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
                Text("Shows your Mac's current internet activity — how fast data is moving, how much has been transferred, and which services are connected.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if let snapshot = viewModel.snapshot {
                    Text("Last updated: \(snapshot.capturedAt.formatted(date: .omitted, time: .standard)) · Auto-refreshes every 10s")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
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
            networkStatCard(
                icon: "arrow.down.circle.fill", title: "Download Speed",
                value: viewModel.downloadSpeedFormatted,
                subtitle: "Total received: \(ByteFormatting.string(snapshot.bytesIn))",
                tint: .blue
            )
            networkStatCard(
                icon: "arrow.up.circle.fill", title: "Upload Speed",
                value: viewModel.uploadSpeedFormatted,
                subtitle: "Total sent: \(ByteFormatting.string(snapshot.bytesOut))",
                tint: .orange
            )
            networkStatCard(
                icon: "link", title: "Active Connections",
                value: "\(snapshot.activeConnections)",
                subtitle: "Apps talking to the internet",
                tint: .green
            )
            networkStatCard(
                icon: "arrow.left.arrow.right.circle.fill", title: "Total Transferred",
                value: ByteFormatting.string(snapshot.bytesIn + snapshot.bytesOut),
                subtitle: "Since last reboot",
                tint: .purple
            )
        }
    }

    private func networkStatCard(icon: String, title: String, value: String, subtitle: String, tint: Color) -> some View {
        StyledCard {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: icon)
                        .font(.caption)
                        .foregroundColor(tint)
                    Text(title)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Text(value)
                    .font(.title3.weight(.semibold))
                    .foregroundColor(.primary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Sparkline

    private var sparklineCard: some View {
        StyledCard {
            VStack(alignment: .leading, spacing: 14) {
                CardSectionHeader(icon: "chart.xyaxis.line", title: "Bandwidth History", color: .blue)

                if viewModel.history.count < 2 {
                    Text("Collecting data...")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 100, alignment: .center)
                } else {
                    Divider()

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
            }
        }
    }

    // MARK: - Connections

    private var connectionsSection: some View {
        StyledCard {
            VStack(alignment: .leading, spacing: 14) {
                CardSectionHeader(
                    icon: "network",
                    title: "Active Connections (\(viewModel.connections.count))",
                    color: .green
                )
                Text("Every app that connects to the internet creates a connection. Port 443 = secure HTTPS, port 80 = HTTP. This is normal — browsers, iCloud, Slack, and system services all maintain multiple connections.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 4)

                Divider()

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
        StyledCard {
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
        }
    }
}
