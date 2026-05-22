//
// EventTests.swift — behavior of GedcomEvent.from(node:): composing date/place/notes/citations.
//

import XCTest
@testable import GedcomKit

final class EventTests: XCTestCase {

    private func eventNode(_ text: String, under recordXref: String, tag: String) -> GedcomNode {
        GedcomTreeBuilder.build(from: GedcomLexer.lex(text).lines)
            .tree.record(for: Xref(recordXref))!.firstChild(tag: tag)!
    }

    /// Tracer: a BIRT with DATE, PLAC, NOTE, and a SOUR citation projects all of them via the
    /// already-tested sub-parsers (GedcomDate, Place, Citation, GedcomText).
    func testProjectsEventWithDatePlaceNotesAndCitations() {
        let birt = eventNode("""
        0 @I1@ INDI
        1 BIRT
        2 DATE ABT 1797
        2 PLAC New York
        2 NOTE Born during the war.
        2 SOUR @S1@
        3 PAGE p. 1
        """, under: "@I1@", tag: "BIRT")

        let event = GedcomEvent.from(node: birt)
        XCTAssertEqual(event.tag, "BIRT")
        XCTAssertEqual(event.date?.qualifier, .about)
        XCTAssertEqual(event.date?.earliest, YMD(year: 1797))
        XCTAssertEqual(event.place?.jurisdictions, ["New York"])
        XCTAssertEqual(event.notes, ["Born during the war."])
        XCTAssertEqual(event.citations.count, 1)
        XCTAssertEqual(event.citations.first?.source, Xref("@S1@"))
    }

    /// An attribute (OCCU) carries its value and a TYPE refinement.
    func testProjectsAttributeValueAndType() {
        let occu = eventNode("""
        0 @I1@ INDI
        1 OCCU Blacksmith
        2 TYPE trade
        """, under: "@I1@", tag: "OCCU")

        let event = GedcomEvent.from(node: occu)
        XCTAssertEqual(event.value, "Blacksmith")
        XCTAssertEqual(event.type, "trade")
        XCTAssertNil(event.date)
    }
}
