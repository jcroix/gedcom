//
// Place.swift — a GEDCOM place: free-text jurisdictions plus optional map coordinates.
//
// A PLAC value is a comma-separated list of jurisdictions ordered finest-first, e.g.
// "Philadelphia, Philadelphia County, Pennsylvania, USA". The real family.ged uses free text like
// "Philadelphia, Pennsylvania". A PLAC node may also carry a MAP child with LATI/LONG coordinates
// (e.g. "N39.95", "W75.16"); we parse those into signed decimals.
//
// STUB (TDD red phase): `parse`/`from(node:)` return a bare value; real splitting + coords by test.
//

import Foundation

/// A parsed place. `raw` is the verbatim PLAC value (for display/losslessness); `jurisdictions`
/// is the comma-split breakdown; lat/long are present only when a MAP sub-record supplied them.
public struct Place: Equatable, Sendable {
    public let raw: String
    public let jurisdictions: [String]
    public let latitude: Double?
    public let longitude: Double?

    public init(raw: String, jurisdictions: [String], latitude: Double? = nil, longitude: Double? = nil) {
        self.raw = raw
        self.jurisdictions = jurisdictions
        self.latitude = latitude
        self.longitude = longitude
    }

    /// Parse just a PLAC value string (no coordinates).
    public static func parse(_ raw: String) -> Place {
        let jurisdictions = raw
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        return Place(raw: raw, jurisdictions: jurisdictions)
    }

    /// Build a Place from a PLAC node, reading any MAP/LATI/LONG coordinates from its children.
    public static func from(node: GedcomNode) -> Place {
        let base = parse(node.value ?? "")
        guard let map = node.firstChild(tag: "MAP") else { return base }
        return Place(raw: base.raw,
                     jurisdictions: base.jurisdictions,
                     latitude: parseCoordinate(map.firstValue(tag: "LATI")),
                     longitude: parseCoordinate(map.firstValue(tag: "LONG")))
    }

    /// Parse a GEDCOM coordinate like "N39.95" / "W75.16" into a signed decimal degree. The leading
    /// hemisphere letter sets the sign: N/E positive, S/W negative. Returns nil if absent/unparseable.
    private static func parseCoordinate(_ text: String?) -> Double? {
        guard let text, let hemisphere = text.first else { return nil }
        guard let magnitude = Double(text.dropFirst()) else { return nil }
        switch hemisphere {
        case "N", "E", "n", "e": return magnitude
        case "S", "W", "s", "w": return -magnitude
        default: return Double(text)   // no hemisphere letter — treat the whole thing as a number
        }
    }
}
