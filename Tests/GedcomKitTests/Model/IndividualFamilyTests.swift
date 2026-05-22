//
// IndividualFamilyTests.swift — projections of INDI and FAM records.
//

import XCTest
@testable import GedcomKit

final class IndividualFamilyTests: XCTestCase {

    private func record(_ text: String, _ xref: String) -> GedcomNode {
        GedcomTreeBuilder.build(from: GedcomLexer.lex(text).lines).tree.record(for: Xref(xref))!
    }

    /// Tracer: an INDI projects its name, sex, birth/death events, and notes.
    func testProjectsIndividualCoreFields() {
        let node = record("""
        0 @I1@ INDI
        1 NAME John /Crox/
        1 SEX M
        1 BIRT
        2 DATE ABT 1797
        2 PLAC New York
        1 DEAT
        2 DATE 7 MAR 1875
        1 NOTE A research note.
        """, "@I1@")

        let person = Individual.from(node: node)
        XCTAssertEqual(person.id, Xref("@I1@"))
        XCTAssertEqual(person.displayName, "John Crox")
        XCTAssertEqual(person.sex, .male)
        XCTAssertEqual(person.birth?.date?.earliest, YMD(year: 1797))
        XCTAssertEqual(person.birth?.place?.jurisdictions, ["New York"])
        XCTAssertEqual(person.death?.date?.earliest, YMD(year: 1875, month: 3, day: 7))
        XCTAssertEqual(person.notes, ["A research note."])
    }

    /// FAMC/FAMS pointers are read when present (other files have them; family.ged does not).
    func testReadsFamilyPointersWhenPresent() {
        let node = record("""
        0 @I1@ INDI
        1 NAME Jane /Doe/
        1 FAMC @F1@
        1 FAMS @F2@
        """, "@I1@")

        let person = Individual.from(node: node)
        XCTAssertEqual(person.childInFamilies, [Xref("@F1@")])
        XCTAssertEqual(person.spouseInFamilies, [Xref("@F2@")])
    }

    /// Tracer: a FAM projects spouses and children IN LISTED ORDER, plus the marriage event.
    func testProjectsFamilyWithChildrenInOrder() {
        let node = record("""
        0 @F1@ FAM
        1 HUSB @I1@
        1 WIFE @I2@
        1 MARR
        2 DATE 1820
        1 CHIL @I3@
        1 CHIL @I4@
        1 CHIL @I5@
        """, "@F1@")

        let family = Family.from(node: node)
        XCTAssertEqual(family.husband, Xref("@I1@"))
        XCTAssertEqual(family.wife, Xref("@I2@"))
        XCTAssertEqual(family.children, [Xref("@I3@"), Xref("@I4@"), Xref("@I5@")])
        XCTAssertEqual(family.marriage?.date?.earliest, YMD(year: 1820))
    }
}
