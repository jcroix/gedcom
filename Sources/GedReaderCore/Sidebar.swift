//
// Sidebar.swift — which sections the sidebar shows, with their badge counts.
//
// The sidebar always shows People / Families / Charts / Relationships / Quality, but the
// source-system rows (Sources / Media / Repositories) appear ONLY when the file actually has
// those records (family.ged has none). This is pure data — the section list + counts — computed
// from the document; the SwiftUI sidebar just renders it. Section titles and SF Symbol names live
// here too (plain strings, no SwiftUI dependency) so the rendering view stays trivial.
//
// STUB (TDD red phase): `items` returns nothing until tests drive it.
//

import GedcomKit

/// A navigable area of the app.
public enum SidebarSection: String, CaseIterable, Identifiable, Sendable {
    case people, families, charts, relationships, quality, sources, media, repositories

    public var id: String { rawValue }

    /// Human-readable title for the sidebar row.
    public var title: String {
        switch self {
        case .people: return "People"
        case .families: return "Families"
        case .charts: return "Charts"
        case .relationships: return "Relationships"
        case .quality: return "Quality"
        case .sources: return "Sources"
        case .media: return "Media"
        case .repositories: return "Repositories"
        }
    }

    /// SF Symbol name for the sidebar row.
    public var systemImage: String {
        switch self {
        case .people: return "person.2"
        case .families: return "house"
        case .charts: return "chart.xyaxis.line"
        case .relationships: return "arrow.triangle.branch"
        case .quality: return "checkmark.seal"
        case .sources: return "book.closed"
        case .media: return "photo"
        case .repositories: return "building.columns"
        }
    }
}

/// A sidebar row: a section plus an optional badge count.
public struct SidebarItem: Identifiable, Equatable, Sendable {
    public let section: SidebarSection
    public let badge: Int?            // nil = no badge (Charts/Relationships have no count)
    public var id: SidebarSection { section }

    public init(section: SidebarSection, badge: Int?) {
        self.section = section
        self.badge = badge
    }
}

/// Builds the visible sidebar for a document. Stateless caseless enum.
public enum Sidebar {
    /// The rows to show. `issueCount` is the precomputed quality-issue count (the Quality badge).
    /// Sources/Media/Repositories are included only when the document has at least one such record.
    public static func items(for document: GedcomDocument, issueCount: Int) -> [SidebarItem] {
        var items: [SidebarItem] = [
            SidebarItem(section: .people, badge: document.individuals.count),
            SidebarItem(section: .families, badge: document.families.count),
            SidebarItem(section: .charts, badge: nil),
            SidebarItem(section: .relationships, badge: nil),
            SidebarItem(section: .quality, badge: issueCount),
        ]
        // Source-system rows only when the file actually contains those records.
        if !document.sources.isEmpty {
            items.append(SidebarItem(section: .sources, badge: document.sources.count))
        }
        if !document.mediaObjects.isEmpty {
            items.append(SidebarItem(section: .media, badge: document.mediaObjects.count))
        }
        if !document.repositories.isEmpty {
            items.append(SidebarItem(section: .repositories, badge: document.repositories.count))
        }
        return items
    }
}
