import Combine
import Foundation

@MainActor
public final class DiskHealthViewModel: ObservableObject {
    @Published public private(set) var snapshot: DiskHealthSnapshot?
    @Published public private(set) var isLoading = false

    private let service: DiskHealthService

    public init(service: DiskHealthService = DiskHealthService()) {
        self.service = service
    }

    public func refresh() async {
        isLoading = true
        let svc = service
        let result = await Task.detached(priority: .userInitiated) {
            svc.captureSnapshot()
        }.value
        snapshot = result
        isLoading = false
    }
}
