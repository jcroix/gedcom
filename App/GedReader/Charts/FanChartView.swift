//
// FanChartView.swift — a fan ancestor chart, FamilySearch-styled (A8).
//
// TEXT ORIENTATION RULE (exactly as FamilySearch does it):
//   * Generation 0 (center person): HORIZONTAL.
//   * Generations 1–2 (parents, grandparents): TANGENTIAL — curved along the arc, glyph-by-glyph
//     (inner rings have long arcs, so curved text fits there).
//   * Generation 3 and beyond: RADIAL — straight text reading outward along the spoke, multi-line
//     (given / surname / dates), long parts truncated with "…" (outer rings are angularly narrow,
//     so radial-outward text fits where curved wouldn't).
//
// Rendering is hybrid: a Canvas draws the wedge fills/outlines/colored arcs, the horizontal center
// label, and the curved (gen 1–2) names. The radial (gen 3+) names are wrapping/truncating SwiftUI
// Text overlays (rotated + positioned). Whole-wedge taps use a polar hit-test.
//
// The fan is a 270° sweep (set by the caller) centered at the top: root at bottom-center, ancestors
// sweeping up and around, gap at the bottom — like FamilySearch.
//

import SwiftUI
import GedReaderCore
import GedcomKit

struct FanChartView: View {
    let layout: FanLayout
    let model: DocumentModel
    /// Left-click on a wedge (select / show details).
    var onSelect: (Xref) -> Void = { _ in }
    /// Right-click menu choice: re-root the chart on this person as the given chart kind.
    var onPickChart: (Xref, ChartKind) -> Void = { _, _ in }
    /// Forces a wedge to render highlighted (used only by the offscreen render hook to verify hover).
    var previewHover: Xref? = nil

    /// The wedge currently under the mouse (drives the hover highlight + the context menu target).
    @State private var hoveredXref: Xref?

    private let ringWidth: CGFloat = 116
    private let curvedMaxGeneration = 2          // gens 1–2 curved/tangential; 3+ radial
    private let lineageBuckets = 4
    private let nameSize: CGFloat = 10
    private let dateSize: CGFloat = 8
    private let curvedLineSpacing: CGFloat = 12

