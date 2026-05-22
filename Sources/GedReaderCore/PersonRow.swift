//
// PersonRow.swift — a precomputed, display-ready row for the People table.
//
// The People list is a SwiftUI Table of thousands of rows; recomputing display strings and sort
// keys per redraw would be wasteful. So we flatten each Individual ONCE into a PersonRow: the
// display strings (name, birth, death, sex) plus numeric/string sort keys. Crucially, birth/death
// keep BOTH the human text ("ABT 1797") for display AND a `sortKey` (decimal year) for ordering, so
// approximate dates sort sensibly next to exact ones. Rows with no date sort LAST.
//
// STUB (TDD red phase): `from`/`all` return placeholders until tests drive them.
//

import Foundation
import GedcomKit

/// One row of the People table.
public struct PersonRow: Identifiable, Equatable, Sendable {
    public let id: Xref
    public let name: String          // display name (e.g. "John Crox")
    public let birth: String         // display birth text (e.g. "ABT 1797"), "" if none
    public let death: String
    public let sex: String           // "M" / "F" / ""
    public let birthSortKey: Double? // decimal year for sorting; nil = undated (sorts last)
    public let deathSortKey: Double?
    public let nameSortKey: String   // "surname given" lowercased, for case-insensitive name sort

    public init(id: Xref, name: String, birth: String, death: String, sex: String,
                birthSortKey: Double?, deathSortKey: Double?, nameSortKey: String) {
        self.id = id
        self.name = name
        self.birth = birth
        self.death = death
        self.sex = sex
        self.birthSortKey = birthSortKey
        self.deathSortKey = deathSortKey
        self.nameSortKey = nameSortKey
    }

    /// Non-optional birth sort value for SwiftUI Table columns (KeyPathComparator needs a
    /// Comparable, and Optional isn't). Undated people get +infinity so they sort LAST ascending.
    public var birthSortValue: Double { birthSortKey ?? .greatestFiniteMagnitude }
    /// Non-optional death sort value (see `birthSortValue`).
    public var deathSortValue: Double { deathSortKey ?? .greatestFiniteMagnitude }

    /// Flatten one individual into a display row.
    public static func from(_ individual: Individual) -> PersonRow {
        let birthDate = individual.birth?.date
        let deathDate = individual.death?.date
        let sexString: String
        switch individual.sex {
        case .male: sexString = "M"
        case .female: sexString = "F"
        case .unknown: sexString = ""
        }
        // Name sort key: surname first (genealogy convention), then given, case-insensitive.
        let nameSortKey = [individual.name?.surname, individual.name?.given]
            .compactMap { $0 }.joined(separator: " ").lowercased()

        return PersonRow(
            id: individual.id,
            name: individual.displayName,
            birth: birthDate?.raw ?? "",
            death: deathDate?.raw ?? "",
            sex: sexString,
            birthSortKey: birthDate?.sortKey,
            deathSortKey: deathDate?.sortKey,
            nameSortKey: nameSortKey)
    }

    /// All rows for a document, in file order.
    public static func all(in document: GedcomDocument) -> [PersonRow] {
        document.allIndividuals.map(from)
    }

    /// Rows sorted by birth date ascending, with undated people last (then by name for stability).
    /// Used as the default People ordering and to verify approximate dates order sensibly.
    public static func sortedByBirth(_ rows: [PersonRow]) -> [PersonRow] {
        rows.sorted { a, b in
            switch (a.birthSortKey, b.birthSortKey) {
            case let (x?, y?): return x != y ? x < y : a.nameSortKey < b.nameSortKey
            case (_?, nil):    return true                 // dated sorts before undated
            case (nil, _?):    return false                // undated sorts after dated
            case (nil, nil):   return a.nameSortKey < b.nameSortKey
            }
        }
    }
}
