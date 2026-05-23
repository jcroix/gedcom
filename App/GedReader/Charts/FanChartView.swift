//
// FanChartView.swift — a colored polar fan ancestor chart with curved names (A8).
//
// Pure-Canvas rendering. Each FanWedge is an annular sector, FILLED with a lineage color (the four
// grandparent branches get distinct hues via FanLayout.lineageBucket, alternating brightness by ring
// so concentric generations read apart). Each ancestor's NAME is drawn CURVED along its ring — laid
// out glyph-by-glyph, each rotated tangent to the arc — matching the FamilySearch fan style. The
// center person (generation 0) uses the accent color and horizontal text.
//
// Tap hit-testing is polar: a SpatialTapGesture point → (ring, angle) → matching wedge → navigate.
// The fan is a half-fan (sweep π): the root sits at bottom-center, ancestors sweep across the top,
// so the tangent rotation (angle + π/2) reads horizontally at the top and turns up the sides.
//

import SwiftUI
import GedReaderCore
import GedcomKit

struct FanChartView: View {
    let layout: FanLayout
    let model: DocumentModel

    private let ringWidth: CGFloat = 84
    private let fontSize: CGFloat = 10
    private let lineageBuckets = 4

    private var radius: CGFloat { CGFloat(layout.generations) * ringWidth }
    private var center: CGPoint { CGPoint(x: radius, y: radius) }   // bottom-center; fan opens up

    var body: some View {
        Canvas { context, _ in
            for wedge in layout.wedges {
                draw(wedge, in: &context)
            }
        }
        .frame(width: radius * 2, height: radius)
        .contentShape(Rectangle())
        .gesture(SpatialTapGesture().onEnded { value in hitTest(value.location) })
    }

    // MARK: Drawing one wedge

    private func draw(_ wedge: FanWedge, in context: inout GraphicsContext) {
        let inner = CGFloat(wedge.generation) * ringWidth
        let outer = inner + ringWidth
        let start = Angle.radians(wedge.startAngle)
        let end = Angle.radians(wedge.endAngle)

        // Annular sector path (outer arc forward, inner arc back).
        var path = Path()
        path.addArc(center: center, radius: outer, startAngle: start, endAngle: end, clockwise: false)
        path.addArc(center: center, radius: max(inner, 0.01), startAngle: end, endAngle: start, clockwise: true)
        path.closeSubpath()

        let bucket = layout.lineageBucket(of: wedge, buckets: lineageBuckets)
        context.fill(path, with: .color(fillColor(wedge: wedge, bucket: bucket)))
        context.stroke(path, with: .color(strokeColor(wedge: wedge, bucket: bucket)), lineWidth: 1)

        // Name.
        let name = model.document?.individuals[wedge.id]?.displayName ?? wedge.id.value
        let textColor: Color = wedge.generation == 0 ? .white : .black
        let midRadius = (inner + outer) / 2
        if wedge.generation == 0 {
            // Root: a tiny inner half-ring — horizontal text reads better than curved.
            let point = CGPoint(x: center.x + cos(wedge.midAngle) * midRadius,
                                y: center.y + sin(wedge.midAngle) * midRadius)
            context.draw(Text(name).font(.system(size: fontSize)).foregroundStyle(textColor), at: point)
        } else {
            drawCurvedName(name, in: &context, radius: midRadius, midAngle: wedge.midAngle, color: textColor)
        }
    }

    /// Draw `name` along the arc at `radius`, centered on `midAngle`, one glyph at a time with each
    /// rotated tangent to the arc (angle + π/2 keeps it readable for an upward-opening fan).
    private func drawCurvedName(_ name: String, in context: inout GraphicsContext,
                                radius: CGFloat, midAngle: Double, color: Color) {
        let chars = Array(name)
        guard !chars.isEmpty, radius > 0 else { return }
        let avgCharWidth = Double(fontSize) * 0.58
        let anglePerChar = avgCharWidth / Double(radius)            // radians each glyph occupies
        var angle = midAngle - anglePerChar * Double(chars.count) / 2 + anglePerChar / 2

        for ch in chars {
            let point = CGPoint(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius)
            context.drawLayer { layer in
                layer.translateBy(x: point.x, y: point.y)
                layer.rotate(by: .radians(angle + .pi / 2))         // tangent to the arc
                layer.draw(Text(String(ch)).font(.system(size: fontSize)).foregroundStyle(color), at: .zero)
            }
            angle += anglePerChar
        }
    }

    // MARK: Colors (four lineage hues; brightness alternates per ring; root uses the accent)

    private func fillColor(wedge: FanWedge, bucket: Int) -> Color {
        if wedge.generation == 0 { return .accentColor }
        let hues: [Double] = [0.58, 0.40, 0.03, 0.13]               // blue, green, red, yellow
        let hue = hues[bucket % hues.count]
        let brightness = wedge.generation.isMultiple(of: 2) ? 0.82 : 0.72   // distinguish rings
        return Color(hue: hue, saturation: 0.45, brightness: brightness)
    }

    private func strokeColor(wedge: FanWedge, bucket: Int) -> Color {
        if wedge.generation == 0 { return .white.opacity(0.6) }
        let hues: [Double] = [0.58, 0.40, 0.03, 0.13]
        return Color(hue: hues[bucket % hues.count], saturation: 0.6, brightness: 0.5)
    }

    // MARK: Hit-testing

    private func hitTest(_ location: CGPoint) {
        let dx = location.x - center.x
        let dy = location.y - center.y
        let ring = Int((hypot(dx, dy)) / ringWidth)
        var angle = atan2(dy, dx)
        if angle < 0 { angle += 2 * .pi }
        if let wedge = layout.wedges.first(where: {
            $0.generation == ring && angle >= $0.startAngle && angle < $0.endAngle
        }) {
            model.navigate(to: wedge.id)
        }
    }
}
