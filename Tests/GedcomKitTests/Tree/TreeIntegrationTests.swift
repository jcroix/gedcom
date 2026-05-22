//
// TreeIntegrationTests.swift — the tree builder against real and synthetic fixture FILES.
//
// Two gates here:
//   * broken.ged: a hand-made file with exactly ONE dangling pointer (a FAM's CHIL points to a
//     person no record defines) — verifies the defensive "flag, don't discard" contract end to end.
//   * family.ged: the real database must build into 2,000 INDI / 594 FAM records with no error
//     diagnostics, and the custom _FSFTID tag must survive into the tree. (Counts track the
//     current fixture copy — see CLAUDE.md / the lexer integration test.)
//

import XCTest
@testable import GedcomKit

final class TreeIntegrationTests: XCTestCase {

    /// Decode + lex + build a bundled fixture file by name, returning the tree and ALL diagnostics
    /// (decode + lex + build combined, mirroring the real load pipeline).
    private func buildFixture(_ name: String) throws -> (tree: GedcomTree, diagnostics: [Diagnostic]) {
        let url = try XCTUnwrap(
            Bundle.module.url(forResource: name, withExtension: "ged", subdirectory: "Fixtures"),
            "\(name).ged missing from test bundle.")
        let decoded = GedcomByteDecoder.decode(try Data(contentsOf: url))
        let lex = GedcomLexer.lex(decoded.text)
        let built = GedcomTreeBuilder.build(from: lex.lines)
        return (built.tree, decoded.diagnostics + lex.diagnostics + built.diagnostics)
    }

    func testBrokenFixtureProducesExactlyOneDanglingReferenceError() throws {
        let (tree, diagnostics) = try buildFixture("broken")

        // The well-formed records still parse.
        XCTAssertNotNil(tree.record(for: Xref("@I1@")))
        XCTAssertNotNil(tree.record(for: Xref("@F1@")))

        // Exactly one error: the CHIL pointer to the undefined @I404@.
        let errors = diagnostics.filter { $0.severity == .error }
        XCTAssertEqual(errors.count, 1, "Expected exactly one dangling-reference error; got: \(errors)")
        XCTAssertEqual(errors.first?.message.contains("@I404@"), true)
    }

    func testRealFileBuildsExpectedRecordCountsWithNoErrors() throws {
        let (tree, diagnostics) = try buildFixture("family")

        // The E2 numeric gate, now via the TREE (not just raw lines).
        XCTAssertEqual(tree.records(tag: "INDI").count, 2000, "Expected 2,000 INDI records.")
        XCTAssertEqual(tree.records(tag: "FAM").count, 594, "Expected 594 FAM records.")

        // The real file has top-down-only relationships (no FAMC/FAMS back-pointers) and all
        // HUSB/WIFE/CHIL pointers resolve, so there should be NO error diagnostics.
        let errors = diagnostics.filter { $0.severity == .error }
        XCTAssertEqual(errors, [], "Real family.ged should build with no error diagnostics; got: \(errors)")

        // The custom _FSFTID tag must survive into the tree on at least one individual.
        let hasFSFTID = tree.records(tag: "INDI").contains { $0.firstChild(tag: "_FSFTID") != nil }
        XCTAssertTrue(hasFSFTID, "_FSFTID custom tag should be preserved on at least one INDI.")

        // The xref index covers every INDI/FAM record (lookup round-trips).
        for record in tree.records where record.tag == "INDI" || record.tag == "FAM" {
            let xref = try XCTUnwrap(record.xref)
            XCTAssertEqual(tree.record(for: xref)?.xref, xref)
        }
    }
}
