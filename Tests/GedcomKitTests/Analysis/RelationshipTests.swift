//
// RelationshipTests.swift — relationship-label behavior on small synthetic trees.
//
// Each test builds a tiny family and asserts the English label, exercising one branch of the
// algorithm (ancestor, descendant, sibling, aunt/uncle, niece/nephew, cousins, removed cousins).
// These pin the port to query.py's labels deterministically; golden tests against the real file
// (and query.py itself) live in RelationshipGoldenTests.
//

import XCTest
@testable import GedcomKit

final class RelationshipTests: XCTestCase {

    /// Helper: build a document + relationship index from GEDCOM text.
    private func setup(_ text: String) -> (GedcomDocument, RelationshipIndex) {
        let doc = GedcomDocument.parse(text)
        return (doc, RelationshipIndex.build(from: doc))
    }

    /// Convenience: label for "subject is the <label> of base".
    private func label(of subject: String, to base: String,
                       _ doc: GedcomDocument, _ index: RelationshipIndex) -> String {
        RelationshipCalculator.relationship(of: Xref(subject), to: Xref(base), in: index, document: doc).label
    }

    /// Tracer: a father. I1 (male) is the parent of I3, so I1 is the "father" of I3.
    func testParentIsFather() {
        let (doc, index) = setup("""
        0 @I1@ INDI
        1 NAME Dad /X/
        1 SEX M
        0 @I3@ INDI
        1 NAME Kid /X/
        0 @F1@ FAM
        1 HUSB @I1@
        1 CHIL @I3@
        """)
        XCTAssertEqual(label(of: "@I1@", to: "@I3@", doc, index), "father")
    }

    // MARK: A 4-generation tree exercising every label branch.
    //
    //   G1(M) = G2(F)                         (generation 1, grandparents)
    //       |
    //     +---------+                         P1 and P2 are siblings (generation 2)
    //     |         |
    //   P1(M)=S1   P2(F)=S2
    //     |              |
    //   C1(M)          C2(F)                  C1 and C2 are first cousins (generation 3)
    //     |
    //   D1(M)                                 D1 is generation 4
    //
    private static let tree = """
    0 @G1@ INDI
    1 NAME Grandpa /A/
    1 SEX M
    0 @G2@ INDI
    1 NAME Grandma /A/
    1 SEX F
    0 @P1@ INDI
    1 NAME ParentOne /A/
    1 SEX M
    0 @P2@ INDI
    1 NAME ParentTwo /A/
    1 SEX F
    0 @S1@ INDI
    1 NAME SpouseOne /B/
    1 SEX F
    0 @S2@ INDI
    1 NAME SpouseTwo /C/
    1 SEX M
    0 @C1@ INDI
    1 NAME CousinOne /A/
    1 SEX M
    0 @C2@ INDI
    1 NAME CousinTwo /C/
    1 SEX F
    0 @D1@ INDI
    1 NAME DescendOne /A/
    1 SEX M
    0 @U1@ INDI
    1 NAME Unrelated /Z/
    1 SEX M
    0 @F1@ FAM
    1 HUSB @G1@
    1 WIFE @G2@
    1 CHIL @P1@
    1 CHIL @P2@
    0 @F2@ FAM
    1 HUSB @P1@
    1 WIFE @S1@
    1 CHIL @C1@
    0 @F3@ FAM
    1 HUSB @S2@
    1 WIFE @P2@
    1 CHIL @C2@
    0 @F4@ FAM
    1 HUSB @C1@
    1 CHIL @D1@
    """

    private func bigTree() -> (GedcomDocument, RelationshipIndex) { setup(Self.tree) }

    func testDescendantLabels() {
        let (doc, index) = bigTree()
        XCTAssertEqual(label(of: "@C1@", to: "@G1@", doc, index), "grandson")      // C1 is grandson of G1
        XCTAssertEqual(label(of: "@D1@", to: "@G1@", doc, index), "great-grandson")
    }

    func testAncestorLabels() {
        let (doc, index) = bigTree()
        XCTAssertEqual(label(of: "@G1@", to: "@C1@", doc, index), "grandfather")
        XCTAssertEqual(label(of: "@G2@", to: "@D1@", doc, index), "great-grandmother")
    }

    func testSiblings() {
        let (doc, index) = bigTree()
        XCTAssertEqual(label(of: "@P1@", to: "@P2@", doc, index), "sibling")
    }

    func testAuntUncleAndNieceNephew() {
        let (doc, index) = bigTree()
        XCTAssertEqual(label(of: "@P2@", to: "@C1@", doc, index), "aunt")    // P2(F) is C1's aunt
        XCTAssertEqual(label(of: "@C1@", to: "@P2@", doc, index), "nephew")  // C1(M) is P2's nephew
    }

    func testGreatAunt() {
        let (doc, index) = bigTree()
        XCTAssertEqual(label(of: "@P2@", to: "@D1@", doc, index), "great-aunt")   // removal 2
    }

    func testFirstCousins() {
        let (doc, index) = bigTree()
        XCTAssertEqual(label(of: "@C1@", to: "@C2@", doc, index), "1st cousin")
    }

    func testFirstCousinOnceRemoved() {
        let (doc, index) = bigTree()
        XCTAssertEqual(label(of: "@D1@", to: "@C2@", doc, index), "1st cousin 1× removed")
    }

    func testSamePersonAndUnrelated() {
        let (doc, index) = bigTree()
        XCTAssertEqual(label(of: "@P1@", to: "@P1@", doc, index), "same person")
        XCTAssertEqual(label(of: "@U1@", to: "@C1@", doc, index), "no known connection")
    }

    /// The connecting path runs base -> LCA -> subject. For first cousins C1 and C2 (base C2),
    /// the path goes up from C2 to the shared grandparent and back down to C1.
    func testCollateralPathThroughCommonAncestor() {
        let (doc, index) = bigTree()
        let result = RelationshipCalculator.relationship(of: Xref("@C1@"), to: Xref("@C2@"),
                                                         in: index, document: doc)
        // base (C2) first, subject (C1) last; the LCA (a grandparent) sits in the middle.
        XCTAssertEqual(result.path?.first, Xref("@C2@"))
        XCTAssertEqual(result.path?.last, Xref("@C1@"))
        XCTAssertTrue(result.path?.contains(Xref("@G1@")) ?? false,
                      "Path should pass through the deterministic common ancestor @G1@.")
    }
}
