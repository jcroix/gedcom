//
// FamiliesListView.swift — the Families section list (A5).
//
// A simple list of families labelled by their spouses (594 of them in family.ged, so no precomputed
// row type is needed). Selecting a family navigates the model to that family's xref; the detail pane
// then shows FamilyDetailView. Selection is one-way, like the People list.
//

import SwiftUI
import GedReaderCore
import GedcomKit

struct FamiliesListView: View {
    let model: DocumentModel

    private var families: [Family] { model.document?.allFamilies ?? [] }

    var body: some View {
        List(families, selection: Binding(
            get: { model.focus },
            set: { if let id = $0 { model.navigate(to: id) } }
        )) { family in
            VStack(alignment: .leading, spacing: 2) {
                Text(spouseLabel(family))
                if let year = family.marriage?.date?.raw {
                    Text("m. \(year)").font(.caption).foregroundStyle(.secondary)
                }
            }
            .tag(family.id)
        }
        .navigationTitle("Families")
    }

    /// "Husband & Wife" using whichever spouses are present, falling back to the family id.
    private func spouseLabel(_ family: Family) -> String {
        let names = family.spouses.compactMap { model.document?.individuals[$0]?.displayName }
        return names.isEmpty ? family.id.value : names.joined(separator: "  &  ")
    }
}
