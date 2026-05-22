//
// PerformanceTests.swift — E6 performance gates with hard time budgets.
//
// Two scaling concerns from the plan:
//   1. LOADING a large file (synthetic 50k individuals) must stay fast — exercises lexer + tree
//      builder + projection at scale.
//   2. The relationship calculator's "all relatives of X" sweep over the real 2k file must stay
//      fast — exercises ancestors()/pathUp() repeatedly.
//
// Budgets are deliberately generous (multiples of observed local times) so they catch a real
// regression — an accidental O(n²) — without flaking on a slow/loaded CI machine.
//
// NOTE on caching: GedcomDate.sortKey is recomputed on each access. Profiling here showed that's
// fast enough at these sizes (a few arithmetic ops), so per YAGNI we deliberately DID NOT add a
// sortKey cache or extra indexes. If a future workload makes this hot, cache at the call site
// (e.g. a precomputed PersonRow), not inside the value type.
//

import XCTest
@testable import GedcomKit

final class PerformanceTests: XCTestCase {

    /// Generate a synthetic GEDCOM document with `count` individuals linked into a lineage of
    /// 2-parent / 1-child families, so the tree builder and relationship index both do real work.
    private func makeSyntheticGedcom(individuals count: Int) -> String {
        var text = "0 HEAD\n1 GEDC\n2 VERS 5.5.1\n"
        text.reserveCapacity(count * 40)
        for i in 1...count {
            text += "0 @I\(i)@ INDI\n1 NAME Person\(i) /Test/\n1 SEX \(i % 2 == 0 ? "F" : "M")\n1 BIRT\n2 DATE \(1500 + i % 400)\n"
        }
        // Families: (i, i+1) are parents of i+2, forming a connected lineage.
        var familyNumber = 1
        var i = 1
        while i + 2 <= count {
            text += "0 @F\(familyNumber)@ FAM\n1 HUSB @I\(i)@\n1 WIFE @I\(i + 1)@\n1 CHIL @I\(i + 2)@\n"
            familyNumber += 1
            i += 2
        }
        text += "0 TRLR\n"
        return text
    }

    /// Loading 50k individuals must complete well under the budget and project them all.
    func testLoadsFiftyThousandIndividualsWithinBudget() {
        let text = makeSyntheticGedcom(individuals: 50_000)
        let data = Data(text.utf8)

        let start = Date()
        let doc = GedcomDocument.load(data)
        let elapsed = Date().timeIntervalSince(start)

        XCTAssertEqual(doc.individuals.count, 50_000)
        XCTAssertEqual(doc.diagnostics.filter { $0.severity == .error }, [])
        XCTAssertLessThan(elapsed, 8.0, "Loading 50k individuals took \(elapsed)s — possible scaling regression.")
    }

    /// Sweeping the whole 2k real file to find every relative of one person must stay fast.
    func testAllRelativesSweepOnRealFileWithinBudget() throws {
        let url = try XCTUnwrap(
            Bundle.module.url(forResource: "family", withExtension: "ged", subdirectory: "Fixtures"))
        let doc = GedcomDocument.load(try Data(contentsOf: url))
        let index = RelationshipIndex.build(from: doc)
        let john = Xref("@I001@")

        let start = Date()
        for other in doc.individuals.keys where other != john {
            _ = RelationshipCalculator.relationship(of: other, to: john, in: index, document: doc)
        }
        let elapsed = Date().timeIntervalSince(start)

        XCTAssertLessThan(elapsed, 5.0, "All-relatives sweep took \(elapsed)s — possible scaling regression.")
    }
}
