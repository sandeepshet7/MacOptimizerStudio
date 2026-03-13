import MacOptimizerStudioCore
import SwiftUI

struct PrivacyView: View {
    @EnvironmentObject private var privacyViewModel: PrivacyViewModel
    @EnvironmentObject private var toastManager: ToastManager

    @State private var activeTab: PrivacyTab = .cleanup
    @State private var pendingCleanup = false

    enum PrivacyTab: String, CaseIterable {
        case cleanup = "Cleanup"
        case permissions = "Permissions"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                tabPicker
                switch activeTab {
                case .cleanup: cleanupContent
                case .permissions: permissionsContent
                }
            }
            .padding(20)
            .frame(maxWidth: 1200)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .task {
            if privacyViewModel.report == nil {
                await privacyViewModel.scan()
            }
            if privacyViewModel.permissions.isEmpty && !privacyViewModel.isScanningPermissions {
                await privacyViewModel.scanPermissions()
            }
        }
        .safeAreaInset(edge: .bottom) {
            if !privacyViewModel.selectedPaths.isEmpty {
                cleanupBar
            }
        }
        .sheet(isPresented: $pendingCleanup) {
            DoubleConfirmSheet(
                title: "Clean Privacy Data",
                warning: """
                You are about to permanently delete \(privacyViewModel.selectedPaths.count) item(s).

                Total size: \(ByteFormatting.string(privacyViewModel.selectedBytes))

                This action cannot be undone. Browser caches will be rebuilt automatically, but history and cookies will be permanently lost.
                """,
                confirmLabel: "Delete Now",
                items: privacyViewModel.report?.items
                    .filter { privacyViewModel.selectedPaths.contains($0.path) }
                    .map { ($0.name, "\($0.path) — \(ByteFormatting.string($0.sizeBytes))") } ?? [],
                onCancel: { pendingCleanup = false },
                onConfirm: {
                    let result = await privacyViewModel.cleanSelected()
                    pendingCleanup = false
                    if result.success {
                        toastManager.show("Privacy cleanup completed")
                    } else {
                        toastManager.show("Cleanup had \(result.errors.count) error(s)", isError: true)
                    }
                }
            )
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Privacy")
                .font(.largeTitle.weight(.bold))
            Text("Clean browser data, manage privacy traces, and review app permissions.")
                .font(.body)
                .foregroundStyle(.secondary)
        }
    }

    private var tabPicker: some View {
        Picker("Tab", selection: $activeTab) {
            ForEach(PrivacyTab.allCases, id: \.self) { tab in
                Text(tab.rawValue).tag(tab)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .frame(maxWidth: 300)
    }

    // MARK: - Cleanup

    private var cleanupContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Button("Scan") {
                    Task { await privacyViewModel.scan() }
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                .disabled(privacyViewModel.isScanning)

                if privacyViewModel.isScanning {
                    ProgressView().controlSize(.small)
                    Text("Scanning...").font(.caption).foregroundStyle(.secondary)
                }

                Spacer()

                if let report = privacyViewModel.report {
                    Text("Total: \(ByteFormatting.string(report.totalBytes))")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.orange)
                }
            }

            if let report = privacyViewModel.report {
                ForEach(PrivacyCategory.allCases) { category in
                    let items = report.items(for: category)
                    if !items.isEmpty {
                        categorySection(category, items: items)
                    }
                }
            } else if !privacyViewModel.isScanning {
                emptyState(icon: "hand.raised.fill", title: "Privacy Scan", detail: "Scan to find browser caches, cookies, recent files, and other privacy traces.")
            } else {
                ForEach(0..<3, id: \.self) { _ in
                    SkeletonCard(height: 60)
                }
            }
        }
    }

    private func categorySection(_ category: PrivacyCategory, items: [PrivacyItem]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: category.icon)
                    .foregroundStyle(.orange)
                Text(category.displayName)
                    .font(.headline)
                Spacer()
                Text(ByteFormatting.string(privacyViewModel.report?.totalBytes(for: category) ?? 0))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                Button("Select All") {
                    privacyViewModel.selectAll(for: category)
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)
            }

            Text(category.description)
                .font(.caption)
                .foregroundStyle(.tertiary)

            VStack(spacing: 0) {
                ForEach(items) { item in
                    privacyItemRow(item)
                    Divider()
                }
            }
            .background(.thinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    private func privacyItemRow(_ item: PrivacyItem) -> some View {
        let isSelected = privacyViewModel.selectedPaths.contains(item.path)
        return HStack(spacing: 8) {
            Button {
                privacyViewModel.toggleSelection(item.path)
            } label: {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? .orange : .secondary)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 1) {
                Text(item.name)
                    .font(.subheadline)
                Text(item.path)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()

            Text("\(item.itemCount) items")
                .font(.caption)
                .foregroundStyle(.tertiary)

            Text(ByteFormatting.string(item.sizeBytes))
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    // MARK: - Cleanup Bar

    private var cleanupBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.orange)
            Text("\(privacyViewModel.selectedPaths.count) selected")
                .font(.subheadline.weight(.semibold))
            Text("(\(ByteFormatting.string(privacyViewModel.selectedBytes)))")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            Button("Deselect All") {
                privacyViewModel.deselectAll()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Button("Clean Selected") {
                pendingCleanup = true
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .controlSize(.small)
        }
        .padding(14)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.1), radius: 8, y: -2)
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    // MARK: - Permissions

    private var permissionsContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Button("Scan Permissions") {
                    Task { await privacyViewModel.scanPermissions() }
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                .disabled(privacyViewModel.isScanningPermissions)

                if privacyViewModel.isScanningPermissions {
                    ProgressView().controlSize(.small)
                }

                Spacer()

                if !privacyViewModel.permissions.isEmpty {
                    Text("\(privacyViewModel.uniqueAppCount) apps with permissions")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if !privacyViewModel.permissions.isEmpty {
                permissionsByTypeView
            } else if !privacyViewModel.isScanningPermissions {
                emptyState(icon: "lock.shield", title: "App Permissions", detail: "Scan to see which apps have access to Camera, Microphone, Location, and more.\n\nNote: May require Full Disk Access for complete results.")
            }
        }
    }

    private var permissionsByTypeView: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(PermissionType.allCases) { permType in
                let apps = privacyViewModel.permissionsByType[permType] ?? []
                if !apps.isEmpty {
                    permissionTypeSection(permType, apps: apps)
                }
            }
        }
    }

    private func permissionTypeSection(_ permType: PermissionType, apps: [AppPermission]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: permType.icon)
                    .foregroundStyle(.blue)
                Text(permType.displayName)
                    .font(.headline)
                Spacer()
                Text("\(apps.count) app(s)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 0) {
                ForEach(apps) { perm in
                    HStack {
                        Text(perm.appName)
                            .font(.subheadline)
                        Spacer()
                        HStack(spacing: 4) {
                            Circle()
                                .fill(perm.isAllowed ? .green : .red)
                                .frame(width: 6, height: 6)
                            Text(perm.isAllowed ? "Allowed" : "Denied")
                                .font(.caption)
                                .foregroundStyle(perm.isAllowed ? .green : .red)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    Divider()
                }
            }
            .background(.thinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    // MARK: - Helpers

    private func emptyState(icon: String, title: String, detail: String) -> some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.08))
                    .frame(width: 70, height: 70)
                Image(systemName: icon)
                    .font(.system(size: 28))
                    .foregroundStyle(.orange)
            }
            Text(title).font(.headline)
            Text(detail)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}
