//
// ModelIntegrationTests.swift — the full projection pipeline against the real family.ged.
//
// E3 gate: GedcomDocument.load on the real file yields 2,000 individuals / 594 families with no
// error diagnostics, detects version + encoding, and a spot-checked known person (@I001@, John
// Crox) projects the right birth/death/notes — proving date/name/event/note parsing all compose
// correctly on real data. (_FSFTID is checked through the raw node, the app's "Other Facts" path.)
//

import XCTest
@testable import GedcomKit

final class ModelIntegrationTests: XCTestCase {

    private func loadRealDocument() throws -> GedcomDocument {
        let url = try XCTUnwrap(
            Bundle.module.url(forResource: "family", withExtension: "ged", subdirectory: "Fixtures"))
        return GedcomDocument.load(try Data(contentsOf: url))
    }

    func testProjectsWholeRealFileWithExpectedCounts() throws {
        let doc = try loadRealDocument()

        XCTAssertEqual(doc.individuals.count, 2000)
        XCTAssertEqual(doc.families.count, 594)
        XCTAssertEqual(doc.gedcomVersion, "5.5.1")
        XCTAssertEqual(doc.encoding, .utf8)
        XCTAssertEqual(doc.sources.count, 0, "family.ged has no SOUR records.")
        XCTAssertEqual(doc.diagnostics.filter { $0.severity == .error }, [])
    }

    func testSpotCheckKnownPersonJohnCrox() throws {
        let doc = try loadRealDocument()
        let john = try XCTUnwrap(doc.individuals[Xref("@I001@")])

        // Name (the real malformed name degrades to a faithful display).
        XCTAssertEqual(john.displayName, "John Crox (Henry's father)")
        XCTAssertEqual(john.sex, .male)

        // Birth: ABT 1797 in New York.
        XCTAssertEqual(john.birth?.date?.qualifier, .about)
        XCTAssertEqual(john.birth?.date?.earliest, YMD(year: 1797))
        XCTAssertEqual(john.birth?.place?.jurisdictions, ["New York"])

        // Death: exact 7 MAR 1875 in Philadelphia, Pennsylvania.
        XCTAssertEqual(john.death?.date?.earliest, YMD(year: 1875, month: 3, day: 7))
        XCTAssertEqual(john.death?.place?.jurisdictions, ["Philadelphia", "Pennsylvania"])

        // Notes: two research notes, the first about the death certificate.
        XCTAssertEqual(john.notes.count, 2)
        XCTAssertTrue(john.notes[0].contains("Uremic Poisoning"))

        // The custom _FSFTID tag is preserved on the raw node (the app's "Other Facts" path).
        XCTAssertEqual(john.node.firstValue(tag: "_FSFTID"), "GSD5-72T")
    }
}
