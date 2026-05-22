//
// LexerIntegrationTests.swift — the lexer/decoder run against the REAL family.ged fixture.
//
// Unit tests above pin down individual line shapes; this is the end-to-end E1 gate: the actual
// 18k-line database must decode as UTF-8 and tokenize with zero error-severity diagnostics. It
// also counts INDI/FAM record lines at the LEXER level (2,000 / 594) — the same counts E2 will
// re-assert through the tree, so a discrepancy localizes the bug to lexer vs. tree.
//
// NOTE ON THE COUNTS: 2,000 / 594 reflect the current fixture copy. The source DB is regenerated
// periodically, so if family.ged is re-copied these numbers may shift; update them here and in
// the E2 tree test together. (See CLAUDE.md.)
//

import XCTest
@testable import GedcomKit

final class LexerIntegrationTests: XCTestCase {

    /// Load the bundled real fixture's raw bytes.
    private func loadFixtureData() throws -> Data {
        let url = try XCTUnwrap(
            Bundle.module.url(forResource: "family", withExtension: "ged", subdirectory: "Fixtures"),
            "family.ged fixture missing from test bundle.")
        return try Data(contentsOf: url)
    }

    func testDecodesAndLexesEntireRealFileWithoutErrors() throws {
        let data = try loadFixtureData()

        // Decode: the real file declares (and is) UTF-8, so this must be clean.
        let decoded = GedcomByteDecoder.decode(data)
        XCTAssertEqual(decoded.encoding, .utf8)
        XCTAssertEqual(decoded.diagnostics, [], "Real family.ged should decode cleanly as UTF-8.")

        // Lex: no line in the real file should be malformed.
        let result = GedcomLexer.lex(decoded.text)
        let errors = result.diagnostics.filter { $0.severity == .error }
        XCTAssertEqual(errors, [], "family.ged should lex with no error diagnostics; got: \(errors)")

        // Record-line counts at the lexer level (the E1 numeric gate).
        let level0 = result.lines.filter { $0.level == 0 }
        XCTAssertEqual(level0.filter { $0.tag == "INDI" }.count, 2000, "Expected 2,000 INDI record lines.")
        XCTAssertEqual(level0.filter { $0.tag == "FAM" }.count, 594, "Expected 594 FAM record lines.")

        // The structural bookends must be present exactly once.
        XCTAssertEqual(result.lines.filter { $0.level == 0 && $0.tag == "HEAD" }.count, 1)
        XCTAssertEqual(result.lines.filter { $0.level == 0 && $0.tag == "TRLR" }.count, 1)

        // Every INDI/FAM record line must actually define an xref (e.g. @I001@) — proving the
        // xref field is being parsed across the whole file, not just in the unit tests.
        for line in level0 where line.tag == "INDI" || line.tag == "FAM" {
            XCTAssertNotNil(line.xref, "Record line at \(line.lineNumber) should define an xref.")
        }
    }
}
