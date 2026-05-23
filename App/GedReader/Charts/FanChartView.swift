//
// FanChartView.swift — a fan ancestor chart, FamilySearch-styled (A8).
//
// Layout (matches FamilySearch, per user feedback):
//   * WHITE background, dark text.
//   * Tasteful lineage color (refined 4-color palette) as a subtle wedge tint + a bold colored
//     OUTER-RING arc. Center person in neutral slate.
//   * INNER rings (generations 1…radialMaxGeneration): names are RADIAL — straight, multi-line
//     SwiftUI Text that wraps to fit the wedge (so long names don't overflow). Read outward; on the
//     left half they flip to stay upright (the unavoidable mirror of any fan's radial text).
//   * OUTER rings (beyond radialMaxGeneration): names are TANGENTIAL and CURVED — drawn glyph-by-
//     glyph along the arc (rotated tangent), the way FamilySearch curves great-grandparents and out.
//
// Rendering is hybrid: a Canvas draws the wedge fills/outlines/arcs AND the curved outer names; the
// radial inner names are positioned/rotated SwiftUI Text on top (free wrapping). Whole-wedge taps use
// a polar hit-test. The fan is a half-fan (sweep π): root at bottom-center, ancestors sweeping the top.
//

import SwiftUI
import GedReaderCore
import GedcomKit

struct FanChartView: View {
    let layout: FanLayout
    let model: DocumentModel

    private let ringWidth: CGFloat = 100
    private let radialMaxGeneration = 3          // gens 1–3 radial; 4+ tangential/curved
    private let lineageBuckets = 4

