//
// GedcomTree.swift — the whole lossless document as an ordered forest of records + an xref index.
//
// A GedcomTree holds every top-level record (HEAD, each INDI/FAM, TRLR, …) as a GedcomNode, IN
// FILE ORDER, and a dictionary mapping each record's xref to its position for O(1) lookup. Keeping
// both the ordered array AND the dictionary is deliberate: order is needed for the future
// lossless writer and for stable display; the dictionary is needed because relationship math and
// pointer resolution look records up by id constantly.
//

/// The lossless, in-memory representation of a parsed GEDCOM file.
public struct GedcomTree: Sendable {

    /// All top-level (level-0) records in original file order.
    public let records: [GedcomNode]

    /// Maps a record's xref to its index in `records`. Only records that DEFINE an xref appear
    /// here (HEAD and TRLR don't). Stored as an index (not a copied node) to avoid duplicating
    /// node data, since GedcomNode is a value type.
    public let index: [Xref: Int]

    public init(records: [GedcomNode], index: [Xref: Int]) {
        self.records = records
        self.index = index
    }

    /// The record defined by `xref`, or nil if no such record exists. O(1).
    public func record(for xref: Xref) -> GedcomNode? {
        guard let i = index[xref] else { return nil }
        return records[i]
    }

    /// All top-level records carrying the given tag, in file order (e.g. every INDI). O(n) — used
    /// for building the typed model once at load, not on hot paths.
    public func records(tag: String) -> [GedcomNode] {
        records.filter { $0.tag == tag }
    }
}
