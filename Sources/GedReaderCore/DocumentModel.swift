//
// DocumentModel.swift — the single source of truth for one open GEDCOM window.
//
// One @Observable @MainActor object drives the whole window: the load state, the loaded document +
// relationship index, the browser-style navigation focus, and the chosen home person. SwiftUI views
// read its properties and call its methods; selection flows ONE way (lists/charts call navigate(to:),
// the detail pane reads `focus`). Keeping it here in GedReaderCore (no SwiftUI import) means all of
// this logic is unit-testable headlessly.
//
// @Observable needs macOS 14 / iOS 17, so this type (and its tests) carry that availability while the
// package minimum stays lower for the UI-free engine.
//
// STUB (TDD red phase): load/navigation are no-ops until tests drive them.
//

import Foundation
import Observation
import GedcomKit

@available(macOS 14, iOS 17, *)
@MainActor
@Observable
public final class DocumentModel {

    /// Where the window is in the open→parse→show lifecycle.
    public enum LoadState {
        case idle                       // nothing opened yet
        case loading                    // parsing off-main (UI shows a progress indicator)
        case loaded(DocumentBundle)     // ready
        case failed(String)             // user-facing error message
    }

    public private(set) var state: LoadState = .idle

    /// Browser-style history of the detail focus (the selected record). `private` storage; the
    /// view layer uses `focus` / `goBack` / `goForward`.
    private var history = NavigationHistory<Xref>()

    /// The home person (root for charts, "Set Home" target). nil until chosen.
    public private(set) var homePerson: Xref?

    public init() {}

    // MARK: Loaded-document accessors

    /// The parsed document, or nil unless loaded.
    public var document: GedcomDocument? {
        if case .loaded(let bundle) = state { return bundle.document }
        return nil
    }

    /// The relationship index, or nil unless loaded.
    public var relationshipIndex: RelationshipIndex? {
        if case .loaded(let bundle) = state { return bundle.index }
        return nil
    }

    /// The precomputed data-quality issues, or [] unless loaded.
    public var issues: [Issue] {
        if case .loaded(let bundle) = state { return bundle.issues }
        return []
    }

    /// A short summary line for the loaded file, e.g. "2,000 people · 594 families".
    public var summary: String? {
        guard let document else { return nil }
        let people = document.individuals.count.formatted()
        let families = document.families.count.formatted()
        return "\(people) people · \(families) families"
    }

    // MARK: Navigation focus

    /// The currently focused record (drives the detail pane), or nil.
    public var focus: Xref? { history.current }
    public var canGoBack: Bool { history.canGoBack }
    public var canGoForward: Bool { history.canGoForward }

    public func navigate(to xref: Xref) { history.navigate(to: xref) }
    public func goBack() { history.goBack() }
    public func goForward() { history.goForward() }

    /// Set the home person to the currently focused record (the "Set Home" command).
    public func setHomeToFocus() { homePerson = focus }

    // MARK: Loading

    /// Load already-read bytes synchronously (used by tests and as the core of `loadFile`). Decides
    /// loaded-vs-failed based on whether anything GEDCOM-shaped was parsed.
    public func load(data: Data) {
        applyLoaded(DocumentBundle.build(from: data))
    }

    /// Open and parse a file off the main thread, showing `.loading` while it works.
    public func loadFile(at url: URL) async {
        state = .loading
        // Read + parse + index entirely off the main actor, then hop back to apply the result.
        let outcome: Result<DocumentBundle, any Error> = await Task.detached(priority: .userInitiated) {
            do { return .success(DocumentBundle.build(from: try Data(contentsOf: url))) }
            catch { return .failure(error) }
        }.value

        switch outcome {
        case .success(let bundle): applyLoaded(bundle)
        case .failure(let error): state = .failed("Couldn't open the file: \(error.localizedDescription)")
        }
    }

    /// Decide loaded-vs-failed from a freshly built bundle. A file that produced NO top-level
    /// records isn't usable GEDCOM (the engine never throws, so this is how we detect "not a GEDCOM
    /// file" — e.g. an arbitrary text file the user picked by mistake).
    private func applyLoaded(_ bundle: DocumentBundle) {
        if bundle.document.tree.records.isEmpty {
            state = .failed("This file doesn’t appear to be a GEDCOM file.")
        } else {
            state = .loaded(bundle)
        }
    }
}
