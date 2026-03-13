import MacOptimizerStudioCore
import SwiftUI

struct BatteryView: View {
    @EnvironmentObject private var systemHealthViewModel: SystemHealthViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header

                if let battery = systemHealthViewModel.snapshot?.battery {
                    batteryGauge(battery)
                    statsCards(battery)
                    if let thermal = systemHealthViewModel.snapshot?.thermal, thermal.hasAnyData {
                        thermalSection(thermal)
                    }
                    healthTips(battery)
                } else if systemHealthViewModel.isLoading {
                    SkeletonCard(height: 200)
                    SkeletonCard(height: 100)
                } else {
                    noBatteryState
                }
            }
            .padding(20)
            .frame(maxWidth: 1200)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .task {
            if systemHealthViewModel.snapshot == nil {
                await systemHealthViewModel.refresh()
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                Text("Battery & Thermal")
                    .font(.largeTitle.weight(.bold))
                Text("Battery health, charge status, and thermal monitoring.")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Refresh") {
                Task { await systemHealthViewModel.refresh() }
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
        }
    }

    // MARK: - Battery Gauge

    private func batteryGauge(_ battery: BatteryInfo) -> some View {
        HStack(spacing: 30) {
            // Charge gauge
            ZStack {
                RingGauge(progress: battery.chargePercent / 100, tint: chargeColor(battery), lineWidth: 14)
                    .frame(width: 140, height: 140)
                VStack(spacing: 2) {
                    Text("\(Int(battery.chargePercent))%")
                        .font(.system(.title, design: .rounded).weight(.bold))
                        .animation(.easeInOut, value: battery.chargePercent)
                    Text(battery.isCharging ? "Charging" : "On Battery")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if battery.isCharging {
                        Image(systemName: "bolt.fill")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                }
            }

            // Health gauge
            ZStack {
                RingGauge(progress: battery.healthPercent / 100, tint: healthColor(battery), lineWidth: 14)
                    .frame(width: 140, height: 140)
                VStack(spacing: 2) {
                    Text("\(Int(battery.healthPercent))%")
                        .font(.system(.title, design: .rounded).weight(.bold))
                    Text("Health")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
        .padding(20)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Stats Cards

    private func statsCards(_ battery: BatteryInfo) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 12)], spacing: 12) {
            statCard(title: "Cycle Count", value: "\(battery.cycleCount)", detail: battery.cycleCount > 800 ? "Consider service" : "Normal range", tint: battery.cycleCount > 800 ? .orange : .green)

            statCard(title: "Current Capacity", value: "\(battery.currentCapacity) mAh", detail: "of \(battery.maxCapacity) mAh max", tint: .blue)

            statCard(title: "Design Capacity", value: "\(battery.designCapacity) mAh", detail: "Original factory capacity", tint: .secondary)

            if let temp = battery.temperatureCelsius {
                statCard(title: "Temperature", value: String(format: "%.1f°C", temp), detail: temp > 35 ? "Running warm" : "Normal", tint: temp > 35 ? .orange : .green)
            }

            statCard(title: "Charge Status", value: battery.isCharging ? "Charging" : "Discharging", detail: "\(Int(battery.chargePercent))% charged", tint: battery.isCharging ? .green : .secondary)

            if battery.healthPercent < 80 {
                statCard(title: "Service", value: "Recommended", detail: "Battery health below 80%", tint: .red)
            }
        }
    }

    private func statCard(title: String, value: String, detail: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(detail)
                .font(.caption)
                .foregroundStyle(.tertiary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(tint.opacity(0.15), lineWidth: 1))
    }

    // MARK: - Thermal Section

    private func thermalSection(_ thermal: ThermalInfo) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Thermal")
                .font(.headline)

            if thermal.hasFans {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 200), spacing: 12)], spacing: 12) {
                    ForEach(thermal.fans) { fan in
                        fanCard(fan)
                    }
                }
            }

            if !thermal.hasFans {
                HStack(spacing: 8) {
                    Image(systemName: "fanblades")
                        .foregroundStyle(.secondary)
                    Text("No fans detected — this Mac may use passive cooling.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(12)
                .background(.thinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    private func fanCard(_ fan: FanInfo) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "fanblades.fill")
                    .foregroundStyle(.blue)
                Text(fan.name)
                    .font(.caption.weight(.semibold))
            }

            Text("\(fan.currentRPM) RPM")
                .font(.title3.weight(.bold))

            if let maxRPM = fan.maxRPM, maxRPM > 0 {
                let ratio = Double(fan.currentRPM) / Double(maxRPM)
                ProportionalBar(value: min(ratio, 1.0), tint: ratio > 0.8 ? .red : (ratio > 0.5 ? .orange : .blue))

                Text("\(fan.currentRPM) / \(maxRPM) RPM")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Health Tips

    private func healthTips(_ battery: BatteryInfo) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Tips")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                if battery.cycleCount > 800 {
                    tipRow(icon: "exclamationmark.triangle.fill", tint: .orange, text: "High cycle count (\(battery.cycleCount)). Battery may need replacement soon.")
                }
                if battery.healthPercent < 80 {
                    tipRow(icon: "wrench.and.screwdriver.fill", tint: .red, text: "Battery health is \(Int(battery.healthPercent))%. Apple recommends service below 80%.")
                }
                if let temp = battery.temperatureCelsius, temp > 35 {
                    tipRow(icon: "thermometer.sun.fill", tint: .orange, text: "Battery temperature is elevated. Avoid charging in hot environments.")
                }
                if battery.healthPercent >= 80 && battery.cycleCount <= 800 {
                    tipRow(icon: "checkmark.seal.fill", tint: .green, text: "Battery is in good condition. Keep charging between 20-80% for optimal longevity.")
                }
            }
            .padding(14)
            .background(.thinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private func tipRow(icon: String, tint: Color, text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(tint)
                .frame(width: 20)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - No Battery

    private var noBatteryState: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.secondary.opacity(0.08))
                    .frame(width: 80, height: 80)
                Image(systemName: "battery.0percent")
                    .font(.system(size: 32))
                    .foregroundStyle(.secondary)
            }
            Text("No Battery Detected")
                .font(.headline)
            Text("This Mac does not have a battery or battery information is unavailable.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if let thermal = systemHealthViewModel.snapshot?.thermal, thermal.hasAnyData {
                thermalSection(thermal)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    // MARK: - Helpers

    private func chargeColor(_ battery: BatteryInfo) -> Color {
        if battery.chargePercent > 50 { return .green }
        if battery.chargePercent > 20 { return .orange }
        return .red
    }

    private func healthColor(_ battery: BatteryInfo) -> Color {
        if battery.healthPercent > 80 { return .green }
        if battery.healthPercent > 60 { return .orange }
        return .red
    }
}
