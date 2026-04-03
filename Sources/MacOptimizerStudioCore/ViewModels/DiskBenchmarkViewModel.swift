import Combine
import Foundation

@MainActor
public final class DiskBenchmarkViewModel: ObservableObject {
    @Published public private(set) var result: BenchmarkResult?
    @Published public private(set) var isRunning = false
    @Published public private(set) var progress: BenchmarkProgress?

    private let service: DiskBenchmarkService

    public init(service: DiskBenchmarkService = DiskBenchmarkService()) {
        self.service = service
    }

    public func runBenchmark(at path: String, fileSizeMB: Int = 256) async {
        guard !isRunning else { return }
        isRunning = true
        progress = BenchmarkProgress(phase: "Preparing", percent: 0)

        let svc = service
        let stream = AsyncStream<BenchmarkProgress> { continuation in
            Task.detached {
                let benchResult = await svc.runBenchmark(at: path, fileSizeMB: fileSizeMB) { prog in
                    continuation.yield(prog)
                }
                continuation.yield(BenchmarkProgress(phase: "Complete", percent: 1.0))
                continuation.finish()
                await MainActor.run {
                    self.result = benchResult
                    self.isRunning = false
                }
            }
        }

        for await prog in stream {
            progress = prog
        }
    }
}
