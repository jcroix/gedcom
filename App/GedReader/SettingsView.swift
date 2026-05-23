//
// SettingsView.swift — the Settings scene (⌘,) (A9).
//
// Minimal v1 preferences. The default chart generations is shared with ChartsView via @AppStorage
// ("chartGenerations"), so changing it here updates the charts (and persists across launches).
//

import SwiftUI

struct SettingsView: View {
    @AppStorage("chartGenerations") private var chartGenerations = 4

    var body: some View {
        Form {
            Stepper("Default chart generations: \(chartGenerations)", value: $chartGenerations, in: 3...8)
        }
        .padding(20)
        .frame(width: 360)
    }
}
