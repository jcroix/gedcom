//
// RelationshipCalculator.swift — function-for-function port of query.py's relationship logic.
//
// Given two people, it returns a plain-English label for how one relates to the other, plus the
// path through their lowest common ancestor (LCA). The algorithm mirrors query.py exactly so its
// captured outputs serve as golden tests:
//   _ancestors  -> ancestors(of:)      BFS upward, ancestor -> generations above
//   _path_up    -> pathUp(from:to:)    BFS up the parent edges to a known ancestor
//   _ascend/_descend/_collateral_label -> the label helpers below
//   find_relationship -> relationship(of:to:)
//
// ONE DELIBERATE FIX vs. query.py (per DevelopmentPlan.md): query.py's
//   ca = min(common, key=lambda a: anc1[a]+anc2[a])
// is nondeterministic when several common ancestors tie on total distance (Python picks an
// arbitrary one). We add an Xref tie-break so the LCA — and therefore the label and path — are
// STABLE and reproducible in tests. The naive `_ordinal` (which yields "11th"→"11th" but also
// "21th") is reproduced AS-IS so labels match query.py character-for-character.
//
// STUB (TDD red phase): `relationship` returns a placeholder; the port is filled in by tests.
//

/// Computes English relationship labels + connecting paths. Stateless caseless enum.
public enum RelationshipCalculator {

    /// The outcome: a label and the path of xrefs from the base person to the subject through the
    /// LCA (nil path when there is no connection or an input isn't a known individual).
    public struct Result: Equatable, Sendable {
        public let label: String
        public let path: [Xref]?

        public init(label: String, path: [Xref]?) {
            self.label = label
            self.path = path
        }
    }

    /// Describe how `subject` is related to `base` — read as "subject is the <label> of base".
    /// (Maps to query.py find_relationship(id1: base, id2: subject).)
    public static func relationship(of subject: Xref,
                                    to base: Xref,
                                    in index: RelationshipIndex,
                                    document: GedcomDocument) -> Result {
        // Match query.py's naming: id1 is the reference (base), id2 is the one described (subject).
        let id1 = base, id2 = subject

        if id1 == id2 { return Result(label: "same person", path: [id1]) }
        guard document.individuals[id1] != nil else { return Result(label: "\"\(id1)\" not in graph", path: nil) }
        guard document.individuals[id2] != nil else { return Result(label: "\"\(id2)\" not in graph", path: nil) }

        let anc1 = ancestors(of: id1, in: index)
        let anc2 = ancestors(of: id2, in: index)
        let subjectIsFemale = document.individuals[id2]?.sex == .female

        // subject is a direct ancestor of base -> ascend label (father/grandfather/…)
        if let generations = anc1[id2] {
            return Result(label: ascendLabel(generations, isFemale: subjectIsFemale),
                          path: pathUp(from: id1, to: id2, in: index))
        }
        // base is a direct ancestor of subject -> descend label (son/grandson/…)
        if let generations = anc2[id1] {
            let path = pathUp(from: id2, to: id1, in: index)
            return Result(label: descendLabel(generations, isFemale: subjectIsFemale),
                          path: Array(path.reversed()))
        }

        // Collateral: find the lowest common ancestor.
        let common = Set(anc1.keys).intersection(anc2.keys)
        guard !common.isEmpty else { return Result(label: "no known connection", path: nil) }

        // query.py: min(common, key=anc1[a]+anc2[a]) — nondeterministic on ties. We add an Xref
        // tie-break so the chosen LCA (and thus label + path) is stable.
        let lca = common.min { a, b in
            let totalA = anc1[a]! + anc2[a]!
            let totalB = anc1[b]! + anc2[b]!
            return totalA != totalB ? totalA < totalB : a < b
        }!

        let label = collateralLabel(anc1[lca]!, anc2[lca]!, isFemale: subjectIsFemale)
        let pathToLCA = pathUp(from: id1, to: lca, in: index)
        let pathFromLCA = pathUp(from: id2, to: lca, in: index)
        // full path = base→LCA, then LCA→subject (reverse of subject→LCA, dropping the duplicated LCA)
        let fullPath = pathToLCA + Array(pathFromLCA.reversed().dropFirst())
        return Result(label: label, path: fullPath)
    }

