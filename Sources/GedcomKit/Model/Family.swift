//
// Family.swift — a projection of a FAM record: the spouses, the children, and family events.
//
// In this data model FAM is where ALL relationships actually live (the file stores them top-down):
// HUSB/WIFE point to the spouses, CHIL points to each child IN LISTED ORDER (which we treat as
// birth order for display), and MARR/DIV/etc. are family events. RelationshipIndex (E4) reads
// these to build the parent<->child graph the relationship calculator needs.
//
// STUB (TDD red phase): `from(node:)` returns a bare family; field extraction filled in by tests.
//

/// A projection of a FAM (family) record.
public struct Family: Identifiable, Equatable, Sendable {
    public let id: Xref
    public let husband: Xref?          // HUSB
    public let wife: Xref?             // WIFE
    public let children: [Xref]        // CHIL, in listed order
    public let events: [GedcomEvent]   // MARR, DIV, ENGA, …
    public let notes: [String]
    public let node: GedcomNode

    public init(id: Xref, husband: Xref?, wife: Xref?, children: [Xref],
                events: [GedcomEvent], notes: [String], node: GedcomNode) {
        self.id = id
        self.husband = husband
        self.wife = wife
        self.children = children
        self.events = events
        self.notes = notes
        self.node = node
    }

    /// The marriage event (first MARR), if any.
    public var marriage: GedcomEvent? { events.first { $0.tag == "MARR" } }

    /// Both spouses' xrefs (whichever are present). Convenience for relationship/graph building.
    public var spouses: [Xref] { [husband, wife].compactMap { $0 } }

    /// Project a FAM record node into a Family.
    public static func from(node: GedcomNode) -> Family {
        let events = node.children
            .filter { GedcomEvent.familyEventTags.contains($0.tag) }
            .map(GedcomEvent.from(node:))
        return Family(
            id: node.xref ?? Xref(""),
            husband: node.firstValue(tag: "HUSB").map(Xref.init),
            wife: node.firstValue(tag: "WIFE").map(Xref.init),
            children: node.children(tag: "CHIL").compactMap { $0.value.map(Xref.init) },
            events: events,
            notes: GedcomText.notes(of: node),
            node: node)
    }
}
