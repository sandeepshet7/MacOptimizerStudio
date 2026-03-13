import Foundation

public struct NetworkMonitorService: Sendable {
    public init() {}

    public func captureSnapshot(previousBytesIn: UInt64, previousBytesOut: UInt64, previousTime: Date?) -> NetworkSnapshot {
        let (totalIn, totalOut) = totalInterfaceBytes()
        let now = Date()

        var rateIn: Double = 0
        var rateOut: Double = 0

        if let prevTime = previousTime, previousBytesIn > 0 || previousBytesOut > 0 {
            let elapsed = now.timeIntervalSince(prevTime)
            if elapsed > 0 {
                let deltaIn = totalIn >= previousBytesIn ? totalIn - previousBytesIn : 0
                let deltaOut = totalOut >= previousBytesOut ? totalOut - previousBytesOut : 0
                rateIn = Double(deltaIn) / elapsed
                rateOut = Double(deltaOut) / elapsed
            }
        }

        let connections = getActiveConnections()

        return NetworkSnapshot(
            bytesIn: totalIn,
            bytesOut: totalOut,
            bytesInPerSec: rateIn,
            bytesOutPerSec: rateOut,
            capturedAt: now,
            activeConnections: connections.count
        )
    }

    public func getActiveConnections() -> [NetworkConnection] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/netstat")
        process.arguments = ["-anp", "tcp"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return []
        }

        guard process.terminationStatus == 0 else { return [] }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else { return [] }

        var connections: [NetworkConnection] = []
        let lines = output.split(separator: "\n")

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, !trimmed.hasPrefix("Active"), !trimmed.hasPrefix("Proto") else { continue }

            let fields = trimmed.split(whereSeparator: { $0 == " " || $0 == "\t" })
                .map(String.init)
            guard fields.count >= 5 else { continue }

            let proto = fields[0]
            let local = fields[3]
            let remote = fields[4]
            let state = fields.count >= 6 ? fields[5] : ""

            connections.append(NetworkConnection(
                processName: "",
                localAddress: local,
                remoteAddress: remote,
                networkProtocol: proto,
                state: state
            ))
        }

        return connections
    }

    // MARK: - Private

    private func totalInterfaceBytes() -> (UInt64, UInt64) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/netstat")
        process.arguments = ["-ib"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return (0, 0)
        }

        guard process.terminationStatus == 0 else { return (0, 0) }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else { return (0, 0) }

        var totalIn: UInt64 = 0
        var totalOut: UInt64 = 0
        let lines = output.split(separator: "\n")

        // Find header to locate Ibytes/Obytes columns
        guard let headerLine = lines.first else { return (0, 0) }
        let headers = headerLine.split(whereSeparator: { $0 == " " || $0 == "\t" })
            .map(String.init)

        guard let ibytesIdx = headers.firstIndex(of: "Ibytes"),
              let obytesIdx = headers.firstIndex(of: "Obytes") else {
            return (0, 0)
        }

        for line in lines.dropFirst() {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }

            let fields = trimmed.split(whereSeparator: { $0 == " " || $0 == "\t" })
                .map(String.init)

            // Skip loopback
            guard fields.count > max(ibytesIdx, obytesIdx),
                  !fields[0].hasPrefix("lo") else {
                continue
            }

            // Only count lines that have link-level address (contain <Link#)
            // or numeric byte counts at the expected columns
            if let inBytes = UInt64(fields[ibytesIdx]),
               let outBytes = UInt64(fields[obytesIdx]) {
                totalIn += inBytes
                totalOut += outBytes
            }
        }

        return (totalIn, totalOut)
    }
}
