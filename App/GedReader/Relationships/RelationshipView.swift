//
// RelationshipView.swift — the relationship calculator screen (A7).
//
// Two searchable person pickers (A defaults to the home person), a big result sentence, and the
// connecting path rendered as a clickable chain through the common ancestor. The calculator and the
// sentence phrasing are already unit-tested in GedReaderCore; this view just wires them to pickers
// and renders the path. Tapping any person in the path navigates the model.
//

import SwiftUI
import GedReaderCore
import GedcomKit

struct RelationshipView: View {
    let model: DocumentModel

    @State private var personA: Xref?
    @State private var personB: Xref?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Relationship").font(.largeTitle.bold())
                HStack(alignment: .top, spacing: 24) {
                    PersonPicker(model: model, label: "Person A", selection: $personA)
                    PersonPicker(model: model, label: "Person B", selection: $personB)
                }
                Divider()
                resultArea
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle("Relationships")
        // Pre-fill A with the home person the first time the screen appears.
        .onAppear { if personA == nil { personA = model.homePerson } }
    }

    @ViewBuilder private var resultArea: some View {
        if let a = personA, let b = personB,
           let index = model.relationshipIndex, let document = model.document {
            let result = RelationshipCalculator.relationship(of: b, to: a, in: index, document: document)
            let nameA = document.individuals[a]?.displayName ?? a.value
            let nameB = document.individuals[b]?.displayName ?? b.value

            Text(RelationshipPhrasing.sentence(subject: nameB, base: nameA, label: result.label))
                .font(.title2).fixedSize(horizontal: false, vertical: true)

            if let path = result.path, path.count > 1 {
                pathChain(path)
            }
        } else {
            Text("Pick two people to see how they're related.").foregroundStyle(.secondary)
        }
    }

    /// The connecting path as a vertical chain of clickable people separated by down-arrows.
    private func pathChain(_ path: [Xref]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Path").font(.headline)
            ForEach(Array(path.enumerated()), id: \.offset) { offset, id in
                if offset > 0 {
                    Image(systemName: "arrow.down").font(.caption).foregroundStyle(.secondary)
                }
                Button(model.document?.individuals[id]?.displayName ?? id.value) {
                    model.navigate(to: id)
                }
                .buttonStyle(.link)
            }
        }
    }
}

/// A small searchable person chooser: shows the current pick and a search field whose name results
/// you tap to (re)select. Uses the precomputed SearchIndex, so it stays responsive at 2k+ people.
private struct PersonPicker: View {
    let model: DocumentModel
    let label: String
    @Binding var selection: Xref?
    @State private var query = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            Text(selection.flatMap { model.document?.individuals[$0]?.displayName } ?? "—")
                .font(.headline)
            TextField("Search by name…", text: $query)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 260)
            if !query.isEmpty {
                let results = model.searchIndex?.search(query, scope: .names).prefix(8) ?? []
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(Array(results)) { result in
                        Button(result.name) {
                            selection = result.id
                            query = ""
                        }
                        .buttonStyle(.link)
                    }
                }
            }
        }
        .frame(maxWidth: 280, alignment: .leading)
    }
}
