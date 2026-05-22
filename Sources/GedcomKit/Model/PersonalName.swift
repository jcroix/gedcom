//
// PersonalName.swift — parse a GEDCOM personal name into its pieces.
//
// GEDCOM encodes a name two (combinable) ways:
//   1. INLINE in the NAME value, with the surname delimited by slashes:
//        "John /Crox/"          -> given "John", surname "Crox"
//        "John /Crox/ Jr"       -> + suffix "Jr"
//        "Dr. John /van Crox/"  -> given "Dr. John", surname "van Crox"
//   2. As SUBORDINATE pieces under NAME: NPFX, GIVN, NICK, SPFX, SURN, NSFX. When present these
//      are authoritative and override what we'd infer from the inline slashes.
//
// This type holds the structured pieces plus the raw inline value (kept verbatim for display and
// losslessness) and a reconstructed `displayName`. Parsing is DEFENSIVE: a name with the wrong
// number of slashes (the real file contains "John Crox (Henry's /father)/") must not crash — it
// degrades to a display-only name with the text preserved.
//
// STUB (TDD red phase): `parse` returns display-only; real piece extraction is filled in by tests.
//

import Foundation  // for String trimming / replacing used when assembling the display name

/// A parsed personal name. All pieces optional because real-world names fill in only some.
public struct PersonalName: Equatable, Sendable {
    public let raw: String              // inline NAME value, verbatim
    public let prefix: String?          // NPFX, e.g. "Dr."
    public let given: String?           // given names (before the first slash, or GIVN)
    public let nickname: String?        // NICK
    public let surnamePrefix: String?   // SPFX, e.g. "van", "de"
    public let surname: String?         // between the slashes, or SURN
    public let suffix: String?          // NSFX, e.g. "Jr", "III"

    public init(raw: String,
                prefix: String? = nil,
                given: String? = nil,
                nickname: String? = nil,
                surnamePrefix: String? = nil,
                surname: String? = nil,
                suffix: String? = nil) {
        self.raw = raw
        self.prefix = prefix
        self.given = given
        self.nickname = nickname
        self.surnamePrefix = surnamePrefix
        self.surname = surname
        self.suffix = suffix
    }

    /// A human-readable single line built from the available pieces, in natural order. Falls back
    /// to the raw value (slashes removed) if no structured pieces were extracted, so there's always
    /// something sensible to show.
    public var displayName: String {
        let assembled = [prefix, given, surnamePrefix, surname, suffix]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        if !assembled.isEmpty { return assembled }
        return raw.replacingOccurrences(of: "/", with: "").trimmingCharacters(in: .whitespaces)
    }

    /// Parse the inline `/Surname/` form. See the file header for the rules. Always returns a value.
    public static func parse(_ inline: String) -> PersonalName {
        let slashCount = inline.filter { $0 == "/" }.count

        // The surname is delimited by a PAIR of slashes. With fewer than two we can't reliably
        // find a surname, so degrade to a display-only name (slashes stripped) rather than guess.
        guard slashCount >= 2, let firstSlash = inline.firstIndex(of: "/") else {
            return PersonalName(raw: inline,
                                given: clean(inline.replacingOccurrences(of: "/", with: "")),
                                surname: nil)
        }

        let afterFirst = inline.index(after: firstSlash)
        guard let secondSlash = inline[afterFirst...].firstIndex(of: "/") else {
            return PersonalName(raw: inline, given: clean(inline), surname: nil)
        }

        // given = before first slash; surname = between slashes; suffix = after second slash.
        // (If there are extra slashes beyond two, they fall into the suffix verbatim — mechanical
        // but lossless, which is what we want for odd real-world names.)
        return PersonalName(
            raw: inline,
            given: clean(String(inline[..<firstSlash])),
            surname: clean(String(inline[afterFirst..<secondSlash])),
            suffix: clean(String(inline[inline.index(after: secondSlash)...])))
    }

    /// Build a name from a NAME node: parse its inline value, then OVERRIDE any piece with an
    /// explicit subordinate tag (NPFX/GIVN/NICK/SPFX/SURN/NSFX) when present — those are
    /// authoritative per the standard.
    public static func from(node: GedcomNode) -> PersonalName {
        let inline = parse(node.value ?? "")
        return PersonalName(
            raw: node.value ?? "",
            prefix: node.firstValue(tag: "NPFX") ?? inline.prefix,
            given: node.firstValue(tag: "GIVN") ?? inline.given,
            nickname: node.firstValue(tag: "NICK") ?? inline.nickname,
            surnamePrefix: node.firstValue(tag: "SPFX") ?? inline.surnamePrefix,
            surname: node.firstValue(tag: "SURN") ?? inline.surname,
            suffix: node.firstValue(tag: "NSFX") ?? inline.suffix)
    }

    /// Trim whitespace and turn an empty piece into nil, so absent pieces are uniformly nil.
    private static func clean(_ s: String) -> String? {
        let trimmed = s.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? nil : trimmed
    }
}
