//
// FanChartView.swift — a fan ancestor chart, FamilySearch-styled (A8).
//
// ONE CONSISTENT TEXT RULE (after earlier inconsistency):
//   * The center person (generation 0) is drawn HORIZONTALLY.
//   * EVERY ancestor ring draws its name TANGENTIALLY — curved along the arc, glyph-by-glyph — and
//     WRAPS onto multiple curved lines so long names fit instead of overflowing. There is no radial
//     text and no per-generation switching, so orientation is uniform everywhere.
//
// Curved-glyph rotation is `glyphAngle + π/2`, which for this upward-opening half-fan reads
// horizontally across the top and turns smoothly up the sides — never upside down.
//
// Styling: white background, dark text, a refined 4-color lineage palette as a subtle wedge tint
// plus a bold colored OUTER-RING arc; the center is neutral slate. Whole-wedge taps use a polar
// hit-test. The fan is a half-fan (sweep π): root at bottom-center, ancestors sweeping the top.
//

import SwiftUI
import GedReaderCore
import GedcomKit

struct FanChartView: View {
    let layout: FanLayout
    let model: DocumentModel

    private let ringWidth: CGFloat = 104
    private let lineageBuckets = 4
    private let nameSize: CGFloat = 10
    private let dateSize: CGFloat = 8
    private let lineSpacing: CGFloat = 12          // radial px between wrapped lines

    private var radius: CGFloat { CGFloat(layout.generations) * ringWidth }

    /// Total angular sweep of the fan (read from the root wedge, which spans it all).
    private var sweep: Double { layout.wedges.first { $0.generation == 0 }.map { $0.endAngle - $0.startAngle } ?? .pi }

    /// Center sits where the top of the fan is `radius` above it. For sweeps wider than 180° the fan
    /// dips below the center on the sides, so the frame is taller than `radius`.
    private var center: CGPoint { CGPoint(x: radius, y: radius) }
    private var frameHeight: CGFloat { radius * CGFloat(max(1.0, 1.0 - cos(sweep / 2))) }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.white
            Canvas { context, _ in
                for wedge in layout.wedges {
                    drawWedge(wedge, in: &context)
                    drawNames(wedge, in: &context)
                }
            }
        }
        .frame(width: radius * 2, height: frameHeight)
        .contentShape(Rectangle())
        .gesture(SpatialTapGesture().onEnded { hitTest($0.location) })
    }

    // MARK: Wedge fill / outline / colored arc

    private func drawWedge(_ wedge: FanWedge, in context: inout GraphicsContext) {
        let inner = CGFloat(wedge.generation) * ringWidth
        let outer = inner + ringWidth
        let color = lineageColor(wedge)
        let start = Angle.radians(wedge.startAngle), end = Angle.radians(wedge.endAngle)

        var sector = Path()
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

    // MARK: Names

    private func drawNames(_ wedge: FanWedge, in context: inout GraphicsContext) {
        let person = model.document?.individuals[wedge.id]
        let name = person?.displayName ?? wedge.id.value
        let dates = lifeYears(person)

        // Center person: horizontal, multi-line.
        if wedge.generation == 0 {
            let point = CGPoint(x: center.x, y: center.y - Double(ringWidth) / 2)
            let text = (dates == nil) ? name : "\(name)\n\(dates!)"
            context.draw(Text(text).font(.system(size: nameSize + 2, weight: .medium))
                .foregroundStyle(.black), at: point)
            return
        }

        // Ancestors: curved, wrapped, name lines then a date line, centered in the ring.
        let inner = CGFloat(wedge.generation) * ringWidth
        let midRadius = inner + ringWidth / 2
        let wedgeAngle = wedge.endAngle - wedge.startAngle
        let maxChars = max(4, Int(wedgeAngle * Double(midRadius) * 0.86 / (Double(nameSize) * 0.58)))

        var lines = wrap(name, maxChars: maxChars)
        if lines.count > 4 { lines = Array(lines.prefix(4)) }     // keep paragraphs sane
        let total = CGFloat(lines.count) + (dates == nil ? 0 : 0.85)
        var r = midRadius + (total - 1) / 2 * lineSpacing         // first (outer) line

        for line in lines {
            drawCurvedLine(line, in: &context, radius: r, midAngle: wedge.midAngle,
                           size: nameSize, weight: .medium, color: .black)
            r -= lineSpacing
        }
        if let dates {
            drawCurvedLine(dates, in: &context, radius: r, midAngle: wedge.midAngle,
                           size: dateSize, weight: .regular, color: Color(white: 0.45))
        }
    }

    /// Greedy word wrap to lines of at most `maxChars` characters (a single long word gets its own line).
    private func wrap(_ text: String, maxChars: Int) -> [String] {
        var lines: [String] = []
        var current = ""
        for word in text.split(separator: " ") {
            if current.isEmpty { current = String(word) }
            else if current.count + 1 + word.count <= maxChars { current += " " + word }
            else { lines.append(current); current = String(word) }
        }
        if !current.isEmpty { lines.append(current) }
        return lines.isEmpty ? [text] : lines
    }

    /// Draw one line of text along the arc at `radius`, centered on `midAngle`, glyph-by-glyph with
    /// each rotated tangent (`angle + π/2` — readable across the top, turning up the sides).
    private func drawCurvedLine(_ text: String, in context: inout GraphicsContext, radius: CGFloat,
                                midAngle: Double, size: CGFloat, weight: Font.Weight, color: Color) {
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

    // MARK: Helpers

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
