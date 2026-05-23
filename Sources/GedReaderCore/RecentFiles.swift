//
// RecentFiles.swift — the "Open Recent" list logic (A9).
//
// A small most-recent-first list of file paths with de-duplication and a cap. The app persists it
// in UserDefaults and renders it as the File ▸ Open Recent menu; this type owns only the list
// behavior so it can be unit-tested. Paths (not bookmarks) are used for v1 simplicity; sandboxed
// security-scoped bookmarks would slot in here later without changing callers.
//
// STUB (TDD red phase): record does nothing until the test drives it.
//

public struct RecentFiles: Equatable, Sendable {
    public private(set) var paths: [String]
    public let limit: Int

    public init(paths: [String] = [], limit: Int = 10) {
        self.limit = limit
        self.paths = Array(paths.prefix(limit))
    }

    /// Record `path` as the most recently used: move it to the front, removing any earlier
    /// occurrence, and trim the list to `limit`.
    public mutating func record(_ path: String) {
        paths.removeAll { $0 == path }          // drop any earlier occurrence
        paths.insert(path, at: 0)               // newest first
        if paths.count > limit { paths.removeLast(paths.count - limit) }
    }
}
