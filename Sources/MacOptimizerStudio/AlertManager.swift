import AppKit
import Foundation
import SwiftUI

@MainActor
final class AlertManager: ObservableObject {
    @Published var lastMemoryAlert: Date?
    @Published var lastCPUAlert: Date?
    @Published var lastDiskAlert: Date?

    var toastManager: ToastManager?
    var onboardingComplete = false

    private let cooldown: TimeInterval = 300 // 5 min between repeated alerts

    func setup() {
        // Nothing needed — alerts are delivered via toast + system sound
    }

    func checkMemoryPressure(_ pressure: String, enabled: Bool) {
        guard onboardingComplete else { return }
        guard enabled, pressure == "critical" else { return }
        guard shouldAlert(last: lastMemoryAlert) else { return }
        lastMemoryAlert = Date()
        alert("Memory Pressure Critical — consider closing unused apps")
    }

    func checkCPU(highCount: Int, topName: String, enabled: Bool) {
        guard onboardingComplete else { return }
        guard enabled, highCount > 0 else { return }
        guard shouldAlert(last: lastCPUAlert) else { return }
        lastCPUAlert = Date()
        alert("\(topName) using high CPU (\(highCount) process(es) > 80%)")
    }

    func checkDisk(usagePercent: Double, enabled: Bool) {
        guard onboardingComplete else { return }
        guard enabled, usagePercent > 90 else { return }
        guard shouldAlert(last: lastDiskAlert) else { return }
        lastDiskAlert = Date()
        alert(String(format: "Disk almost full (%.0f%%) — free up space", usagePercent))
    }

    private func shouldAlert(last: Date?) -> Bool {
        guard let last else { return true }
        return Date().timeIntervalSince(last) > cooldown
    }

    private func alert(_ message: String) {
        NSSound.beep()
        toastManager?.show(message, isError: true)
    }
}
