import AppKit
import MacOptimizerStudioCore
import SwiftUI

struct DiskView: View {
    @EnvironmentObject private var viewModel: DiskViewModel
    @EnvironmentObject private var toastManager: ToastManager

    @Binding var scanPreset: ScanPreset
    @State private var folderTargetFilter: TargetKind?
    @State private var searchQuery = ""
    @State private var onlyLargeFolders = false
    @State private var selectedCategory: TargetCategory?
    @State private var sortOrder: [KeyPathComparator<FolderTotal>] = [
        .init(\.sizeBytes, order: .reverse)
    ]

    // Cleanup state
    @State private var selectedEntryPaths: Set<String> = []
    @State private var executionRequest: ExecutionRequest?
    @State private var lastCopiedCommand: String?
    @State private var expandedKinds: Set<TargetKind> = []
    @State private var pendingDangerCommand: CleanupCommand?
    @State private var pendingDangerPath = ""

    @AppStorage("confirm_before_cleanup") private var confirmBeforeCleanup = true

    private let factory = CleanupCommandFactory()

    private var selectedEntries: [TargetEntry] {
        viewModel.allEntries.filter { selectedEntryPaths.contains($0.path) }
    }

    private var selectedBytes: UInt64 {
        selectedEntries.reduce(UInt64(0)) { $0 + $1.sizeBytes }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                scanRootsPanel

                if viewModel.report != nil {
                    categorySummary
                    cleanupTargetsPanel
                    largestFoldersPanel

                    if let report = viewModel.report, !report.errors.isEmpty {
                        scanErrorsPanel(report.errors)
                    }
                } else if viewModel.isScanning {
                    scanningState
                } else if let error = viewModel.lastError {
                    scanErrorBanner(error)
                } else {
                    emptyState
                }
            }
            .padding(20)
            .frame(maxWidth: 1280)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .safeAreaInset(edge: .bottom) {
            if viewModel.report != nil {
                diskFloatingActionBar
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .alert("Danger: Delete .git Folder", isPresented: Binding(
            get: { pendingDangerCommand != nil },
            set: { if !$0 { pendingDangerCommand = nil } }
        )) {
            Button("Cancel", role: .cancel) { pendingDangerCommand = nil }
            Button("Copy Delete Command", role: .destructive) {
                if let command = pendingDangerCommand {
                    copyCommand(command.command)
                }
                pendingDangerCommand = nil
            }
        } message: {
            Text("Deleting .git is permanent and irreversible.\n\nPath: \(pendingDangerPath)")
        }
        .sheet(item: $executionRequest) { request in
            MultiConfirmSheet(request: request) { success in
                executionRequest = nil
                selectedEntryPaths.removeAll()
                if success {
                    toastManager.show("Disk cleanup completed successfully")
                } else {
                    toastManager.show("Cleanup completed with errors", isError: true)
                }
                Task { await viewModel.scan(maxDepth: scanPreset.maxDepth, top: scanPreset.top) }
            }
        }
        .onChange(of: viewModel.isScanning) { _ in
            if !viewModel.isScanning && viewModel.report != nil {
                autoExpandTopKinds()
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        Button {
            addFolder()
        } label: {
            VStack(spacing: 18) {
                ZStack {
                    Circle()
                        .fill(Color.orange.opacity(0.08))
                        .frame(width: 80, height: 80)
                    Image(systemName: "externaldrive.badge.plus")
                        .font(.system(size: 38))
                        .foregroundStyle(.orange.opacity(0.7))
                }
                VStack(spacing: 6) {
                    Text("Add folders and run a scan")
                        .font(.title3.weight(.semibold))
                    Text("Find cleanable targets across 15 ecosystems — Python, Node.js, Rust, Swift, Go, and more.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 400)
                }
                HStack(spacing: 6) {
                    Image(systemName: "folder.badge.plus")
                        .font(.caption.weight(.semibold))
                    Text("Click to add folders")
                        .font(.subheadline.weight(.medium))
                }
                .foregroundStyle(.orange)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 44)
            .background(panelFill)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    private func scanErrorBanner(_ message: String) -> some View {
        VStack(spacing: 14) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 36))
                .foregroundStyle(.orange)
            Text("Scan Failed")
                .font(.title3.weight(.semibold))
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 500)
                .textSelection(.enabled)
            if message.contains("scanner binary not found") || message.contains("Rust scanner") {
                Text("Run scripts/build_rust_scanner.sh to build the scanner.")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
            Button("Retry Scan") {
                viewModel.clearError()
                Task { await viewModel.scan(maxDepth: scanPreset.maxDepth, top: scanPreset.top) }
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
            .controlSize(.regular)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 44)
        .background(panelFill)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var scanningState: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)
            Text("Scanning folders...")
                .font(.title3.weight(.semibold))
            Text("Analyzing project directories for cleanup targets.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 10)], spacing: 10) {
                ForEach(0..<4, id: \.self) { _ in
                    SkeletonCard(height: 80)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }

    private func addFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.canCreateDirectories = false
        panel.prompt = "Add Roots"
        if panel.runModal() == .OK, !panel.urls.isEmpty {
            viewModel.addRoots(panel.urls)
            Task {
                await viewModel.scan(maxDepth: scanPreset.maxDepth, top: scanPreset.top)
            }
        }
    }

    // MARK: - Scan Roots

    private var scanRootsPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Scan Roots")
                    .font(.headline)
                Spacer()
                if viewModel.isScanning {
                    ProgressView().controlSize(.small)
                }
                if let duration = viewModel.lastScanDuration {
                    Text(String(format: "%.1fs", duration))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if viewModel.roots.isEmpty {
                Text("No roots selected. Use Add Folder in the top bar or drag folders here.")
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 6)
            } else {
                ForEach(viewModel.roots, id: \.path) { root in
                    HStack {
                        Image(systemName: "folder")
                            .foregroundColor(.orange)
                        Text(root.path)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .font(.subheadline)

                        Spacer()

                        Button {
                            revealInFinder(path: root.path)
                        } label: {
                            Image(systemName: "arrow.right.circle")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .help("Reveal in Finder")

                        Button("Remove") {
                            viewModel.removeRoot(root)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(14)
        .background(panelFill)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Selection Bar

    private var diskFloatingActionBar: some View {
        HStack(spacing: 10) {
            Button("Select All Non-Git") {
                selectedEntryPaths = Set(viewModel.allEntries.filter { $0.kind != .git }.map(\.path))
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            if !selectedEntries.isEmpty {
                Button("Deselect All") {
                    selectedEntryPaths.removeAll()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            Spacer()

            if lastCopiedCommand != nil {
                Label("Copied", systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.green)
            }

            if !selectedEntries.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.orange)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("\(selectedEntries.count) selected")
                            .font(.subheadline.weight(.semibold))
                        Text(ByteFormatting.string(selectedBytes))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Button {
                    copySelectedCommands(selectedEntries)
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button {
                    executeSelected(selectedEntries)
                } label: {
                    Label("Execute", systemImage: "play.fill")
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                .controlSize(.small)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) { Divider() }
    }

    // MARK: - Category Summary

    private var categorySummary: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 10)], spacing: 10) {
            ForEach(TargetCategory.allCases, id: \.self) { category in
                categorySummaryCard(category)
            }
        }
    }

    private func categorySummaryCard(_ category: TargetCategory) -> some View {
        let summary = viewModel.summary(for: category)
        let isActive = selectedCategory == category
        let tint = categoryColor(category)

        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: category.icon)
                    .foregroundStyle(tint)
                Text(category.displayName)
                    .font(.subheadline.weight(.semibold))
                Spacer()
            }

            Text(ByteFormatting.string(summary.sizeBytes))
                .font(.title3.weight(.semibold))
                .animation(.easeInOut(duration: 0.4), value: summary.sizeBytes)
            ProportionalBar(value: categoryBarRatio(summary.sizeBytes), tint: tint)
            Text("\(summary.count) folders")
                .font(.caption)
                .foregroundStyle(.secondary)

            Button(isActive ? "Clear" : "Filter") {
                selectedCategory = selectedCategory == category ? nil : category
                folderTargetFilter = nil
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(panelFill)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isActive ? tint.opacity(0.8) : tint.opacity(0.15), lineWidth: isActive ? 2 : 1)
        )
    }

    // MARK: - Cleanup Targets

    private var cleanupTargetsPanel: some View {
        let kinds = filteredKinds

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Cleanup Targets")
                    .font(.headline)
                Spacer()
                if selectedCategory != nil || folderTargetFilter != nil {
                    Button("Clear Filters") {
                        selectedCategory = nil
                        folderTargetFilter = nil
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                Button {
                    let roots = viewModel.roots.map(\.path)
                    copyCommand(factory.safeBundleCommand(
                        roots: roots,
                        kinds: TargetKind.allCases.filter { viewModel.summary(for: $0).count > 0 },
                        entries: viewModel.entriesGrouped()
                    ))
                } label: {
                    Label("Copy All Commands", systemImage: "doc.on.doc")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help("Copy all safe cleanup commands to clipboard. Paste in Terminal to run them.")
            }

            ForEach(kinds, id: \.self) { kind in
                kindSection(kind: kind, tint: categoryColor(kind.category))
            }
        }
        .padding(14)
        .background(panelFill)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func kindSection(kind: TargetKind, tint: Color) -> some View {
        let entries = viewModel.entries(for: kind)
        let summary = viewModel.summary(for: kind)
        let isExpanded = expandedKinds.contains(kind)

        return VStack(alignment: .leading, spacing: 6) {
            Button {
                withAnimation(.easeInOut(duration: 0.15)) {
                    if expandedKinds.contains(kind) {
                        expandedKinds.remove(kind)
                    } else {
                        expandedKinds.insert(kind)
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.tertiary)
                        .frame(width: 10)

                    Text(kind.displayName)
                        .font(.system(.subheadline, design: .monospaced).weight(.semibold))
                        .foregroundStyle(.primary)

                    Text(kind.ecosystem)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.primary.opacity(0.05))
                        .clipShape(Capsule())
                        .foregroundStyle(.secondary)

                    Spacer()

                    Text("\(summary.count)")
                        .font(.caption.weight(.medium))
                    Text(ByteFormatting.string(summary.sizeBytes))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)

            if isExpanded && !entries.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(entries.prefix(30)) { entry in
                        entryRow(entry, tint: tint)
                    }
                    if entries.count > 30 {
                        Text("+ \(entries.count - 30) more...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.leading, 30)
                    }
                    if kind != .git {
                        Text("Restore: \(kind.restoreHint)")
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(.tertiary)
                            .padding(.leading, 30)
                    }
                }
            }
        }
        .padding(8)
        .background(entries.isEmpty ? Color.clear : tint.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func entryRow(_ entry: TargetEntry, tint: Color) -> some View {
        let isSelected = selectedEntryPaths.contains(entry.path)

        return VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Button {
                    if isSelected { selectedEntryPaths.remove(entry.path) }
                    else { selectedEntryPaths.insert(entry.path) }
                } label: {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(isSelected ? tint : .secondary)
                }
                .buttonStyle(.plain)

                Text(entry.path)
                    .font(.system(.caption, design: .monospaced))
                    .lineLimit(1)
                    .truncationMode(.middle)

                if let staleness = entry.stalenessLabel {
                    Text(staleness)
                        .font(.system(.caption2, design: .rounded).weight(.bold))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.orange.opacity(0.15))
                        .foregroundStyle(.orange)
                        .clipShape(Capsule())
                }

                Spacer()

                Button {
                    revealInFinder(path: entry.path)
                } label: {
                    Image(systemName: "arrow.right.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Reveal in Finder")

                Text(ByteFormatting.string(entry.sizeBytes))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }

            // Action buttons
            let commands = factory.commands(for: entry)
            let safeCmd = commands.first(where: { !$0.requiresWarning && $0.title == "Move to Trash" })
            let optimizeCmds = commands.filter { $0.title.contains("Optimize") || $0.title.contains("gc") || $0.title.contains("prune") || $0.title.contains("clean") }
            let dangerCmd = commands.first(where: { $0.requiresWarning })

            HStack(spacing: 6) {
                if let safeCmd {
                    Button("Copy Command") {
                        copyCommand(safeCmd.command)
                    }
                    .buttonStyle(.bordered)
                    .tint(tint)
                    .help("Copy the safe cleanup command to your clipboard. Paste in Terminal to execute: \(safeCmd.command)")
                }
                ForEach(optimizeCmds.prefix(1), id: \.title) { opt in
                    Button(opt.title) {
                        copyCommand(opt.command)
                    }
                    .buttonStyle(.bordered)
                    .help("Copy command to clipboard: \(opt.command)")
                }
                if let dangerCmd {
                    Button("Delete .git") {
                        pendingDangerPath = entry.path
                        pendingDangerCommand = dangerCmd
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                    .help("Permanently delete the .git folder. This removes version history but keeps your code.")
                }
            }
            .controlSize(.mini)
            .padding(.leading, 30)
        }
        .padding(.vertical, 4)
    }

    // MARK: - Largest Folders Table

    private var largestFoldersPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Largest Folders")
                    .font(.headline)

                Spacer()

                Toggle("100 MB+", isOn: $onlyLargeFolders)
                    .toggleStyle(.switch)
                    .font(.caption)

                TextField("Filter path", text: $searchQuery)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 200)
            }

            if viewModel.report != nil {
                Table(sortedFolderTotals, sortOrder: $sortOrder) {
                    TableColumn("Path", value: \.path) { total in
                        HStack(spacing: 6) {
                            Text(total.path)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Button {
                                revealInFinder(path: total.path)
                            } label: {
                                Image(systemName: "arrow.right.circle")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                            .help("Reveal in Finder")
                        }
                    }
                    .width(min: 340)

                    TableColumn("Size", value: \.sizeBytes) { total in
                        Text(ByteFormatting.string(total.sizeBytes))
                    }
                    .width(min: 100)

                    TableColumn("%") { total in
                        Text(String(format: "%.1f%%", folderPercent(total) * 100))
                    }
                    .width(min: 60)

                    TableColumn("Bar") { total in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.primary.opacity(0.06))
                                .frame(width: 100, height: 6)
                            Capsule()
                                .fill(Color.orange)
                                .frame(width: max(4, 100 * folderPercent(total)), height: 6)
                        }
                    }
                    .width(min: 120)
                }
                .frame(minHeight: 200)
            }
        }
        .padding(14)
        .background(panelFill)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Scan Errors

    private func scanErrorsPanel(_ errors: [ScanErrorEntry]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Scan Errors (\(errors.count))", systemImage: "exclamationmark.triangle")
                .font(.headline)
                .foregroundStyle(.orange)

            ForEach(errors.prefix(5)) { error in
                VStack(alignment: .leading, spacing: 2) {
                    Text(error.path)
                        .font(.system(.caption, design: .monospaced))
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Text(error.message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            if errors.count > 5 {
                Text("+ \(errors.count - 5) more...")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(14)
        .background(panelFill)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.orange.opacity(0.25), lineWidth: 1)
        )
    }

    // MARK: - Helpers

    // Uses viewModel.allEntries (cached, rebuilt only on scan)

    private var filteredKinds: [TargetKind] {
        if let cat = selectedCategory {
            return TargetKind.kinds(for: cat)
        }
        return TargetKind.allCases.filter { viewModel.summary(for: $0).count > 0 }
    }

    private func categoryColor(_ category: TargetCategory) -> Color {
        switch category {
        case .dependencies: return .blue
        case .buildOutput: return .orange
        case .cache: return .purple
        case .vcs: return .green
        }
    }

    private func categoryBarRatio(_ bytes: UInt64) -> Double {
        let maxBytes = TargetCategory.allCases.map { viewModel.summary(for: $0).sizeBytes }.max() ?? 1
        guard maxBytes > 0 else { return 0 }
        return Double(bytes) / Double(maxBytes)
    }

    private func autoExpandTopKinds() {
        let kindsWithResults = TargetKind.allCases
            .filter { viewModel.summary(for: $0).count > 0 }
            .sorted { viewModel.summary(for: $0).sizeBytes > viewModel.summary(for: $1).sizeBytes }
        let topKinds = kindsWithResults.prefix(3)
        expandedKinds = Set(topKinds)
    }

    private var panelFill: some ShapeStyle {
        .thinMaterial
    }

    private var filteredFolderTotals: [FolderTotal] {
        guard let report = viewModel.report else { return [] }
        let needle = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        return report.folderTotals.filter { total in
            let pathLower = total.path.lowercased()
            let pathMatch = needle.isEmpty || pathLower.contains(needle)
            let sizeMatch = !onlyLargeFolders || total.sizeBytes >= 100 * 1024 * 1024

            let targetMatch: Bool
            if let kind = folderTargetFilter {
                let marker = kind.folderName.lowercased()
                targetMatch = pathLower.contains("/\(marker)") || pathLower.hasSuffix("/\(marker)")
            } else if let cat = selectedCategory {
                let markers = TargetKind.kinds(for: cat).map { $0.folderName.lowercased() }
                targetMatch = markers.contains { marker in
                    pathLower.contains("/\(marker)") || pathLower.hasSuffix("/\(marker)")
                }
            } else {
                targetMatch = true
            }

            return pathMatch && sizeMatch && targetMatch
        }
    }

    private var sortedFolderTotals: [FolderTotal] {
        filteredFolderTotals.sorted(using: sortOrder)
    }

    private var totalRootBytes: UInt64 {
        guard let report = viewModel.report else { return 0 }
        let roots = Set(report.roots)
        return report.folderTotals
            .filter { roots.contains($0.path) }
            .reduce(UInt64(0)) { $0 + $1.sizeBytes }
    }

    private func folderPercent(_ total: FolderTotal) -> CGFloat {
        guard totalRootBytes > 0 else { return 0 }
        return CGFloat(Double(total.sizeBytes) / Double(totalRootBytes))
    }

    private func revealInFinder(path: String) {
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: path)
    }

    private func copyCommand(_ command: String) {
        Clipboard.copy(command)
        lastCopiedCommand = command
    }

    private func copySelectedCommands(_ entries: [TargetEntry]) {
        let commands = entries.map { entry -> String in
            if entry.kind == .git {
                return "git -C \(ShellEscaper.quote(entry.projectRoot)) gc --aggressive --prune=now"
            } else {
                return "mv \(ShellEscaper.quote(entry.path)) ~/.Trash/"
            }
        }
        copyCommand(commands.joined(separator: "\n"))
    }

    private func executeSelected(_ entries: [TargetEntry]) {
        let commands = entries.map { entry -> String in
            if entry.kind == .git {
                return factory.commands(for: entry).first(where: { $0.title.contains("gc") })?.command
                    ?? "git -C \(ShellEscaper.quote(entry.projectRoot)) gc --aggressive --prune=now"
            } else {
                return factory.commands(for: entry).first(where: { $0.title == "Move to Trash" })?.command
                    ?? "mv \(ShellEscaper.quote(entry.path)) ~/.Trash/"
            }
        }
        let items = entries.map { entry in
            ExecutionItem(label: "\(entry.kind.displayName) — \(entry.projectRoot)", path: entry.path, sizeBytes: entry.sizeBytes)
        }
        let hasGit = entries.contains { $0.kind == .git }
        executionRequest = ExecutionRequest(
            title: "Execute Cleanup (\(entries.count) items)",
            warningMessage: hasGit
                ? "Git repos will be optimized. Other folders will be moved to Trash."
                : "Selected folders will be moved to ~/.Trash.",
            risk: hasGit ? .moderate : .safe,
            items: items,
            commands: commands,
            confirmationWord: "CLEANUP"
        )
    }
}
