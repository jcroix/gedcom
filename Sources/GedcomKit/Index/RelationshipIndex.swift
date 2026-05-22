//
// RelationshipIndex.swift — the parent<->child graph the relationship calculator walks.
//
// The source file stores relationships ONLY top-down on FAM records (HUSB/WIFE are parents, CHIL
// are children); individuals carry no FAMC/FAMS back-pointers. This index reconstructs the graph
// query.py built with networkx, but keeps BOTH directions natively so no graph-reversal is ever
// needed:
//   * childrenOf[parent] = that parent's children
//   * parentsOf[child]    = that child's parents
// It also synthesizes the FAMC/FAMS back-links the file lacks (which family a person is a child
// of / a spouse in), so the app can navigate a person -> their families.
//
// Like query.py's build_graph, an edge is only created when BOTH endpoints are known individuals
// (dangling CHIL/HUSB/WIFE pointers are skipped — those are already flagged as diagnostics by the
// tree builder). Adjacency lists keep INSERTION ORDER and are de-duplicated, so traversal is
// deterministic (query.py used Python sets, whose order is not).
//
// STUB (TDD red phase): `build` returns empty maps; population is filled in by tests.
//

/// An immutable parent<->child graph plus synthesized family back-links, derived from a document.
public struct RelationshipIndex: Sendable {
    /// child xref -> its parents, in the order families/parents were encountered.
    public let parentsOf: [Xref: [Xref]]
    /// parent xref -> its children, in encountered order.
    public let childrenOf: [Xref: [Xref]]
    /// person xref -> FAM records where they appear as a child (synthesized FAMC).
    public let familiesAsChild: [Xref: [Xref]]
    /// person xref -> FAM records where they appear as a spouse (synthesized FAMS).
    public let familiesAsSpouse: [Xref: [Xref]]

    public init(parentsOf: [Xref: [Xref]],
                childrenOf: [Xref: [Xref]],
                familiesAsChild: [Xref: [Xref]],
                familiesAsSpouse: [Xref: [Xref]]) {
        self.parentsOf = parentsOf
        self.childrenOf = childrenOf
        self.familiesAsChild = familiesAsChild
        self.familiesAsSpouse = familiesAsSpouse
    }

    /// The parents of `person` (empty if none/unknown).
    public func parents(of person: Xref) -> [Xref] { parentsOf[person] ?? [] }
    /// The children of `person` (empty if none/unknown).
    public func children(of person: Xref) -> [Xref] { childrenOf[person] ?? [] }

    /// Build the index from a fully projected document. Only edges between known individuals are
    /// added; dangling family pointers are ignored here (already diagnosed during tree building).
    public static func build(from document: GedcomDocument) -> RelationshipIndex {
        var parentsOf: [Xref: [Xref]] = [:]
        var childrenOf: [Xref: [Xref]] = [:]
        var familiesAsChild: [Xref: [Xref]] = [:]
        var familiesAsSpouse: [Xref: [Xref]] = [:]

        // Walk families in FILE ORDER so edge/back-link insertion is deterministic.
        for family in document.allFamilies {
            let parents = family.spouses.filter { document.individuals[$0] != nil }
            let children = family.children.filter { document.individuals[$0] != nil }

            // Synthesize the FAMC/FAMS back-links the file omits.
            for spouse in parents { familiesAsSpouse[spouse, default: []].append(family.id) }
            for child in children { familiesAsChild[child, default: []].append(family.id) }

            // Parent->child edges (both directions), one per (parent, child) pair.
            for parent in parents {
                for child in children {
                    appendUnique(child, to: &childrenOf, under: parent)
                    appendUnique(parent, to: &parentsOf, under: child)
                }
            }
        }

        return RelationshipIndex(parentsOf: parentsOf, childrenOf: childrenOf,
                                 familiesAsChild: familiesAsChild, familiesAsSpouse: familiesAsSpouse)
    }

    /// Append `value` to the adjacency list at `key`, skipping duplicates (a person can appear in
    /// two families with the same other parent only once as an edge).
    private static func appendUnique(_ value: Xref, to dict: inout [Xref: [Xref]], under key: Xref) {
        if dict[key]?.contains(value) == true { return }
        dict[key, default: []].append(value)
    }
}
