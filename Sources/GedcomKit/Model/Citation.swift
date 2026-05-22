//
// Citation.swift — a SOURCE_CITATION: a reference FROM a fact/event TO a source.
//
// Citations appear nested under events, attributes, or records (e.g. `2 SOUR @S1@`). They point to
// a SOUR record (or, less commonly, carry inline source text) and refine it with a page locator
// (PAGE), a data block, and a quality assessment (QUAY 0–3). A general-purpose reader must model
// them even though family.ged has none.
//
// STUB (TDD red phase): `from(node:)` returns an empty projection; fields filled in by tests.
//

/// A projection of a SOURCE_CITATION (the `SOUR` node found UNDER a fact, not a top-level record).
public struct Citation: Equatable, Sendable {
    public let source: Xref?     // the @S1@ pointer, or nil for an inline citation
    public let page: String?     // PAGE locator, e.g. "p. 42"
    public let quality: Int?     // QUAY certainty assessment, 0...3
    public let notes: [String]
    public let node: GedcomNode

    public init(source: Xref?, page: String?, quality: Int?, notes: [String], node: GedcomNode) {
        self.source = source
        self.page = page
        self.quality = quality
        self.notes = notes
        self.node = node
    }

    /// Project a citation node (a `SOUR` node nested under a fact) into a Citation.
    public static func from(node: GedcomNode) -> Citation {
        // The citation node's own value is the @S1@ pointer for the common pointer form; an inline
        // citation has descriptive text (or nothing) there instead, so only treat @…@ as a source.
        let sourceRef = node.value.flatMap { value -> Xref? in
            (value.hasPrefix("@") && value.hasSuffix("@")) ? Xref(value) : nil
        }
        return Citation(
            source: sourceRef,
            page: node.firstValue(tag: "PAGE"),
            quality: node.firstValue(tag: "QUAY").flatMap(Int.init),
            notes: GedcomText.notes(of: node),
            node: node)
    }
}
