//
// ChartRenderer.swift — render a chart view to a PNG file offscreen, then exit (dev/test only).
//
// SwiftUI's ImageRenderer rasterizes a view to a bitmap WITHOUT a window or display, so this works
// headlessly (unlike `screencapture`, which needs screen-recording access). It exists so the chart
// views can be visually verified from a script: launch the app with GEDREADER_AUTOLOAD + AUTOCHART
// (+ optional AUTOHOME, RENDER_GENS) and GEDREADER_RENDER_PNG=<path>; the app writes the chart image
// and quits. No effect in normal use.
//

import SwiftUI
import GedReaderCore
import GedcomKit

@MainActor
enum ChartRenderer {
    static func renderAndExit(model: DocumentModel, env: [String: String], to path: String) {
        guard let document = model.document, let index = model.relationshipIndex else { exit(1) }
        let root = env["GEDREADER_AUTOHOME"].map { Xref($0) } ?? document.allIndividuals.first?.id
        guard let root else { exit(1) }
        let gens = Int(env["GEDREADER_RENDER_GENS"] ?? "5") ?? 5

        let chart: AnyView
        switch env["GEDREADER_AUTOCHART"] ?? "Fan" {
        case "Pedigree":
            chart = AnyView(NodeChartView(layout: ChartLayoutEngine.pedigree(root: root, generations: gens, index: index), model: model))
        case "Descendant":
            chart = AnyView(NodeChartView(layout: ChartLayoutEngine.descendant(root: root, depth: gens, index: index), model: model))
        default:
            let sweep = Double.pi * 1.5
            chart = AnyView(FanChartView(layout: ChartLayoutEngine.fan(root: root, generations: gens, index: index,
                                                                       sweep: sweep, startAngle: 1.5 * .pi - sweep / 2),
                                         model: model))
        }

        let renderer = ImageRenderer(content: chart.background(.white))
        renderer.scale = 2
        if let image = renderer.nsImage,
           let tiff = image.tiffRepresentation,
           let rep = NSBitmapImageRep(data: tiff),
           let png = rep.representation(using: .png, properties: [:]) {
            try? png.write(to: URL(fileURLWithPath: path))
        }
        exit(0)
    }
}
