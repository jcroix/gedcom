//
// ShellView.swift — the 3-column NavigationSplitView shown once a document is loaded (A1).
//
// Column 1 (sidebar): the sections from Sidebar.items(for:) with badge counts; source-system rows
//   appear only when present. Selecting a section drives the content column.
// Column 2 (content): the list for the selected section. People is implemented (A2); the others
//   show a placeholder until their milestones (A5–A8).
// Column 3 (detail): reads model.focus and shows the focused person (A2). Selection flows ONE way:
//   lists call model.navigate(to:), the detail reads model.focus.
//

import SwiftUI
import GedReaderCore
import GedcomKit

struct ShellView: View {
    @Bindable var model: DocumentModel
    @State private var selectedSection: SidebarSection? = .people

    var body: some View {
        NavigationSplitView {
            sidebar
        } content: {
            content
                .navigationSplitViewColumnWidth(min: 280, ideal: 360)
        } detail: {
            detail
        }
        .navigationTitle("GedReader")
        .navigationSubtitle(model.summary ?? "")
    }

    // MARK: Sidebar

    private var sidebar: some View {
        List(sidebarItems, selection: $selectedSection) { item in
            Label(item.section.title, systemImage: item.section.systemImage)
                .badge(item.badge ?? 0)         // 0 shows nothing meaningful; fine for count rows
                .tag(item.section)
        }
        .navigationSplitViewColumnWidth(min: 200, ideal: 220)
    }

    private var sidebarItems: [SidebarItem] {
        guard let document = model.document else { return [] }
        return Sidebar.items(for: document, issueCount: model.issues.count)
    }

    // MARK: Content column

    @ViewBuilder private var content: some View {
        switch selectedSection {
        case .people:
            PeopleListView(model: model)
        case .none:
            ContentUnavailableView("Pick a section", systemImage: "sidebar.left")
        default:
            // A5–A8 sections land later; show a friendly placeholder for now.
            ContentUnavailableView(
                "\(selectedSection?.title ?? "") — coming soon",
                systemImage: selectedSection?.systemImage ?? "hammer",
                description: Text("This section is part of a later milestone."))
        }
    }

    // MARK: Detail column

    @ViewBuilder private var detail: some View {
        if let focus = model.focus, model.document?.individuals[focus] != nil {
            PersonDetailView(personID: focus, model: model)
        } else {
            ContentUnavailableView("No selection", systemImage: "person.crop.circle",
                                   description: Text("Select a person to see their details."))
        }
    }
}
