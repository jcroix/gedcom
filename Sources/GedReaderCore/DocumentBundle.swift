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

/// The result of loading a GEDCOM file: the parsed document plus its relationship index.
public struct DocumentBundle: Sendable {
    public let document: GedcomDocument
    public let index: RelationshipIndex

    public init(document: GedcomDocument, index: RelationshipIndex) {
        self.document = document
        self.index = index
    }

    /// Parse `data` and build the relationship index. Pure and side-effect-free, so it's safe to
    /// run on a background task. Never throws — the engine degrades malformed input into diagnostics.
    public static func build(from data: Data) -> DocumentBundle {
        let document = GedcomDocument.load(data)
        return DocumentBundle(document: document, index: RelationshipIndex.build(from: document))
    }
}
