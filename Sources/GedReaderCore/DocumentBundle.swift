//
// DocumentBundle.swift — everything produced by loading one GEDCOM file, ready for the UI.
//
// Loading does two heavy things off the main thread: parse the file into a GedcomDocument, and
// build the RelationshipIndex from it. Bundling them in one Sendable value lets us compute the
// whole thing on a background task and hand it to the @MainActor DocumentModel in a single hop.
//
// It's a plain composition of engine types (no new behavior), so it has no separate stub/TDD —
// it's exercised through DocumentModel's tests.
//

import Foundation
import GedcomKit

/// The result of loading a GEDCOM file: the parsed document, its relationship index, and the
/// data-quality issues — all computed up front (off-main) so the UI never blocks recomputing them.
public struct DocumentBundle: Sendable {
    public let document: GedcomDocument
    public let index: RelationshipIndex
    public let issues: [Issue]
    public let searchIndex: SearchIndex

    public init(document: GedcomDocument, index: RelationshipIndex, issues: [Issue], searchIndex: SearchIndex) {
        self.document = document
        self.index = index
        self.issues = issues
        self.searchIndex = searchIndex
    }

    /// Parse `data`, build the relationship + search indexes, and run the quality checker. Pure and
    /// side-effect-free, so it's safe to run on a background task. Never throws — the engine
    /// degrades malformed input into diagnostics.
    public static func build(from data: Data) -> DocumentBundle {
        let document = GedcomDocument.load(data)
        let index = RelationshipIndex.build(from: document)
        let issues = QualityChecker.issues(for: document, index: index)
        let searchIndex = SearchIndex.build(from: document)
        return DocumentBundle(document: document, index: index, issues: issues, searchIndex: searchIndex)
    }
}
