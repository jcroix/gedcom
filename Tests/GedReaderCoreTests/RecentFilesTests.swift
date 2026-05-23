//
// RecentFilesTests.swift — Open Recent list behavior (most-recent-first, dedupe, cap).
//

import XCTest
@testable import GedReaderCore

final class RecentFilesTests: XCTestCase {

    func testRecordPutsMostRecentFirst() {
        var recents = RecentFiles()
        recents.record("/a.ged")
        recents.record("/b.ged")
        XCTAssertEqual(recents.paths, ["/b.ged", "/a.ged"])
    }

    func testReRecordingMovesToFrontWithoutDuplicating() {
        var recents = RecentFiles()
        recents.record("/a.ged")
        recents.record("/b.ged")
        recents.record("/a.ged")            // touch /a again
        XCTAssertEqual(recents.paths, ["/a.ged", "/b.ged"])
    }

    func testListIsCappedAtLimit() {
        var recents = RecentFiles(limit: 2)
        recents.record("/a.ged")
        recents.record("/b.ged")
        recents.record("/c.ged")
        XCTAssertEqual(recents.paths, ["/c.ged", "/b.ged"], "Oldest is dropped past the cap.")
    }
}
