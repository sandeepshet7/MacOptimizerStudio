import MacOptimizerStudioCore
import SwiftUI

struct CacheCleanupView: View {
    @EnvironmentObject private var cacheViewModel: CacheViewModel
    @EnvironmentObject private var toastManager: ToastManager
    @State private var expandedCategories: Set<CacheCategory> = Set(CacheCategory.allCases)
    @State private var executionRequest: ExecutionRequest?
    @State private var lastCopiedCommand: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                scanBar

                if let report = cacheViewModel.report {
                    safeToCleanHero
                    summaryCards
                    categoryList(report: report)
                } else if cacheViewModel.isScanning {
                    skeletonLoading
                } else {
                    emptyState
                }
            }
            .padding(20)
            .frame(maxWidth: 1200)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .safeAreaInset(edge: .bottom) {
            if !cacheViewModel.selectedEntries.isEmpty {
                floatingActionBar
            }
        }
        .task {
            if cacheViewModel.report == nil && !cacheViewModel.isScanning {
                await cacheViewModel.scan()
            }
        }
        .sheet(item: $executionRequest) { request in
            MultiConfirmSheet(request: request) { success in
                executionRequest = nil
                if success {
                    cacheViewModel.logCleanup(itemCount: request.items.count)
                    toastManager.show("Cache cleanup completed successfully")
                } else {
                    toastManager.show("Cleanup completed with errors", isError: true)
                }
                Task { await cacheViewModel.scan() }
            }
        }
    }

    // MARK: - Floating Action Bar

    private var floatingActionBar: some View {
        let selected = cacheViewModel.selectedEntries
        let cautionCount = selected.filter { $0.riskLevel == .caution }.count

        return HStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.orange)
                VStack(alignment: .leading, spacing: 1) {
                    Text("\(selected.count) selected")
                        .font(.subheadline.weight(.semibold))
                    Text(ByteFormatting.string(cacheViewModel.selectedTotalBytes))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if cautionCount > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.red)
                    Text("\(cautionCount) caution")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            Spacer()

            Button("Deselect All") {
                cacheViewModel.deselectAll()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Button("Copy Commands") {
                let commands = cacheViewModel.cleanupCommands().joined(separator: "\n")
                Clipboard.copy(commands)
                lastCopiedCommand = commands
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Button {
                executionRequest = cacheViewModel.executionRequest()
            } label: {
                Label("Clean Selected", systemImage: "trash")
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .controlSize(.small)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) { Divider() }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Cache Cleanup")
                .font(.largeTitle.weight(.semibold))

            HStack(spacing: 4) {
                Image(systemName: "exclamationmark.shield.fill")
                    .foregroundStyle(.orange)
                Text("All deletions require multiple confirmations. Nothing runs without your explicit consent.")
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Scan Bar

    private var scanBar: some View {
        HStack(spacing: 12) {
            Button {
                Task { await cacheViewModel.scan() }
            } label: {
                Label(cacheViewModel.isScanning ? "Scanning..." : "Scan Caches", systemImage: "magnifyingglass")
                    .font(.body.weight(.semibold))
            }
            .buttonStyle(.borderedProminent)
            .disabled(cacheViewModel.isScanning)

            if cacheViewModel.isScanning {
                ProgressView()
                    .controlSize(.small)
                Text("Scanning system caches...")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if let report = cacheViewModel.report {
                Text("\(report.entries.count) items found · \(ByteFormatting.string(report.totalBytes)) total")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if lastCopiedCommand != nil {
                Label("Copied", systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.green)
            }
        }
        .padding(14)
        .background(panelFill)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Safe to Clean Hero

    private var safeToCleanHero: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Safe to Clean Now")
                    .font(.headline)
                    .foregroundStyle(.green)
                Text(ByteFormatting.string(cacheViewModel.safeTotalBytes))
                    .font(.system(.largeTitle, design: .rounded).weight(.bold))
                    .animation(.easeInOut(duration: 0.4), value: cacheViewModel.safeTotalBytes)
                Text("\(cacheViewModel.safeEntryCount) items ready for cleanup")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if !cacheViewModel.topOffenders.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Top Offenders")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    ForEach(cacheViewModel.topOffenders) { entry in
                        HStack(spacing: 6) {
                            Text(entry.name)
                                .font(.caption)
                                .lineLimit(1)
                                .truncationMode(.middle)
                                .frame(maxWidth: 160, alignment: .leading)
                            Text(ByteFormatting.string(entry.sizeBytes))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(entry.sizeBytes > 1024 * 1024 * 1024 ? .red : .orange)
                        }
                    }
                }
                .padding(10)
                .background(Color.orange.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            Button {
                cacheViewModel.selectAllSafe()
            } label: {
                Label("Select All Safe", systemImage: "checkmark.circle")
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
            .controlSize(.small)
        }
        .padding(16)
        .background(Color.green.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.green.opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - Summary Cards

    private var summaryCards: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 200), spacing: 12)], spacing: 12) {
            ForEach(CacheCategory.allCases) { category in
                categorySummaryCard(category)
            }
        }
    }

    private func categorySummaryCard(_ category: CacheCategory) -> some View {
        let total = cacheViewModel.categoryTotal(category)
        let count = cacheViewModel.categoryCount(category)
        let tint = categoryTint(category)

        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: category.icon)
                    .foregroundStyle(tint)
                Text(category.displayName)
                    .font(.caption.weight(.semibold))
                Spacer()
            }

            if count > 0 {
                Text(ByteFormatting.string(total))
                    .font(.headline)
                Text("\(count) items")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("None found")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(panelFill)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(tint.opacity(count > 0 ? 0.25 : 0.08), lineWidth: 1)
        )
    }

    // MARK: - Category List

    private func categoryList(report: CacheScanReport) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(CacheCategory.allCases) { category in
                let entries = cacheViewModel.entries(for: category)
                if !entries.isEmpty {
                    categorySection(category, entries: entries)
                }
            }
        }
    }

    private func categorySection(_ category: CacheCategory, entries: [CacheEntry]) -> some View {
        let isExpanded = expandedCategories.contains(category)
        let tint = categoryTint(category)
        let total = entries.reduce(UInt64(0)) { $0 + $1.sizeBytes }

        return VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    if expandedCategories.contains(category) {
                        expandedCategories.remove(category)
                    } else {
                        expandedCategories.insert(category)
                    }
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 12)

                    Image(systemName: category.icon)
                        .foregroundStyle(tint)
                        .frame(width: 20)

                    Text(category.displayName)
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Spacer()

                    Text("\(entries.count) items · \(ByteFormatting.string(total))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Button("Select All") { cacheViewModel.selectAll(for: category) }
                        .buttonStyle(.bordered)
                        .controlSize(.mini)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
            }
            .buttonStyle(.plain)

            if isExpanded {
                Divider().padding(.horizontal, 14)

                VStack(alignment: .leading, spacing: 4) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(category.description)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                        HStack(spacing: 4) {
                            Image(systemName: "info.circle")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text("If deleted: \(category.whatBreaksIfDeleted)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        if category.willRegenerate {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.clockwise")
                                    .font(.caption2)
                                    .foregroundStyle(.green)
                                Text("Auto-regenerates")
                                    .font(.caption2)
                                    .foregroundStyle(.green)
                            }
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.top, 8)

                    ForEach(entries) { entry in
                        cacheEntryRow(entry, tint: tint)
                        if entry.id != entries.last?.id {
                            Divider().padding(.horizontal, 46)
                        }
                    }
                }
                .padding(.bottom, 12)
            }
        }
        .background(panelFill)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(tint.opacity(0.15), lineWidth: 1)
        )
    }

    private func cacheEntryRow(_ entry: CacheEntry, tint: Color) -> some View {
        let isSelected = cacheViewModel.selectedPaths.contains(entry.path)

        return HStack(spacing: 10) {
            Button {
                cacheViewModel.toggleSelection(entry)
            } label: {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? tint : .secondary)
                    .font(.title3)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(entry.name)
                        .font(.subheadline.weight(.medium))
                    riskBadge(entry.riskLevel)
                }
                Text(entry.path)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(entry.itemDescription)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }

            Spacer()

            Text(ByteFormatting.string(entry.sizeBytes))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(entry.sizeBytes > 500 * 1024 * 1024 ? .red : .primary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(isSelected ? tint.opacity(0.06) : Color.clear)
    }

    private func riskBadge(_ risk: CacheRiskLevel) -> some View {
        let (text, color): (String, Color) = {
            switch risk {
            case .safe: return ("Safe", .green)
            case .moderate: return ("Moderate", .orange)
            case .caution: return ("Caution", .red)
            }
        }()

        return Text(text)
            .font(.system(.caption2, design: .rounded).weight(.semibold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(Capsule())
            .help(risk.deletionImpactSummary)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        Button {
            Task { await cacheViewModel.scan() }
        } label: {
            VStack(spacing: 18) {
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.08))
                        .frame(width: 80, height: 80)
                    Image(systemName: "archivebox.circle.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(.blue.opacity(0.6))
                }

                VStack(spacing: 6) {
                    Text("Scan your system caches")
                        .font(.title3.weight(.semibold))
                    Text("Finds cleanable caches across ~/Library, Xcode, npm, pip, Homebrew, browsers, and more.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 380)
                }

                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.caption.weight(.semibold))
                    Text("Click to scan")
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

    // MARK: - Skeleton Loading

    private var skeletonLoading: some View {
        VStack(spacing: 12) {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 200), spacing: 12)], spacing: 12) {
                ForEach(0..<4, id: \.self) { _ in
                    SkeletonCard(height: 80)
                }
            }
            ForEach(0..<3, id: \.self) { _ in
                VStack(spacing: 0) {
                    SkeletonRow()
                    Divider()
                    SkeletonRow()
                    Divider()
                    SkeletonRow()
                }
                .background(.thinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    // MARK: - Helpers

    private var panelFill: some ShapeStyle {
        .thinMaterial
    }

    private func categoryTint(_ category: CacheCategory) -> Color {
        switch category {
        case .appCaches: return .blue
        case .systemLogs: return .gray
        case .xcodeData: return .cyan
        case .packageManager: return .green
        case .browserData: return .orange
        case .containerData: return .purple
        case .temporaryFiles: return .pink
        case .languageFiles: return .indigo
        case .mailAttachments: return .mint
        case .iOSBackups: return .teal
        case .brokenPreferences: return .brown
        }
    }
}