    private var radius: CGFloat { CGFloat(layout.generations) * ringWidth }
    private var center: CGPoint { CGPoint(x: radius, y: radius) }   // bottom-center; opens upward

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.white
            // Wedge geometry + colored arcs + the CURVED outer-ring names, all in one Canvas.
            Canvas { context, _ in
                for wedge in layout.wedges {
                    drawWedge(wedge, in: &context)
                    if wedge.generation > radialMaxGeneration {
                        drawCurvedNames(wedge, in: &context)
                    }
                }
            }
            // Radial inner names (and the root) as wrapping SwiftUI Text overlays.
            ForEach(layout.wedges.filter { $0.generation <= radialMaxGeneration }) { wedge in
                radialLabel(wedge).allowsHitTesting(false)
            }
        }
        .frame(width: radius * 2, height: radius)
        .contentShape(Rectangle())
        .gesture(SpatialTapGesture().onEnded { hitTest($0.location) })
    }

    // MARK: Wedge fill / outline / colored arc

    private func drawWedge(_ wedge: FanWedge, in context: inout GraphicsContext) {
        let inner = CGFloat(wedge.generation) * ringWidth
        let outer = inner + ringWidth
        let color = lineageColor(wedge)

        var sector = Path()
        let start = Angle.radians(wedge.startAngle), end = Angle.radians(wedge.endAngle)
        sector.addArc(center: center, radius: outer, startAngle: start, endAngle: end, clockwise: false)
        sector.addArc(center: center, radius: max(inner, 0.01), startAngle: end, endAngle: start, clockwise: true)
        sector.closeSubpath()

        context.fill(sector, with: .color(color.opacity(0.16)))
        context.stroke(sector, with: .color(Color(white: 0.80)), lineWidth: 1)
        if wedge.generation > 0 {
            var arc = Path()
            arc.addArc(center: center, radius: outer - 1.5, startAngle: start, endAngle: end, clockwise: false)
            context.stroke(arc, with: .color(color), lineWidth: 3)
        }
    }

    // MARK: Curved (tangential) outer-ring names

    private func drawCurvedNames(_ wedge: FanWedge, in context: inout GraphicsContext) {
        let person = model.document?.individuals[wedge.id]
        let midRadius = CGFloat(wedge.generation) * ringWidth + ringWidth / 2
        drawCurvedText(person?.displayName ?? wedge.id.value, in: &context,
                       radius: midRadius + 6, midAngle: wedge.midAngle, size: 10, weight: .medium)
        if let years = lifeYears(person) {
            drawCurvedText(years, in: &context, radius: midRadius - 12, midAngle: wedge.midAngle,
                           size: 8, weight: .regular, color: .gray)
        }
    }

    /// Draw `text` along the arc at `radius`, centered on `midAngle`, glyph-by-glyph, each rotated
    /// tangent (angle + π/2 keeps it readable for an upward fan: horizontal at top, turning up the sides).
    private func drawCurvedText(_ text: String, in context: inout GraphicsContext, radius: CGFloat,
                                midAngle: Double, size: CGFloat, weight: Font.Weight, color: Color = .black) {
        let chars = Array(text)
        guard !chars.isEmpty, radius > 0 else { return }
        let anglePerChar = Double(size) * 0.58 / Double(radius)
        var angle = midAngle - anglePerChar * Double(chars.count) / 2 + anglePerChar / 2
        for ch in chars {
            let p = CGPoint(x: center.x + cos(angle) * Double(radius), y: center.y + sin(angle) * Double(radius))
            context.drawLayer { layer in
                layer.translateBy(x: p.x, y: p.y)
                layer.rotate(by: .radians(angle + .pi / 2))
                layer.draw(Text(String(ch)).font(.system(size: size, weight: weight)).foregroundStyle(color), at: .zero)
            }
            angle += anglePerChar
        }
    }

    // MARK: Radial (inner) names — wrapping SwiftUI Text

    private func radialLabel(_ wedge: FanWedge) -> some View {
        let inner = CGFloat(wedge.generation) * ringWidth
        let midRadius = inner + ringWidth / 2
        let arcLength = CGFloat(wedge.endAngle - wedge.startAngle) * midRadius
        let point = CGPoint(x: center.x + cos(wedge.midAngle) * Double(midRadius),
                            y: center.y + sin(wedge.midAngle) * Double(midRadius))

        let w: CGFloat, h: CGFloat, rotation: Double
        if wedge.generation == 0 {
            (w, h, rotation) = (ringWidth * 1.6, ringWidth * 0.8, 0)              // root: horizontal
        } else {
            // Radial: text wraps along the radial extent (width), lines stack along the arc (height).
            (w, h, rotation) = (ringWidth * 0.84, arcLength * 0.92, radialRotation(wedge.midAngle))
        }

        return labelContent(wedge)
            .frame(width: max(w, 30), height: max(h, 16))
            .rotationEffect(.radians(rotation))
            .position(point)
    }

    @ViewBuilder private func labelContent(_ wedge: FanWedge) -> some View {
        let person = model.document?.individuals[wedge.id]
        VStack(spacing: 1) {
            Text(person?.displayName ?? wedge.id.value)
                .font(.system(size: wedge.generation == 0 ? 12 : 10, weight: .medium))
            if let years = lifeYears(person) {
                Text(years).font(.system(size: 8)).foregroundStyle(.secondary)
            }
        }
        .multilineTextAlignment(.center)
        .minimumScaleFactor(0.5)
        .lineLimit(4)
        .foregroundStyle(.black)
    }

    // MARK: Helpers

    /// Radial rotation: reads OUTWARD on the right half, flips to upright (reading inward) on the left
    /// half — the standard, unavoidable mirror of radial fan text.
    private func radialRotation(_ theta: Double) -> Double { cos(theta) >= 0 ? theta : theta + .pi }

    private func lifeYears(_ person: Individual?) -> String? {
        let b = person?.birth?.date?.earliest?.year ?? person?.birth?.date?.latest?.year
        let d = person?.death?.date?.earliest?.year ?? person?.death?.date?.latest?.year
        switch (b, d) {
        case let (b?, d?): return "\(b)–\(d)"
        case let (b?, nil): return "b. \(b)"
        case let (nil, d?): return "d. \(d)"
        case (nil, nil): return nil
        }
    }

    private func lineageColor(_ wedge: FanWedge) -> Color {
        guard wedge.generation > 0 else { return Color(red: 0.42, green: 0.46, blue: 0.52) }  // slate
        let palette: [Color] = [
            Color(red: 0.31, green: 0.48, blue: 0.65),   // muted blue
            Color(red: 0.35, green: 0.63, blue: 0.49),   // sage green
            Color(red: 0.84, green: 0.42, blue: 0.40),   // terracotta
            Color(red: 0.90, green: 0.68, blue: 0.31),   // amber
        ]
        return palette[layout.lineageBucket(of: wedge, buckets: lineageBuckets) % palette.count]
    }

    private func hitTest(_ location: CGPoint) {
        let dx = location.x - center.x, dy = location.y - center.y
        let ring = Int(hypot(dx, dy) / ringWidth)
        var angle = atan2(dy, dx)
        if angle < 0 { angle += 2 * .pi }
        if let wedge = layout.wedges.first(where: {
            $0.generation == ring && angle >= $0.startAngle && angle < $0.endAngle
        }) {
            model.navigate(to: wedge.id)
        }
    }
}
