//
// GedcomDate.swift — parse GEDCOM date values into something sortable and comparable.
//
// GEDCOM dates are messy genealogical dates, not calendar timestamps. They can be exact
// ("7 MAR 1875"), partial ("MAR 1875", "1875"), approximate ("ABT 1797", "EST/CAL"), bounded
// ("BEF 1800", "AFT 1750"), a range ("BET 1800 AND 1810"), or a period ("FROM 1900 TO 1910").
//
// What the rest of the engine needs from a date:
//   * the ORIGINAL text, verbatim, for display (we never lose what the file said);
//   * a way to SORT people by date where approximate dates still order sensibly;
//   * a numeric value for AGE/PLAUSIBILITY math in the quality checker.
//
// So a GedcomDate keeps the raw string, a qualifier (how precise/what kind), and resolved
// earliest/latest bounds as `YMD`. From those it derives a `sortKey` (a decimal year at the
// midpoint of its span). Anything it can't parse degrades to `.unparsed` with nil bounds — the
// raw text is still preserved, nothing throws.
//
// STUB (TDD red phase): `parse` returns `.unparsed`; real parsing is filled in test-by-test.
//

import Foundation

/// A partial calendar date: year always, month/day optional. Used as a date's resolved bound.
/// Comparable so bounds can be ordered; comparison treats a missing month/day as the start of its
/// period (month nil < any month), which is the right ordering for "1875" vs "MAR 1875".
public struct YMD: Equatable, Comparable, Sendable {
    public let year: Int
    public let month: Int?   // 1...12
    public let day: Int?     // 1...31

    public init(year: Int, month: Int? = nil, day: Int? = nil) {
        self.year = year
        self.month = month
        self.day = day
    }

    public static func < (lhs: YMD, rhs: YMD) -> Bool {
        if lhs.year != rhs.year { return lhs.year < rhs.year }
        if (lhs.month ?? 0) != (rhs.month ?? 0) { return (lhs.month ?? 0) < (rhs.month ?? 0) }
        return (lhs.day ?? 0) < (rhs.day ?? 0)
    }
}

/// A parsed GEDCOM date value.
public struct GedcomDate: Equatable, Sendable {

    /// What kind of date this is — drives both display ("abt 1797") and how bounds were derived.
    public enum Qualifier: Equatable, Sendable {
        case exact         // "7 MAR 1875"
        case about         // "ABT 1797"
        case estimated     // "EST 1790"
        case calculated    // "CAL 1800"
        case before        // "BEF 1800"  -> only `latest` known
        case after         // "AFT 1750"  -> only `earliest` known
        case between       // "BET 1800 AND 1810"
        case period        // "FROM 1900 TO 1910" / "FROM 1900" / "TO 1910"
        case interpreted   // "INT 1850 (some phrase)"
        case unparsed      // couldn't make sense of it; raw text is still kept
    }

    /// The value exactly as it appeared in the file (lossless; used for display).
    public let raw: String
    public let qualifier: Qualifier

    /// Lower/upper bounds of the date's span. For an exact/approximate single date these are equal.
    /// For BEF, `earliest` is nil; for AFT, `latest` is nil; for BET/period both are set.
    public let earliest: YMD?
    public let latest: YMD?

    public init(raw: String, qualifier: Qualifier, earliest: YMD?, latest: YMD?) {
        self.raw = raw
        self.qualifier = qualifier
        self.earliest = earliest
        self.latest = latest
    }