    // MARK: - Graph walks (ports of _ancestors / _path_up)

    /// BFS upward from `node` following parent edges; returns ancestor -> generations above (1 =
    /// parent, 2 = grandparent, …). `node` itself is excluded. Mirrors query.py `_ancestors`.
    static func ancestors(of node: Xref, in index: RelationshipIndex) -> [Xref: Int] {
        var result: [Xref: Int] = [:]
        var queue: [(Xref, Int)] = [(node, 0)]
        var seen: Set<Xref> = []
        while !queue.isEmpty {
            let (current, depth) = queue.removeFirst()
            if seen.contains(current) { continue }
            seen.insert(current)
            if current != node { result[current] = depth }
            for parent in index.parents(of: current) where !seen.contains(parent) {
                queue.append((parent, depth + 1))
            }
        }
        return result
    }

    /// Shortest path from `start` up to `ancestor` following parent edges, inclusive of both ends.
    /// Mirrors query.py `_path_up` (BFS on the reversed/child→parent graph). Falls back to
    /// [start, ancestor] if no path is found, exactly as query.py does.
    static func pathUp(from start: Xref, to ancestor: Xref, in index: RelationshipIndex) -> [Xref] {
        if start == ancestor { return [start] }
        var visited: Set<Xref> = [start]
        var queue: [[Xref]] = [[start]]
        while !queue.isEmpty {
            let path = queue.removeFirst()
            for parent in index.parents(of: path.last!) {
                if parent == ancestor { return path + [parent] }
                if !visited.contains(parent) {
                    visited.insert(parent)
                    queue.append(path + [parent])
                }
            }
        }
        return [start, ancestor]
    }

    // MARK: - Label helpers (ports of _ordinal / _ascend_label / _descend_label / _collateral_label)

    /// "1st", "2nd", "3rd", else "<n>th". Reproduces query.py's naive rule verbatim (so e.g. 21
    /// becomes "21th") — fidelity to the golden output matters more than English correctness here.
    private static func ordinal(_ n: Int) -> String {
        switch n {
        case 1: return "1st"
        case 2: return "2nd"
        case 3: return "3rd"
        default: return "\(n)th"
        }
    }

    /// father / grandfather / great-grandfather (n-2 "great-" prefixes); mother/grandmother for F.
    private static func ascendLabel(_ n: Int, isFemale: Bool) -> String {
        if n == 1 { return isFemale ? "mother" : "father" }
        if n == 2 { return isFemale ? "grandmother" : "grandfather" }
        return String(repeating: "great-", count: n - 2) + (isFemale ? "grandmother" : "grandfather")
    }

    /// son / grandson / great-grandson; daughter/granddaughter for F.
    private static func descendLabel(_ n: Int, isFemale: Bool) -> String {
        if n == 1 { return isFemale ? "daughter" : "son" }
        if n == 2 { return isFemale ? "granddaughter" : "grandson" }
        return String(repeating: "great-", count: n - 2) + (isFemale ? "granddaughter" : "grandson")
    }

    /// Collateral label from the base person's perspective. `n1` = base's steps up to the LCA,
    /// `n2` = subject's steps up to the LCA. Direct port of query.py `_collateral_label`.
    private static func collateralLabel(_ n1: Int, _ n2: Int, isFemale: Bool) -> String {
        if n1 == 0 { return descendLabel(n2, isFemale: isFemale) }
        if n2 == 0 { return ascendLabel(n1, isFemale: isFemale) }

        let mn = min(n1, n2), mx = max(n1, n2)
        let removal = mx - mn

        if mn == 1 {
            if removal == 0 { return "sibling" }
            if n2 > n1 {
                // subject is further from the LCA — a younger generation -> niece/nephew
                let base = isFemale ? "niece" : "nephew"
                return removal == 1 ? base : String(repeating: "great-", count: removal - 1) + base
            } else {
                // subject is closer to the LCA — an older generation -> aunt/uncle
                let base = isFemale ? "aunt" : "uncle"
                return removal == 1 ? base : String(repeating: "great-", count: removal - 1) + base
            }
        }

        let cousinNumber = mn - 1
        let base = "\(ordinal(cousinNumber)) cousin"
        return removal == 0 ? base : "\(base) \(removal)× removed"
    }
}
