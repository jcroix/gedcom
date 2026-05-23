//
// PeopleListView.swift — the sortable People table + search (A2, A4).
//
// When the search field is empty this shows the full sortable Table of precomputed PersonRow values
// (Name/Born/Died/Sex; Born/Died sort by decimal year so ABT dates order sensibly). When the user
// types, it switches to a results list scoped to Names / Notes / All, with a note-match snippet.
// Search runs against the precomputed SearchIndex (built off-main at load), so it's instant.
// Selecting in either view navigates the model (one-way selection).
//

import SwiftUI
import GedReaderCore
import GedcomKit

struct PeopleListView: View {
    let model: DocumentModel

    @State private var sortOrder: [KeyPathComparator<PersonRow>] = [
        KeyPathComparator(\.birthSortValue, order: .forward),
    ]
    @State private var query = ""
    @State private var scope: SearchIndex.Scope = .all

    var body: some View {
        Group {
            if query.trimmingCharacters(in: .whitespaces).isEmpty {
                peopleTable
            } else {
                searchResults
            }
        }
        .searchable(text: $query, placement: .toolbar, prompt: "Search names and notes")
        .searchScopes($scope) {
            Text("All").tag(SearchIndex.Scope.all)
            Text("Names").tag(SearchIndex.Scope.names)
            Text("Notes").tag(SearchIndex.Scope.notes)
        }
        .navigationTitle("People")
    }

    // MARK: Full table

    private var rows: [PersonRow] {
        guard let document = model.document else { return [] }
        return PersonRow.all(in: document).sorted(using: sortOrder)
    }

    private var peopleTable: some View {
        Table(rows, selection: selectionBinding, sortOrder: $sortOrder) {
            TableColumn("Name", value: \.nameSortKey) { row in Text(row.name) }
            TableColumn("Born", value: \.birthSortValue) { row in Text(row.birth) }
            TableColumn("Died", value: \.deathSortValue) { row in Text(row.death) }
            TableColumn("Sex", value: \.sex) { row in Text(row.sex) }
                .width(40)
        }
    }

    // MARK: Search results

    private var results: [SearchIndex.Result] {
        model.searchIndex?.search(query, scope: scope) ?? []
    }

    private var searchResults: some View {
        List(results, selection: selectionBinding) { result in
            VStack(alignment: .leading, spacing: 2) {
                Text(result.name)
                if let snippet = result.snippet {
                    Text(snippet).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                }
            }
            .tag(result.id)
        }
        .overlay {
            if results.isEmpty { ContentUnavailableView.search(text: query) }
        }
    }

    // MARK: Selection (shared by table and results) — one-way: selecting navigates the model.

    private var selectionBinding: Binding<Xref?> {
        Binding(get: { model.focus }, set: { if let id = $0 { model.navigate(to: id) } })
    }
}
