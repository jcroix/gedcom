//
// FanChartView.swift — a polar fan ancestor chart (A8).
//
// Pure-Canvas rendering: each FanWedge is drawn as an annular sector (two arcs), with the person's
// name drawn at the wedge's mid-angle/mid-radius. Hit-testing is polar: a SpatialTapGesture gives the
// tap point, which we convert to (ring, angle) and match against the wedges to find the tapped
// ancestor, then navigate. The layout (angles) comes from the unit-tested ChartLayoutEngine.fan.
//
// The fan is a half-fan (sweep π): the root sits at bottom-center and ancestors sweep across the top.
//

import SwiftUI
import GedReaderCore
import GedcomKit

struct FanChartView: View {
    let layout: FanLayout
    let model: DocumentModel

    private let ringWidth: CGFloat = 78

    /// Outer radius of the whole fan.
    private var radius: CGFloat { CGFloat(layout.generations) * ringWidth }
    /// Center is bottom-middle of the bounding box (a half-fan opens upward).
    private var center: CGPoint { CGPoint(x: radius, y: radius) }

    var body: some View {
        Canvas { context, _ in
            for wedge in layout.wedges {
                let inner = CGFloat(wedge.generation) * ringWidth
                let outer = inner + ringWidth
                let start = Angle.radians(wedge.startAngle)
                let end = Angle.radians(wedge.endAngle)

                // Annular sector: outer arc forward, inner arc back, closed.
                var path = Path()
                path.addArc(center: center, radius: outer, startAngle: start, endAngle: end, clockwise: false)
                path.addArc(center: center, radius: inner, startAngle: end, endAngle: start, clockwise: true)
                path.closeSubpath()
                context.fill(path, with: .color(Color(white: 0.5).opacity(0.10)))
                context.stroke(path, with: .color(.secondary.opacity(0.5)), lineWidth: 1)

                // Name at the wedge midpoint.
                let midRadius = (inner + outer) / 2
                let point = CGPoint(x: center.x + cos(wedge.midAngle) * midRadius,
                                    y: center.y + sin(wedge.midAngle) * midRadius)
                let name = model.document?.individuals[wedge.id]?.displayName ?? wedge.id.value
                context.draw(Text(name).font(.system(size: 9)), at: point)
            }
        }
        .frame(width: radius * 2, height: radius)
        .contentShape(Rectangle())
        .gesture(SpatialTapGesture().onEnded { value in hitTest(value.location) })
    }

    /// Convert a tap point to (ring, angle) and navigate to the matching wedge's person.
    private func hitTest(_ location: CGPoint) {
        let dx = location.x - center.x
        let dy = location.y - center.y
        let ring = Int((hypot(dx, dy)) / ringWidth)
        var angle = atan2(dy, dx)
        if angle < 0 { angle += 2 * .pi }     // normalize to [0, 2π) to match wedge angles
        if let wedge = layout.wedges.first(where: {
            $0.generation == ring && angle >= $0.startAngle && angle < $0.endAngle
        }) {
            model.navigate(to: wedge.id)
        }
    }
}
