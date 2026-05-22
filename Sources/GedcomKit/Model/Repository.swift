//
// Repository.swift — a REPO record: an archive/library that holds sources.
//
// Minimal projection (name + notes) — enough for the app to list repositories when a file has
// them. The real family.ged has none; covered by synthetic tests per the full-standard rule.
//
// STUB (TDD red phase): `from(node:)` returns an empty projection; fields filled in by tests.
//

/// A projection of a REPO (repository) record.
public struct Repository: Identifiable, Equatable, Sendable {
    public let id: Xref
    public let name: String?     // NAME
    public let notes: [String]
    public let node: GedcomNode

    public init(id: Xref, name: String?, notes: [String], node: GedcomNode) {
        self.id = id
        self.name = name
        self.notes = notes
        self.node = node
    }

    /// Project a REPO record node into a Repository. Precondition: `node` is a level-0 REPO with xref.
    public static func from(node: GedcomNode) -> Repository {
        return Repository(
            id: node.xref ?? Xref(""),
            name: node.firstValue(tag: "NAME"),
            notes: GedcomText.notes(of: node),
            node: node)
    }
}
