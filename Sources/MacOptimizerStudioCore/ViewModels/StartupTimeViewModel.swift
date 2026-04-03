import Combine
import Foundation

@MainActor
public final class StartupTimeViewModel: ObservableObject {
    @Published public private(set) var snapshot: StartupTimeSnapshot?
    @Published public private(set) var contributors: [StartupContributor] = []
    @Published public private(set) var isLoading = false

    private let service: StartupTimeService

    public init(service: StartupTimeService = StartupTimeService()) {
        self.service = service
    }

    public func measure() async {
        isLoading = true
        let svc = service

        let result = await Task.detached(priority: .userInitiated) {
            let snap = svc.captureSnapshot()
            let contribs = svc.gatherContributors()
            return (snap, contribs)
        }.value

        snapshot = result.0
        contributors = result.1
        isLoading = false
    }
}
