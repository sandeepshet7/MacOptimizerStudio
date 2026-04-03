import MacOptimizerStudioCore
import SwiftUI

struct UpdaterView: View {
    @EnvironmentObject private var updaterViewModel: UpdaterViewModel
    @EnvironmentObject private var toastManager: ToastManager

    @State private var pendingUpdateAll = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                if !updaterViewModel.isBrewInstalled {
                    brewNotInstalledState
                } else if updaterViewModel.isChecking {
                    loadingState
                } else if updaterViewModel.hasChecked && updaterViewModel.outdatedApps.isEmpty {
                    upToDateState
                } else if !updaterViewModel.outdatedApps.isEmpty {
                    summaryCards
                    outdatedList
                } else {
                    emptyState
                }

                brewNote
            }
            .padding(20)
            .frame(maxWidth: 1200)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .sheet(isPresented: $pendingUpdateAll) {
            updateAllSheet
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Updater")
                        .font(.largeTitle.weight(.bold))
                    Text("Check for outdated apps installed via Homebrew and update them.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if updaterViewModel.isUpdating {
                    HStack(spacing: 8) {
                        ProgressView()
                            .controlSize(.small)
                        Text(updaterViewModel.updateProgress ?? "Updating...")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                Button {
                    Task { await updaterViewModel.checkForUpdates() }
                } label: {
                    Label(updaterViewModel.isChecking ? "Checking..." : "Check for Updates", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                .disabled(updaterViewModel.isChecking || updaterViewModel.isUpdating)
            }
        }
    }

    // MARK: - Summary Cards

    private var summaryCards: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 12)], spacing: 12) {
            StatCard(
                icon: "exclamationmark.arrow.circlepath",
                title: "Outdated",
                value: "\(updaterViewModel.outdatedCount)",
                tint: .orange
            )
            StatCard(
                icon: "shippingbox.fill",
                title: "Formulae",
                value: "\(updaterViewModel.outdatedApps.filter { $0.isHomebrew }.count)",
                tint: .blue
            )
        }
    }

    // MARK: - Outdated List

    private var outdatedList: some View {
        StyledCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    CardSectionHeader(icon: "arrow.down.circle.fill", title: "Outdated Packages", color: .orange)
                    Text("\(updaterViewModel.outdatedCount)")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.orange.opacity(0.15))
                        .foregroundStyle(.orange)
                        .clipShape(Capsule())
                    Spacer()

                    Button {
                        pendingUpdateAll = true
                    } label: {
                        Label("Update All", systemImage: "arrow.down.circle.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                    .disabled(updaterViewModel.isUpdating)
                }

                Divider()

                VStack(spacing: 0) {
                    outdatedHeader
                    Divider()
                    ForEach(updaterViewModel.outdatedApps) { app in
                        outdatedRow(app)
                        Divider()
                    }
                }
            }
        }
    }

    private var outdatedHeader: some View {
        HStack(spacing: 0) {
            Text("Package").frame(maxWidth: .infinity, alignment: .leading)
            Text("Current").frame(width: 140, alignment: .leading)
            Text("Latest").frame(width: 140, alignment: .leading)
            Text("Actions").frame(width: 100, alignment: .center)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)
        .padding(.vertical, 6)
    }

    private func outdatedRow(_ app: OutdatedApp) -> some View {
        HStack(spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: "shippingbox.fill")
                    .foregroundStyle(.orange.opacity(0.7))
                    .font(.caption)
                Text(app.name)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(app.currentVersion)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .frame(width: 140, alignment: .leading)

            Text(app.latestVersion)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.green)
                .lineLimit(1)
                .frame(width: 140, alignment: .leading)

            Button {
                Task {
                    let result = await updaterViewModel.updateApp(app)
                    toastManager.show(
                        result.success ? "Updated \(app.name)" : "Failed to update \(app.name)",
                        isError: !result.success
                    )
                }
            } label: {
                Label("Update", systemImage: "arrow.down.circle")
                    .font(.caption)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .tint(.orange)
            .disabled(updaterViewModel.isUpdating)
            .frame(width: 100, alignment: .center)
        }
        .font(.subheadline)
        .padding(.vertical, 4)
    }

    // MARK: - States

    private var brewNotInstalledState: some View {
        StyledCard {
            VStack(spacing: 18) {
                ZStack {
                    Circle()
                        .fill(Color.secondary.opacity(0.08))
                        .frame(width: 80, height: 80)
                    Image(systemName: "mug.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(.secondary.opacity(0.6))
                }
                VStack(spacing: 6) {
                    Text("Homebrew Not Installed")
                        .font(.title3.weight(.semibold))
                    Text("Install Homebrew to check for outdated packages and manage updates.")
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

    private var loadingState: some View {
        VStack(spacing: 12) {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 12)], spacing: 12) {
                ForEach(0..<3, id: \.self) { _ in
                    SkeletonCard(height: 70)
                }
            }
            StyledCard {
                VStack(spacing: 0) {
                    SkeletonRow()
                    Divider()
                    SkeletonRow()
                    Divider()
                    SkeletonRow()
                }
            }
        }
    }

    private var upToDateState: some View {
        StyledCard {
            VStack(spacing: 18) {
                ZStack {
                    Circle()
                        .fill(Color.green.opacity(0.08))
                        .frame(width: 80, height: 80)
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(.green.opacity(0.7))
                }
                VStack(spacing: 6) {
                    Text("All Up to Date")
                        .font(.title3.weight(.semibold))
                    Text("All Homebrew packages are at their latest versions.")
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

    private var emptyState: some View {
        Button {
            Task { await updaterViewModel.checkForUpdates() }
        } label: {
            StyledCard {
                VStack(spacing: 18) {
                    ZStack {
                        Circle()
                            .fill(Color.orange.opacity(0.08))
                            .frame(width: 80, height: 80)
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.system(size: 44))
                            .foregroundStyle(.orange.opacity(0.6))
                    }
                    VStack(spacing: 6) {
                        Text("Check for Updates")
                            .font(.title3.weight(.semibold))
                        Text("Scan Homebrew for outdated formulae and casks.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 380)
                    }
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.clockwise")
                            .font(.caption.weight(.semibold))
                        Text("Click to check")
                            .font(.subheadline.weight(.medium))
                    }
                    .foregroundStyle(.orange)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 28)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Brew Note

    private var brewNote: some View {
        StyledCard {
            HStack(spacing: 8) {
                Image(systemName: "info.circle")
                    .foregroundStyle(.secondary)
                Text("Only shows apps installed via Homebrew (formulae and casks).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Update All Sheet

    private var updateAllSheet: some View {
        DoubleConfirmSheet(
            title: "Update All Packages",
            warning: "This will run `brew upgrade` to update all \(updaterViewModel.outdatedCount) outdated packages to their latest versions.\n\nThis may take several minutes depending on the number of updates.",
            confirmLabel: "Update All",
            onCancel: { pendingUpdateAll = false },
            onConfirm: {
                await updaterViewModel.updateAll()
                toastManager.show(
                    updaterViewModel.outdatedApps.isEmpty
                        ? "All packages updated successfully"
                        : "Update completed with \(updaterViewModel.outdatedCount) remaining",
                    isError: !updaterViewModel.outdatedApps.isEmpty
                )
                pendingUpdateAll = false
            }
        )
    }
}
