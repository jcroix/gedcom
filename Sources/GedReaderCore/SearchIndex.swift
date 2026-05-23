//
// SearchIndex.swift — case-insensitive search over people's names and notes (A4).
//
// Built ONCE per document (off-main, stored in DocumentBundle) by precomputing each person's
// lowercased name and lowercased note text. Searching is then a linear scan of those precomputed
// strings — instant at a few thousand people, and far simpler than an inverted index (YAGNI; revisit
// if profiling a huge file ever demands it). A scope (Names / Notes / All) restricts where we match,
// and note matches carry a short snippet around the hit so the UI can show context.
//
// STUB (TDD red phase): build/search return nothing until tests drive them.
//

import Foundation
import GedcomKit

public struct SearchIndex: Sendable {

    /// Where to look for matches.
    public enum Scope: Sendable, Hashable {
        case names, notes, all
    }

    /// A single search hit.
    public struct Result: Identifiable, Sendable, Equatable {
        public let id: Xref
        public let name: String
        public let snippet: String?      // context around a note match; nil for name-only matches
    }

    /// One precomputed, searchable record per individual.
    private struct Entry: Sendable {
        let id: Xref
        let name: String
        let lowerName: String
        let notes: [String]
        let lowerNotes: [String]
    }
    private let entries: [Entry]

    private init(entries: [Entry]) { self.entries = entries }

    /// Precompute the searchable text for every individual, in file order.
    public static func build(from document: GedcomDocument) -> SearchIndex {
        let entries = document.allIndividuals.map { person in
            Entry(id: person.id,
                  name: person.displayName,
                  lowerName: person.displayName.lowercased(),
                  notes: person.notes,
                  lowerNotes: person.notes.map { $0.lowercased() })
        }
        return SearchIndex(entries: entries)
    }

    /// Find people matching `query` within `scope`. Empty/blank query returns no results.
    public func search(_ query: String, scope: Scope) -> [Result] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !needle.isEmpty else { return [] }

        let searchesNames = (scope == .names || scope == .all)
        let searchesNotes = (scope == .notes || scope == .all)

        var results: [Result] = []
        for entry in entries {
            let nameMatch = searchesNames && entry.lowerName.contains(needle)

            // Note match: first note containing the needle yields a context snippet.
            var snippet: String? = nil
            if searchesNotes, let i = entry.lowerNotes.firstIndex(where: { $0.contains(needle) }) {
                snippet = Self.snippet(from: entry.notes[i], matching: needle)
            }

            if nameMatch || snippet != nil {
                results.append(Result(id: entry.id, name: entry.name, snippet: snippet))
            }
        }
        return results
    }

    /// A short excerpt of `note` around the first (case-insensitive) match of `query`, with ellipses
    /// when truncated. Searches the original text directly so the snippet preserves original casing.
    private static func snippet(from note: String, matching query: String, context: Int = 30) -> String {
        guard let range = note.range(of: query, options: .caseInsensitive) else { return note }
        let chars = Array(note)
        let start = note.distance(from: note.startIndex, to: range.lowerBound)
        let end = note.distance(from: note.startIndex, to: range.upperBound)
        let lo = max(0, start - context)
        let hi = min(chars.count, end + context)
        var excerpt = String(chars[lo..<hi])
        if lo > 0 { excerpt = "…" + excerpt }
        if hi < chars.count { excerpt += "…" }
        return excerpt
    }
}
