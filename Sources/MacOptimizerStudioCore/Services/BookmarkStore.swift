import Foundation

public final class BookmarkStore {
    private let defaults: UserDefaults
    private let storageKey = "scan_root_bookmarks"

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func loadRoots() -> [URL] {
        guard let bookmarkData = defaults.array(forKey: storageKey) as? [Data] else {
            return []
        }

        var urls: [URL] = []
        for data in bookmarkData {
            var stale = false
            do {
                let url = try URL(
                    resolvingBookmarkData: data,
                    options: [.withSecurityScope],
                    relativeTo: nil,
                    bookmarkDataIsStale: &stale
                )
                urls.append(url)
            } catch {
                continue
            }
        }

        return urls
    }

    public func saveRoots(_ roots: [URL]) {
        let encoded = roots.compactMap { url -> Data? in
            try? url.bookmarkData(
                options: [.withSecurityScope],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
        }
        defaults.set(encoded, forKey: storageKey)
    }
}
