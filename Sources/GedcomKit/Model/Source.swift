//
// Source.swift — a SOUR record: a bibliographic source of genealogical evidence.
//
// The real family.ged has no SOUR records, but a general-purpose reader must model them (see the
// "parse the full standard" rule). A SOUR record typically carries a title (TITL), author (AUTH),
// publication info (PUBL), a pointer to the holding repository (REPO @R1@), and notes.
//
// STUB (TDD red phase): `from(node:)` returns an empty projection; fields filled in by tests.
//

/// A projection of a SOUR (source) record. References its tree node for anything not modeled here.
public struct Source: Identifiable, Equatable, Sendable {
    public let id: Xref
    public let title: String?         // TITL
    public let author: String?        // AUTH
    public let publication: String?   // PUBL
    public let repository: Xref?      // REPO pointer to a Repository record
    public let notes: [String]
    public let node: GedcomNode

    public init(id: Xref, title: String?, author: String?, publication: String?,
                repository: Xref?, notes: [String], node: GedcomNode) {
        self.id = id
        self.title = title
        self.author = author
        self.publication = publication
        self.repository = repository
        self.notes = notes
        self.node = node
    }

    /// Project a SOUR record node into a Source. Precondition: `node` is a level-0 SOUR with an xref.
    public static func from(node: GedcomNode) -> Source {
        return Source(
            id: node.xref ?? Xref(""),
            title: node.firstValue(tag: "TITL"),
            author: node.firstValue(tag: "AUTH"),
            publication: node.firstValue(tag: "PUBL"),
            repository: node.firstValue(tag: "REPO").map(Xref.init),
            notes: GedcomText.notes(of: node),
            node: node)
    }
}
