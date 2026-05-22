//
// SystemTests.swift — end-to-end parsing of the third-party public GEDCOM corpus.
//
// Unlike the unit/integration tests (which target family.ged and synthetic inputs), these load
// real, varied files from SystemFixtures/ (see that folder's README for provenance) and assert the
// engine handles each WITHOUT CRASHING and produces sane structure. They're the broad
// "does it cope with files we didn't write?" net: different versions, encodings, and line endings.
//

import XCTest
@testable import GedcomKit

final class SystemTests: XCTestCase {

    private func loadSystemFixture(_ name: String) throws -> GedcomDocument {
        let url = try XCTUnwrap(
            Bundle.module.url(forResource: name, withExtension: "ged", subdirectory: "SystemFixtures"),
            "\(name).ged missing from SystemFixtures.")
        return GedcomDocument.load(try Data(contentsOf: url))
    }

    private func errorCount(_ doc: GedcomDocument) -> Int {
        doc.diagnostics.filter { $0.severity == .error }.count
    }

    /// The smallest valid GEDCOM 7.0 file: just HEAD + TRLR. Detects version, no records, no errors.
    func testMinimal70() throws {
        let doc = try loadSystemFixture("minimal70")
        XCTAssertEqual(doc.gedcomVersion, "7.0")
        XCTAssertEqual(doc.individuals.count, 0)
        XCTAssertEqual(doc.families.count, 0)
        XCTAssertEqual(errorCount(doc), 0)
    }

    /// A broad GEDCOM 7.0 file that begins with a UTF-8 BOM — exercises BOM stripping + 7.0 parsing.
    func testMaximal70WithBOM() throws {
        let doc = try loadSystemFixture("maximal70")
        XCTAssertEqual(doc.encoding, .utf8)              // BOM detected as UTF-8
        XCTAssertEqual(doc.gedcomVersion, "7.0")
        XCTAssertEqual(doc.individuals.count, 4)
        XCTAssertEqual(doc.families.count, 2)
        XCTAssertEqual(errorCount(doc), 0, "maximal70 should parse without errors; got: \(doc.diagnostics)")
    }

    /// royal92: a large ANSEL-encoded 5.5 file. Exercises the ANSEL decode path (Latin-1 fallback +
    /// one warning) and a big connected graph. Structure (ASCII) parses fully despite ANSEL.
    func testRoyal92Ansel() throws {
        let doc = try loadSystemFixture("royal92")
        XCTAssertEqual(doc.encoding, .ansel)
        XCTAssertEqual(doc.individuals.count, 3010)
        XCTAssertEqual(doc.families.count, 1422)
        // Exactly one ANSEL-fallback warning is expected from the decoder.
        XCTAssertEqual(doc.diagnostics.filter { $0.severity == .warning && $0.message.uppercased().contains("ANSEL") }.count, 1)

        // The relationship engine works on it: Queen Victoria connects to many relatives.
        let index = RelationshipIndex.build(from: doc)
        print("ROYAL92: errors=\(errorCount(doc)) indi=\(doc.individuals.count) fam=\(doc.families.count)")
        XCTAssertFalse(index.parentsOf.isEmpty, "royal92 should yield a populated relationship graph.")
    }

    /// TGC551: the GEDCOM 5.5 torture test, with classic-Mac CR-only line endings. The key assertion
    /// is that CR endings tokenize correctly (the whole file is NOT one giant line) and individuals
    /// are projected. The torture test packs many tags; we just require it parses sanely.
    func testTGC551CROnlyLineEndings() throws {
        let doc = try loadSystemFixture("TGC551")
        // If CR normalization failed, there'd be ~1 record; instead we get the real structure.
        XCTAssertGreaterThan(doc.tree.records.count, 5, "CR-only file must split into many records.")
        XCTAssertGreaterThanOrEqual(doc.individuals.count, 1)
        print("TGC551: version=\(doc.gedcomVersion ?? "?") records=\(doc.tree.records.count) indi=\(doc.individuals.count) fam=\(doc.families.count) errors=\(errorCount(doc))")
    }
}
