import AppKit
import MacOptimizerStudioCore
import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var diskViewModel: DiskViewModel
    @EnvironmentObject private var memoryViewModel: MemoryViewModel
    @EnvironmentObject private var cacheViewModel: CacheViewModel
    @EnvironmentObject private var systemHealthViewModel: SystemHealthViewModel
    @EnvironmentObject private var dockerViewModel: DockerViewModel

    let openMemory: () -> Void
    let openCache: () -> Void
    let openDisk: () -> Void
    let openCPU: () -> Void
    let openDocker: () -> Void
    let addScanRoot: () -> Void

    @State private var memoryHistory: [Double] = []
    @State private var cpuHistory: [Double] = []
    @State private var isSmartScanning = false
    @State private var smartScanStep = 0
    @State private var smartScanComplete = false
    @State private var smartScanCleanableBytes: UInt64 = 0
    @State private var smartScanIssueCount = 0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                welcomeHeader
                if isSmartScanning || smartScanComplete {
                    smartScanSection
                }
                healthScoreCard
                overviewCards
                if !diskViewModel.roots.isEmpty {
                    diskOverviewCard
                }
                insightsPanel
            }
            .padding(24)
            .frame(maxWidth: 1200)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .task {
            if memoryViewModel.snapshot == nil {
                memoryViewModel.refreshNow()
            }
            if systemHealthViewModel.snapshot == nil {
                await systemHealthViewModel.refresh()
            }
        }
        .onChange(of: memoryViewModel.snapshot?.memoryStats?.usedBytes) { _ in
            if let stats = memoryViewModel.snapshot?.memoryStats, stats.totalBytes > 0 {
                let pct = Double(stats.usedBytes) / Double(stats.totalBytes) * 100
                memoryHistory.append(pct)
                if memoryHistory.count > 20 { memoryHistory.removeFirst() }
            }
            if let snapshot = memoryViewModel.snapshot {
                let topCPU = snapshot.processes.max { ($0.cpuPercent ?? 0) < ($1.cpuPercent ?? 0) }
                cpuHistory.append(topCPU?.cpuPercent ?? 0)
                if cpuHistory.count > 20 { cpuHistory.removeFirst() }
            }
        }
    }

    // MARK: - Welcome

    private var welcomeHeader: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text("MacOptimizer Studio")
                    .font(.largeTitle.weight(.bold))
                Text("Monitor performance, clean caches, and optimize your Mac.")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                Task { await runSmartScan() }
            } label: {
                Label("Smart Scan", systemImage: "bolt.shield.fill")
                    .font(.headline)
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
            .controlSize(.large)
            .disabled(isSmartScanning)
        }
    }

    // MARK: - Smart Scan

    private func runSmartScan() async {
        isSmartScanning = true
        smartScanComplete = false
        smartScanStep = 0
        smartScanCleanableBytes = 0
        smartScanIssueCount = 0

        // Step 1: Scan caches
        withAnimation { smartScanStep = 1 }
        await cacheViewModel.scan()

        // Step 2: Check system health
        withAnimation { smartScanStep = 2 }
        await systemHealthViewModel.refresh()

        // Step 3: Check Docker
        withAnimation { smartScanStep = 3 }
        await dockerViewModel.refresh()

        // Step 4: Analyze results
        withAnimation { smartScanStep = 4 }
        try? await Task.sleep(nanoseconds: 500_000_000)

        // Compute summary
        var cleanable: UInt64 = 0
        var issues = 0

        if let report = cacheViewModel.report {
            cleanable += cacheViewModel.safeTotalBytes
            if report.totalBytes > 500 * 1024 * 1024 { issues += 1 }
        }
        if let snapshot = systemHealthViewModel.snapshot {
            if snapshot.diskUsage.usagePercent > 75 { issues += 1 }
        }
        if let pressure = memoryViewModel.snapshot?.systemMemoryPressure {
            if pressure == .warning || pressure == .critical { issues += 1 }
        }
        if let dockerSnap = dockerViewModel.snapshot, dockerSnap.isRunning {
            cleanable += dockerViewModel.totalDiskUsage
            if dockerViewModel.totalDiskUsage > 5 * 1_000_000_000 { issues += 1 }
        }

        smartScanCleanableBytes = cleanable
        smartScanIssueCount = issues

        withAnimation {
            isSmartScanning = false
            smartScanComplete = true
        }
    }

    private var smartScanSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Smart Scan")
                .font(.title3.weight(.semibold))

            // Step indicators
            VStack(alignment: .leading, spacing: 8) {
                smartScanStepRow(step: 1, label: "Scanning caches...")
                smartScanStepRow(step: 2, label: "Checking system health...")
                smartScanStepRow(step: 3, label: "Checking Docker...")
                smartScanStepRow(step: 4, label: "Analyzing results...")
            }

            // Summary after completion
            if smartScanComplete {
                HStack(spacing: 20) {
                    smartScanSummaryItem(
                        icon: "archivebox.fill",
                        label: "Cleanable",
                        value: ByteFormatting.string(smartScanCleanableBytes),
                        tint: .blue
                    )

                    Divider().frame(height: 40)

                    smartScanSummaryItem(
                        icon: smartScanIssueCount > 0 ? "exclamationmark.triangle.fill" : "checkmark.seal.fill",
                        label: "Issues",
                        value: smartScanIssueCount > 0 ? "\(smartScanIssueCount) found" : "None",
                        tint: smartScanIssueCount > 0 ? .orange : .green
                    )

                    Divider().frame(height: 40)

                    smartScanSummaryItem(
                        icon: "heart.fill",
                        label: "Health Score",
                        value: "\(computeHealthScore()) / 100",
                        tint: computeHealthScore() >= 80 ? .green : (computeHealthScore() >= 50 ? .orange : .red)
                    )

                    Spacer()

                    VStack(spacing: 6) {
                        Button("View Caches") { openCache() }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        Button("View CPU") { openCPU() }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                    }
                }
                .padding(14)
                .background(.thinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.green.opacity(0.2), lineWidth: 1))
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(16)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.orange.opacity(0.15), lineWidth: 1)
        )
    }

    private func smartScanStepRow(step: Int, label: String) -> some View {
        let isComplete = smartScanStep > step || smartScanComplete
        let isCurrent = smartScanStep == step && isSmartScanning

        return HStack(spacing: 10) {
            if isComplete {
                Image(systemName: "checkmark.circle.fill")
                    .font(.body)
                    .foregroundStyle(.green)
                    .transition(.scale.combined(with: .opacity))
            } else if isCurrent {
                ProgressView()
                    .controlSize(.small)
                    .frame(width: 18, height: 18)
            } else {
                Image(systemName: "circle")
                    .font(.body)
                    .foregroundStyle(.secondary.opacity(0.4))
            }

            Text(label)
                .font(.subheadline)
                .foregroundStyle(isComplete ? .primary : (isCurrent ? .primary : .secondary))

            Spacer()
        }
        .animation(.easeInOut(duration: 0.3), value: smartScanStep)
        .animation(.easeInOut(duration: 0.3), value: smartScanComplete)
    }

    private func smartScanSummaryItem(icon: String, label: String, value: String, tint: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(tint)
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.subheadline.weight(.bold))
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Health Score

    @State private var healthScoreAnimated = false

    private var healthScoreCard: some View {
        let score = computeHealthScore()
        let displayScore = healthScoreAnimated ? score : 0
        let scoreColor: Color = score >= 80 ? .green : (score >= 50 ? .orange : .red)
        let displayColor: Color = healthScoreAnimated ? scoreColor : .secondary
        let label: String = score >= 80 ? "Great" : (score >= 50 ? "Needs Attention" : "Critical")

        return HStack(spacing: 24) {
            ZStack {
                RingGauge(progress: Double(displayScore) / 100.0, tint: displayColor, lineWidth: 12)
                    .frame(width: 90, height: 90)
                VStack(spacing: 0) {
                    Text("\(displayScore)")
                        .font(.system(.title, design: .rounded).weight(.bold))
                        .foregroundStyle(displayColor)
                            Text("/ 100")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Mac Health Score")
                    .font(.headline)
                HStack(spacing: 6) {
                    Text(label)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(scoreColor)
                    SeverityBadge(level: score >= 80 ? .healthy : (score >= 50 ? .moderate : .critical))
                }
                .opacity(healthScoreAnimated ? 1 : 0)

                HStack(spacing: 16) {
                    scoreComponent(icon: "externaldrive", label: "Disk", points: diskScorePoints, max: 25)
                    scoreComponent(icon: "memorychip", label: "Memory", points: memoryScorePoints, max: 25)
                    scoreComponent(icon: "cpu", label: "CPU", points: cpuScorePoints, max: 15)
                    scoreComponent(icon: "battery.75percent", label: "Battery", points: batteryScorePoints, max: 15)
                }
                .opacity(healthScoreAnimated ? 1 : 0)

                Text(healthSummaryText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .opacity(healthScoreAnimated ? 1 : 0)
            }

            Spacer()
        }
        .padding(18)
        .background(
            LinearGradient(
                colors: [scoreColor.opacity(0.05), scoreColor.opacity(0.02)],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(scoreColor.opacity(0.2), lineWidth: 1))
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.easeOut(duration: 1.0)) {
                    healthScoreAnimated = true
                }
            }
        }
    }

    private func scoreComponent(icon: String, label: String, points: Int, max: Int) -> some View {
        ScoreComponentView(
            icon: icon,
            label: label,
            points: points,
            max: max,
            detail: scoreDetail(label: label, points: points, max: max),
            tip: scoreTip(label: label, points: points, max: max)
        )
    }

    private func scoreDetail(label: String, points: Int, max: Int) -> String {
        switch label {
        case "Disk":
            let pct = systemHealthViewModel.snapshot?.diskUsage.usagePercent
            return pct.map { String(format: "%.0f%% used", $0) } ?? "No data"
        case "Memory":
            return memoryViewModel.snapshot?.systemMemoryPressure.rawValue.capitalized ?? "Unknown"
        case "CPU":
            let hotCount = memoryViewModel.snapshot?.processes.filter { ($0.cpuPercent ?? 0) > 80 }.count ?? 0
            return hotCount == 0 ? "All quiet" : "\(hotCount) hot process(es)"
        case "Battery":
            let health = systemHealthViewModel.snapshot?.battery?.healthPercent
            return health.map { String(format: "%.0f%% health", $0) } ?? "No battery"
        default:
            return ""
        }
    }

    private func scoreTip(label: String, points: Int, max: Int) -> String {
        switch label {
        case "Disk": return "Best when disk usage < 60%"
        case "Memory": return "Best when memory pressure is Normal"
        case "CPU": return "Best when no process exceeds 80%"
        case "Battery": return "Best when battery health > 90%"
        default: return ""
        }
    }

    private var healthSummaryText: String {
        var issues: [String] = []
        if memoryScorePoints == 0 { issues.append("memory pressure is critical") }
        else if memoryScorePoints <= 12 { issues.append("memory pressure is elevated") }
        if diskScorePoints <= 5 { issues.append("disk space is very low") }
        else if diskScorePoints <= 12 { issues.append("disk space is getting low") }
        if cpuScorePoints == 0 { issues.append("multiple processes are using high CPU") }
        if batteryScorePoints <= 7 { issues.append("battery health is degraded") }
        if issues.isEmpty { return "All systems healthy. Hover over each score for details." }
        return "Attention: \(issues.joined(separator: ", ")). Hover for details."
    }

    private func computeHealthScore() -> Int {
        diskScorePoints + memoryScorePoints + cpuScorePoints + batteryScorePoints + cacheScorePoints + uptimeScorePoints
    }

    private var diskScorePoints: Int {
        guard let disk = systemHealthViewModel.snapshot?.diskUsage else { return 20 }
        if disk.usagePercent < 60 { return 25 }
        if disk.usagePercent < 75 { return 20 }
        if disk.usagePercent < 85 { return 12 }
        if disk.usagePercent < 90 { return 5 }
        return 0
    }

    private var memoryScorePoints: Int {
        guard let pressure = memoryViewModel.snapshot?.systemMemoryPressure else { return 20 }
        switch pressure {
        case .normal: return 25
        case .warning: return 12
        case .critical: return 0
        case .unknown: return 20
        }
    }

    private var cpuScorePoints: Int {
        guard let snapshot = memoryViewModel.snapshot else { return 12 }
        let highCPU = snapshot.processes.filter { ($0.cpuPercent ?? 0) > 80 }.count
        if highCPU == 0 { return 15 }
        if highCPU <= 2 { return 7 }
        return 0
    }

    private var batteryScorePoints: Int {
        guard let battery = systemHealthViewModel.snapshot?.battery else { return 15 }
        if battery.healthPercent > 90 { return 15 }
        if battery.healthPercent > 80 { return 12 }
        if battery.healthPercent > 60 { return 7 }
        return 3
    }

    private var cacheScorePoints: Int {
        guard let report = cacheViewModel.report else { return 8 }
        let safeBytes = cacheViewModel.safeTotalBytes
        if safeBytes < 500 * 1024 * 1024 { return 10 }
        if safeBytes < 2 * 1024 * 1024 * 1024 { return 5 }
        return 0
    }

    private var uptimeScorePoints: Int {
        guard let uptime = systemHealthViewModel.snapshot?.hardware.uptimeSeconds else { return 8 }
        if uptime < 3 * 86400 { return 10 }
        if uptime < 7 * 86400 { return 7 }
        return 3
    }

    // MARK: - Overview Cards with Ring Gauges

    private var overviewCards: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 260), spacing: 16)], spacing: 16) {
            memoryOverviewCard.staggeredAppear(index: 0)
            cacheOverviewCard.staggeredAppear(index: 1)
            cpuOverviewCard.staggeredAppear(index: 2)
            dockerOverviewCard.staggeredAppear(index: 3)
        }
    }

    private var memoryOverviewCard: some View {
        ringCard(
            icon: "memorychip",
            title: "Memory",
            tint: pressureColor,
            action: openMemory
        ) {
            if let snapshot = memoryViewModel.snapshot {
                let usedPercent: Double = {
                    guard let stats = snapshot.memoryStats, stats.totalBytes > 0 else { return 0 }
                    return Double(stats.usedBytes) / Double(stats.totalBytes)
                }()

                RingGauge(progress: usedPercent, tint: pressureColor, lineWidth: 8)
                    .frame(width: 70, height: 70)
                    .overlay {
                        VStack(spacing: 0) {
                            Text("\(Int(usedPercent * 100))%")
                                .font(.system(.title3, design: .rounded).weight(.bold))
                                                .animation(.easeInOut, value: usedPercent)
                        }
                    }
            } else {
                RingGauge(progress: 0, tint: .secondary, lineWidth: 8)
                    .frame(width: 70, height: 70)
                    .overlay {
                        Text("--")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(.secondary)
                    }
            }
        } detail: {
            if let snapshot = memoryViewModel.snapshot {
                HStack(spacing: 6) {
                    Text(pressureLabel)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(pressureColor)
                    SeverityBadge(level: memorySeverity)
                }

                if let stats = snapshot.memoryStats {
                    Text("\(ByteFormatting.memoryString(stats.usedBytes)) of \(ByteFormatting.memoryString(stats.totalBytes))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if memoryHistory.count > 2 {
                    Sparkline(data: memoryHistory, tint: pressureColor, height: 20)
                }

                if let top = snapshot.processes.first {
                    Text("Top: \(top.name)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            } else {
                Text("Collecting...")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var cacheOverviewCard: some View {
        ringCard(
            icon: "archivebox",
            title: "Cache",
            tint: .blue,
            action: openCache
        ) {
            if let report = cacheViewModel.report {
                let safePercent: Double = report.totalBytes > 0
                    ? Double(cacheViewModel.safeTotalBytes) / Double(report.totalBytes)
                    : 0

                RingGauge(progress: safePercent, tint: .green, lineWidth: 8, trackColor: .blue.opacity(0.15))
                    .frame(width: 70, height: 70)
                    .overlay {
                        VStack(spacing: 0) {
                            Text("\(report.entries.count)")
                                .font(.system(.title3, design: .rounded).weight(.bold))
                                                .animation(.easeInOut, value: report.entries.count)
                            Text("items")
                                .font(.system(.caption2, design: .rounded))
                                .foregroundStyle(.secondary)
                        }
                    }
            } else {
                RingGauge(progress: 0, tint: .blue, lineWidth: 8)
                    .frame(width: 70, height: 70)
                    .overlay {
                        Image(systemName: "magnifyingglass")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
            }
        } detail: {
            if let report = cacheViewModel.report {
                Text(ByteFormatting.string(report.totalBytes))
                    .font(.headline.weight(.bold))
    
                let safeBytes = cacheViewModel.safeTotalBytes
                let safeRatio = report.totalBytes > 0 ? Double(safeBytes) / Double(report.totalBytes) : 0
                ProportionalBar(value: safeRatio, tint: .green)

                if safeBytes > 0 {
                    HStack(spacing: 4) {
                        Circle().fill(.green).frame(width: 6, height: 6)
                        Text("\(ByteFormatting.string(safeBytes)) safe to clean")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                    Button("Clean Safe") {
                        cacheViewModel.selectAllSafe()
                        openCache()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                    .tint(.green)
                } else {
                    Text("\(report.entries.count) items found")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("Not scanned")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Button {
                    Task { await cacheViewModel.scan() }
                } label: {
                    Label("Scan Caches", systemImage: "magnifyingglass")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
    }

    private var cpuOverviewCard: some View {
        ringCard(
            icon: "cpu",
            title: "CPU",
            tint: .purple,
            action: openCPU
        ) {
            if let snapshot = memoryViewModel.snapshot {
                let topCPU = snapshot.processes.max { ($0.cpuPercent ?? 0) < ($1.cpuPercent ?? 0) }
                let cpuPercent = min((topCPU?.cpuPercent ?? 0) / 100.0, 1.0)

                RingGauge(progress: cpuPercent, tint: cpuPercent > 0.8 ? .red : (cpuPercent > 0.5 ? .orange : .purple), lineWidth: 8)
                    .frame(width: 70, height: 70)
                    .overlay {
                        VStack(spacing: 0) {
                            Text(String(format: "%.0f%%", (topCPU?.cpuPercent ?? 0)))
                                .font(.system(.title3, design: .rounded).weight(.bold))
                                                .animation(.easeInOut, value: topCPU?.cpuPercent)
                        }
                    }
            } else {
                RingGauge(progress: 0, tint: .purple, lineWidth: 8)
                    .frame(width: 70, height: 70)
                    .overlay {
                        Text("--")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(.secondary)
                    }
            }
        } detail: {
            if let snapshot = memoryViewModel.snapshot {
                let topCPU = snapshot.processes.max { ($0.cpuPercent ?? 0) < ($1.cpuPercent ?? 0) }
                if let topCPU {
                    HStack(spacing: 6) {
                        Text(topCPU.name)
                            .font(.headline.weight(.bold))
                            .lineLimit(1)
                        SeverityBadge(level: cpuSeverity)
                    }

                    if cpuHistory.count > 2 {
                        Sparkline(data: cpuHistory, tint: cpuSeverity.color, height: 20)
                    }

                    let highCPU = snapshot.processes.filter { ($0.cpuPercent ?? 0) > 50 }.count
                    if highCPU > 0 {
                        HStack(spacing: 4) {
                            Circle().fill(.orange).frame(width: 6, height: 6)
                            Text("\(highCPU) process(es) > 50%")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                    } else {
                        Text("All processes normal")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text("Idle")
                        .font(.headline.weight(.bold))
                }
            } else {
                Text("Collecting...")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var dockerOverviewCard: some View {
        ringCard(
            icon: "shippingbox",
            title: "Docker",
            tint: .indigo,
            action: openDocker
        ) {
            if let snapshot = dockerViewModel.snapshot, snapshot.isRunning {
                let imageCount = Double(dockerViewModel.imageCount)
                let progress = min(imageCount / 20.0, 1.0) // normalize to 20 images max

                RingGauge(progress: progress, tint: .indigo, lineWidth: 8)
                    .frame(width: 70, height: 70)
                    .overlay {
                        VStack(spacing: 0) {
                            Text("\(dockerViewModel.imageCount)")
                                .font(.system(.title3, design: .rounded).weight(.bold))
                                                .animation(.easeInOut, value: dockerViewModel.imageCount)
                            Text("images")
                                .font(.system(.caption2, design: .rounded))
                                .foregroundStyle(.secondary)
                        }
                    }
            } else {
                RingGauge(progress: 0, tint: .indigo, lineWidth: 8)
                    .frame(width: 70, height: 70)
                    .overlay {
                        Image(systemName: dockerViewModel.snapshot?.isInstalled == true ? "power" : "shippingbox")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
            }
        } detail: {
            if let snapshot = dockerViewModel.snapshot {
                if !snapshot.isRunning {
                    Text(snapshot.isInstalled ? "Not Running" : "Not Installed")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.secondary)
                } else {
                    Text(ByteFormatting.string(dockerViewModel.totalDiskUsage))
                        .font(.headline.weight(.bold))
        
                    // Normalize: 20GB = full bar
                    let diskRatio = min(Double(dockerViewModel.totalDiskUsage) / (20.0 * 1_000_000_000), 1.0)
                    ProportionalBar(value: diskRatio, tint: diskRatio > 0.7 ? .red : .indigo)

                    Text("\(dockerViewModel.imageCount) images · \(dockerViewModel.volumeCount) volumes")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if dockerViewModel.runningContainerCount > 0 {
                        HStack(spacing: 4) {
                            Circle().fill(.green).frame(width: 6, height: 6)
                            Text("\(dockerViewModel.runningContainerCount) running")
                                .font(.caption)
                                .foregroundStyle(.green)
                        }
                    }

                    if dockerViewModel.totalDiskUsage > 5 * 1_000_000_000 {
                        Button("Prune") { openDocker() }
                            .buttonStyle(.bordered)
                            .controlSize(.mini)
                            .tint(.indigo)
                    }
                }
            } else {
                Text("Not scanned")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Button {
                    Task { await dockerViewModel.refresh() }
                } label: {
                    Label("Check Docker", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
    }

    // MARK: - Ring Card Template

    private func ringCard<Ring: View, Detail: View>(
        icon: String,
        title: String,
        tint: Color,
        action: @escaping () -> Void,
        @ViewBuilder ring: () -> Ring,
        @ViewBuilder detail: () -> Detail
    ) -> some View {
        RingCardContainer(icon: icon, title: title, tint: tint, action: action, ring: ring, detail: detail)
    }

    // MARK: - Disk Overview

    private var diskOverviewCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Disk", systemImage: "externaldrive")
                    .font(.headline)

                Spacer()

                Button { openDisk() } label: {
                    Text("View Details")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.blue)
                }
                .buttonStyle(.plain)
            }

            if let report = diskViewModel.report {
                HStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(ByteFormatting.string(diskViewModel.totalCleanupBytes))
                            .font(.title2.weight(.bold))
                                    Text("\(diskViewModel.totalCleanupCount) cleanup targets")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Divider().frame(height: 36)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(diskViewModel.roots.count) roots")
                            .font(.subheadline.weight(.semibold))
                        if let duration = diskViewModel.lastScanDuration {
                            Text("Last scan: \(String(format: "%.1fs", duration))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    if !diskViewModel.activeCategories.isEmpty {
                        HStack(spacing: 6) {
                            ForEach(diskViewModel.activeCategories, id: \.self) { cat in
                                let summary = diskViewModel.summary(for: cat)
                                VStack(spacing: 2) {
                                    Text(cat.displayName)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                    Text(ByteFormatting.string(summary.sizeBytes))
                                        .font(.caption.weight(.semibold))
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(.ultraThinMaterial)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                            }
                        }
                    }
                }

                if !report.errors.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.caption)
                            .foregroundStyle(.orange)
                        Text("\(report.errors.count) scan errors")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
            } else {
                VStack(spacing: 12) {
                    HStack(spacing: 16) {
                        Image(systemName: "externaldrive.badge.plus")
                            .font(.system(size: 32))
                            .foregroundStyle(.secondary)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("No scan results yet")
                                .font(.subheadline.weight(.medium))
                            Text("Add project folders and scan to find cleanup targets.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button {
                            addScanRoot()
                        } label: {
                            Label("Add Folders", systemImage: "folder.badge.plus")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
            }
        }
        .padding(16)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }

    // MARK: - Insights

    private var insightsPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Insights")
                .font(.title3.weight(.semibold))

            ForEach(Array(insights.enumerated()), id: \.offset) { index, insight in
                insightRow(insight)
                    .staggeredAppear(index: index + 4) // offset from cards
            }

            if insights.isEmpty {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.title3)
                        .foregroundStyle(.green)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("All Clear")
                            .font(.subheadline.weight(.semibold))
                        Text("No immediate issues detected. Run a cache scan or add disk roots for deeper analysis.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.thinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private func insightRow(_ insight: InsightItem) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: insight.icon)
                .font(.title3)
                .foregroundStyle(insight.tint)
                .frame(width: 28)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 4) {
                Text(insight.title)
                    .font(.subheadline.weight(.semibold))
                Text(insight.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let action = insight.action {
                    Button {
                        action()
                    } label: {
                        Text("View Details")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.blue)
                    }
                    .buttonStyle(.plain)
                }
            }

            Spacer()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(insight.tint.opacity(0.15), lineWidth: 1)
        )
    }

    // MARK: - Insights Data

    private struct InsightItem {
        let icon: String
        let tint: Color
        let title: String
        let detail: String
        let action: (() -> Void)?
    }

    private var insights: [InsightItem] {
        var items: [InsightItem] = []

        if let pressure = memoryViewModel.snapshot?.systemMemoryPressure {
            if pressure == .critical {
                items.append(InsightItem(
                    icon: "exclamationmark.triangle.fill", tint: .red,
                    title: "Memory Pressure Critical",
                    detail: "High compression + swap demand. Close heavy apps or restart to free memory.",
                    action: openMemory
                ))
            } else if pressure == .warning {
                items.append(InsightItem(
                    icon: "exclamationmark.circle.fill", tint: .orange,
                    title: "Memory Pressure Elevated",
                    detail: "Consider closing unused applications to reduce memory pressure.",
                    action: openMemory
                ))
            }
        }

        if let report = cacheViewModel.report {
            let safeBytes = cacheViewModel.safeTotalBytes
            if safeBytes > 1024 * 1024 * 1024 {
                items.append(InsightItem(
                    icon: "archivebox.fill", tint: .blue,
                    title: "\(ByteFormatting.string(safeBytes)) Safe to Clean",
                    detail: "\(cacheViewModel.safeEntryCount) cache items can be safely removed to free disk space.",
                    action: openCache
                ))
            } else if report.totalBytes > 500 * 1024 * 1024 {
                items.append(InsightItem(
                    icon: "archivebox", tint: .blue,
                    title: "\(ByteFormatting.string(report.totalBytes)) in Caches",
                    detail: "\(report.entries.count) cache items found. Review and clean to free space.",
                    action: openCache
                ))
            }
        }

        if let snapshot = systemHealthViewModel.snapshot {
            let disk = snapshot.diskUsage
            if disk.usagePercent > 90 {
                items.append(InsightItem(
                    icon: "externaldrive.fill.badge.exclamationmark", tint: .red,
                    title: "Disk Almost Full (\(String(format: "%.0f%%", disk.usagePercent)))",
                    detail: "Only \(ByteFormatting.string(disk.freeBytes)) free. Clean caches and scan disk folders.",
                    action: openDisk
                ))
            } else if disk.usagePercent > 75 {
                items.append(InsightItem(
                    icon: "externaldrive.fill", tint: .orange,
                    title: "Disk Usage High (\(String(format: "%.0f%%", disk.usagePercent)))",
                    detail: "\(ByteFormatting.string(disk.freeBytes)) free. Consider cleaning up.",
                    action: openDisk
                ))
            }
        }

        if diskViewModel.totalCleanupBytes > 5 * 1024 * 1024 * 1024 {
            items.append(InsightItem(
                icon: "folder.fill", tint: .orange,
                title: "\(ByteFormatting.string(diskViewModel.totalCleanupBytes)) in Dev Folders",
                detail: "\(diskViewModel.totalCleanupCount) folders across \(diskViewModel.activeKinds.count) types. Review and clean up.",
                action: openDisk
            ))
        }

        if let dockerSnap = dockerViewModel.snapshot, dockerSnap.isRunning {
            if dockerViewModel.totalDiskUsage > 10 * 1024 * 1024 * 1024 {
                items.append(InsightItem(
                    icon: "shippingbox.fill", tint: .indigo,
                    title: "Docker Using \(ByteFormatting.string(dockerViewModel.totalDiskUsage))",
                    detail: "\(dockerViewModel.imageCount) images, \(dockerViewModel.volumeCount) volumes. Consider pruning unused resources.",
                    action: openDocker
                ))
            }
        }

        if let snapshot = memoryViewModel.snapshot {
            let highCPU = snapshot.processes.filter { ($0.cpuPercent ?? 0) > 80 }
            if !highCPU.isEmpty {
                let names = highCPU.prefix(2).map(\.name).joined(separator: ", ")
                items.append(InsightItem(
                    icon: "cpu", tint: .purple,
                    title: "\(highCPU.count) Process(es) Using High CPU",
                    detail: "\(names) consuming significant CPU resources.",
                    action: openCPU
                ))
            }
        }

        if let uptime = systemHealthViewModel.snapshot?.hardware.uptimeSeconds, uptime > 7 * 86400 {
            items.append(InsightItem(
                icon: "clock.fill", tint: .secondary,
                title: "System Running \(systemHealthViewModel.uptimeFormatted)",
                detail: "A restart can clear accumulated memory pressure and improve performance.",
                action: nil
            ))
        }

        return items
    }

    // MARK: - Helpers

    private var pressureLabel: String {
        guard let pressure = memoryViewModel.snapshot?.systemMemoryPressure else { return "Unknown" }
        switch pressure {
        case .normal: return "Normal"
        case .warning: return "Warning"
        case .critical: return "Critical"
        case .unknown: return "Unknown"
        }
    }

    private var pressureColor: Color {
        guard let pressure = memoryViewModel.snapshot?.systemMemoryPressure else { return .secondary }
        switch pressure {
        case .normal: return .green
        case .warning: return .orange
        case .critical: return .red
        case .unknown: return .secondary
        }
    }

    private var memorySeverity: SeverityLevel {
        guard let pressure = memoryViewModel.snapshot?.systemMemoryPressure else { return .healthy }
        switch pressure {
        case .normal: return .healthy
        case .warning: return .moderate
        case .critical: return .critical
        case .unknown: return .healthy
        }
    }

    private var cpuSeverity: SeverityLevel {
        guard let snapshot = memoryViewModel.snapshot else { return .healthy }
        let topCPU = snapshot.processes.max { ($0.cpuPercent ?? 0) < ($1.cpuPercent ?? 0) }
        let cpu = topCPU?.cpuPercent ?? 0
        if cpu > 80 { return .critical }
        if cpu > 50 { return .moderate }
        return .healthy
    }
}

// MARK: - Score Component with Hover Popover

private struct ScoreComponentView: View {
    let icon: String
    let label: String
    let points: Int
    let max: Int
    let detail: String
    let tip: String

    @State private var isHovered = false

    private var color: Color {
        points == max ? .green : (points > max / 2 ? .orange : .red)
    }

    private var status: String {
        points == max ? "Excellent" : (points > max / 2 ? "Fair" : "Poor")
    }

    var body: some View {
        VStack(spacing: 2) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(color)
            Text("\(points)/\(max)")
                .font(.system(.caption2, design: .rounded).weight(.medium))
            Text(label)
                .font(.system(.caption2))
                .foregroundStyle(.tertiary)
        }
        .onHover { hovering in
            isHovered = hovering
        }
        .popover(isPresented: $isHovered, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: icon)
                        .foregroundStyle(color)
                    Text(label)
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Text(status)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(color)
                }

                HStack(spacing: 4) {
                    Text("Score:")
                        .foregroundStyle(.secondary)
                    Text("\(points)")
                        .fontWeight(.semibold)
                    Text("/ \(max)")
                        .foregroundStyle(.secondary)
                }
                .font(.caption)

                if !detail.isEmpty {
                    HStack(spacing: 4) {
                        Text("Current:")
                            .foregroundStyle(.secondary)
                        Text(detail)
                    }
                    .font(.caption)
                }

                Divider()

                Text(tip)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(10)
            .frame(width: 200)
        }
    }
}

// MARK: - Ring Card Container (with hover)

private struct RingCardContainer<Ring: View, Detail: View>: View {
    let icon: String
    let title: String
    let tint: Color
    let action: () -> Void
    @ViewBuilder let ring: Ring
    @ViewBuilder let detail: Detail

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 0) {
                // Header
                HStack {
                    Label(title, systemImage: icon)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Image(systemName: "arrow.right")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(isHovered ? tint : .secondary)
                        .padding(6)
                        .background(isHovered ? tint.opacity(0.12) : Color.clear)
                        .clipShape(Circle())
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 10)

                // Ring + Detail side by side
                HStack(spacing: 16) {
                    ring

                    VStack(alignment: .leading, spacing: 4) {
                        detail
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
        }
        .buttonStyle(.plain)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isHovered ? tint.opacity(0.35) : tint.opacity(0.15), lineWidth: isHovered ? 1.5 : 1)
        )
        .scaleEffect(isHovered ? 1.01 : 1.0)
        .shadow(color: isHovered ? tint.opacity(0.08) : .clear, radius: 8, y: 2)
        .animation(.easeInOut(duration: 0.2), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - Ring Gauge Shape

struct RingGauge: View {
    let progress: Double
    let tint: Color
    var lineWidth: CGFloat = 8
    var trackColor: Color = .primary.opacity(0.08)

    var body: some View {
        ZStack {
            Circle()
                .stroke(trackColor, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))

            Circle()
                .trim(from: 0, to: min(max(progress, 0), 1))
                .stroke(
                    AngularGradient(
                        colors: [tint.opacity(0.6), tint],
                        center: .center,
                        startAngle: .degrees(0),
                        endAngle: .degrees(360 * progress)
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.8), value: progress)
        }
    }
}
