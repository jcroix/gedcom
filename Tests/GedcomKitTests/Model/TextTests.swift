//
// TextTests.swift — behavior of GedcomText.assemble (CONT/CONC reassembly).
//

import XCTest
@testable import GedcomKit

final class TextTests: XCTestCase {

    /// Build a single record's first child node from GEDCOM text, for testing assembly.
    private func firstChildNode(_ text: String) -> GedcomNode {
        GedcomTreeBuilder.build(from: GedcomLexer.lex(text).lines).tree.records[0].children[0]
    }

    /// Tracer: a NOTE whose value continues with CONT (new line) then CONC (glued on) reassembles
    /// into one string with the line break where CONT was and no break where CONC was.
    func testAssemblesContAsNewlineAndConcAsDirectAppend() {
        let note = firstChildNode("""
        0 @I1@ INDI
        1 NOTE First line
        2 CONT Second line
        2 CONC  glued on
        """)

        XCTAssertEqual(GedcomText.assemble(from: note), "First line\nSecond line glued on")
    }
}
