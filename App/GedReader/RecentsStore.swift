//
// RecentsStore.swift — app-wide persistence of the Open Recent list (A9).
//
// Wraps the unit-tested RecentFiles value with UserDefaults persistence and @Observable change
// tracking so the Open Recent menu updates live. One instance is owned by the app and shared with
// the commands and windows. (Paths are stored directly for v1; sandboxed bookmarks would slot in
// here later.)
//

import Foundation
import Observation
import GedReaderCore

@available(macOS 14, *)
@Observable
final class RecentsStore {
    private static let defaultsKey = "recentFiles"
    private(set) var recents: RecentFiles

    init() {
        let saved = UserDefaults.standard.stringArray(forKey: Self.defaultsKey) ?? []
        recents = RecentFiles(paths: saved)
    }

    /// Record a just-opened file and persist the updated list.
    func record(_ path: String) {
        recents.record(path)
        UserDefaults.standard.set(recents.paths, forKey: Self.defaultsKey)
    }

    /// Clear the Open Recent list.
    func clear() {
        recents = RecentFiles()
        UserDefaults.standard.removeObject(forKey: Self.defaultsKey)
    }
}
