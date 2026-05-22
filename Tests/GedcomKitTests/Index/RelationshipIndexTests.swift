//
// RelationshipIndexTests.swift — building the parent<->child graph + back-links from FAM records.
//

import XCTest
@testable import GedcomKit

final class RelationshipIndexTests: XCTestCase {

    /// A family of two parents + two children, like family.ged stores it (top-down on FAM).
    private func indexForTwoParentTwoChildFamily() -> RelationshipIndex {
        let doc = GedcomDocument.parse("""
        0 @I1@ INDI
        1 NAME Dad /X/
        0 @I2@ INDI
        1 NAME Mom /X/
        0 @I3@ INDI
        1 NAME Kid A /X/
        0 @I4@ INDI
        1 NAME Kid B /X/
        0 @F1@ FAM
        1 HUSB @I1@
        1 WIFE @I2@
        1 CHIL @I3@
        1 CHIL @I4@
        """)
        return RelationshipIndex.build(from: doc)
    }

    /// Tracer: both parents link to both children, in both directions.
    func testBuildsParentAndChildEdgesBothDirections() {
        let index = indexForTwoParentTwoChildFamily()

        // Each child has both parents.
        XCTAssertEqual(Set(index.parents(of: Xref("@I3@"))), [Xref("@I1@"), Xref("@I2@")])
        XCTAssertEqual(Set(index.parents(of: Xref("@I4@"))), [Xref("@I1@"), Xref("@I2@")])

        // Each parent has both children, in listed order.
        XCTAssertEqual(index.children(of: Xref("@I1@")), [Xref("@I3@"), Xref("@I4@")])
        XCTAssertEqual(index.children(of: Xref("@I2@")), [Xref("@I3@"), Xref("@I4@")])
    }

    /// FAMC/FAMS back-links are synthesized: children point back to the family-as-child, spouses to
    /// the family-as-spouse. (The source file has none of these; we reconstruct them.)
    func testSynthesizesFamilyBackLinks() {
        let index = indexForTwoParentTwoChildFamily()

        XCTAssertEqual(index.familiesAsChild[Xref("@I3@")], [Xref("@F1@")])
        XCTAssertEqual(index.familiesAsSpouse[Xref("@I1@")], [Xref("@F1@")])
        XCTAssertEqual(index.familiesAsSpouse[Xref("@I2@")], [Xref("@F1@")])
        XCTAssertNil(index.familiesAsChild[Xref("@I1@")])   // a parent isn't a child here
    }

    /// Edges to unknown individuals (dangling CHIL) are skipped, mirroring query.py's build_graph.
    func testSkipsEdgesToUnknownIndividuals() {
        let doc = GedcomDocument.parse("""
        0 @I1@ INDI
        1 NAME Dad /X/
        0 @F1@ FAM
        1 HUSB @I1@
        1 CHIL @I999@
        """)
        let index = RelationshipIndex.build(from: doc)
        XCTAssertEqual(index.children(of: Xref("@I1@")), [], "Dangling child pointer must not create an edge.")
    }
}
