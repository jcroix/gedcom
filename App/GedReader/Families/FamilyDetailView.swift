//
// FamilyDetailView.swift — the detail pane for one family (A5).
//
// Shows the two spouses (clickable), the marriage event, and the children IN BIRTH ORDER (clickable,
// with their birth years) via FamilyBrowsing.childrenInBirthOrder. Every person link navigates the
// shared model focus, so you can hop family → child → that child's family, etc.
//

import SwiftUI
import GedReaderCore
import GedcomKit

struct FamilyDetailView: View {
    let familyID: Xref
    let model: DocumentModel

    private var family: Family? { model.document?.families[familyID] }

    var body: some View {
        ScrollView {
            if let family {
                VStack(alignment: .leading, spacing: 24) {
                    Text("Family").font(.largeTitle.bold())
                    spouses(family)
                    if let marriage = family.marriage {
                        section("Marriage") {
                            Text([marriage.date?.raw, marriage.place?.raw].compactMap { $0 }.joined(separator: " · "))
                        }
                    }
                    children(family)
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text("Family not found.").foregroundStyle(.secondary).padding()
            }
        }
        .navigationTitle("Family")
    }

    private func spouses(_ family: Family) -> some View {
        section("Spouses") {
            personLinks(family.spouses)
        }
    }

    private func children(_ family: Family) -> some View {
        let ordered = model.document.map { FamilyBrowsing.childrenInBirthOrder(of: family, in: $0) } ?? []
        return section(ordered.isEmpty ? "Children" : "Children (\(ordered.count), birth order)") {
            if ordered.isEmpty {
                Text("No children recorded.").foregroundStyle(.secondary)
            } else {
                personLinks(ordered, showBirthYear: true)
            }
        }
    }

    /// A column of clickable person links; optionally annotate each with their birth date.
    @ViewBuilder private func personLinks(_ ids: [Xref], showBirthYear: Bool = false) -> some View {
        ForEach(ids, id: \.self) { id in
            let person = model.document?.individuals[id]
            HStack(spacing: 6) {
                Button(person?.displayName ?? id.value) { model.navigate(to: id) }
                    .buttonStyle(.link)
                if showBirthYear, let birth = person?.birth?.date?.raw {
                    Text("(\(birth))").font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline)
            content()
        }
    }
}
