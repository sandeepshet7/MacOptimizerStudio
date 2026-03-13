import Combine
import Foundation

@MainActor
public final class MemoryViewModel: ObservableObject {
    @Published public private(set) var snapshot: MemorySnapshot?
    @Published public private(set) var previousSnapshot: MemorySnapshot?
    @Published public private(set) var isPaused = false
    @Published public var topCount: Int = 20
    @Published public private(set) var growingPIDs: Set<Int32> = []

    private let service: MemoryMonitorService
    private var timer: Timer?
    private var rssHistory: [Int32: [UInt64]] = [:]
    private let historyDepth = 6

    public init(service: MemoryMonitorService = MemoryMonitorService()) {
        self.service = service
    }

    public func startPolling(interval: TimeInterval = 3.0) {
        guard timer == nil else { return }
        refreshNow()

        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, !self.isPaused else { return }
                self.refreshNow()
            }
        }
    }

    public func stopPolling() {
        timer?.invalidate()
        timer = nil
    }

    public func togglePaused() {
        isPaused.toggle()
    }

    public func refreshNow() {
        let svc = service
        let top = topCount
        Task {
            let newSnapshot = await Task.detached(priority: .userInitiated) {
                svc.captureSnapshot(topCount: top)
            }.value
            previousSnapshot = snapshot
            snapshot = newSnapshot
            updateRSSHistory()
        }
    }

    public func isGrowing(pid: Int32) -> Bool {
        growingPIDs.contains(pid)
    }

    private func updateRSSHistory() {
        guard let processes = snapshot?.processes else { return }

        let activePIDs = Set(processes.map(\.pid))
        rssHistory = rssHistory.filter { activePIDs.contains($0.key) }

        for process in processes {
            var history = rssHistory[process.pid] ?? []
            history.append(process.rssBytes)
            if history.count > historyDepth {
                history.removeFirst(history.count - historyDepth)
            }
            rssHistory[process.pid] = history
        }

        var growing = Set<Int32>()
        for (pid, history) in rssHistory {
            if history.count >= 5 {
                let tail = history.suffix(5)
                let isMonotonicallyIncreasing = zip(tail, tail.dropFirst()).allSatisfy { $0 < $1 }
                if isMonotonicallyIncreasing {
                    growing.insert(pid)
                }
            }
        }
        growingPIDs = growing
    }
}
