import Darwin
import Foundation

private extension UInt64 {
    func saturatingSubtract(_ other: UInt64) -> UInt64 {
        self > other ? self - other : 0
    }
}

public final class MemoryMonitorService: Sendable {
    /// Cache the host Mach port to avoid leaking send rights on every call.
    nonisolated(unsafe) private static let hostPort: mach_port_t = mach_host_self()

    // Store previous CPU times for delta-based CPU% calculation
    private let previousCPUTimes = ManagedAtomic<[pid_t: (user: UInt64, system: UInt64, timestamp: UInt64)]>()

    public init() {}

    public func captureSnapshot(topCount: Int = 20) -> MemorySnapshot {
        let processes = topMemoryProcesses(limit: topCount)
        let (pressure, stats) = systemMemoryPressureAndStats()
        return MemorySnapshot(capturedAt: Date(), systemMemoryPressure: pressure, processes: processes, memoryStats: stats)
    }

    private func topMemoryProcesses(limit: Int) -> [ProcessMemoryEntry] {
        let maxPids = 16_384
        var pids = [pid_t](repeating: 0, count: maxPids)
        let count = proc_listallpids(&pids, Int32(MemoryLayout<pid_t>.stride * pids.count))
        guard count > 0 else {
            return []
        }

        let now = mach_absolute_time()
        var newCPUTimes: [pid_t: (user: UInt64, system: UInt64, timestamp: UInt64)] = [:]
        let prevTimes = previousCPUTimes.load() ?? [:]

        // Get timebase info for converting mach_absolute_time to nanoseconds
        var timebaseInfo = mach_timebase_info_data_t()
        mach_timebase_info(&timebaseInfo)

        // Phase 1: Collect PID + RSS + CPU times without resolving names (cheap).
        struct RawEntry {
            let pid: pid_t
            let rss: UInt64
            let cpuPercent: Double?
        }
        var rawEntries: [RawEntry] = []
        rawEntries.reserveCapacity(Int(count))

        for pid in pids.prefix(Int(count)) where pid > 0 {
            var taskInfo = proc_taskinfo()
            let taskInfoSize = MemoryLayout<proc_taskinfo>.stride
            let infoResult = proc_pidinfo(
                pid,
                PROC_PIDTASKINFO,
                UInt64(0),
                &taskInfo,
                Int32(taskInfoSize)
            )

            guard infoResult == taskInfoSize else {
                continue
            }

            let userTime = taskInfo.pti_total_user
            let systemTime = taskInfo.pti_total_system

            // Calculate CPU% from delta if we have a previous sample
            var cpuPercent: Double? = nil
            if let prev = prevTimes[pid] {
                let deltaUser = userTime.saturatingSubtract(prev.user)
                let deltaSystem = systemTime.saturatingSubtract(prev.system)
                let deltaCPUNs = deltaUser + deltaSystem
                let deltaWallNs = (now - prev.timestamp) * UInt64(timebaseInfo.numer) / UInt64(timebaseInfo.denom)
                if deltaWallNs > 0 {
                    cpuPercent = Double(deltaCPUNs) / Double(deltaWallNs) * 100.0
                }
            }

            newCPUTimes[pid] = (user: userTime, system: systemTime, timestamp: now)
            rawEntries.append(RawEntry(pid: pid, rss: UInt64(taskInfo.pti_resident_size), cpuPercent: cpuPercent))
        }

        previousCPUTimes.store(newCPUTimes)

        // Phase 2: Sort by RSS and take top N.
        rawEntries.sort { $0.rss > $1.rss }
        let topRaw = rawEntries.prefix(limit)

        // Phase 3: Resolve names only for top N entries (expensive syscalls).
        return topRaw.map { raw in
            ProcessMemoryEntry(
                pid: raw.pid,
                name: processName(pid: raw.pid),
                rssBytes: raw.rss,
                compressedBytes: nil,
                cpuPercent: raw.cpuPercent
            )
        }
    }

    private func processName(pid: pid_t) -> String {
        var nameBuffer = [CChar](repeating: 0, count: Int(MAXPATHLEN))
        let nameLength = proc_name(pid, &nameBuffer, UInt32(nameBuffer.count))
        if nameLength > 0 {
            return decodeCStringBuffer(nameBuffer)
        }

        let pathLength = proc_pidpath(pid, &nameBuffer, UInt32(nameBuffer.count))
        if pathLength > 0 {
            let fullPath = decodeCStringBuffer(nameBuffer)
            return URL(fileURLWithPath: fullPath).lastPathComponent
        }

        return "PID \(pid)"
    }

    private func systemMemoryPressureAndStats() -> (MemoryPressureLevel, SystemMemoryStats?) {
        var vmStats = vm_statistics64()
        var count = mach_msg_type_number_t(
            MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size
        )

        let result = withUnsafeMutablePointer(to: &vmStats) { pointer -> kern_return_t in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { intPointer in
                host_statistics64(Self.hostPort, HOST_VM_INFO64, intPointer, &count)
            }
        }

        guard result == KERN_SUCCESS else {
            return (.unknown, nil)
        }

        var pageSize: vm_size_t = 0
        host_page_size(Self.hostPort, &pageSize)

        let ps = UInt64(pageSize)
        let totalBytes = ProcessInfo.processInfo.physicalMemory

        let freePages = UInt64(vmStats.free_count) + UInt64(vmStats.speculative_count)
        let freeBytes = freePages * ps
        let wiredBytes = UInt64(vmStats.wire_count) * ps
        let compressedBytes = UInt64(vmStats.compressor_page_count) * ps
        let internalBytes = UInt64(vmStats.internal_page_count) * ps
        let appBytes = internalBytes.saturatingSubtract(compressedBytes)

        let usedBytes = totalBytes.saturatingSubtract(freeBytes)

        let swapUsed = swapUsedBytes()

        let stats = SystemMemoryStats(
            totalBytes: totalBytes,
            usedBytes: usedBytes,
            wiredBytes: wiredBytes,
            compressedBytes: compressedBytes,
            appBytes: appBytes,
            freeBytes: freeBytes,
            swapUsedBytes: swapUsed
        )

        guard totalBytes > 0 else { return (.unknown, stats) }
        let ratio = Double(usedBytes) / Double(totalBytes)

        let pressure: MemoryPressureLevel
        switch ratio {
        case ..<0.75:
            pressure = .normal
        case ..<0.90:
            pressure = .warning
        default:
            pressure = .critical
        }

        return (pressure, stats)
    }

    private func swapUsedBytes() -> UInt64 {
        var swapUsage = xsw_usage()
        var size = MemoryLayout<xsw_usage>.size
        let result = sysctlbyname("vm.swapusage", &swapUsage, &size, nil, 0)
        guard result == 0 else { return 0 }
        return UInt64(swapUsage.xsu_used)
    }

    private func decodeCStringBuffer(_ buffer: [CChar]) -> String {
        let utf8 = buffer.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }
        return String(decoding: utf8, as: UTF8.self)
    }
}

// Simple thread-safe wrapper for the CPU times dictionary
private final class ManagedAtomic<T>: @unchecked Sendable {
    private var value: T?
    private let lock = NSLock()

    init() {
        self.value = nil
    }

    func load() -> T? {
        lock.lock()
        defer { lock.unlock() }
        return value
    }

    func store(_ newValue: T) {
        lock.lock()
        defer { lock.unlock() }
        value = newValue
    }
}