    private var radius: CGFloat { CGFloat(layout.generations) * ringWidth }
    private var sweep: Double { layout.wedges.first { $0.generation == 0 }.map { $0.endAngle - $0.startAngle } ?? .pi }
    private var center: CGPoint { CGPoint(x: radius, y: radius) }
    private var frameHeight: CGFloat { radius * CGFloat(max(1.0, 1.0 - cos(sweep / 2))) }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.white
            Canvas { context, _ in
                for wedge in layout.wedges {
                    drawWedge(wedge, in: &context)
                    if wedge.generation == 0 { drawCenterLabel(wedge, in: &context) }
                    else if wedge.generation <= curvedMaxGeneration { drawCurvedNames(wedge, in: &context) }
                }
            }
            // Radial (gen 3+) names as wrapping/truncating SwiftUI overlays.
            ForEach(layout.wedges.filter { $0.generation > curvedMaxGeneration }) { wedge in
                radialLabel(wedge).allowsHitTesting(false)
            }
        }
        .frame(width: radius * 2, height: frameHeight)
        .contentShape(Rectangle())
        // Left-click selects the wedge under the cursor.
        .gesture(SpatialTapGesture(coordinateSpace: .local).onEnded {
            if let wedge = wedge(at: $0.location) { onSelect(wedge.id) }
        })
        // Track the mouse to highlight the hovered wedge (white → light grey, FamilySearch-style).
        .onContinuousHover(coordinateSpace: .local) { phase in
            switch phase {
            case .active(let point): hoveredXref = wedge(at: point)?.id
            case .ended: hoveredXref = nil
            }
        }
        // Right-click the hovered wedge to re-root a chart on that person.
        .contextMenu {
            if let id = hoveredXref, let person = model.document?.individuals[id] {
                Text(person.displayName)
                Divider()
                Button("Center Fan Here") { onPickChart(id, .fan) }
                Button("Pedigree From Here") { onPickChart(id, .pedigree) }
                Button("Descendants From Here") { onPickChart(id, .descendant) }
                Divider()
                Button("Show Details") { onSelect(id) }
            }
        }
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
        // Hovered wedge turns light grey (like FamilySearch); otherwise a subtle lineage tint.
        let highlighted = (hoveredXref ?? previewHover) == wedge.id
        context.fill(sector, with: .color(highlighted ? Color(white: 0.82) : color.opacity(0.16)))
        context.stroke(sector, with: .color(Color(white: 0.80)), lineWidth: 1)
        if wedge.generation > 0 {
            var arc = Path()
            arc.addArc(center: center, radius: outer - 1.5, startAngle: start, endAngle: end, clockwise: false)
            context.stroke(arc, with: .color(color), lineWidth: 3)
        }
    }

    // MARK: Center (horizontal)

    private func drawCenterLabel(_ wedge: FanWedge, in context: inout GraphicsContext) {
        let person = model.document?.individuals[wedge.id]
        let name = person?.displayName ?? wedge.id.value
        let text = lifeYears(person).map { "\(name)\n\($0)" } ?? name
        let point = CGPoint(x: center.x, y: center.y - Double(ringWidth) / 2)
        context.draw(Text(text).font(.system(size: nameSize + 2, weight: .medium)).foregroundStyle(.black), at: point)
    }

    // MARK: Curved (tangential, gen 3+)

    private func drawCurvedNames(_ wedge: FanWedge, in context: inout GraphicsContext) {
        let person = model.document?.individuals[wedge.id]
        let midRadius = CGFloat(wedge.generation) * ringWidth + ringWidth / 2
        let wedgeAngle = wedge.endAngle - wedge.startAngle
        let maxChars = max(4, Int(wedgeAngle * Double(midRadius) * 0.86 / (Double(nameSize) * 0.58)))

        var lines = wrap(person?.displayName ?? wedge.id.value, maxChars: maxChars)
        if lines.count > 3 { lines = Array(lines.prefix(3)) }
        let dates = lifeYears(person)
        let total = CGFloat(lines.count) + (dates == nil ? 0 : 0.85)
        var r = midRadius + (total - 1) / 2 * curvedLineSpacing
        for line in lines {
            drawCurvedLine(line, in: &context, radius: r, midAngle: wedge.midAngle, size: nameSize, weight: .medium, color: .black)
            r -= curvedLineSpacing
        }
        if let dates {
            drawCurvedLine(dates, in: &context, radius: r, midAngle: wedge.midAngle, size: dateSize, weight: .regular, color: Color(white: 0.45))
        }
    }

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

    // MARK: Radial (gen 1–2) — wrapping/truncating SwiftUI text

    private func radialLabel(_ wedge: FanWedge) -> some View {
        let inner = CGFloat(wedge.generation) * ringWidth
        let midRadius = inner + ringWidth / 2
        let arcLength = CGFloat(wedge.endAngle - wedge.startAngle) * midRadius
        let point = CGPoint(x: center.x + cos(wedge.midAngle) * Double(midRadius),
                            y: center.y + sin(wedge.midAngle) * Double(midRadius))
        return radialContent(wedge)
            .frame(width: ringWidth * 0.86, height: max(arcLength * 0.9, 24))
            .rotationEffect(.radians(radialRotation(wedge.midAngle)))
            .position(point)
    }

    @ViewBuilder private func radialContent(_ wedge: FanWedge) -> some View {
        let person = model.document?.individuals[wedge.id]
        VStack(spacing: 0) {
            if let given = person?.name?.given, let surname = person?.name?.surname {
                Text(given).lineLimit(1).truncationMode(.tail)
                Text(surname).lineLimit(1).truncationMode(.tail)
            } else {
                Text(person?.displayName ?? wedge.id.value).lineLimit(2).truncationMode(.tail)
            }
            if let dates = lifeYears(person) {
                Text(dates).font(.system(size: dateSize)).foregroundStyle(.secondary)
            }
        }
        .font(.system(size: nameSize, weight: .medium))
        .foregroundStyle(.black)
        .multilineTextAlignment(.center)
    }

    /// Radial rotation: reads OUTWARD on the right half; flips to upright (reading inward) on the
    /// left half — the unavoidable mirror of radial fan text, same as FamilySearch.
    private func radialRotation(_ theta: Double) -> Double { cos(theta) >= 0 ? theta : theta + .pi }

    // MARK: Helpers

    /// Greedy word wrap; a single word longer than `maxChars` is truncated with "…".
    private func wrap(_ text: String, maxChars: Int) -> [String] {
        var lines: [String] = []
        var current = ""
        for raw in text.split(separator: " ") {
            let word = raw.count > maxChars ? String(raw.prefix(max(1, maxChars - 1))) + "…" : String(raw)
            if current.isEmpty { current = word }
            else if current.count + 1 + word.count <= maxChars { current += " " + word }
            else { lines.append(current); current = word }
        }
        if !current.isEmpty { lines.append(current) }
        return lines.isEmpty ? [text] : lines
    }

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
        guard wedge.generation > 0 else { return Color(red: 0.42, green: 0.46, blue: 0.52) }
        let palette: [Color] = [
            Color(red: 0.31, green: 0.48, blue: 0.65),
            Color(red: 0.35, green: 0.63, blue: 0.49),
            Color(red: 0.84, green: 0.42, blue: 0.40),
            Color(red: 0.90, green: 0.68, blue: 0.31),
        ]
        return palette[layout.lineageBucket(of: wedge, buckets: lineageBuckets) % palette.count]
    }

    /// The wedge at a point in the view's local coordinates (polar hit-test), or nil.
    private func wedge(at location: CGPoint) -> FanWedge? {
        let dx = location.x - center.x, dy = location.y - center.y
        let ring = Int(hypot(dx, dy) / ringWidth)
        var angle = atan2(dy, dx)
        if angle < 0 { angle += 2 * .pi }
        return layout.wedges.first { $0.generation == ring && angle >= $0.startAngle && angle < $0.endAngle }
    }
}
