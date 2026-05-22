//
// GedcomEvent.swift — a projection of an event or attribute node (BIRT, DEAT, MARR, OCCU, …).
//
// GEDCOM models life events (BIRT/DEAT/MARR/BURI/…) and attributes (OCCU/RESI/EDUC/…) the same
// structural way: a tag, an optional value, and optional DATE / PLAC / NOTE / SOUR children. So one
// small type covers both. It COMPOSES the other model pieces — GedcomDate, Place, Citation — rather
// than re-parsing them, which keeps each parser in exactly one place.
//
// The static tag SETS here are the single source of truth for "which child tags are events" when
// projecting an Individual or Family, so that knowledge lives with the event type, not scattered.
//
// STUB (TDD red phase): `from(node:)` returns a bare event; child extraction filled in by tests.
//

/// A projection of an individual/family event or attribute.
public struct GedcomEvent: Equatable, Sendable {
    public let tag: String           // BIRT, DEAT, MARR, OCCU, RESI, EVEN, …
    public let type: String?         // TYPE refinement (esp. for generic EVEN/FACT)
    public let value: String?        // the event's own value (e.g. OCCU "Farmer", or "Y" = "occurred")
    public let date: GedcomDate?
    public let place: Place?
    public let notes: [String]
    public let citations: [Citation]
    public let node: GedcomNode

    public init(tag: String, type: String?, value: String?, date: GedcomDate?, place: Place?,
                notes: [String], citations: [Citation], node: GedcomNode) {
        self.tag = tag
        self.type = type
        self.value = value
        self.date = date
        self.place = place
        self.notes = notes
        self.citations = citations
        self.node = node
    }

    /// Project any event/attribute node into a GedcomEvent.
    public static func from(node: GedcomNode) -> GedcomEvent {
        return GedcomEvent(
            tag: node.tag,
            type: node.firstValue(tag: "TYPE"),
            value: node.value,
            date: node.firstValue(tag: "DATE").map(GedcomDate.parse),
            place: node.firstChild(tag: "PLAC").map(Place.from(node:)),
            notes: GedcomText.notes(of: node),
            citations: node.children(tag: "SOUR").map(Citation.from(node:)),
            node: node)
    }

    // MARK: Tag sets (which child tags are events/attributes, per the standard)

    /// INDI-level event and attribute tags (5.5.1 + common). Used to pick an individual's events.
    public static let individualEventTags: Set<String> = [
        // events
        "BIRT", "CHR", "DEAT", "BURI", "CREM", "ADOP", "BAPM", "BARM", "BASM", "BLES",
        "CHRA", "CONF", "FCOM", "ORDN", "NATU", "EMIG", "IMMI", "CENS", "PROB", "WILL",
        "GRAD", "RETI", "EVEN",
        // attributes
        "CAST", "DSCR", "EDUC", "IDNO", "NATI", "NCHI", "NMR", "OCCU", "PROP", "RELI",
        "RESI", "SSN", "TITL", "FACT",
    ]

    /// FAM-level event tags (5.5.1 + common). Used to pick a family's events.
    public static let familyEventTags: Set<String> = [
        "ANUL", "CENS", "DIV", "DIVF", "ENGA", "MARB", "MARC", "MARR", "MARL", "MARS",
        "RESI", "EVEN",
    ]
}
