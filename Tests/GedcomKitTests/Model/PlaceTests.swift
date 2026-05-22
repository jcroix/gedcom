//
// PlaceTests.swift — behavior of Place parsing (jurisdictions + MAP coordinates).
//

import XCTest
@testable import GedcomKit

final class PlaceTests: XCTestCase {

    /// Tracer: a comma-separated PLAC value splits into trimmed jurisdictions, finest first.
    func testSplitsCommaSeparatedJurisdictions() {
        let place = Place.parse("Philadelphia, Pennsylvania, USA")
        XCTAssertEqual(place.jurisdictions, ["Philadelphia", "Pennsylvania", "USA"])
        XCTAssertEqual(place.raw, "Philadelphia, Pennsylvania, USA")
        XCTAssertNil(place.latitude)
    }

    /// A PLAC node with a MAP child yields signed decimal coordinates (S/W negative).
    func testReadsMapCoordinatesFromNode() throws {
        let placeNode = GedcomTreeBuilder.build(from: GedcomLexer.lex("""
        0 @I1@ INDI
        1 BIRT
        2 PLAC Philadelphia, Pennsylvania
        3 MAP
        4 LATI N39.95
        4 LONG W75.16
        """).lines).tree.records[0].firstChild(tag: "BIRT")!.firstChild(tag: "PLAC")!

        let place = Place.from(node: placeNode)
        XCTAssertEqual(place.jurisdictions, ["Philadelphia", "Pennsylvania"])
        XCTAssertEqual(try XCTUnwrap(place.latitude), 39.95, accuracy: 0.001)
        XCTAssertEqual(try XCTUnwrap(place.longitude), -75.16, accuracy: 0.001)   // West => negative
    }
}
