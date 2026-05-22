//
// PeopleListView.swift — the sortable People table (A2).
//
// A SwiftUI Table of precomputed PersonRow values (correct and fast at ~2k rows). Columns:
// Name / Born / Died / Sex. Sorting uses KeyPathComparator on the row's fields — Born/Died sort by
// the numeric `birthSortKey`/`deathSortKey` so approximate dates ("ABT 1797") order sensibly while
// the cell still displays the human text. Selecting a row navigates the model (one-way selection).
//

import SwiftUI
import GedReaderCore
import GedcomKit

struct PeopleListView: View {
    let model: DocumentModel

    // Default order: by birth date (undated last). Re-sorts when the user clicks a column header.
    @State private var sortOrder: [KeyPathComparator<PersonRow>] = [
        KeyPathComparator(\.birthSortValue, order: .forward),
    ]

    private var rows: [PersonRow] {
        guard let document = model.document else { return [] }
        return PersonRow.all(in: document).sorted(using: sortOrder)
    }

    var body: some View {
        // Single selection bound to the model's focus; clicking a row navigates to that person.
        Table(rows, selection: Binding(
            get: { model.focus },
            set: { if let id = $0 { model.navigate(to: id) } }
        ), sortOrder: $sortOrder) {
            TableColumn("Name", value: \.nameSortKey) { row in Text(row.name) }
            TableColumn("Born", value: \.birthSortValue) { row in Text(row.birth) }
            TableColumn("Died", value: \.deathSortValue) { row in Text(row.death) }
            TableColumn("Sex", value: \.sex) { row in Text(row.sex) }
                .width(40)
        }
        .navigationTitle("People")
    }
}