    /// Parse a raw GEDCOM date value. Always returns a value; unparseable input becomes `.unparsed`.
    public static func parse(_ raw: String) -> GedcomDate {
        var tokens = raw.split(separator: " ").map { String($0).uppercased() }
        // Normalize two full-standard wrinkles before keyword handling:
        //   * a leading calendar escape like "@#DJULIAN@" (we don't convert calendars in v1, but we
        //     must not choke on the escape — strip it and parse the date that follows);
        //   * a trailing BC marker ("44 B.C.") which we fold into a negative sign on the year.
        tokens = strippingCalendarEscape(tokens)
        tokens = foldingBCMarker(tokens)

        guard let keyword = tokens.first else { return unparsed(raw) }
        let rest = Array(tokens.dropFirst())

        switch keyword {
        case "ABT": return single(raw, .about, rest)
        case "EST": return single(raw, .estimated, rest)
        case "CAL": return single(raw, .calculated, rest)

        case "BEF":   // bounded above only
            guard let d = parseSimpleDate(rest) else { return unparsed(raw) }
            return GedcomDate(raw: raw, qualifier: .before, earliest: nil, latest: d)

        case "AFT":   // bounded below only
            guard let d = parseSimpleDate(rest) else { return unparsed(raw) }
            return GedcomDate(raw: raw, qualifier: .after, earliest: d, latest: nil)

        case "BET":   // BET <date> AND <date>
            guard let andIndex = rest.firstIndex(of: "AND"),
                  let lo = parseSimpleDate(Array(rest[..<andIndex])),
                  let hi = parseSimpleDate(Array(rest[(andIndex + 1)...]))
            else { return unparsed(raw) }
            return GedcomDate(raw: raw, qualifier: .between, earliest: lo, latest: hi)

        case "FROM":  // FROM <date> [TO <date>]
            if let toIndex = rest.firstIndex(of: "TO") {
                let lo = parseSimpleDate(Array(rest[..<toIndex]))
                let hi = parseSimpleDate(Array(rest[(toIndex + 1)...]))
                guard lo != nil || hi != nil else { return unparsed(raw) }
                return GedcomDate(raw: raw, qualifier: .period, earliest: lo, latest: hi)
            }
            guard let lo = parseSimpleDate(rest) else { return unparsed(raw) }
            return GedcomDate(raw: raw, qualifier: .period, earliest: lo, latest: nil)

        case "TO":    // open-started period
            guard let hi = parseSimpleDate(rest) else { return unparsed(raw) }
            return GedcomDate(raw: raw, qualifier: .period, earliest: nil, latest: hi)

        case "INT":   // INT <date> (interpretation phrase) — parse only the date part
            let dateTokens = Array(rest.prefix(while: { !$0.hasPrefix("(") }))
            guard let d = parseSimpleDate(dateTokens) else { return unparsed(raw) }
            return GedcomDate(raw: raw, qualifier: .interpreted, earliest: d, latest: d)

        default:      // no keyword -> a plain exact date (or unparseable phrase)
            guard let d = parseSimpleDate(tokens) else { return unparsed(raw) }
            return GedcomDate(raw: raw, qualifier: .exact, earliest: d, latest: d)
        }
    }

    // MARK: - sortKey

    /// A single decimal year at the MIDPOINT of this date's span, for sorting and age math. Nil
    /// when the date couldn't be parsed. A bounded date (BEF/AFT) collapses to its one known
    /// endpoint; a range/period uses the midpoint between its ends. Examples:
    ///   "1875"            -> 1875.5  (spans the whole year, midpoint mid-year)
    ///   "BET 1800 AND 1810" -> ~1805.5
    public var sortKey: Double? {
        let lo = earliest ?? latest
        let hi = latest ?? earliest
        guard let lo, let hi else { return nil }
        return (Self.decimalYearStart(lo) + Self.decimalYearEnd(hi)) / 2
    }

    // MARK: - Parsing helpers

    /// All-uppercase month abbreviations -> month number, in GEDCOM's canonical order.
    private static let months: [String: Int] = [
        "JAN": 1, "FEB": 2, "MAR": 3, "APR": 4, "MAY": 5, "JUN": 6,
        "JUL": 7, "AUG": 8, "SEP": 9, "OCT": 10, "NOV": 11, "DEC": 12,
    ]

    /// Build a single-date GedcomDate with the given qualifier, or `.unparsed` if the date part
    /// doesn't parse. Used for ABT/EST/CAL which all wrap one date.
    private static func single(_ raw: String, _ qualifier: Qualifier, _ tokens: [String]) -> GedcomDate {
        guard let d = parseSimpleDate(tokens) else { return unparsed(raw) }
        return GedcomDate(raw: raw, qualifier: qualifier, earliest: d, latest: d)
    }

