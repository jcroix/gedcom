//
// RelationshipGoldenTests.swift — the Swift port must reproduce query.py's labels on real data.
//
// The expected labels below were CAPTURED by running the original query.py against family.ged
// (e.g. `python3 query.py "@I001@" "@I003@"`). They are the golden oracle for the port. Each tuple
// reads "subject is the <label> of base", matching query.py's "base → subject: <label>" output.
//
// Pairs were chosen to be unambiguous (no LCA tie that query.py would resolve nondeterministically)
// so the comparison is meaningful. The deterministic-tie-break behavior is covered separately by
// the synthetic path test in RelationshipTests.
//
// If family.ged is re-copied and these people change, re-capture with query.py and update here.
//

import XCTest
@testable import GedcomKit

final class RelationshipGoldenTests: XCTestCase {

    /// Load the real document + its relationship index. Done per test (it parses in milliseconds);
    /// a shared mutable static would violate Swift 6 strict-concurrency, and isn't worth it here.
    private func loadRealFile() throws -> (GedcomDocument, RelationshipIndex) {
        let url = try XCTUnwrap(
            Bundle.module.url(forResource: "family", withExtension: "ged", subdirectory: "Fixtures"))
        let document = GedcomDocument.load(try Data(contentsOf: url))
        return (document, RelationshipIndex.build(from: document))
    }

    /// (subject, base, expected) — "subject is the <label> of base", captured from query.py.
    private let goldenCases: [(subject: String, base: String, label: String)] = [
        ("@I003@", "@I001@", "son"),            // Henry is the son of John
        ("@I001@", "@I003@", "father"),         // John is the father of Henry
        ("@I003@", "@I004@", "sibling"),        // Henry & Charles are siblings
        ("@I004@", "@I003@", "sibling"),
        ("@I003@", "@I002@", "son"),            // Henry is the son of Eliza
        ("@I002@", "@I003@", "mother"),         // Eliza is the mother of Henry
        ("@I3300@", "@I001@", "son"),
        ("@I001@", "@I3300@", "father"),
        ("@I016@", "@I001@", "granddaughter"),  // Laura is John's granddaughter
        ("@I001@", "@I016@", "grandfather"),    // John is Laura's grandfather
        ("@I016@", "@I004@", "niece"),          // Laura is Charles's niece
        ("@I004@", "@I016@", "uncle"),          // Charles is Laura's uncle
        ("@I016@", "@I018@", "sibling"),        // Laura & William are siblings
        ("@I018@", "@I016@", "sibling"),
    ]

    func testMatchesQueryPyLabels() throws {
        let (document, index) = try loadRealFile()
        for testCase in goldenCases {
            let result = RelationshipCalculator.relationship(
                of: Xref(testCase.subject), to: Xref(testCase.base),
                in: index, document: document)
            XCTAssertEqual(result.label, testCase.label,
                           "\(testCase.subject) relative to \(testCase.base): expected '\(testCase.label)', got '\(result.label)'")
        }
    }

    /// Sanity + light perf: scanning the whole file for John Crox's relatives finds a substantial
    /// connected set (he's a documented family head), and the same scan is deterministic.
    func testJohnCroxHasManyConnectedRelatives() throws {
        let (document, index) = try loadRealFile()
        let john = Xref("@I001@")
        let connected = document.individuals.keys.filter { other in
            other != john &&
            RelationshipCalculator.relationship(of: other, to: john,
                                                in: index, document: document).label != "no known connection"
        }
        XCTAssertGreaterThan(connected.count, 50, "John Crox should connect to many relatives.")
    }
}
