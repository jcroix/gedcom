//
// ChartLayoutEngineTests.swift — pedigree (and later descendant/fan) layout geometry.
//

import XCTest
@testable import GedReaderCore
import GedcomKit

final class ChartLayoutEngineTests: XCTestCase {

    /// A 3-generation family: root @C@, parents @F@/@M@, grandparents @GF@/@GM@ (father's side).
    private func index() -> RelationshipIndex {
        let doc = GedcomDocument.parse("""
        0 @C@ INDI
        1 NAME Child /X/
        0 @F@ INDI
        1 NAME Father /X/
        0 @M@ INDI
        1 NAME Mother /X/
        0 @GF@ INDI
        1 NAME Grandfather /X/
        0 @GM@ INDI
        1 NAME Grandmother /X/
        0 @FAM1@ FAM
        1 HUSB @F@
        1 WIFE @M@
        1 CHIL @C@
        0 @FAM2@ FAM
        1 HUSB @GF@
        1 WIFE @GM@
        1 CHIL @F@
        """)
        return RelationshipIndex.build(from: doc)
    }

    func testPedigreePlacesGenerationsLeftToRightFatherAboveMother() {
        let layout = ChartLayoutEngine.pedigree(root: Xref("@C@"), generations: 3, index: index())

        func node(_ x: String) -> ChartNode? { layout.nodes.first { $0.id == Xref(x) } }

        // Root and both parents and one grandparent pair are placed (5 nodes).
        XCTAssertEqual(layout.nodes.count, 5)
        XCTAssertEqual(node("@C@")?.generation, 0)
        XCTAssertEqual(node("@F@")?.generation, 1)
        XCTAssertEqual(node("@GF@")?.generation, 2)

        // Generations grow left→right: gen 0 x < gen 1 x < gen 2 x.
        XCTAssertLessThan(node("@C@")!.center.x, node("@F@")!.center.x)
        XCTAssertLessThan(node("@F@")!.center.x, node("@GF@")!.center.x)

        // Within a couple, the father sits above the mother (smaller y).
        XCTAssertLessThan(node("@F@")!.center.y, node("@M@")!.center.y)
        XCTAssertLessThan(node("@GF@")!.center.y, node("@GM@")!.center.y)

        // Edges connect child→each parent: root has 2 parent edges; @F@ has 2 (its parents).
        XCTAssertEqual(layout.edges.count, 4)
        XCTAssertGreaterThan(layout.width, 0)
        XCTAssertGreaterThan(layout.height, 0)
    }

    /// A descendant chart: root above, two children below, root centered over them.
    func testDescendantPlacesRootAboveAndCenteredOverChildren() {
        let doc = GedcomDocument.parse("""
        0 @P@ INDI
        1 NAME Parent /X/
        0 @A@ INDI
        1 NAME ChildA /X/
        0 @B@ INDI
        1 NAME ChildB /X/
        0 @F@ FAM
        1 HUSB @P@
        1 CHIL @A@
        1 CHIL @B@
        """)
        let layout = ChartLayoutEngine.descendant(root: Xref("@P@"), depth: 2,
                                                  index: RelationshipIndex.build(from: doc))
        func node(_ x: String) -> ChartNode? { layout.nodes.first { $0.id == Xref(x) } }

        XCTAssertEqual(layout.nodes.count, 3)
        XCTAssertEqual(node("@P@")?.generation, 0)
        XCTAssertEqual(node("@A@")?.generation, 1)
        // Children are below the root (larger y), and the root sits between them horizontally.
        XCTAssertLessThan(node("@P@")!.center.y, node("@A@")!.center.y)
        let (ax, bx, px) = (node("@A@")!.center.x, node("@B@")!.center.x, node("@P@")!.center.x)
        XCTAssertEqual(px, (min(ax, bx) + max(ax, bx)) / 2, accuracy: 0.001)
        XCTAssertEqual(layout.edges.count, 2)   // parent → each child
    }

    /// A fan chart: root spans the whole sweep at ring 0; the father's wedge is the first half.
    func testFanRootSpansSweepAndFatherTakesFirstHalf() throws {
        let layout = ChartLayoutEngine.fan(root: Xref("@C@"), generations: 2, index: index(),
                                           sweep: .pi, startAngle: 0)
        func wedge(_ x: String) throws -> FanWedge { try XCTUnwrap(layout.wedges.first { $0.id == Xref(x) }) }

        XCTAssertEqual(try wedge("@C@").generation, 0)
        XCTAssertEqual(try wedge("@C@").startAngle, 0, accuracy: 0.0001)
        XCTAssertEqual(try wedge("@C@").endAngle, .pi, accuracy: 0.0001)
        // Father (@F@) takes [0, π/2); mother (@M@) takes [π/2, π).
        XCTAssertEqual(try wedge("@F@").startAngle, 0, accuracy: 0.0001)
        XCTAssertEqual(try wedge("@F@").endAngle, .pi / 2, accuracy: 0.0001)
        XCTAssertEqual(try wedge("@M@").startAngle, .pi / 2, accuracy: 0.0001)
    }
}
