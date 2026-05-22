//
// DocumentTests.swift — GedcomDocument orchestration (parse text -> typed projections).
//

import XCTest
@testable import GedcomKit

final class DocumentTests: XCTestCase {

    /// Tracer: parsing a small document populates the individual/family dictionaries (keyed by
    /// xref), detects the GEDCOM version, and surfaces no errors.
    func testParsesDocumentIntoTypedRecords() {
        let doc = GedcomDocument.parse("""
        0 HEAD
        1 GEDC
        2 VERS 5.5.1
        0 @I1@ INDI
        1 NAME John /Crox/
        0 @I2@ INDI
        1 NAME Jane /Doe/
        0 @F1@ FAM
        1 HUSB @I1@
        1 WIFE @I2@
        0 TRLR
        """)

        XCTAssertEqual(doc.gedcomVersion, "5.5.1")
        XCTAssertEqual(doc.individuals.count, 2)
        XCTAssertEqual(doc.families.count, 1)
        XCTAssertEqual(doc.individuals[Xref("@I1@")]?.displayName, "John Crox")
        XCTAssertEqual(doc.families[Xref("@F1@")]?.husband, Xref("@I1@"))
        XCTAssertEqual(doc.diagnostics.filter { $0.severity == .error }, [])
    }

    /// File-ordered accessors return projections in the file's record order.
    func testAllIndividualsInFileOrder() {
        let doc = GedcomDocument.parse("""
        0 @I2@ INDI
        1 NAME Second /Person/
        0 @I1@ INDI
        1 NAME First /Person/
        """)
        XCTAssertEqual(doc.allIndividuals.map(\.id), [Xref("@I2@"), Xref("@I1@")])
    }
}
