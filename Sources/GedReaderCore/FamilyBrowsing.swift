//
// FamilyBrowsing.swift — helpers for the Families section (A5).
//
// The only logic worth isolating from the views is ordering a family's children by birth date.
// GEDCOM lists CHIL in entry order (often, but not always, birth order); we sort by each child's
// birth sortKey so the family detail reliably shows children oldest-first, with undated children
// kept in their original listed order at the end (a stable sort via the listed index as tiebreak).
//
// STUB (TDD red phase): returns the unsorted children until the test drives it.
//

import GedcomKit

public enum FamilyBrowsing {

    /// A family's children ordered by birth date (oldest first); undated children keep their listed
    /// order and come last. Returns xrefs (the view resolves them to people for display).
    public static func childrenInBirthOrder(of family: Family, in document: GedcomDocument) -> [Xref] {
        // Pair each child with its listed index so we can sort stably (undated keep listed order).
        let indexed = family.children.enumerated().map { (listedIndex, xref) -> (Xref, Double, Int) in
            let birth = document.individuals[xref]?.birth?.date?.sortKey ?? .greatestFiniteMagnitude
            return (xref, birth, listedIndex)
        }
        return indexed
            .sorted { ($0.1, $0.2) < ($1.1, $1.2) }   // by birth year, then listed index
            .map(\.0)
    }
}
