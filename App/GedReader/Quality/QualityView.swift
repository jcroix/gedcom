//
// QualityView.swift — the Quality section: issues grouped by category, click to jump (A6).
//
// Renders the precomputed issues (model.issues) grouped via QualityGrouping — errors first, each
// group showing its count. Each issue row shows a severity icon, the message, and its involved
// person(s) as links; clicking a person navigates the model (and switches to People so the detail
// pane is in a sensible context). Two-person issues (e.g. possible-duplicate) link both people.
//

import SwiftUI
import GedReaderCore
import GedcomKit

struct QualityView: View {
    let model: DocumentModel

    private var groups: [IssueGroup] { QualityGrouping.groups(model.issues) }

    var body: some View {
        Group {
            if groups.isEmpty {
                ContentUnavailableView("No issues found", systemImage: "checkmark.seal",
                                       description: Text("The data passed all quality checks."))
            } else {
                List {
                    ForEach(groups) { group in
                        Section {
                            ForEach(Array(group.issues.enumerated()), id: \.offset) { _, issue in
                                issueRow(issue)
                            }
                        } header: {
                            Label("\(group.category.displayTitle) (\(group.count))",
                                  systemImage: icon(for: group.severity))
                        }
                    }
                }
            }
        }
        .navigationTitle("Quality")
    }

    private func issueRow(_ issue: Issue) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(issue.message).font(.callout)
            HStack {
                ForEach(issue.individuals, id: \.self) { id in
                    Button(model.document?.individuals[id]?.displayName ?? id.value) {
                        model.currentSection = .people     // give the navigation a sensible home
                        model.navigate(to: id)
                    }
                    .buttonStyle(.link)
                }
            }
        }
        .padding(.vertical, 2)
    }

    private func icon(for severity: Diagnostic.Severity) -> String {
        switch severity {
        case .error: return "exclamationmark.octagon"
        case .warning: return "exclamationmark.triangle"
        case .info: return "info.circle"
        }
    }
}
