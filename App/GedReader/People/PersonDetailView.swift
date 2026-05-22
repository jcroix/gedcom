//
// PersonDetailView.swift — the detail pane for one person (A2).
//
// Sections: vitals (name/sex/birth/death), an events timeline, clickable relatives (parents /
// spouses / children — tapping navigates the model), selectable notes, and "Other Facts" which
// shows EVERYTHING not otherwise displayed — including the custom _FSFTID tag and any unknown tags
// — raw, so nothing in the file is hidden. Relatives and the graph come from the relationship index.
//
// Built so a future phase-2 editor can swap Text -> TextField in place without restructuring.
//

import SwiftUI
import GedReaderCore
import GedcomKit

struct PersonDetailView: View {
    let personID: Xref
    let model: DocumentModel

    /// Child tags shown elsewhere (vitals/timeline/relatives/notes) and therefore excluded from
    /// "Other Facts". Everything else (e.g. _FSFTID, vendor tags) shows raw under Other Facts.
    private static let handledTags: Set<String> =
        Set(["NAME", "SEX", "NOTE", "OBJE", "FAMC", "FAMS", "CHAN"]).union(GedcomEvent.individualEventTags)

    private var person: Individual? { model.document?.individuals[personID] }

    var body: some View {
        ScrollView {
            if let person {
                VStack(alignment: .leading, spacing: 24) {
                    vitals(person)
                    if !person.events.isEmpty { eventsTimeline(person) }
                    relatives
                    if !person.notes.isEmpty { notesSection(person) }
                    otherFacts(person)
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text("Person not found.").foregroundStyle(.secondary).padding()
            }
        }
        .navigationTitle(person?.displayName ?? "Person")
    }

    // MARK: Vitals

    private func vitals(_ person: Individual) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(person.displayName).font(.largeTitle.bold())
            if person.sex != .unknown {
                Text(person.sex == .female ? "Female" : "Male").foregroundStyle(.secondary)
            }
            if let birth = person.birth { Text("Born: \(eventLine(birth))") }
            if let death = person.death { Text("Died: \(eventLine(death))") }
        }
    }

    /// "ABT 1797 · New York" — date and place, whichever are present.
    private func eventLine(_ event: GedcomEvent) -> String {
        [event.date?.raw, event.place?.raw].compactMap { $0 }.joined(separator: " · ")
    }

    // MARK: Events timeline

    private func eventsTimeline(_ person: Individual) -> some View {
        section("Events") {
            ForEach(Array(sortedEvents(person).enumerated()), id: \.offset) { _, event in
                HStack(alignment: .top) {
                    Text(event.tag).font(.caption.monospaced()).frame(width: 56, alignment: .leading)
                        .foregroundStyle(.secondary)
                    Text(eventLine(event).isEmpty ? (event.value ?? "—") : eventLine(event))
                }
            }
        }
    }

    private func sortedEvents(_ person: Individual) -> [GedcomEvent] {
        person.events.sorted { ($0.date?.sortKey ?? .greatestFiniteMagnitude) < ($1.date?.sortKey ?? .greatestFiniteMagnitude) }
    }

    // MARK: Relatives (clickable)

    private var relatives: some View {
        section("Relatives") {
            relativeGroup("Parents", ids: model.relationshipIndex?.parents(of: personID) ?? [])
            relativeGroup("Spouses", ids: spouseIDs)
            relativeGroup("Children", ids: model.relationshipIndex?.children(of: personID) ?? [])
        }
    }

    /// Spouses = the OTHER spouse in each family this person is a spouse of.
    private var spouseIDs: [Xref] {
        guard let index = model.relationshipIndex, let document = model.document else { return [] }
        return (index.familiesAsSpouse[personID] ?? []).flatMap { familyID -> [Xref] in
            guard let family = document.families[familyID] else { return [] }
            return family.spouses.filter { $0 != personID }
        }
    }

    @ViewBuilder private func relativeGroup(_ label: String, ids: [Xref]) -> some View {
        if !ids.isEmpty {
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(.caption).foregroundStyle(.secondary)
                ForEach(ids, id: \.self) { id in
                    Button(model.document?.individuals[id]?.displayName ?? id.value) {
                        model.navigate(to: id)               // one-way selection: navigate the model
                    }
                    .buttonStyle(.link)
                }
            }
        }
    }

    // MARK: Notes

    private func notesSection(_ person: Individual) -> some View {
        section("Notes") {
            ForEach(Array(person.notes.enumerated()), id: \.offset) { _, note in
                Text(note).textSelection(.enabled)          // long notes are selectable
            }
        }
    }

    // MARK: Other Facts (raw — nothing hidden)

    @ViewBuilder private func otherFacts(_ person: Individual) -> some View {
        let extras = person.node.children.filter { !Self.handledTags.contains($0.tag) }
        if !extras.isEmpty {
            section("Other Facts") {
                ForEach(Array(extras.enumerated()), id: \.offset) { _, node in
                    HStack(alignment: .top) {
                        Text(node.tag).font(.caption.monospaced()).frame(width: 80, alignment: .leading)
                            .foregroundStyle(.secondary)
                        Text(node.value ?? "").textSelection(.enabled)
                    }
                }
            }
        }
    }

    // MARK: Section helper

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline)
            content()
        }
    }
}
