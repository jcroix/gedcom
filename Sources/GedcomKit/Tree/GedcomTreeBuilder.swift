//
// GedcomTreeBuilder.swift — assemble a flat [GedcomLine] stream into the lossless GedcomTree.
//
// STUB (TDD red phase): returns an empty tree until tests drive the real nesting + indexing logic.
//
// Plan (once implemented):
//   * Nest lines by their level number: a line at level L is a child of the most recent line at
//     level L-1. Top-level (level 0) lines are records.
//   * Build the xref index (record id -> position) and flag DUPLICATE definitions.
//   * Walk every node's value: if a value looks like a pointer (@X@) but no record defines @X@,
//     raise ONE diagnostic per dangling reference (query.py silently dropped these).
// All of this is defensive: malformed nesting is flagged but never discards data.
//

/// Builds the lossless tree from lexed lines. Stateless caseless enum.
public enum GedcomTreeBuilder {

    /// Assemble `lines` into a GedcomTree, returning any diagnostics raised while doing so
    /// (duplicate xref definitions, dangling pointers, malformed nesting).
    public static func build(from lines: [GedcomLine]) -> (tree: GedcomTree, diagnostics: [Diagnostic]) {
        var diagnostics: [Diagnostic] = []

        // 1. Nest the flat line stream into top-level records by level number.
        var cursor = 0
        let records = parseNodes(lines, &cursor, atLevel: 0, diagnostics: &diagnostics)

        // 2. Index records by their defined xref; flag any duplicate definition (keep the first).
        var index: [Xref: Int] = [:]
        for (position, record) in records.enumerated() {
            guard let xref = record.xref else { continue }   // HEAD/TRLR define no id
            if index[xref] != nil {
                diagnostics.append(Diagnostic(
                    severity: .error,
                    message: "Duplicate record id \(xref); keeping the first definition.",
                    lineNumber: record.line.lineNumber))
            } else {
                index[xref] = position
            }
        }

        // 3. Detect dangling pointers: any value that looks like @X@ but names no defined record.
        detectDanglingPointers(records, index: index, into: &diagnostics)

        return (GedcomTree(records: records, index: index), diagnostics)
    }

    // MARK: - Nesting

    /// Recursively consume lines that belong at `level` (and their deeper descendants), starting at
    /// `cursor`, returning the sibling nodes built at this level. `cursor` is advanced past every
    /// line consumed. Stops when a line shallower than `level` appears (it belongs to an ancestor).
    ///
    /// Defensive handling of malformed nesting: if a line is DEEPER than expected (a skipped level),
    /// we flag it once and adopt it at the current level rather than discarding the data — the
    /// node's original line.level is preserved untouched, only its tree placement is best-effort.
    private static func parseNodes(_ lines: [GedcomLine],
                                   _ cursor: inout Int,
                                   atLevel level: Int,
                                   diagnostics: inout [Diagnostic]) -> [GedcomNode] {
        var nodes: [GedcomNode] = []
        while cursor < lines.count {
            let line = lines[cursor]
            if line.level < level { break }   // belongs to an ancestor — let the caller handle it
            if line.level > level {
                diagnostics.append(Diagnostic(
                    severity: .warning,
                    message: "Unexpected nesting: level \(line.level) where \(level) was expected; "
                           + "attaching in place to avoid data loss.",
                    lineNumber: line.lineNumber))
            }
            cursor += 1
            // This line's children are everything deeper than IT (use its own level + 1, which is
            // correct even when we adopted a level-jumped line above).
            let children = parseNodes(lines, &cursor, atLevel: line.level + 1, diagnostics: &diagnostics)
            nodes.append(makeNode(line, children: children))
        }
        return nodes
    }

    /// Build a node and compute its source line span (own line through the deepest descendant line).
    private static func makeNode(_ line: GedcomLine, children: [GedcomNode]) -> GedcomNode {
        let deepestChildEnd = children.map { $0.sourceLineRange.upperBound }.max()
        let end = max(line.lineNumber, deepestChildEnd ?? line.lineNumber)
        return GedcomNode(line: line, children: children, sourceLineRange: line.lineNumber...end)
    }

    // MARK: - Dangling pointer detection

    /// Walk the whole forest; for each node whose value is a pointer to an undefined record, add one
    /// error diagnostic. Recurses through children so nested pointers (HUSB/WIFE/CHIL/FAMC/…) count.
    private static func detectDanglingPointers(_ nodes: [GedcomNode],
                                               index: [Xref: Int],
                                               into diagnostics: inout [Diagnostic]) {
        for node in nodes {
            if let value = node.value, looksLikePointer(value), index[Xref(value)] == nil {
                diagnostics.append(Diagnostic(
                    severity: .error,
                    message: "Dangling reference: \(node.tag) points to \(value), which no record defines.",
                    lineNumber: node.line.lineNumber))
            }
            detectDanglingPointers(node.children, index: index, into: &diagnostics)
        }
    }

    /// True if a value is a cross-reference pointer that is EXPECTED to resolve to a record, i.e.
    /// `@something@` — but NOT the special GEDCOM 7.0 `@VOID@` placeholder, which deliberately
    /// points to nothing and must never be reported as dangling.
    private static func looksLikePointer(_ value: String) -> Bool {
        value.count >= 3 && value.hasPrefix("@") && value.hasSuffix("@") && value != "@VOID@"
    }
}
