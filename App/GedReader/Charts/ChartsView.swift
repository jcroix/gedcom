//
// ChartsView.swift — the Charts section: pick a chart type, generations, zoom, and root (A8).
//
// Roots the chart at the home person (else the current focus, else the first individual). Offers
// Pedigree (ancestors), Descendant, and Fan, a generations stepper, and ⌘±/⌘0 zoom. The layout is
// computed by the unit-tested ChartLayoutEngine; rendering is delegated to NodeChartView (pedigree/
// descendant) or FanChartView. Everything sits in a zoom/scroll container.
//

import SwiftUI
import GedReaderCore
import GedcomKit

/// The chart types the Charts section can draw (shared with FanChartView's context menu).
enum ChartKind: String, CaseIterable, Identifiable {
    case pedigree = "Pedigree", descendant = "Descendant", fan = "Fan"
    var id: String { rawValue }
}

struct ChartsView: View {
    let model: DocumentModel

    @State private var kind: ChartKind = .pedigree
    // Shared with Settings (⌘,) and persisted across launches.
    @AppStorage("chartGenerations") private var generations = 4
    @State private var scale: CGFloat = 1
    @State private var chartBaseSize: CGSize = .zero   // measured natural size of the chart (scale 1)
    // When set (by clicking/right-clicking a wedge), the chart re-roots on this person; nil = home.
    @State private var chartRoot: Xref?

    /// Chart root: an explicit re-center, else Home, else current focus, else the first person.
    private var root: Xref? {
        chartRoot ?? model.homePerson ?? model.focus ?? model.document?.allIndividuals.first?.id
    }

    var body: some View {
        VStack(spacing: 0) {
            controls
            Divider()
            chartArea
        }
        .navigationTitle("Charts")
        // Headless smoke-test hook (no effect in normal use): pick the chart type at launch.
        .task {
            if let raw = ProcessInfo.processInfo.environment["GEDREADER_AUTOCHART"],
               let k = ChartKind(rawValue: raw) { kind = k }
        }
    }

    private var controls: some View {
        HStack(spacing: 16) {
            Picker("Chart", selection: $kind) {
                ForEach(ChartKind.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .frame(width: 280)
            .labelsHidden()

            Stepper("Generations: \(generations)", value: $generations, in: 3...8)
                .fixedSize()

            // Shown once the chart has been re-centered on someone else: jump back to the home root.
            if chartRoot != nil {
                Button { chartRoot = nil } label: { Label("Recenter on Home", systemImage: "house") }
            }

            Spacer()

            Button { scale = max(0.3, scale - 0.2) } label: { Image(systemName: "minus.magnifyingglass") }
                .keyboardShortcut("-", modifiers: .command).help("Zoom out")
            Button { scale = 1 } label: { Image(systemName: "1.magnifyingglass") }
                .keyboardShortcut("0", modifiers: .command).help("Actual size")
            Button { scale = min(3, scale + 0.2) } label: { Image(systemName: "plus.magnifyingglass") }
                .keyboardShortcut("+", modifiers: .command).help("Zoom in")

            if let root, let name = model.document?.individuals[root]?.displayName {
                Text("Root: \(name)").foregroundStyle(.secondary).lineLimit(1)
            }
        }
        .padding(8)
    }

    @ViewBuilder private var chartArea: some View {
        if let root, let index = model.relationshipIndex {
            ScrollView([.horizontal, .vertical]) {
                // `scaleEffect` only scales visually — it does NOT change layout size, so the
                // ScrollView wouldn't know the zoomed content grew (you couldn't scroll to the parts
                // pushed off-screen). We measure the chart's natural size (it's `fixedSize`, so that
                // size is independent of the wrapping frame), scale it, then size the frame to
                // base × scale so the ScrollView's scrollable content matches what's drawn.
                chart(root: root, index: index)
                    .fixedSize()
                    .background(GeometryReader { proxy in
                        Color.clear.preference(key: ChartBaseSizeKey.self, value: proxy.size)
                    })
                    .scaleEffect(scale, anchor: .topLeading)
                    .frame(width: chartBaseSize.width * scale,
                           height: chartBaseSize.height * scale,
                           alignment: .topLeading)
                    .padding(20)
            }
            .onPreferenceChange(ChartBaseSizeKey.self) { chartBaseSize = $0 }
            // The fan uses a light theme; fill the whole scroll area white (not just the fan rect).
            .background(kind == .fan ? Color.white : Color.clear)
        } else {
            ContentUnavailableView("Nothing to chart", systemImage: "chart.xyaxis.line",
                                   description: Text("Set a Home person or select someone to chart."))
        }
    }

    @ViewBuilder private func chart(root: Xref, index: RelationshipIndex) -> some View {
        switch kind {
        case .pedigree:
            NodeChartView(layout: ChartLayoutEngine.pedigree(root: root, generations: generations, index: index),
                          model: model)
        case .descendant:
            NodeChartView(layout: ChartLayoutEngine.descendant(root: root, depth: generations, index: index),
                          model: model)
        case .fan:
            // 270° sweep centered at the top (like FamilySearch) so deep branches don't pile up
            // vertically at the 3/9-o'clock edges of a strict half-fan.
            let sweep = Double.pi * 1.5
            FanChartView(
                layout: ChartLayoutEngine.fan(root: root, generations: generations, index: index,
                                              sweep: sweep, startAngle: 1.5 * .pi - sweep / 2),
                model: model,
                // Left-click selects (shows the person in the detail pane).
                onSelect: { model.navigate(to: $0) },
                // Right-click menu: re-root the chart on that person as the chosen kind.
                onPickChart: { id, pickedKind in
                    model.navigate(to: id)
                    chartRoot = id
                    kind = pickedKind
                })
        }
    }
}

/// Carries the chart's measured natural (scale-1) size up so the zoom frame can be sized to
/// base × scale, making the ScrollView scrollable across zoomed-in content.
private struct ChartBaseSizeKey: PreferenceKey {
    static let defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        let next = nextValue()
        if next != .zero { value = next }
    }
}
