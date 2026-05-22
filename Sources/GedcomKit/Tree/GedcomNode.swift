//
// GedcomNode.swift — one node in the lossless GEDCOM tree.
//
// A GedcomNode wraps a single tokenized line and holds its subordinate lines as child nodes, in
// their ORIGINAL order. The tree built from these nodes is the engine's source of truth: it
// preserves everything the file contained — unknown/custom tags, CONT/CONC splits, and the order
// of records and fields — so that (in a future phase) a writer can reproduce the file with minimal
// diffs. The typed model layer (Individual, Family, …) is a convenience projection that READS
// these nodes; it never owns the data.
//
// Value type on purpose: the whole document is immutable in-memory state keyed by Xref. Nodes are
// navigated top-down (parent -> children); upward navigation isn't needed because record lookup
// goes through GedcomTree's xref dictionary, not parent pointers.
//

/// A node in the lossless GEDCOM tree: a line plus its ordered subordinate nodes.
public struct GedcomNode: Equatable, Sendable {

    /// The tokenized line this node represents.
    public let line: GedcomLine

    /// Subordinate nodes (the lines at level+1 directly under this one), in file order.
    public let children: [GedcomNode]

    /// The 1-based physical line span this node covers: from its own line through the last line of
    /// its deepest descendant. Intended for the future lossless writer (rewrite a record by
    /// replacing its line range) and for "jump to source" in the app. Blank lines that were
    /// skipped during lexing are not represented, so the range is a span, not a guarantee of
    /// contiguity.
    public let sourceLineRange: ClosedRange<Int>

    public init(line: GedcomLine, children: [GedcomNode], sourceLineRange: ClosedRange<Int>) {
        self.line = line
        self.children = children
        self.sourceLineRange = sourceLineRange
    }

    // MARK: Convenience accessors (read-through to the underlying line)

    /// Nesting level (0 = top-level record).
    public var level: Int { line.level }

    /// The GEDCOM tag (INDI, NAME, DATE, _FSFTID, …).
    public var tag: String { line.tag }

    /// The line's value, if any (may be a pointer like `@F1@`).
    public var value: String? { line.value }

    /// The record id this node defines (only top-level records and pointers-with-ids have one).
    public var xref: Xref? { line.xref }

    // MARK: Child queries (used by the model projection layer)

    /// The first direct child with the given tag, or nil. GEDCOM often allows a field at most once
    /// (e.g. a person's SEX), so "first" is the common access pattern.
    public func firstChild(tag: String) -> GedcomNode? {
        children.first { $0.tag == tag }
    }

    /// All direct children with the given tag, in order (e.g. every CHIL under a FAM).
    public func children(tag: String) -> [GedcomNode] {
        children.filter { $0.tag == tag }
    }

    /// The value of the first direct child with the given tag (e.g. the BIRT's DATE), or nil.
    public func firstValue(tag: String) -> String? {
        firstChild(tag: tag)?.value
    }
}
