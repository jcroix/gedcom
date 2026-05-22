//
// SourceSystemTests.swift — projections of the source/citation subsystem (SOUR/REPO/OBJE +
// SOURCE_CITATION). The real family.ged has none of these, so these use synthetic GEDCOM.
//

import XCTest
@testable import GedcomKit

final class SourceSystemTests: XCTestCase {

    /// Build a tree from GEDCOM text and return the level-0 record with the given xref.
    private func record(_ text: String, _ xref: String) -> GedcomNode {
        GedcomTreeBuilder.build(from: GedcomLexer.lex(text).lines).tree.record(for: Xref(xref))!
    }

    func testProjectsSourceRecordFields() {
        let node = record("""
        0 @S1@ SOUR
        1 TITL Vital Records of Philadelphia
        1 AUTH City Archives
        1 PUBL 1901
        1 REPO @R1@
        1 NOTE Held on microfilm.
        """, "@S1@")

        let source = Source.from(node: node)
        XCTAssertEqual(source.id, Xref("@S1@"))
        XCTAssertEqual(source.title, "Vital Records of Philadelphia")
        XCTAssertEqual(source.author, "City Archives")
        XCTAssertEqual(source.publication, "1901")
        XCTAssertEqual(source.repository, Xref("@R1@"))
        XCTAssertEqual(source.notes, ["Held on microfilm."])
    }

    func testProjectsCitationFields() {
        // A citation node is the SOUR found UNDER a fact (here, under a BIRT).
        let citationNode = record("""
        0 @I1@ INDI
        1 BIRT
        2 SOUR @S1@
        3 PAGE p. 42, line 3
        3 QUAY 3
        3 NOTE Transcription verified.
        """, "@I1@").firstChild(tag: "BIRT")!.firstChild(tag: "SOUR")!

        let citation = Citation.from(node: citationNode)
        XCTAssertEqual(citation.source, Xref("@S1@"))
        XCTAssertEqual(citation.page, "p. 42, line 3")
        XCTAssertEqual(citation.quality, 3)
        XCTAssertEqual(citation.notes, ["Transcription verified."])
    }

    func testProjectsRepositoryFields() {
        let node = record("""
        0 @R1@ REPO
        1 NAME Philadelphia City Archives
        1 NOTE Open weekdays.
        """, "@R1@")

        let repo = Repository.from(node: node)
        XCTAssertEqual(repo.id, Xref("@R1@"))
        XCTAssertEqual(repo.name, "Philadelphia City Archives")
        XCTAssertEqual(repo.notes, ["Open weekdays."])
    }

    func testProjectsMediaObjectIncludingSevenOhNesting() {
        // 7.0-style: FORM nests under FILE. We must still find it.
        let node = record("""
        0 @M1@ OBJE
        1 FILE photos/john.jpg
        2 FORM jpg
        1 TITL John Crox portrait
        """, "@M1@")

        let media = MediaObject.from(node: node)
        XCTAssertEqual(media.id, Xref("@M1@"))
        XCTAssertEqual(media.file, "photos/john.jpg")
        XCTAssertEqual(media.format, "jpg")
        XCTAssertEqual(media.title, "John Crox portrait")
    }
}
