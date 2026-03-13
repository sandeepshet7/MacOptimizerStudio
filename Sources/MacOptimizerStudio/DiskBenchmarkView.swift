import MacOptimizerStudioCore
import SwiftUI

struct DiskBenchmarkView: View {
    @EnvironmentObject private var viewModel: DiskBenchmarkViewModel
    @EnvironmentObject private var toastManager: ToastManager

    @State private var selectedSizeMB = 256
    @State private var testPath: String = NSTemporaryDirectory()

    private let sizeOptions: [(String, Int)] = [
        ("128 MB", 128),
        ("256 MB", 256),
        ("512 MB", 512),
        ("1 GB", 1024),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                header
                configSection
                if viewModel.isRunning {
                    progressSection
                }
                if let result = viewModel.result {
                    speedGauges(result)
                    resultsCard(result)
                } else if !viewModel.isRunning {
                    emptyState
                }
            }
            .padding(16)
            .frame(maxWidth: 1180)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .task {
            if viewModel.result == nil && !viewModel.isRunning {
                await viewModel.runBenchmark(at: testPath, fileSizeMB: selectedSizeMB)
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Disk Benchmark")
                .font(.title2.weight(.bold))
            Text("Measure sequential and random disk I/O performance")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Config Section

    private var configSection: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Test File Size")
                    .font(.subheadline.weight(.medium))
                Picker("Size", selection: $selectedSizeMB) {
                    ForEach(sizeOptions, id: \.1) { option in
                        Text(option.0).tag(option.1)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 360)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Test Location")
                    .font(.subheadline.weight(.medium))
                HStack(spacing: 8) {
                    Text(testPath)
                        .font(.caption.monospaced())
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(Color.primary.opacity(0.04))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .frame(maxWidth: 300)

                    Button("Choose") {
                        pickFolder()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 6) {
                Button {
                    Task { await viewModel.runBenchmark(at: testPath, fileSizeMB: selectedSizeMB) }
                } label: {
                    HStack(spacing: 6) {
                        if viewModel.isRunning {
                            ProgressView().controlSize(.mini)
                        }
                        Text(viewModel.isRunning ? "Running..." : "Start Benchmark")
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                .controlSize(.large)
                .disabled(viewModel.isRunning)

                if viewModel.isRunning {
                    Text("Do not interrupt.")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
        }
        .padding(12)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Progress

    private var progressSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let prog = viewModel.progress {
                HStack {
                    Text(prog.phase)
                        .font(.subheadline.weight(.medium))
                    Spacer()
                    Text(String(format: "%.0f%%", prog.percent * 100))
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                ProgressView(value: prog.percent, total: 1.0)
                    .tint(.orange)
                    .animation(.easeInOut(duration: 0.3), value: prog.percent)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(12)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Speed Gauges

    private func speedGauges(_ result: BenchmarkResult) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 240), spacing: 12)], spacing: 12) {
            speedGauge(
                title: "Sequential Read",
                value: result.sequentialReadMBps,
                unit: "MB/s",
                maxValue: 8000,
                color: .blue
            )
            speedGauge(
                title: "Sequential Write",
                value: result.sequentialWriteMBps,
                unit: "MB/s",
                maxValue: 8000,
                color: .orange
            )
            if let iops = result.randomReadIOPS {
                speedGauge(
                    title: "Random Read",
                    value: iops,
                    unit: "IOPS",
                    maxValue: 500_000,
                    color: .green
                )
            }
            if let iops = result.randomWriteIOPS {
                speedGauge(
                    title: "Random Write",
                    value: iops,
                    unit: "IOPS",
                    maxValue: 500_000,
                    color: .purple
                )
            }
        }
    }

    private func speedGauge(title: String, value: Double, unit: String, maxValue: Double, color: Color) -> some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            ZStack {
                // Background arc
                Circle()
                    .trim(from: 0.15, to: 0.85)
                    .stroke(color.opacity(0.12), style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .rotationEffect(.degrees(90))

                // Value arc
                let fraction = min(value / maxValue, 1.0)
                Circle()
                    .trim(from: 0.15, to: 0.15 + 0.70 * fraction)
                    .stroke(
                        AngularGradient(
                            colors: [color.opacity(0.5), color],
                            center: .center,
                            startAngle: .degrees(0),
                            endAngle: .degrees(360)
                        ),
                        style: StrokeStyle(lineWidth: 10, lineCap: .round)
                    )
                    .rotationEffect(.degrees(90))
                    .animation(.easeOut(duration: 0.8), value: fraction)

                VStack(spacing: 2) {
                    Text(formatValue(value))
                        .font(.title2.weight(.bold).monospacedDigit())
                    Text(unit)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 120, height: 120)
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Results Card

    private func resultsCard(_ result: BenchmarkResult) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Detailed Results")
                .font(.headline)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 200), spacing: 12)], spacing: 10) {
                resultRow(label: "Sequential Read", value: String(format: "%.1f MB/s", result.sequentialReadMBps))
                resultRow(label: "Sequential Write", value: String(format: "%.1f MB/s", result.sequentialWriteMBps))
                if let iops = result.randomReadIOPS {
                    resultRow(label: "Random Read IOPS", value: formatValue(iops))
                }
                if let iops = result.randomWriteIOPS {
                    resultRow(label: "Random Write IOPS", value: formatValue(iops))
                }
                resultRow(label: "Test File Size", value: "\(result.fileSizeMB) MB")
                resultRow(label: "Test Path", value: result.testPath)
            }

            Text("Captured: \(result.capturedAt.formatted(date: .abbreviated, time: .standard))")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func resultRow(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "gauge.with.dots.needle.67percent")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text("No Benchmark Data")
                .font(.title3.weight(.semibold))
            Text("Configure your test parameters and tap \"Start Benchmark\" to measure disk performance.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    // MARK: - Helpers

    private func pickFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Choose a folder for the benchmark test file"
        panel.prompt = "Select"

        if panel.runModal() == .OK, let url = panel.url {
            testPath = url.path
        }
    }

    private func formatValue(_ value: Double) -> String {
        if value >= 1_000_000 {
            return String(format: "%.1fM", value / 1_000_000)
        } else if value >= 1_000 {
            return String(format: "%.1fK", value / 1_000)
        } else {
            return String(format: "%.1f", value)
        }
    }
}
