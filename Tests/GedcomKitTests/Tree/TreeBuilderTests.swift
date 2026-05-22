//
// TreeBuilderTests.swift — behavior of GedcomTreeBuilder (lexed lines -> lossless tree).
//
// These describe how flat lines nest into records by level, how the xref index resolves records,
// how everything (custom tags, order) is preserved, and how malformed structure (duplicate ids,
// dangling pointers) degrades into diagnostics without losing data.
//

import XCTest
@testable import GedcomKit

final class TreeBuilderTests: XCTestCase {

    /// Lex GEDCOM text and build a tree from it in one step (the common test setup).
    private func buildTree(_ text: String) -> (tree: GedcomTree, diagnostics: [Diagnostic]) {
        GedcomTreeBuilder.build(from: GedcomLexer.lex(text).lines)
    }

    // MARK: Tracer — nesting by level.

    /// One INDI record with a NAME child and a BIRT that itself contains a DATE. Proves the core
    /// behavior: level numbers become parent/child nesting, the record is top-level and keyed by
    /// its xref, and the grandchild (DATE under BIRT) nests correctly.
    func testNestsLinesByLevelIntoRecordTree() throws {
        let (tree, diagnostics) = buildTree("""
        0 @I001@ INDI
        1 NAME John /Crox/
        1 BIRT
        2 DATE ABT 1797
        """)

        XCTAssertEqual(diagnostics, [])
        XCTAssertEqual(tree.records.count, 1)

        let indi = try XCTUnwrap(tree.record(for: Xref("@I001@")))
        XCTAssertEqual(indi.tag, "INDI")
        XCTAssertEqual(indi.level, 0)
        XCTAssertEqual(indi.children.count, 2)                       // NAME and BIRT

        XCTAssertEqual(indi.firstValue(tag: "NAME"), "John /Crox/")

        let birt = try XCTUnwrap(indi.firstChild(tag: "BIRT"))
        XCTAssertNil(birt.value)                                     // BIRT itself has no value
        XCTAssertEqual(birt.firstValue(tag: "DATE"), "ABT 1797")     // the DATE nests under BIRT
    }

    // MARK: Losslessness — order + unknown/custom tags preserved.

    /// Field order is preserved exactly, and the custom `_FSFTID` tag survives as a normal node
    /// with its value intact (nothing is dropped or reordered). This is the losslessness guarantee
    /// the future writer depends on.
    func testPreservesFieldOrderAndCustomTags() throws {
        let (tree, diagnostics) = buildTree("""
        0 @I001@ INDI
        1 NAME John /Crox/
        1 SEX M
        1 _FSFTID L1AB-2CD
        1 NOTE A note
        """)

        XCTAssertEqual(diagnostics, [])
        let indi = try XCTUnwrap(tree.record(for: Xref("@I001@")))

        // Children appear in the exact source order, including the custom tag in its position.
        XCTAssertEqual(indi.children.map(\.tag), ["NAME", "SEX", "_FSFTID", "NOTE"])
        XCTAssertEqual(indi.firstValue(tag: "_FSFTID"), "L1AB-2CD")
    }

    /// A record's sourceLineRange spans from its own line through the last line of its deepest
    /// descendant — the basis for "jump to source" and the future minimal-diff writer.
    func testRecordSourceLineRangeSpansItsDescendants() throws {
        // Lines 1..4 below; the INDI starts at 1 and its deepest line (DATE) is 4.
        let (tree, _) = buildTree("""
        0 @I001@ INDI
        1 NAME John /Crox/
        1 BIRT
        2 DATE ABT 1797
        """)
        let indi = try XCTUnwrap(tree.record(for: Xref("@I001@")))
        XCTAssertEqual(indi.sourceLineRange, 1...4)

        let birt = try XCTUnwrap(indi.firstChild(tag: "BIRT"))
        XCTAssertEqual(birt.sourceLineRange, 3...4)                  // BIRT (line 3) through DATE (4)
    }

    // MARK: Defensive — malformed structure degrades into diagnostics, never data loss.

    /// Two records sharing an xref: the first definition wins, and exactly one error diagnostic is
    /// raised pointing at the duplicate.
    func testDuplicateXrefKeepsFirstAndYieldsOneError() {
        let (tree, diagnostics) = buildTree("""
        0 @I001@ INDI
        1 NAME First /Def/
        0 @I001@ INDI
        1 NAME Second /Def/
        """)

        // Index resolves to the FIRST definition.
        XCTAssertEqual(tree.record(for: Xref("@I001@"))?.firstValue(tag: "NAME"), "First /Def/")

        let errors = diagnostics.filter { $0.severity == .error }
        XCTAssertEqual(errors.count, 1)
        XCTAssertEqual(errors.first?.message.contains("@I001@"), true)
    }

    /// `@VOID@` is a valid GEDCOM 7.0 placeholder pointer meaning "intentionally nothing" — it must
    /// NOT be reported as a dangling reference even though no record defines it.
    func testVoidPointerIsNotADanglingReference() {
        let (_, diagnostics) = buildTree("""
        0 @F1@ FAM
        1 HUSB @VOID@
        1 CHIL @VOID@
        """)
        XCTAssertEqual(diagnostics.filter { $0.severity == .error }, [],
                       "@VOID@ is a deliberate GEDCOM 7.0 placeholder, not a broken reference.")
    }

    /// A pointer value (here FAMC) that references a record no one defines is a dangling reference:
    /// exactly one error diagnostic, and the rest of the tree is intact.
    func testDanglingPointerYieldsOneError() throws {
        let (tree, diagnostics) = buildTree("""
        0 @I001@ INDI
        1 NAME John /Crox/
        1 FAMC @F999@
        """)

        // The INDI itself is fine; only the pointer is bad.
        XCTAssertNotNil(tree.record(for: Xref("@I001@")))

        let errors = diagnostics.filter { $0.severity == .error }
        XCTAssertEqual(errors.count, 1)
        XCTAssertEqual(errors.first?.message.contains("@F999@"), true)
        XCTAssertEqual(errors.first?.lineNumber, 3)
    }
}
