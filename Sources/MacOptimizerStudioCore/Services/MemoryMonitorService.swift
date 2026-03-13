import Darwin
import Foundation

private extension UInt64 {
    func saturatingSubtract(_ other: UInt64) -> UInt64 {
        self > other ? self - other : 0
    }
}

public struct MemoryMonitorService {
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

        let cpuPercentByPid = cpuPercentagesByPid()

        var entries: [ProcessMemoryEntry] = []
        entries.reserveCapacity(min(Int(count), limit * 4))

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

            let name = processName(pid: pid)
            let entry = ProcessMemoryEntry(
                pid: pid,
                name: name,
                rssBytes: UInt64(taskInfo.pti_resident_size),
                compressedBytes: nil,
                cpuPercent: cpuPercentByPid[pid]
            )
            entries.append(entry)
        }

        entries.sort { $0.rssBytes > $1.rssBytes }
        return Array(entries.prefix(limit))
    }

    private func cpuPercentagesByPid() -> [pid_t: Double] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/ps")
        process.arguments = ["-axo", "pid=,pcpu="]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return [:]
        }

        guard process.terminationStatus == 0 else {
            return [:]
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else {
            return [:]
        }

        var mapping: [pid_t: Double] = [:]

        for line in output.split(separator: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                continue
            }

            let fields = trimmed.split(whereSeparator: { $0 == " " || $0 == "\t" })
            guard fields.count >= 2,
                  let pid = Int32(fields[0]),
                  let cpu = Double(fields[1]) else {
                continue
            }

            mapping[pid] = cpu
        }

        return mapping
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
                host_statistics64(mach_host_self(), HOST_VM_INFO64, intPointer, &count)
            }
        }

        guard result == KERN_SUCCESS else {
            return (.unknown, nil)
        }

        var pageSize: vm_size_t = 0
        host_page_size(mach_host_self(), &pageSize)

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
