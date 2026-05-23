//
// ChartLayoutEngine.swift — pure geometry for the pedigree / descendant / fan charts (A8).
//
// The charts use a hybrid renderer: this engine computes node positions (and connector endpoints,
// or fan wedge angles) OFF the main thread; the SwiftUI views then draw connectors in a Canvas and
// place tappable node cards at those positions. Keeping the math here (plain Doubles, no CoreGraphics
// or SwiftUI) makes the layout — the part most likely to be subtly wrong — unit-testable.
//
// Coordinate system: origin top-left, x grows right, y grows down (matches SwiftUI). Pedigree grows
// LEFT→RIGHT (root at left, ancestors fanning right); descendant grows TOP→DOWN.
//
// STUB (TDD red phase): layout functions return empty until tests drive them.
//

import GedcomKit

/// A point in chart space (top-left origin). Plain Doubles so it's trivially Sendable.
public struct ChartPoint: Sendable, Equatable {
    public let x: Double
    public let y: Double
    public init(x: Double, y: Double) { self.x = x; self.y = y }
}

/// One placed person card.
public struct ChartNode: Identifiable, Sendable, Equatable {
    public let id: Xref
    public let center: ChartPoint
    public let generation: Int
    public init(id: Xref, center: ChartPoint, generation: Int) {
        self.id = id; self.center = center; self.generation = generation
    }
}

/// A connector between two placed nodes (center-to-center; the view insets to card edges).
public struct ChartEdge: Sendable, Equatable {
    public let from: ChartPoint
    public let to: ChartPoint
    public init(from: ChartPoint, to: ChartPoint) { self.from = from; self.to = to }
}

/// A laid-out chart: nodes, connecting edges, and the total canvas size needed.
public struct ChartLayout: Sendable, Equatable {
    public let nodes: [ChartNode]
    public let edges: [ChartEdge]
    public let width: Double
    public let height: Double
    public init(nodes: [ChartNode], edges: [ChartEdge], width: Double, height: Double) {
        self.nodes = nodes; self.edges = edges; self.width = width; self.height = height
    }
}

public enum ChartLayoutEngine {

    /// Lay out an ANCESTOR (pedigree) chart rooted at `root`, `generations` columns wide (gen 0 =
    /// root at the left). Each ancestor occupies a vertical band; a node's father takes the upper
    /// half of its band and its mother the lower half (the classic bracket pedigree). Missing
    /// ancestors simply leave their slot empty. `cardWidth`/`cardHeight` size the cards;
    /// `hGap`/`rowHeight` space columns and the finest generation's rows.
    public static func pedigree(root: Xref,
                                generations: Int,
                                index: RelationshipIndex,
                                cardWidth: Double = 180,
                                cardHeight: Double = 44,
                                hGap: Double = 40,
                                rowHeight: Double = 60) -> ChartLayout {
        var nodes: [ChartNode] = []
        var edges: [ChartEdge] = []

        let columnWidth = cardWidth + hGap
        // The finest generation has up to 2^(generations-1) slots; that sets the total height.
        let slots = Double(1 << max(0, generations - 1))
        let totalHeight = slots * rowHeight
        let totalWidth = Double(generations) * columnWidth - hGap   // no trailing gap after last column

        // Center x for a given generation's column.
        func centerX(_ generation: Int) -> Double { Double(generation) * columnWidth + cardWidth / 2 }

        // Place `person` centered in the vertical band [yTop, yBottom]; recurse to its parents,
        // father in the upper half, mother in the lower half (classic bracket pedigree).
        func place(_ person: Xref, generation: Int, yTop: Double, yBottom: Double) {
            let center = ChartPoint(x: centerX(generation), y: (yTop + yBottom) / 2)
            nodes.append(ChartNode(id: person, center: center, generation: generation))

            guard generation + 1 < generations else { return }
            let parents = index.parents(of: person)
            let mid = (yTop + yBottom) / 2

            if let father = parents.first {
                edges.append(ChartEdge(from: center,
                                       to: ChartPoint(x: centerX(generation + 1), y: (yTop + mid) / 2)))
                place(father, generation: generation + 1, yTop: yTop, yBottom: mid)
            }
            if parents.count > 1 {
                edges.append(ChartEdge(from: center,
                                       to: ChartPoint(x: centerX(generation + 1), y: (mid + yBottom) / 2)))
                place(parents[1], generation: generation + 1, yTop: mid, yBottom: yBottom)
            }
        }

        place(root, generation: 0, yTop: 0, yBottom: totalHeight)
        return ChartLayout(nodes: nodes, edges: edges, width: totalWidth, height: totalHeight)
    }

