//
// NavigationHistory.swift — browser-style back/forward history for the detail focus.
//
// The app navigates like a web browser: clicking a person/family/issue pushes a new "page", and
// ⌘[ / ⌘] step back and forward through the visited stack. This is pure value-type logic with no
// UI dependency, so it lives in GedReaderCore and is unit-tested directly. DocumentModel holds one
// of these and exposes its `current` as the detail-pane focus.
//
// Model: two stacks plus a current item. Navigating to a NEW item pushes the old current onto the
// back stack and clears the forward stack (just like a browser — a new navigation discards the
// forward history). goBack/goForward shuttle the current item between the stacks.
//
// STUB (TDD red phase): operations are no-ops until tests drive them.
//

/// Browser-style back/forward history over `Element`s (e.g. the focused record's Xref).
public struct NavigationHistory<Element: Equatable> {
    private var backStack: [Element] = []
    private var forwardStack: [Element] = []

    /// The currently focused item, or nil before anything has been visited.
    public private(set) var current: Element?

    public init() {}

    public var canGoBack: Bool { !backStack.isEmpty }
    public var canGoForward: Bool { !forwardStack.isEmpty }

    /// Navigate to `element`: it becomes current, the old current is pushed onto the back stack,
    /// and the forward stack is cleared. Navigating to the item already current is a no-op (so we
    /// don't pile up duplicate history entries when re-selecting the focused record).
    public mutating func navigate(to element: Element) {
        if element == current { return }            // re-selecting the focused item: no-op
        if let current { backStack.append(current) }
        current = element
        forwardStack.removeAll()
    }

    /// Step back to the previous item, if any.
    public mutating func goBack() {
        guard let current, let previous = backStack.popLast() else { return }
        forwardStack.append(current)
        self.current = previous
    }

    /// Step forward to the next item, if any.
    public mutating func goForward() {
        guard let current, let next = forwardStack.popLast() else { return }
        backStack.append(current)
        self.current = next
    }
}
