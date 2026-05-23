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
        .toolbar {
            ToolbarItemGroup(placement: .navigation) {
                Button { model.goBack() } label: { Image(systemName: "chevron.left") }
                    .disabled(!model.canGoBack)
                    .help("Back")
                Button { model.goForward() } label: { Image(systemName: "chevron.right") }
                    .disabled(!model.canGoForward)
                    .help("Forward")
            }
            ToolbarItem {
                Button { model.setHomeToFocus() } label: { Label("Set Home", systemImage: "house") }
                    .disabled(model.focus == nil)
                    .help("Set the focused person as Home")
            }
        }
    }

    // MARK: Sidebar

    private var sidebar: some View {
        // Single-selection lists bind to an OPTIONAL; map it onto the non-optional model state.
        let selection = Binding<SidebarSection?>(
            get: { model.currentSection },
            set: { if let section = $0 { model.currentSection = section } })

        return List(sidebarItems, selection: selection) { item in
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
        switch model.currentSection {
        case .people:
            PeopleListView(model: model)
        case .families:
            FamiliesListView(model: model)
        case .quality:
            QualityView(model: model)
        case .relationships:
            RelationshipView(model: model)
        case .charts:
            ChartsView(model: model)
        default:
            // Source-system sections (Sources/Media/Repositories) are browsable via the tree;
            // dedicated views can be added when a file actually exercises them.
            ContentUnavailableView(
                "\(model.currentSection.title) — coming soon",
                systemImage: model.currentSection.systemImage,
                description: Text("This section is part of a later milestone."))
        }
    }

    // MARK: Detail column

    @ViewBuilder private var detail: some View {
        // Focus is a single Xref that may name a person or a family; route accordingly.
        if let focus = model.focus, model.document?.individuals[focus] != nil {
            PersonDetailView(personID: focus, model: model)
        } else if let focus = model.focus, model.document?.families[focus] != nil {
            FamilyDetailView(familyID: focus, model: model)
        } else {
            ContentUnavailableView("No selection", systemImage: "person.crop.circle",
                                   description: Text("Select a person or family to see details."))
        }
    }
}