    /// Lay out a DESCENDANT chart rooted at `root`, growing top→down for `depth` generations. Each
    /// node is centered horizontally over its laid-out children (a simple tidy tree); leaves are
    /// packed left-to-right. `document` is used only to keep the traversal deterministic via the
    /// relationship index. Cycles/duplicate descendants are guarded against by a visited set.
    public static func descendant(root: Xref,
                                  depth: Int,
                                  index: RelationshipIndex,
                                  cardWidth: Double = 180,
                                  cardHeight: Double = 44,
                                  hGap: Double = 24,
                                  rowHeight: Double = 90) -> ChartLayout {
        var nodes: [ChartNode] = []
        var edges: [ChartEdge] = []
        var visited: Set<Xref> = []
        var leafCursor = 0.0
        let slotWidth = cardWidth + hGap

        // Returns the center x assigned to `person`.
        @discardableResult
        func place(_ person: Xref, generation: Int) -> Double {
            visited.insert(person)
            let y = Double(generation) * rowHeight + cardHeight / 2
            let children = (generation + 1 < depth)
                ? index.children(of: person).filter { !visited.contains($0) }
                : []

            let centerX: Double
            if children.isEmpty {
                centerX = leafCursor * slotWidth + cardWidth / 2   // pack leaves left-to-right
                leafCursor += 1
            } else {
                let childXs = children.map { place($0, generation: generation + 1) }
                centerX = (childXs.min()! + childXs.max()!) / 2    // center over children
            }

            let center = ChartPoint(x: centerX, y: y)
            nodes.append(ChartNode(id: person, center: center, generation: generation))
            for child in children {
                if let childNode = nodes.first(where: { $0.id == child }) {
                    edges.append(ChartEdge(from: center, to: childNode.center))
                }
            }
            return centerX
        }

        place(root, generation: 0)
        let width = max(leafCursor * slotWidth, slotWidth)
        let height = Double(depth) * rowHeight
        return ChartLayout(nodes: nodes, edges: edges, width: width, height: height)
    }

    /// Lay out a FAN (ancestor) chart: the root occupies the center ring (generation 0) spanning the
    /// whole `sweep`; each ancestor's wedge splits in half for its father (first half) and mother
    /// (second half) one ring out. Returns angular wedges (the FanChartView draws polar arcs and
    /// does polar→wedge hit-testing). Angles are radians measured clockwise from `startAngle`.
    public static func fan(root: Xref,
                           generations: Int,
                           index: RelationshipIndex,
                           sweep: Double = .pi,
                           startAngle: Double = .pi) -> FanLayout {
        var wedges: [FanWedge] = []

        func place(_ person: Xref, generation: Int, start: Double, end: Double) {
            wedges.append(FanWedge(id: person, generation: generation, startAngle: start, endAngle: end))
            guard generation + 1 < generations else { return }
            let parents = index.parents(of: person)
            let mid = (start + end) / 2
            if let father = parents.first { place(father, generation: generation + 1, start: start, end: mid) }
            if parents.count > 1 { place(parents[1], generation: generation + 1, start: mid, end: end) }
        }

        place(root, generation: 0, start: startAngle, end: startAngle + sweep)
        return FanLayout(wedges: wedges, generations: generations)
    }
}

/// One ancestor's angular wedge in a fan chart (ring = generation; angles in radians).
public struct FanWedge: Identifiable, Sendable, Equatable {
    public let id: Xref
    public let generation: Int
    public let startAngle: Double
    public let endAngle: Double
    public init(id: Xref, generation: Int, startAngle: Double, endAngle: Double) {
        self.id = id; self.generation = generation; self.startAngle = startAngle; self.endAngle = endAngle
    }
    /// The angle at the middle of this wedge (where a label/card is centered).
    public var midAngle: Double { (startAngle + endAngle) / 2 }
}

/// A laid-out fan chart.
public struct FanLayout: Sendable, Equatable {
    public let wedges: [FanWedge]
    public let generations: Int
    public init(wedges: [FanWedge], generations: Int) {
        self.wedges = wedges; self.generations = generations
    }

    /// Which lineage "bucket" a wedge belongs to, for consistent per-branch coloring (à la
    /// FamilySearch's 4 grandparent colors). Buckets divide the whole fan sweep into `buckets`
    /// equal angular slices, so every ancestor in the same slice (the same descending branch)
    /// gets the same bucket regardless of generation. The root (gen 0) spans everything; callers
    /// typically color it separately.
    public func lineageBucket(of wedge: FanWedge, buckets: Int) -> Int {
        guard buckets > 0, let root = wedges.first(where: { $0.generation == 0 }) else { return 0 }
        let span = root.endAngle - root.startAngle
        guard span > 0 else { return 0 }
        let fraction = (wedge.midAngle - root.startAngle) / span      // 0..1 across the fan
        return min(max(Int(fraction * Double(buckets)), 0), buckets - 1)
    }
}
