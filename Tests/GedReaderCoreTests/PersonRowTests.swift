//
// PersonRowTests.swift — flattening individuals to display rows + birth-order sorting.
//

import XCTest
@testable import GedReaderCore
import GedcomKit

final class PersonRowTests: XCTestCase {

    private func individuals(_ text: String) -> [Individual] {
        GedcomDocument.parse(text).allIndividuals
    }

    /// Tracer: a row carries display strings and a birth sort key derived from the (approximate) date.
    func testFlattensIndividualToDisplayRow() throws {
        let person = try XCTUnwrap(individuals("""
        0 @I1@ INDI
        1 NAME John /Crox/
        1 SEX M
        1 BIRT
        2 DATE ABT 1797
        1 DEAT
        2 DATE 7 MAR 1875
        """).first)

        let row = PersonRow.from(person)
        XCTAssertEqual(row.id, Xref("@I1@"))
        XCTAssertEqual(row.name, "John Crox")
        XCTAssertEqual(row.birth, "ABT 1797")
        XCTAssertEqual(row.death, "7 MAR 1875")
        XCTAssertEqual(row.sex, "M")
        XCTAssertEqual(try XCTUnwrap(row.birthSortKey), 1797.5, accuracy: 0.01)   // ABT 1797 -> mid-year
    }

    /// Birth-order sorting interleaves approximate and exact dates correctly and puts undated last.
    func testSortsByBirthWithApproximateDatesAndUndatedLast() {
        let rows = PersonRow.all(in: GedcomDocument.parse("""
        0 @I1@ INDI
        1 NAME Late /Z/
        1 BIRT
        2 DATE 1900
        0 @I2@ INDI
        1 NAME Early /A/
        1 BIRT
        2 DATE ABT 1850
        0 @I3@ INDI
        1 NAME Undated /U/
        0 @I4@ INDI
        1 NAME Middle /M/
        1 BIRT
        2 DATE 1875
        """))

        let order = PersonRow.sortedByBirth(rows).map(\.id)
        XCTAssertEqual(order, [Xref("@I2@"), Xref("@I4@"), Xref("@I1@"), Xref("@I3@")],
                       "Expected 1850, 1875, 1900, then the undated person last.")
    }
}
