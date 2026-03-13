import Combine
import Foundation

@MainActor
public final class NetworkViewModel: ObservableObject {
    @Published public private(set) var snapshot: NetworkSnapshot?
    @Published public private(set) var connections: [NetworkConnection] = []
    @Published public private(set) var isLoading = false
    @Published public private(set) var history: [(Date, Double, Double)] = []

    private let service: NetworkMonitorService
    private var timer: Timer?
    private var previousBytesIn: UInt64 = 0
    private var previousBytesOut: UInt64 = 0
    private var previousTime: Date?
    private let maxHistoryPoints = 60

    public init(service: NetworkMonitorService = NetworkMonitorService()) {
        self.service = service
    }

    public func startPolling(interval: TimeInterval = 2.0) {
        guard timer == nil else { return }
        refresh()

        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.refresh()
            }
        }
    }

    public func stopPolling() {
        timer?.invalidate()
        timer = nil
    }

    public func refresh() {
        let svc = service
        let prevIn = previousBytesIn
        let prevOut = previousBytesOut
        let prevTime = previousTime

        isLoading = snapshot == nil

        Task {
            let newSnapshot = await Task.detached(priority: .userInitiated) {
                svc.captureSnapshot(previousBytesIn: prevIn, previousBytesOut: prevOut, previousTime: prevTime)
            }.value

            let newConnections = await Task.detached(priority: .userInitiated) {
                svc.getActiveConnections()
            }.value

            self.previousBytesIn = newSnapshot.bytesIn
            self.previousBytesOut = newSnapshot.bytesOut
            self.previousTime = newSnapshot.capturedAt
            self.snapshot = newSnapshot
            self.connections = newConnections
            self.isLoading = false

            // Only add to history once we have rate data (skip first sample)
            if prevTime != nil {
                self.history.append((newSnapshot.capturedAt, newSnapshot.bytesInPerSec, newSnapshot.bytesOutPerSec))
                if self.history.count > self.maxHistoryPoints {
                    self.history.removeFirst(self.history.count - self.maxHistoryPoints)
                }
            }
        }
    }

    // MARK: - Computed

    public var downloadSpeedFormatted: String {
        guard let s = snapshot else { return "--" }
        return formatSpeed(s.bytesInPerSec)
    }

    public var uploadSpeedFormatted: String {
        guard let s = snapshot else { return "--" }
        return formatSpeed(s.bytesOutPerSec)
    }

    private func formatSpeed(_ bytesPerSec: Double) -> String {
        if bytesPerSec < 1024 {
            return String(format: "%.0f B/s", bytesPerSec)
        } else if bytesPerSec < 1024 * 1024 {
            return String(format: "%.1f KB/s", bytesPerSec / 1024)
        } else if bytesPerSec < 1024 * 1024 * 1024 {
            return String(format: "%.2f MB/s", bytesPerSec / (1024 * 1024))
        } else {
            return String(format: "%.2f GB/s", bytesPerSec / (1024 * 1024 * 1024))
        }
    }
}
