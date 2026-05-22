//
// QualityTests.swift — each data-quality rule fires on its own synthetic trigger (and clean data
// stays quiet). The 9 rules are tested one trigger at a time so a regression localizes precisely.
//

import XCTest
@testable import GedcomKit

final class QualityTests: XCTestCase {

    /// Run the checker over inline GEDCOM and return the issue categories found.
    private func categories(_ text: String) -> Set<Issue.Category> {
        let doc = GedcomDocument.parse(text)
        let index = RelationshipIndex.build(from: doc)
        return Set(QualityChecker.issues(for: doc, index: index).map(\.category))
    }

    /// Tracer: a death dated before a birth fires deathBeforeBirth.
    func testDeathBeforeBirthFires() {
        let found = categories("""
        0 @I1@ INDI
        1 NAME Bad /Dates/
        1 BIRT
        2 DATE 1900
        1 DEAT
        2 DATE 1850
        """)
        XCTAssertTrue(found.contains(.deathBeforeBirth))
    }

    func testChildBeforeParentFires() {
        let found = categories("""
        0 @I1@ INDI
        1 NAME Parent /X/
        1 BIRT
        2 DATE 1950
        0 @I2@ INDI
        1 NAME Child /X/
        1 BIRT
        2 DATE 1900
        0 @F1@ FAM
        1 HUSB @I1@
        1 CHIL @I2@
        """)
        XCTAssertTrue(found.contains(.childBeforeParent))
        XCTAssertFalse(found.contains(.parentTooYoung), "Negative age is childBeforeParent, not tooYoung.")
    }

    func testParentTooYoungFires() {
        let found = categories("""
        0 @I1@ INDI
        1 NAME Parent /X/
        1 BIRT
        2 DATE 1900
        0 @I2@ INDI
        1 NAME Child /X/
        1 BIRT
        2 DATE 1908
        0 @F1@ FAM
        1 HUSB @I1@
        1 CHIL @I2@
        """)
        XCTAssertTrue(found.contains(.parentTooYoung))   // age ~8 < 13
    }

    func testParentTooOldFires() {
        let found = categories("""
        0 @I1@ INDI
        1 NAME Parent /X/
        1 BIRT
        2 DATE 1900
        0 @I2@ INDI
        1 NAME Child /X/
        1 BIRT
        2 DATE 1980
        0 @F1@ FAM
        1 WIFE @I1@
        1 CHIL @I2@
        """)
        XCTAssertTrue(found.contains(.parentTooOld))     // age ~80 > 65
    }

    func testImplausibleLifespanFires() {
        let found = categories("""
        0 @I1@ INDI
        1 NAME Methuselah /X/
        1 BIRT
        2 DATE 1700
        1 DEAT
        2 DATE 1900
        """)
        XCTAssertTrue(found.contains(.implausibleLifespan))   // ~200 years
    }

    func testEventAfterDeathFires() {
        let found = categories("""
        0 @I1@ INDI
        1 NAME Ghost /X/
        1 BIRT
        2 DATE 1820
        1 DEAT
        2 DATE 1850
        1 RESI
        2 DATE 1860
        """)
        XCTAssertTrue(found.contains(.eventAfterDeath))   // residence after death
        XCTAssertFalse(found.contains(.implausibleLifespan))
    }

    func testMissingBirthDateFires() {
        let found = categories("""
        0 @I1@ INDI
        1 NAME Undated /X/
        """)
        XCTAssertEqual(found, [.missingBirthDate], "Only the missing-birth rule should fire.")
    }

    func testBrokenReferenceFires() {
        let found = categories("""
        0 @I1@ INDI
        1 NAME Parent /X/
        1 BIRT
        2 DATE 1900
        0 @F1@ FAM
        1 HUSB @I1@
        1 CHIL @I999@
        """)
        XCTAssertTrue(found.contains(.brokenReference))   // @I999@ doesn't exist
    }

    func testPossibleDuplicateFires() {
        let found = categories("""
        0 @I1@ INDI
        1 NAME John /Smith/
        1 BIRT
        2 DATE 1850
        0 @I2@ INDI
        1 NAME John /Smith/
        1 BIRT
        2 DATE 1851
        """)
        XCTAssertTrue(found.contains(.possibleDuplicate))   // same name, same birth decade
    }

    /// Clean, plausible data produces NO issues — guards against false positives.
    func testCleanDataProducesNoIssues() {
        let doc = GedcomDocument.parse("""
        0 @I1@ INDI
        1 NAME Dad /Clean/
        1 BIRT
        2 DATE 1900
        1 DEAT
        2 DATE 1970
        0 @I2@ INDI
        1 NAME Mom /Tidy/
        1 BIRT
        2 DATE 1905
        1 DEAT
        2 DATE 1980
        0 @I3@ INDI
        1 NAME Kid /Clean/
        1 BIRT
        2 DATE 1930
        0 @F1@ FAM
        1 HUSB @I1@
        1 WIFE @I2@
        1 CHIL @I3@
        """)
        let index = RelationshipIndex.build(from: doc)
        XCTAssertEqual(QualityChecker.issues(for: doc, index: index), [])
    }
}