    private static func unparsed(_ raw: String) -> GedcomDate {
        GedcomDate(raw: raw, qualifier: .unparsed, earliest: nil, latest: nil)
    }

    /// Parse the bare date forms "YYYY", "MON YYYY", or "DD MON YYYY" (tokens already uppercased,
    /// calendar escape stripped, BC folded into a negative year). Returns nil for anything else,
    /// which lets callers degrade to `.unparsed`.
    private static func parseSimpleDate(_ tokens: [String]) -> YMD? {
        switch tokens.count {
        case 1:
            guard let year = parseYear(tokens[0]) else { return nil }
            return YMD(year: year)
        case 2:
            guard let month = months[tokens[0]], let year = parseYear(tokens[1]) else { return nil }
            return YMD(year: year, month: month)
        case 3:
            guard let day = Int(tokens[0]), (1...31).contains(day),
                  let month = months[tokens[1]], let year = parseYear(tokens[2]) else { return nil }
            return YMD(year: year, month: month, day: day)
        default:
            return nil
        }
    }

    /// Parse a year token, accepting dual-dated years like "1745/46" (take the earlier year) and a
    /// leading "-" for BC years. Returns nil if it isn't a year.
    private static func parseYear(_ token: String) -> Int? {
        var text = token
        if let slash = text.firstIndex(of: "/") {   // dual dating "1745/46" -> "1745"
            text = String(text[..<slash])
        }
        return Int(text)
    }

    /// Drop a leading calendar escape ("@#DGREGORIAN@", "@#DJULIAN@", even "@#DFRENCH R@" which
    /// spans two tokens). Returns the tokens after the escape. Leaves a malformed (unterminated)
    /// escape untouched so it degrades to `.unparsed` rather than silently eating the date.
    private static func strippingCalendarEscape(_ tokens: [String]) -> [String] {
        guard let first = tokens.first, first.hasPrefix("@#") else { return tokens }
        // The escape ends at the first token that closes with '@'.
        for (index, token) in tokens.enumerated() where token.hasSuffix("@") {
            return Array(tokens[(index + 1)...])
        }
        return tokens
    }

    /// Recognized BC markers (uppercased). 5.5.1 uses "B.C."; we also accept BCE forms.
    private static let bcMarkers: Set<String> = ["BC", "B.C.", "BCE", "B.C.E."]

    /// If the value ends in a BC marker, drop it and prefix "-" onto the year token so downstream
    /// parsing yields a negative year (e.g. ["44","B.C."] -> ["-44"]).
    private static func foldingBCMarker(_ tokens: [String]) -> [String] {
        guard let last = tokens.last, bcMarkers.contains(last), tokens.count >= 2 else { return tokens }
        var result = Array(tokens.dropLast())
        result.append("-" + result.removeLast())
        return result
    }

    /// Decimal year at the START of a YMD's precision span (e.g. "1875" -> 1875.0, "MAR 1875" ->
    /// ~1875.167). Day/month are 1-based; the /372 keeps day fractions within a month slot.
    private static func decimalYearStart(_ ymd: YMD) -> Double {
        let monthOffset = Double((ymd.month ?? 1) - 1) / 12.0
        let dayOffset = Double((ymd.day ?? 1) - 1) / 372.0
        return Double(ymd.year) + monthOffset + dayOffset
    }

    /// Decimal year at the END of a YMD's precision span: a year-only date ends a full year later,
    /// a month-only date ends a month later, a full date ends a day later. This gives ranges and
    /// partial dates a sensible width for midpoint computation.
    private static func decimalYearEnd(_ ymd: YMD) -> Double {
        guard let month = ymd.month else { return Double(ymd.year) + 1.0 }
        guard let day = ymd.day else { return Double(ymd.year) + Double(month) / 12.0 }
        return Double(ymd.year) + Double(month - 1) / 12.0 + Double(day) / 372.0
    }
}
