//
// FamilyBrowsingTests.swift — ordering a family's children by birth.
//

import XCTest
@testable import GedReaderCore
import GedcomKit

final class FamilyBrowsingTests: XCTestCase {

    /// Children are returned oldest-first by birth date, with the undated child kept last.
    func testChildrenInBirthOrderWithUndatedLast() {
        let doc = GedcomDocument.parse("""
        0 @I1@ INDI
        1 NAME Dad /X/
        0 @C1@ INDI
        1 NAME Youngest /X/
        1 BIRT
        2 DATE 1890
        0 @C2@ INDI
        1 NAME Undated /X/
        0 @C3@ INDI
        1 NAME Oldest /X/
        1 BIRT
        2 DATE 1880
        0 @F1@ FAM
        1 HUSB @I1@
        1 CHIL @C1@
        1 CHIL @C2@
        1 CHIL @C3@
        """)
        let family = doc.families[Xref("@F1@")]!

        let ordered = FamilyBrowsing.childrenInBirthOrder(of: family, in: doc)
        XCTAssertEqual(ordered, [Xref("@C3@"), Xref("@C1@"), Xref("@C2@")],
                       "Oldest (1880), then 1890, then the undated child last.")
    }
}
