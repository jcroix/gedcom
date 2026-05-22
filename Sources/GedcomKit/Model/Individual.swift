//
// Individual.swift — a projection of an INDI record into the fields the app and analysis need.
//
// An Individual COMPOSES the smaller parsers: PersonalName for names, GedcomEvent for the life
// events/attributes, GedcomText for notes. It also reads FAMC/FAMS family pointers WHEN PRESENT —
// but note the real family.ged has none of those (relationships are stored top-down on FAM
// records only), so for that file these stay empty and RelationshipIndex (E4) synthesizes the
// back-links. The projection references its tree `node` so anything not modeled (custom tags like
// _FSFTID, unknown tags) is still reachable for the app's raw "Other Facts" display.
//
// STUB (TDD red phase): `from(node:)` returns a bare individual; field extraction filled in by tests.
//

/// Biological sex as recorded in SEX. Anything other than M/F (incl. 7.0's X, or missing) is
/// `.unknown`; the raw value remains available on the node if ever needed.
public enum Sex: String, Sendable, Equatable {
    case male = "M"
    case female = "F"
    case unknown = "U"

    /// Map a raw SEX value to a case. Defensive: nil/unrecognized -> .unknown.
    public static func parse(_ value: String?) -> Sex {
        switch value?.uppercased() {
        case "M": return .male
        case "F": return .female
        default:  return .unknown
        }
    }
}

/// A projection of an INDI (individual) record.
public struct Individual: Identifiable, Equatable, Sendable {
    public let id: Xref
    public let name: PersonalName?        // primary name (first NAME), nil if the record has none
    public let names: [PersonalName]      // all NAME variants, in order (AKA etc.)
    public let sex: Sex
    public let events: [GedcomEvent]      // life events + attributes, in file order
    public let notes: [String]
    public let media: [MediaObject]       // inline OBJE links
    public let childInFamilies: [Xref]    // FAMC: families where this person is a child
    public let spouseInFamilies: [Xref]   // FAMS: families where this person is a spouse
    public let node: GedcomNode

    public init(id: Xref, name: PersonalName?, names: [PersonalName], sex: Sex,
                events: [GedcomEvent], notes: [String], media: [MediaObject],
                childInFamilies: [Xref], spouseInFamilies: [Xref], node: GedcomNode) {
        self.id = id
        self.name = name
        self.names = names
        self.sex = sex
        self.events = events
        self.notes = notes
        self.media = media
        self.childInFamilies = childInFamilies
        self.spouseInFamilies = spouseInFamilies
        self.node = node
    }

    // MARK: Convenience

    /// The primary birth event (first BIRT), if any.
    public var birth: GedcomEvent? { events.first { $0.tag == "BIRT" } }

    /// The primary death event (first DEAT), if any.
    public var death: GedcomEvent? { events.first { $0.tag == "DEAT" } }

    /// A display string for lists/charts; falls back to a placeholder when unnamed.
    public var displayName: String { name?.displayName ?? "(unnamed)" }

    /// Project an INDI record node into an Individual.
    public static func from(node: GedcomNode) -> Individual {
        let names = node.children(tag: "NAME").map(PersonalName.from(node:))
        let events = node.children
            .filter { GedcomEvent.individualEventTags.contains($0.tag) }
            .map(GedcomEvent.from(node:))
        return Individual(
            id: node.xref ?? Xref(""),
            name: names.first,
            names: names,
            sex: Sex.parse(node.firstValue(tag: "SEX")),
            events: events,
            notes: GedcomText.notes(of: node),
            media: node.children(tag: "OBJE").map(MediaObject.from(node:)),
            childInFamilies: node.children(tag: "FAMC").compactMap { $0.value.map(Xref.init) },
            spouseInFamilies: node.children(tag: "FAMS").compactMap { $0.value.map(Xref.init) },
            node: node)
    }
}
