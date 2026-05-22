//
// QualityIntegrationTests.swift — the quality checker against the real family.ged.
//
// E5 gate: a full-file run completes and produces SANE counts — no broken references (we verified
// in E2 that all pointers resolve), curated genealogical errors are rare, and the bucketed
// duplicate scan doesn't explode. Exact counts track the current fixture; bounds are intentionally
// loose so ordinary edits to the source data don't break the test.
//

import XCTest
@testable import GedcomKit

final class QualityIntegrationTests: XCTestCase {

    func testFullFileRunGivesSaneCounts() throws {
        let url = try XCTUnwrap(
            Bundle.module.url(forResource: "family", withExtension: "ged", subdirectory: "Fixtures"))
        let doc = GedcomDocument.load(try Data(contentsOf: url))
        let index = RelationshipIndex.build(from: doc)

        let issues = QualityChecker.issues(for: doc, index: index)
        var histogram: [Issue.Category: Int] = [:]
        for issue in issues { histogram[issue.category, default: 0] += 1 }
        print("QUALITY HISTOGRAM (family.ged): \(histogram.mapValues { $0 }.sorted { $0.key.rawValue < $1.key.rawValue })")

        // All pointers in the real file resolve (consistent with E2's zero error diagnostics).
        XCTAssertEqual(histogram[.brokenReference, default: 0], 0, "Real file should have no broken references.")
        // The run found something to report (many people lack birth dates, etc.).
        XCTAssertGreaterThan(issues.count, 0)
        // The bucketed duplicate scan must not explode into thousands (would signal a bug).
        XCTAssertLessThan(histogram[.possibleDuplicate, default: 0], 500)
    }
}
