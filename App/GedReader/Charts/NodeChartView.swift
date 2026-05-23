//
// NodeChartView.swift — renders a ChartLayout (pedigree or descendant) (A8).
//
// Hybrid renderer per the plan: a Canvas draws the connector lines (cheap, no hit-testing needed),
// and each person is a real SwiftUI Button placed with .position(...) so it gets free hit-testing —
// tapping navigates the model. The whole thing is sized to the layout and lives inside the zoom/
// scroll container in ChartsView.
//

import SwiftUI
import GedReaderCore
import GedcomKit

struct NodeChartView: View {
    let layout: ChartLayout
    let model: DocumentModel

    private let cardWidth: CGFloat = 180
    private let cardHeight: CGFloat = 44

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Connectors.
            Canvas { context, _ in
                for edge in layout.edges {
                    var path = Path()
                    path.move(to: CGPoint(x: edge.from.x, y: edge.from.y))
                    path.addLine(to: CGPoint(x: edge.to.x, y: edge.to.y))
                    context.stroke(path, with: .color(.secondary.opacity(0.6)), lineWidth: 1)
                }
            }
            // Node cards.
            ForEach(layout.nodes) { node in
                card(node)
                    .position(x: node.center.x, y: node.center.y)
            }
        }
        .frame(width: max(layout.width, cardWidth), height: max(layout.height, cardHeight))
        .padding(cardWidth / 2)   // room so edge cards aren't clipped
    }

    private func card(_ node: ChartNode) -> some View {
        let isFocused = model.focus == node.id
        return Button {
            model.navigate(to: node.id)
        } label: {
            Text(model.document?.individuals[node.id]?.displayName ?? node.id.value)
                .font(.caption)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(width: cardWidth, height: cardHeight)
                .background(isFocused ? Color.accentColor.opacity(0.25) : Color(white: 0.5).opacity(0.12))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(.secondary.opacity(0.4)))
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
    }
}
