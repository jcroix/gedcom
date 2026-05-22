//
// SidebarTests.swift — which sidebar rows show, with what counts.
//

import XCTest
@testable import GedReaderCore
import GedcomKit

final class SidebarTests: XCTestCase {

    /// family.ged-shaped data (no sources/media/repos): the five core rows with counts, and the
    /// source-system rows hidden.
    func testCoreSectionsWithCountsAndSourceRowsHidden() {
        let doc = GedcomDocument.parse("""
        0 @I1@ INDI
        1 NAME A /X/
        0 @I2@ INDI
        1 NAME B /X/
        0 @F1@ FAM
        1 HUSB @I1@
        1 WIFE @I2@
        """)
        let items = Sidebar.items(for: doc, issueCount: 3)

        XCTAssertEqual(items.map(\.section),
                       [.people, .families, .charts, .relationships, .quality])
        XCTAssertEqual(items.first { $0.section == .people }?.badge, 2)
        XCTAssertEqual(items.first { $0.section == .families }?.badge, 1)
        XCTAssertEqual(items.first { $0.section == .quality }?.badge, 3)
        XCTAssertNil(items.first { $0.section == .charts }?.badge, "Charts has no count badge.")
    }

    /// When the file has SOUR/OBJE/REPO records, those rows appear with counts.
    func testSourceSystemRowsAppearWhenPresent() {
        let doc = GedcomDocument.parse("""
        0 @I1@ INDI
        1 NAME A /X/
        0 @S1@ SOUR
        1 TITL A source
        0 @R1@ REPO
        1 NAME An archive
        0 @M1@ OBJE
        1 FILE photo.jpg
        """)
        let items = Sidebar.items(for: doc, issueCount: 0)
        let sections = items.map(\.section)

        XCTAssertTrue(sections.contains(.sources))
        XCTAssertTrue(sections.contains(.media))
        XCTAssertTrue(sections.contains(.repositories))
        XCTAssertEqual(items.first { $0.section == .sources }?.badge, 1)
    }
}
