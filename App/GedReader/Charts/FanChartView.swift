//
// FanChartView.swift — a fan ancestor chart, FamilySearch-styled (A8).
//
// Design choices (from user feedback comparing to FamilySearch):
//   * WHITE background, dark text — most readable.
//   * Tasteful lineage COLOR, always on: each of the four grandparent branches gets a refined hue
//     (a muted Tableau-style palette, not FamilySearch's cyan/olive/yellow). It's applied as a SUBTLE
//     wedge tint plus a bold colored OUTER-RING arc — visible but never fighting the text.
//   * MULTI-LINE names: each label is a real SwiftUI Text in a wedge-sized frame, so it wraps (and
//     shrinks) to fit instead of overflowing the edges. A small birth–death line is added when known.
//   * Rotation by ring: inner rings (≤ radialMaxGeneration) read RADIALLY (along the spoke), outer
//     rings read TANGENTIALLY (along the arc) — matching FamilySearch's great-grandparents-and-out.
//
// Rendering is hybrid: a Canvas strokes the wedge outlines (and optional colored arcs); the names are
// positioned/rotated SwiftUI views on top (free wrapping + layout). Whole-wedge taps are handled by a
// polar hit-test. The fan is a half-fan (sweep π): root at bottom-center, ancestors sweeping the top.
//

import SwiftUI
import GedReaderCore
import GedcomKit

struct FanChartView: View {
    let layout: FanLayout
    let model: DocumentModel

    private let ringWidth: CGFloat = 96
    private let radialMaxGeneration = 2          // gens 1–2 radial; 3+ tangential
    private let lineageBuckets = 4

    private var radius: CGFloat { CGFloat(layout.generations) * ringWidth }
    private var center: CGPoint { CGPoint(x: radius, y: radius) }   // bottom-center; opens upward

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.white                                   // readable light background
            outlines
            ForEach(layout.wedges) { wedge in
                label(for: wedge)
                    .allowsHitTesting(false)              // taps fall through to the wedge hit-test
            }
        }
        .frame(width: radius * 2, height: radius)
        .contentShape(Rectangle())
        .gesture(SpatialTapGesture().onEnded { hitTest($0.location) })
    }

    // MARK: Wedge outlines (+ optional colored outer-ring arcs)

    private var outlines: some View {
        Canvas { context, _ in
            for wedge in layout.wedges {
                let inner = CGFloat(wedge.generation) * ringWidth
                let outer = inner + ringWidth
                let sector = sectorPath(inner: inner, outer: outer, wedge: wedge)
                let color = lineageColor(wedge)

                // Subtle lineage tint, light separators, and a bold colored arc on the outer edge.
                context.fill(sector, with: .color(color.opacity(0.16)))
                context.stroke(sector, with: .color(Color(white: 0.80)), lineWidth: 1)

                if wedge.generation > 0 {
                    var arc = Path()
                    arc.addArc(center: center, radius: outer - 1.5,
                               startAngle: .radians(wedge.startAngle), endAngle: .radians(wedge.endAngle),
                               clockwise: false)
                    context.stroke(arc, with: .color(color), lineWidth: 3)
                }
            }
        }
    }

    private func sectorPath(inner: CGFloat, outer: CGFloat, wedge: FanWedge) -> Path {
        var path = Path()
        let start = Angle.radians(wedge.startAngle), end = Angle.radians(wedge.endAngle)
        path.addArc(center: center, radius: outer, startAngle: start, endAngle: end, clockwise: false)
        path.addArc(center: center, radius: max(inner, 0.01), startAngle: end, endAngle: start, clockwise: true)
        path.closeSubpath()
        return path
    }

    // MARK: Name labels (wrapped, rotated SwiftUI text)

    private func label(for wedge: FanWedge) -> some View {
        let inner = CGFloat(wedge.generation) * ringWidth
        let midRadius = inner + ringWidth / 2
        let arcLength = CGFloat(wedge.endAngle - wedge.startAngle) * midRadius
        let point = CGPoint(x: center.x + cos(wedge.midAngle) * Double(midRadius),
                            y: center.y + sin(wedge.midAngle) * Double(midRadius))

        // Frame + rotation depend on radial vs tangential orientation.
        let radial = wedge.generation > 0 && wedge.generation <= radialMaxGeneration
        let w: CGFloat, h: CGFloat, rotation: Double
        if wedge.generation == 0 {
            (w, h, rotation) = (ringWidth * 1.6, ringWidth * 0.8, 0)            // root: horizontal
        } else if radial {
            (w, h, rotation) = (ringWidth * 0.82, arcLength * 0.9, radialRotation(wedge.midAngle))
        } else {
            (w, h, rotation) = (arcLength * 0.92, ringWidth * 0.82, wedge.midAngle + .pi / 2)
        }

        return labelContent(for: wedge)
            .frame(width: max(w, 30), height: max(h, 16))
            .rotationEffect(.radians(rotation))
            .position(point)
    }

    @ViewBuilder private func labelContent(for wedge: FanWedge) -> some View {
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

    /// "1882–1956" / "b. 1882" / "d. 1956" from the person's birth/death years, or nil if unknown.
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

    /// Radial text rotation: reads OUTWARD on the right half, INWARD on the left half, always upright.
    private func radialRotation(_ theta: Double) -> Double {
        cos(theta) >= 0 ? theta : theta + .pi
    }

    // MARK: Color

    /// A refined, muted four-color palette (Tableau-style) for the grandparent lineages — distinct
    /// but harmonious, and easy on a white background. The center person uses a neutral slate.
    private func lineageColor(_ wedge: FanWedge) -> Color {
        guard wedge.generation > 0 else { return Color(red: 0.42, green: 0.46, blue: 0.52) }  // slate
        let palette: [Color] = [
            Color(red: 0.31, green: 0.48, blue: 0.65),   // muted blue
            Color(red: 0.35, green: 0.63, blue: 0.49),   // sage green
            Color(red: 0.84, green: 0.42, blue: 0.40),   // terracotta red
            Color(red: 0.90, green: 0.68, blue: 0.31),   // warm amber
        ]
        let bucket = layout.lineageBucket(of: wedge, buckets: lineageBuckets)
        return palette[bucket % palette.count]
    }

    // MARK: Hit-testing

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
