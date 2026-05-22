//
// NameTests.swift — behavior of PersonalName parsing.
//
// The spec for turning a GEDCOM NAME (inline `/Surname/` and/or subordinate pieces) into a
// structured, displayable name — including the defensive degrade path for the real malformed name
// "John Crox (Henry's /father)/".
//

import XCTest
@testable import GedcomKit

final class NameTests: XCTestCase {

    /// Tracer: the canonical "Given /Surname/" form splits into given + surname.
    func testParsesGivenAndSurname() {
        let name = PersonalName.parse("John /Crox/")
        XCTAssertEqual(name.given, "John")
        XCTAssertEqual(name.surname, "Crox")
        XCTAssertNil(name.suffix)
        XCTAssertEqual(name.displayName, "John Crox")
    }

    /// A suffix after the closing slash is captured; multi-word surnames (incl. "van"/"de") are
    /// kept whole between the slashes.
    func testParsesSuffixAndMultiWordSurname() {
        let name = PersonalName.parse("Dr. John /van Crox/ Jr")
        XCTAssertEqual(name.given, "Dr. John")
        XCTAssertEqual(name.surname, "van Crox")
        XCTAssertEqual(name.suffix, "Jr")
        XCTAssertEqual(name.displayName, "Dr. John van Crox Jr")
    }

    /// A name with no slashes can't delimit a surname, so it's all given/display — never crashes.
    func testParsesNameWithoutSlashesAsDisplayOnly() {
        let name = PersonalName.parse("Madonna")
        XCTAssertEqual(name.given, "Madonna")
        XCTAssertNil(name.surname)
        XCTAssertEqual(name.displayName, "Madonna")
    }

    /// The real malformed name from family.ged. The mechanical slash rule yields an odd surname,
    /// but the contract is: NO CRASH and a faithful, readable display. (This documents exactly what
    /// the parser does with it so a future change is a conscious one.)
    func testDegradesGracefullyOnRealMalformedName() {
        let name = PersonalName.parse("John Crox (Henry's /father)/")
        XCTAssertEqual(name.given, "John Crox (Henry's")
        XCTAssertEqual(name.surname, "father)")
        XCTAssertNil(name.suffix)
        XCTAssertEqual(name.displayName, "John Crox (Henry's father)")
    }

    /// Subordinate NAME pieces override the inline parse: here SURN says the surname is "Crox"
    /// even though there are no slashes in the inline value, and GIVN refines the given name.
    func testSubordinatePiecesOverrideInlineValue() {
        let nameNode = GedcomTreeBuilder.build(from: GedcomLexer.lex("""
        0 @I1@ INDI
        1 NAME John Crox
        2 GIVN John
        2 SURN Crox
        2 NSFX Jr
        2 NPFX Dr.
        """).lines).tree.record(for: Xref("@I1@"))!.firstChild(tag: "NAME")!

        let name = PersonalName.from(node: nameNode)
        XCTAssertEqual(name.prefix, "Dr.")
        XCTAssertEqual(name.given, "John")
        XCTAssertEqual(name.surname, "Crox")
        XCTAssertEqual(name.suffix, "Jr")
        XCTAssertEqual(name.displayName, "Dr. John Crox Jr")
    }
}
