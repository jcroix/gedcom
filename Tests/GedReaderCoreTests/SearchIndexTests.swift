//
// SearchIndexTests.swift — name/note search behavior, scopes, and snippets.
//

import XCTest
@testable import GedReaderCore
import GedcomKit

final class SearchIndexTests: XCTestCase {

    private func index(_ text: String) -> SearchIndex {
        SearchIndex.build(from: GedcomDocument.parse(text))
    }

    private let sample = """
    0 @I1@ INDI
    1 NAME John /Crox/
    1 NOTE Worked as a carpenter in Philadelphia.
    0 @I2@ INDI
    1 NAME Jane /Smith/
    1 NOTE Emigrated from Ireland.
    """

    /// Tracer: a case-insensitive name search finds the person, with no snippet.
    func testNameSearchFindsPerson() {
        let results = index(sample).search("crox", scope: .names)
        XCTAssertEqual(results.map(\.id), [Xref("@I1@")])
        XCTAssertNil(results.first?.snippet)
    }

    /// A notes-scope search finds a person by a word that appears ONLY in their note, with a snippet.
    func testNotesSearchFindsByNoteWordWithSnippet() {
        let results = index(sample).search("carpenter", scope: .notes)
        XCTAssertEqual(results.map(\.id), [Xref("@I1@")])
        XCTAssertEqual(results.first?.snippet?.lowercased().contains("carpenter"), true)
    }

    /// Scope filters where matches come from.
    func testScopeRestrictsMatches() {
        let idx = index(sample)
        // "Smith" is a surname (name) but not in any note.
        XCTAssertEqual(idx.search("smith", scope: .names).map(\.id), [Xref("@I2@")])
        XCTAssertEqual(idx.search("smith", scope: .notes).map(\.id), [])
        // "Ireland" is only in a note.
        XCTAssertEqual(idx.search("ireland", scope: .names).map(\.id), [])
        XCTAssertEqual(idx.search("ireland", scope: .all).map(\.id), [Xref("@I2@")])
    }

    /// A blank query matches nothing (so the UI shows the full list, not everything as "results").
    func testBlankQueryReturnsNothing() {
        XCTAssertTrue(index(sample).search("   ", scope: .all).isEmpty)
    }
}
