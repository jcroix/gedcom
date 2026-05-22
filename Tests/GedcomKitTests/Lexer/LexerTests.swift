//
// LexerTests.swift — behavior of GedcomLexer.lex(_:).
//
// These tests describe WHAT the lexer extracts from raw text, line by line, through its public
// API only. They double as the living spec for GEDCOM line tokenization: read them to recall
// exactly how each line shape (record-defining, valued, pointer, custom tag, malformed) is
// expected to tokenize.
//

import XCTest
@testable import GedcomKit

final class LexerTests: XCTestCase {

    // MARK: Tracer bullet — the simplest possible line.

    /// "0 HEAD" is a level-0 record line with a tag and nothing else. This proves the whole
    /// path: text in, one GedcomLine out, fields populated, line number 1, no diagnostics.
    func testLexesSingleTaglineWithNoXrefOrValue() {
        let result = GedcomLexer.lex("0 HEAD")

        XCTAssertEqual(result.diagnostics, [])
        XCTAssertEqual(result.lines, [
            GedcomLine(level: 0, xref: nil, tag: "HEAD", value: nil, lineNumber: 1)
        ])
    }

    // MARK: A realistic record block — all the line shapes + blanks + numbering.

    /// One INDI record followed by a blank line and the start of the next record. This single
    /// test pins down several behaviors at once:
    ///   * record-defining line carries the xref (`@I001@`), tag, no value;
    ///   * a NAME value is kept verbatim including its `/Surname/` slashes;
    ///   * a tag with no value (BIRT) has value nil;
    ///   * a FAMC pointer lands in `value` (NOT `xref`) — it refers, it doesn't define;
    ///   * a custom `_FSFTID` tag survives untouched with its value;
    ///   * a BLANK line is skipped entirely (no token, no diagnostic) yet does not disturb the
    ///     1-based line numbers of later lines (the second INDI is line 9, not line 8).
    func testLexesRecordBlockWithBlankLineAndAllShapes() {
        let text = """
        0 @I001@ INDI
        1 NAME John /Crox/
        1 SEX M
        1 BIRT
        2 DATE ABT 1797
        1 FAMC @F1@
        1 _FSFTID L1AB-2CD

        0 @I002@ INDI
        """

        let result = GedcomLexer.lex(text)

        XCTAssertEqual(result.diagnostics, [], "A blank line between records must not produce a diagnostic.")
        XCTAssertEqual(result.lines, [
            GedcomLine(level: 0, xref: Xref("@I001@"), tag: "INDI", value: nil, lineNumber: 1),
            GedcomLine(level: 1, tag: "NAME", value: "John /Crox/", lineNumber: 2),
            GedcomLine(level: 1, tag: "SEX", value: "M", lineNumber: 3),
            GedcomLine(level: 1, tag: "BIRT", value: nil, lineNumber: 4),
            GedcomLine(level: 2, tag: "DATE", value: "ABT 1797", lineNumber: 5),
            GedcomLine(level: 1, tag: "FAMC", value: "@F1@", lineNumber: 6),
            GedcomLine(level: 1, tag: "_FSFTID", value: "L1AB-2CD", lineNumber: 7),
            // line 8 is blank → skipped
            GedcomLine(level: 0, xref: Xref("@I002@"), tag: "INDI", value: nil, lineNumber: 9),
        ])
    }

    // MARK: Defensive behavior — never throw out the file.

    /// A line whose first token isn't a non-negative integer is malformed. The lexer must skip it,
    /// record exactly one `error` diagnostic pointing at its line, and keep tokenizing the rest.
    /// This is the heart of the "degrade gracefully, never discard the file" contract.
    func testMalformedLineYieldsDiagnosticAndIsSkippedWhileNeighborsSurvive() {
        let text = """
        0 HEAD
        garbage that has no level
        0 TRLR
        """

        let result = GedcomLexer.lex(text)

        XCTAssertEqual(result.lines, [
            GedcomLine(level: 0, tag: "HEAD", value: nil, lineNumber: 1),
            GedcomLine(level: 0, tag: "TRLR", value: nil, lineNumber: 3),
        ], "Lines before and after a malformed line must still be tokenized.")

        XCTAssertEqual(result.diagnostics.count, 1)
        XCTAssertEqual(result.diagnostics.first?.severity, .error)
        XCTAssertEqual(result.diagnostics.first?.lineNumber, 2)
    }

    /// CONT (a hard line break) and CONC (a no-separator continuation) lines are tokenized like
    /// any other line — tag = CONT/CONC, value = the continued text. The lexer does NOT join them
    /// into the parent value; that assembly happens in model projection (E3), where the parent
    /// node is known. This test documents that the lexer leaves them as separate tokens.
    func testContAndConcAreTokenizedAsOrdinaryLinesNotAssembled() {
        let text = """
        1 NOTE First line of the note
        2 CONT Second line after a hard break
        2 CONC  and this is glued onto the second line
        """

        let result = GedcomLexer.lex(text)

        XCTAssertEqual(result.diagnostics, [])
        XCTAssertEqual(result.lines, [
            GedcomLine(level: 1, tag: "NOTE", value: "First line of the note", lineNumber: 1),
            GedcomLine(level: 2, tag: "CONT", value: "Second line after a hard break", lineNumber: 2),
            // Note the value preserves the leading space after "CONC " — CONC concatenation is
            // significant whitespace, so the lexer must not trim it.
            GedcomLine(level: 2, tag: "CONC", value: " and this is glued onto the second line", lineNumber: 3),
        ])
    }
}
