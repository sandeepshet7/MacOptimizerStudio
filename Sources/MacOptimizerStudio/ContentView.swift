import AppKit
import MacOptimizerStudioCore
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @AppStorage(StorageKeys.hasSeenIntro) private var hasSeenIntro = false
    @AppStorage(StorageKeys.defaultScanPreset) private var defaultScanPreset = "balanced"

    @EnvironmentObject private var diskViewModel: DiskViewModel
    @EnvironmentObject private var memoryViewModel: MemoryViewModel
    @EnvironmentObject private var cacheViewModel: CacheViewModel
    @EnvironmentObject private var systemHealthViewModel: SystemHealthViewModel

    @EnvironmentObject private var auditLogViewModel: AuditLogViewModel
    @EnvironmentObject private var duplicateFinderViewModel: DuplicateFinderViewModel
    @EnvironmentObject private var toastManager: ToastManager
    @EnvironmentObject private var alertManager: AlertManager

    @AppStorage(StorageKeys.alertMemoryCritical) private var alertMemoryCritical = true
    @AppStorage(StorageKeys.alertCPUHigh) private var alertCPUHigh = true
    @AppStorage(StorageKeys.alertDiskFull) private var alertDiskFull = true

    @State private var selectedSection: AppSection = .home
    @State private var scanPreset: ScanPreset = .balanced
    @State private var dropTargeted = false
    @State private var hasAppliedDefaultPreset = false

    var body: some View {
        Group {
            if #available(macOS 13, *) {
                NavigationSplitView {
                    sidebar
                } detail: {
                    detailView
                }
                .navigationSplitViewStyle(.balanced)
            } else {
                NavigationView {
                    sidebar
                    detailView
                }
            }
        }
        .navigationTitle("")
        .onDrop(of: [UTType.fileURL], isTargeted: $dropTargeted) { providers in
            handleDrop(providers)
        }
        .overlay {
            if dropTargeted {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.accentColor, lineWidth: 3)
                    .background(Color.accentColor.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .allowsHitTesting(false)
            }
        }
        .toast(toastManager)
        .preferredColorScheme(.dark)
        .onAppear {
            if !hasAppliedDefaultPreset {
                scanPreset = ScanPreset(rawValue: defaultScanPreset) ?? .balanced
                hasAppliedDefaultPreset = true
            }
            alertManager.onboardingComplete = hasSeenIntro
        }
        .onChange(of: hasSeenIntro) { _ in
            alertManager.onboardingComplete = hasSeenIntro
        }
        .sheet(isPresented: Binding(
            get: { !hasSeenIntro },
            set: { isPresented in
                if !isPresented {
                    hasSeenIntro = true
                }
            }
        )) {
            IntroSheet(hasSeenIntro: $hasSeenIntro)
        }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Logo
            HStack(spacing: 10) {
                Group {
                    if let iconURL = ResourceBundle.bundle?.url(forResource: "app_icon", withExtension: "png"),
                       let nsImage = NSImage(contentsOf: iconURL) {
                        Image(nsImage: nsImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    } else {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(
                                    LinearGradient(
                                        colors: [Color.orange, Color.orange.opacity(0.8)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                            Image(systemName: "gauge.with.dots.needle.67percent")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(.white)
                        }
                    }
                }
                .frame(width: 32, height: 32)
                VStack(alignment: .leading, spacing: 0) {
                    Text("MacOptimizer")
                        .font(.subheadline.weight(.bold))
                    Text("Studio")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 20)
            .padding(.bottom, 8)

            Divider()
                .padding(.horizontal, 16)
                .padding(.bottom, 12)

            // Navigation
            SidebarScrollableNav {
                VStack(spacing: 4) {
                    ForEach(AppSection.grouped, id: \.0) { group, sections in
                        if !group.title.isEmpty {
                            Text(group.title.uppercased())
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.tertiary)
                                .padding(.leading, 16)
                                .padding(.top, 12)
                                .padding(.bottom, 2)
                        }
                        ForEach(sections, id: \.self) { section in
                            sidebarButton(section)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
            }

            Divider()
                .padding(.horizontal, 16)

            // Settings button — simulate Cmd+, keystroke
            Button {
                if let menu = NSApp.mainMenu?.item(withTitle: "MacOptimizer Studio")?.submenu
                    ?? NSApp.mainMenu?.items.first?.submenu {
                    for item in menu.items {
                        if item.keyEquivalent == "," {
                            menu.performActionForItem(at: menu.index(of: item))
                            return
                        }
                    }
                }
                // Fallback
                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
            } label: {
                settingsButtonLabel
            }
            .buttonStyle(.plain)
        }
        .frame(minWidth: 210, idealWidth: 220, maxWidth: 250)
        .background(DesignTokens.pageBackground)
    }

    private var settingsButtonLabel: some View {
        HStack(spacing: 8) {
            Image(systemName: "gearshape")
                .font(.subheadline)
            Text("Settings")
                .font(.subheadline)
            Spacer()
            Text("\u{2318},")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private func sidebarButton(_ section: AppSection) -> some View {
        let button = SidebarButtonView(
            section: section,
            isActive: selectedSection == section,
            dotColor: sidebarDotColor(for: section),
            action: { selectedSection = section }
        )
        if let key = shortcut(for: section) {
            button.keyboardShortcut(key, modifiers: [.command])
        } else {
            button
        }
    }

    // MARK: - Detail

    private var detailView: some View {
        VStack(spacing: 0) {
            if showsTopBar {
                topBar
                Divider()
            }
            activeSectionView
                .id(selectedSection)
                .transition(.opacity.combined(with: .offset(y: 6)))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .background(DesignTokens.pageBackground)
        .onChange(of: memoryViewModel.snapshot?.systemMemoryPressure) { _ in
            if let pressure = memoryViewModel.snapshot?.systemMemoryPressure {
                systemHealthViewModel.updateMemoryPressure(pressure)
            }
            // Only fire alerts after onboarding is complete
            guard hasSeenIntro else { return }
            if let pressure = memoryViewModel.snapshot?.systemMemoryPressure {
                alertManager.checkMemoryPressure(pressure.rawValue, enabled: alertMemoryCritical)
            }
            if let snapshot = memoryViewModel.snapshot {
                let highCPU = snapshot.processes.filter { ($0.cpuPercent ?? 0) > 80 }
                if let top = highCPU.first {
                    alertManager.checkCPU(highCount: highCPU.count, topName: top.name, enabled: alertCPUHigh)
                }
            }
            if let hw = systemHealthViewModel.snapshot {
                alertManager.checkDisk(usagePercent: hw.diskUsage.usagePercent, enabled: alertDiskFull)
            }
        }
    }

    private var showsTopBar: Bool {
        selectedSection == .disk
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Disk & Cleanup")
                    .font(.headline)
                Text("Scan roots, analyze, and clean dev folders")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            Picker("Scan Mode", selection: $scanPreset) {
                ForEach(ScanPreset.allCases) { preset in
                    Text(preset.title).tag(preset)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 220)
            .help(scanPresetTooltip)

            Button {
                addScanRoot()
            } label: {
                Label("Add Folder", systemImage: "folder.badge.plus")
            }
            .buttonStyle(.bordered)

            Button {
                runScan()
            } label: {
                Label(diskViewModel.isScanning ? "Scanning..." : "Scan", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
            .keyboardShortcut("r", modifiers: [.command])
            .disabled(diskViewModel.roots.isEmpty || diskViewModel.isScanning)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(DesignTokens.pageBackground.opacity(0.94))
    }

    @ViewBuilder
    private var activeSectionView: some View {
        switch selectedSection {
        case .home:
            HomeView(
                openMemory: { selectedSection = .memory },
                openCache: { selectedSection = .cache },
                openDisk: { selectedSection = .disk },
                openCPU: { selectedSection = .cpu },
                addScanRoot: addScanRoot
            )
            .sectionTransition()
        case .memory:
            MemoryView().sectionTransition()
        case .cache:
            CacheCleanupView().sectionTransition()
        case .disk:
            DiskView(scanPreset: $scanPreset).sectionTransition()
        case .duplicateFinder:
            DuplicateFinderView().sectionTransition()
        case .cpu:
            CPUView().sectionTransition()
        case .battery:
            BatteryView().sectionTransition()
        case .loginItems:
            LoginItemsView().sectionTransition()
        case .privacy:
            PrivacyView().sectionTransition()
        case .apps:
            AppManagerView().sectionTransition()
        case .network:
            NetworkView().sectionTransition()
        case .brokenDownloads:
            BrokenDownloadsView().sectionTransition()
        case .activityLog:
            AuditLogView().sectionTransition()
        }
    }

    // MARK: - Actions

    private func addScanRoot() {
        let urls = pickFolders()
        guard !urls.isEmpty else { return }
        diskViewModel.addRoots(urls)
    }

    private func runScan() {
        memoryViewModel.refreshNow()
        Task {
            await diskViewModel.scan(maxDepth: scanPreset.maxDepth, top: scanPreset.top)
        }
    }

    // MARK: - Helpers

    private func shortcut(for section: AppSection) -> KeyEquivalent? {
        switch section {
        case .home: return "1"
        case .memory: return "2"
        case .cpu: return "3"
        case .battery: return "4"
        case .cache: return "5"
        case .disk: return "6"
        case .activityLog: return "7"
        default: return nil
        }
    }

    private func sidebarDotColor(for section: AppSection) -> Color? {
        switch section {
        case .memory:
            guard let pressure = memoryViewModel.snapshot?.systemMemoryPressure else { return nil }
            switch pressure {
            case .critical: return .red
            case .warning: return .orange
            default: return nil
            }
        case .cache:
            if let report = cacheViewModel.report, report.totalBytes > 10 * 1024 * 1024 * 1024 {
                return .orange
            }
            return nil
        case .cpu:
            if let snapshot = memoryViewModel.snapshot {
                let highCPU = snapshot.processes.contains { ($0.cpuPercent ?? 0) > 80 }
                return highCPU ? .orange : nil
            }
            return nil
        case .battery:
            if let battery = systemHealthViewModel.snapshot?.battery, battery.healthPercent < 80 {
                return .red
            }
            return nil
        case .activityLog:
            return auditLogViewModel.totalActions > 0 ? .green : nil
        default:
            return nil
        }
    }

    private var scanPresetTooltip: String {
        switch scanPreset {
        case .fast:
            return "Fast: Shallow scan (depth 4, top 120 items). Quick overview of cleanup targets."
        case .balanced:
            return "Balanced: Moderate scan (depth 6, top 220 items). Good for regular cleanup."
        case .deep:
            return "Deep: Full recursive scan (depth 10, top 500 items). Finds everything but takes longer."
        }
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        for provider in providers {
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                guard let url, url.hasDirectoryPath else { return }
                DispatchQueue.main.async {
                    diskViewModel.addRoots([url])
                }
            }
        }
        return true
    }

    private func pickFolders() -> [URL] {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.canCreateDirectories = false
        panel.prompt = "Add Roots"
        return panel.runModal() == .OK ? panel.urls : []
    }
}

// MARK: - Sidebar Button with Hover

private struct SidebarButtonView: View {
    let section: AppSection
    let isActive: Bool
    let dotColor: Color?
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: section.icon)
                    .font(.body)
                    .frame(width: 22)
                    .foregroundStyle(isActive ? .white : .primary.opacity(0.55))

                Text(section.title)
                    .font(.body.weight(isActive ? .semibold : .medium))
                    .foregroundStyle(isActive ? .white : .primary)

                Spacer(minLength: 0)

                if let dotColor {
                    Circle()
                        .fill(dotColor)
                        .frame(width: 8, height: 8)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(
                isActive
                    ? AnyShapeStyle(
                        LinearGradient(
                            colors: [DesignTokens.accent, DesignTokens.accent.opacity(0.85)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    : AnyShapeStyle(isHovered ? Color.primary.opacity(0.06) : Color.clear)
            )
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - Sidebar Scrollable Nav with Bottom Indicator

private struct SidebarScrollableNav<Content: View>: View {
    @ViewBuilder let content: Content
    @State private var showBottomHint = true
    @State private var bounceOffset: CGFloat = 0

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                content

                // Sentinel at the very bottom — when visible, user has scrolled far enough
                GeometryReader { geo in
                    Color.clear
                        .preference(key: BottomVisibleKey.self, value: geo.frame(in: .named("sidebarScroll")).maxY)
                }
                .frame(height: 1)
            }
            .coordinateSpace(name: "sidebarScroll")
            .onPreferenceChange(BottomVisibleKey.self) { bottomY in
                // When the sentinel's maxY is close to or less than the visible height, we're at bottom
                // We don't know the exact scroll view height, but if bottomY < some reasonable value, hide
                withAnimation(.easeOut(duration: 0.3)) {
                    showBottomHint = bottomY > 50
                }
            }

            if showBottomHint {
                VStack(spacing: 0) {
                    LinearGradient(
                        colors: [DesignTokens.pageBackground.opacity(0), DesignTokens.pageBackground.opacity(0.95)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 24)

                    HStack(spacing: 4) {
                        Image(systemName: "chevron.compact.down")
                            .font(.body.weight(.semibold))
                            .offset(y: bounceOffset)
                    }
                    .foregroundStyle(.orange.opacity(0.7))
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 4)
                    .background(DesignTokens.pageBackground.opacity(0.95))
                }
                .allowsHitTesting(false)
                .transition(.opacity)
                .onAppear {
                    withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                        bounceOffset = 3
                    }
                }
            }
        }
    }
}

private struct BottomVisibleKey: PreferenceKey {
    nonisolated(unsafe) static var defaultValue: CGFloat = .infinity
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = min(value, nextValue())
    }
}

// MARK: - Onboarding Wizard

private struct IntroSheet: View {
    @Binding var hasSeenIntro: Bool
    @State private var step = 0

    private let totalSteps = 5

    var body: some View {
        VStack(spacing: 0) {
            // Progress bar
            progressBar

            // Content
            Group {
                switch step {
                case 0: welcomeStep
                case 1: monitorStep
                case 2: cleanupStep
                case 3: securityStep
                default: quickStartStep
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .transition(.asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            ))
            .id(step)

            Divider()

            // Navigation buttons
            navigationBar
        }
        .frame(width: 620, height: 520)
    }

    // MARK: - Progress Bar

    private var progressBar: some View {
        VStack(spacing: 6) {
            HStack(spacing: 0) {
                ForEach(0..<totalSteps, id: \.self) { i in
                    Rectangle()
                        .fill(i <= step ? Color.orange : Color.orange.opacity(0.15))
                        .frame(height: 3)
                        .animation(.easeInOut(duration: 0.3), value: step)
                }
            }

            HStack {
                Text("Step \(step + 1) of \(totalSteps)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Spacer()
                if step < totalSteps - 1 {
                    Button("Skip tour") {
                        hasSeenIntro = true
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 24)
        }
        .padding(.top, 12)
    }

    // MARK: - Step 0: Welcome

    private var welcomeStep: some View {
        ScrollView {
            VStack(spacing: 20) {
                Spacer().frame(height: 8)

                // App icon
                Group {
                    if let iconURL = ResourceBundle.bundle?.url(forResource: "app_icon", withExtension: "png"),
                       let nsImage = NSImage(contentsOf: iconURL) {
                        Image(nsImage: nsImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    } else {
                        ZStack {
                            RoundedRectangle(cornerRadius: 20)
                                .fill(
                                    LinearGradient(
                                        colors: [Color.orange, Color.orange.opacity(0.7)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                            Image(systemName: "gauge.with.dots.needle.67percent")
                                .font(.system(size: 36))
                                .foregroundStyle(.white)
                        }
                    }
                }
                .frame(width: 72, height: 72)
                .shadow(color: .orange.opacity(0.3), radius: 12, y: 4)

                VStack(spacing: 8) {
                    Text("Welcome to MacOptimizer Studio")
                        .font(.title.weight(.bold))
                    Text("Your Mac, But Faster")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }

                Divider().padding(.horizontal, 40)

                // Trust pillars
                VStack(spacing: 12) {
                    trustPillar(
                        icon: "shield.checkered",
                        title: "Safe by design",
                        detail: "Every destructive action requires multi-step confirmation. Nothing runs without your explicit consent."
                    )
                    trustPillar(
                        icon: "eye",
                        title: "Transparent",
                        detail: "All operations are logged in the Activity Log. You can export a full audit trail at any time."
                    )
                }
                .padding(.horizontal, 24)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
    }

    // MARK: - Step 1: Monitor

    private var monitorStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                stepHeader(
                    icon: "waveform.path.ecg",
                    title: "Monitor Your Mac",
                    subtitle: "Real-time insights into system health",
                    color: .blue
                )

                featureCard(
                    icon: "memorychip", color: .blue,
                    title: "Memory",
                    detail: "Live memory pressure gauge, per-process RAM usage, and one-click memory purge. See which apps are hogging RAM.",
                    badge: "Real-time"
                )
                featureCard(
                    icon: "cpu", color: .orange,
                    title: "CPU",
                    detail: "Track CPU-intensive processes. Get contextual alerts when usage is high. Quit or force-quit runaway processes.",
                    badge: "Real-time"
                )
                featureCard(
                    icon: "battery.75percent", color: .green,
                    title: "Battery",
                    detail: "Battery health percentage, cycle count, thermal state, and charging status. Know when your battery needs attention.",
                    badge: nil
                )
                featureCard(
                    icon: "network", color: .purple,
                    title: "Network",
                    detail: "Monitor bandwidth usage, active connections, and network interface status in real-time.",
                    badge: "Real-time"
                )
            }
            .padding(24)
        }
    }

    // MARK: - Step 2: Cleanup

    private var cleanupStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                stepHeader(
                    icon: "sparkles",
                    title: "Free Up Space",
                    subtitle: "Safely clean caches, dev folders, and more",
                    color: .green
                )

                featureCard(
                    icon: "archivebox", color: .blue,
                    title: "Cache Cleanup",
                    detail: "Scan system caches across ~/Library, Xcode, npm, pip, Homebrew, browsers, and more. Each item shows risk level (Safe/Caution).",
                    badge: "Popular"
                )
                featureCard(
                    icon: "externaldrive", color: .orange,
                    title: "Disk Scan",
                    detail: "Add project folders and scan for cleanable targets like node_modules, .build, __pycache__ across 15+ ecosystems.",
                    badge: nil
                )
                Text("Also includes:")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 10)], spacing: 10) {
                    miniFeature(icon: "arrow.down.circle.dotted", title: "Downloads", detail: "Broken files")
                    miniFeature(icon: "square.stack.3d.up", title: "Apps", detail: "View footprint")
                }
            }
            .padding(24)
        }
    }

    // MARK: - Step 3: Security & Advanced

    private var securityStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                stepHeader(
                    icon: "lock.shield",
                    title: "Security & Advanced",
                    subtitle: "Privacy tools and system diagnostics",
                    color: .red
                )

                featureCard(
                    icon: "flame", color: .red,
                    title: "File Shredder",
                    detail: "Securely destroy files by overwriting 3x with random data before deletion. Files CANNOT be recovered by any tool. Drag and drop files onto the window.",
                    badge: "Permanent"
                )
                featureCard(
                    icon: "hand.raised.fill", color: .indigo,
                    title: "Privacy",
                    detail: "Clean browser caches, cookies, history, and recent documents. Review which apps have access to Camera, Microphone, Location, and more.",
                    badge: nil
                )
                featureCard(
                    icon: "shield.lefthalf.filled", color: .green,
                    title: "Activity Log",
                    detail: "Every destructive action is logged with timestamp, paths, and sizes. Export as text for auditing. Proves all actions were user-confirmed.",
                    badge: "Audit trail"
                )

                Text("System tools:")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 10)], spacing: 10) {
                    miniFeature(icon: "power", title: "Login Items", detail: "Startup programs")
                    miniFeature(icon: "puzzlepiece.extension", title: "Extensions", detail: "Plugins & add-ons")
                    miniFeature(icon: "arrow.down.circle", title: "Updater", detail: "Homebrew updates")
                    miniFeature(icon: "stethoscope", title: "Disk Health", detail: "S.M.A.R.T. status")
                    miniFeature(icon: "stopwatch", title: "Startup Time", detail: "Boot analysis")
                    miniFeature(icon: "gauge.with.dots.needle.67percent", title: "Benchmark", detail: "Disk speed test")
                }
            }
            .padding(24)
        }
    }

    // MARK: - Step 4: Quick Start

    private var quickStartStep: some View {
        ScrollView {
            VStack(spacing: 20) {
                Spacer().frame(height: 8)

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.green)

                Text("You're all set!")
                    .font(.title2.weight(.bold))
                Text("Here's how to get started:")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 14) {
                    quickStartItem(
                        number: "1",
                        title: "Check the Home dashboard",
                        detail: "See your Mac's health score, disk usage, memory pressure, and actionable insights at a glance.",
                        color: .orange
                    )
                    quickStartItem(
                        number: "2",
                        title: "Run a Cache scan",
                        detail: "Go to Cache in the sidebar. It auto-scans on first visit. Review items marked \"Safe\" and clean them.",
                        color: .blue
                    )
                    quickStartItem(
                        number: "3",
                        title: "Add project folders to Disk",
                        detail: "Go to Disk, add your dev folders, and find cleanable targets like node_modules and build caches.",
                        color: .green
                    )
                    quickStartItem(
                        number: "4",
                        title: "Explore the sidebar",
                        detail: "There are 20+ features organized into Monitor, Cleanup, and System groups. Scroll down to see them all!",
                        color: .purple
                    )
                }
                .padding(.horizontal, 20)

                Divider().padding(.horizontal, 40)

                HStack(spacing: 6) {
                    Image(systemName: "keyboard")
                        .foregroundColor(.secondary)
                    Text("Pro tip: Use ")
                        .foregroundColor(.secondary)
                    + Text("Cmd+1..9")
                        .font(.caption.weight(.semibold))
                    + Text(" to quickly jump between sections.")
                        .foregroundColor(.secondary)
                }
                .font(.caption)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
    }

    // MARK: - Navigation Bar

    private var navigationBar: some View {
        HStack {
            if step > 0 {
                Button {
                    withAnimation(.easeInOut(duration: 0.3)) { step -= 1 }
                } label: {
                    Label("Back", systemImage: "chevron.left")
                }
                .buttonStyle(.bordered)
            }

            Spacer()

            // Step dots
            HStack(spacing: 6) {
                ForEach(0..<totalSteps, id: \.self) { i in
                    Circle()
                        .fill(i == step ? Color.orange : Color.orange.opacity(0.2))
                        .frame(width: 7, height: 7)
                        .scaleEffect(i == step ? 1.2 : 1.0)
                        .animation(.easeInOut(duration: 0.2), value: step)
                }
            }

            Spacer()

            if step < totalSteps - 1 {
                Button {
                    withAnimation(.easeInOut(duration: 0.3)) { step += 1 }
                } label: {
                    Label("Next", systemImage: "chevron.right")
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                .keyboardShortcut(.defaultAction)
            } else {
                Button {
                    hasSeenIntro = true
                } label: {
                    Label("Get Started", systemImage: "arrow.right")
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
        .background(DesignTokens.pageBackground)
    }

    // MARK: - Components

    private func stepHeader(icon: String, title: String, subtitle: String, color: Color) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(color.opacity(0.12))
                    .frame(width: 40, height: 40)
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(color)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.title3.weight(.bold))
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func featureCard(icon: String, color: Color, title: String, detail: String, badge: String?) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(color.opacity(0.1))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.body)
                    .foregroundStyle(color)
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                    if let badge {
                        Text(badge)
                            .font(.system(size: 9, weight: .semibold))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(color.opacity(0.12))
                            .foregroundStyle(color)
                            .clipShape(Capsule())
                    }
                }
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func miniFeature(icon: String, title: String, detail: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.caption.weight(.medium))
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(0.02))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func trustPillar(icon: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.orange)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func quickStartItem(number: String, title: String, detail: String, color: Color) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(color)
                    .frame(width: 26, height: 26)
                Text(number)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
