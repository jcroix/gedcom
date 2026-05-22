//
// DateTests.swift — behavior of GedcomDate.parse and its sortKey.
//
// This is the living spec for genealogical date parsing: read these to recall exactly how each
// GEDCOM date form (exact, partial, ABT/EST/CAL, BEF/AFT, BET..AND, FROM..TO, garbage) resolves
// to a qualifier + earliest/latest bounds, and how those map to a sortable decimal year.
//

import XCTest
@testable import GedcomKit

final class DateTests: XCTestCase {

    /// Tracer: a full exact date resolves to .exact with day/month/year, both bounds equal.
    func testParsesExactDayMonthYear() {
        let date = GedcomDate.parse("7 MAR 1875")
        XCTAssertEqual(date.qualifier, .exact)
        XCTAssertEqual(date.earliest, YMD(year: 1875, month: 3, day: 7))
        XCTAssertEqual(date.latest, YMD(year: 1875, month: 3, day: 7))
        XCTAssertEqual(date.raw, "7 MAR 1875")   // original preserved verbatim
    }

    // MARK: Partial precision

    func testParsesYearOnly() {
        let date = GedcomDate.parse("1875")
        XCTAssertEqual(date.qualifier, .exact)
        XCTAssertEqual(date.earliest, YMD(year: 1875))
        XCTAssertEqual(date.latest, YMD(year: 1875))
    }

    func testParsesMonthAndYear() {
        let date = GedcomDate.parse("MAR 1875")
        XCTAssertEqual(date.earliest, YMD(year: 1875, month: 3))
    }

    // MARK: Approximation qualifiers

    func testParsesApproximateQualifiers() {
        XCTAssertEqual(GedcomDate.parse("ABT 1797").qualifier, .about)
        XCTAssertEqual(GedcomDate.parse("EST 1790").qualifier, .estimated)
        XCTAssertEqual(GedcomDate.parse("CAL 1800").qualifier, .calculated)
        XCTAssertEqual(GedcomDate.parse("ABT 1797").earliest, YMD(year: 1797))
    }

    // MARK: Bounded / range / period

    func testParsesBeforeBoundsAboveOnly() {
        let date = GedcomDate.parse("BEF 1800")
        XCTAssertEqual(date.qualifier, .before)
        XCTAssertNil(date.earliest)
        XCTAssertEqual(date.latest, YMD(year: 1800))
    }

    func testParsesAfterBoundsBelowOnly() {
        let date = GedcomDate.parse("AFT 1750")
        XCTAssertEqual(date.qualifier, .after)
        XCTAssertEqual(date.earliest, YMD(year: 1750))
        XCTAssertNil(date.latest)
    }

    func testParsesBetweenAndRange() {
        let date = GedcomDate.parse("BET 1800 AND 1810")
        XCTAssertEqual(date.qualifier, .between)
        XCTAssertEqual(date.earliest, YMD(year: 1800))
        XCTAssertEqual(date.latest, YMD(year: 1810))
    }

    func testParsesFromToPeriod() {
        let date = GedcomDate.parse("FROM 1900 TO 1910")
        XCTAssertEqual(date.qualifier, .period)
        XCTAssertEqual(date.earliest, YMD(year: 1900))
        XCTAssertEqual(date.latest, YMD(year: 1910))
    }

    func testParsesInterpretedDateIgnoringPhrase() {
        let date = GedcomDate.parse("INT 1850 (about when the census was taken)")
        XCTAssertEqual(date.qualifier, .interpreted)
        XCTAssertEqual(date.earliest, YMD(year: 1850))
    }

    // MARK: Degrade gracefully

    func testUnparseableDateKeepsRawAndIsUnparsed() {
        let date = GedcomDate.parse("sometime in the gold rush")
        XCTAssertEqual(date.qualifier, .unparsed)
        XCTAssertNil(date.earliest)
        XCTAssertNil(date.latest)
        XCTAssertNil(date.sortKey)
        XCTAssertEqual(date.raw, "sometime in the gold rush")   // never lose the text
    }

    // MARK: sortKey

    /// sortKey is a decimal year at the span midpoint, so approximate and ranged dates still order
    /// sensibly against exact ones.
    func testSortKeyOrdersDatesSensibly() throws {
        let y1800 = try XCTUnwrap(GedcomDate.parse("1800").sortKey)
        let abt1805 = try XCTUnwrap(GedcomDate.parse("ABT 1805").sortKey)
        let range = try XCTUnwrap(GedcomDate.parse("BET 1800 AND 1810").sortKey)

        XCTAssertEqual(y1800, 1800.5, accuracy: 0.001)            // mid-year of 1800
        XCTAssertEqual(range, 1805.5, accuracy: 0.01)             // midpoint of 1800..1810
        XCTAssertLessThan(y1800, abt1805)                        // 1800 sorts before ~1805
        XCTAssertLessThan(abt1805, GedcomDate.parse("1820").sortKey!)
    }

    // MARK: Full-standard forms not present in family.ged (general-purpose completeness)

    /// Dual dating (Julian/Gregorian new-year ambiguity), e.g. "1745/46". The earlier year is the
    /// resolved year; the raw is preserved for display.
    func testParsesDualDatedYear() {
        let date = GedcomDate.parse("12 FEB 1745/46")
        XCTAssertEqual(date.qualifier, .exact)
        XCTAssertEqual(date.earliest, YMD(year: 1745, month: 2, day: 12))
    }

    /// BC / B.C. years resolve to a negative year so they sort before year 1.
    func testParsesBCYear() throws {
        let date = GedcomDate.parse("44 B.C.")
        XCTAssertEqual(date.earliest, YMD(year: -44))
        XCTAssertLessThan(try XCTUnwrap(date.sortKey), 0)
    }

    /// A leading calendar escape (@#DJULIAN@ etc.) is recognized and stripped; the date after it
    /// parses normally. (We don't convert calendars for v1 — Gregorian-ish decimal year is fine for
    /// sorting — but we must not choke on the escape.)
    func testParsesLeadingCalendarEscape() {
        let date = GedcomDate.parse("@#DJULIAN@ 14 APR 1752")
        XCTAssertEqual(date.qualifier, .exact)
        XCTAssertEqual(date.earliest, YMD(year: 1752, month: 4, day: 14))
    }
}
