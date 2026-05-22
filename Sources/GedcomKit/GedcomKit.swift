//
// GedcomKit.swift — module root / namespace anchor for the GEDCOM engine.
//
// This file exists mainly so the GedcomKit target has at least one source file from the very
// first commit (an empty SPM target won't build). As real types arrive (Lexer, GedcomTree,
// the typed model, RelationshipCalculator, QualityChecker) they live in their own files under
// the subdirectories named in DevelopmentPlan.md; this file stays small.
//
// `Xref` is defined here because it is the single most pervasive concept in the engine: every
// INDI/FAM record is identified by its GEDCOM cross-reference id (the `@I001@` / `@F12@` token),
// and the whole in-memory model is dictionary-keyed by it. Giving it a named type (instead of
// passing raw Strings around) makes signatures self-documenting and prevents accidentally mixing
// an xref up with an arbitrary string value.

import Foundation

/// A GEDCOM cross-reference identifier — the `@…@` token that names a top-level record,
/// e.g. `@I001@` for an individual or `@F12@` for a family.
///
/// Stored WITH the surrounding `@` delimiters exactly as they appear in the file, because the
/// lossless layer must reproduce the original bytes and the future writer must preserve the
/// exact id set. Code that needs the bare id (without `@`) should derive it, never mutate this.
///
/// It's a thin wrapper over `String` (a "newtype") so that:
///   * dictionaries/sets keyed by xref are type-checked (`[Xref: Individual]`, not `[String: …]`),
///   * an xref can't be silently confused with a name, tag, or note text.
public struct Xref: Hashable, Sendable, Comparable, CustomStringConvertible {
    /// The raw identifier including delimiters, e.g. "@I001@".
    public let value: String

    public init(_ value: String) {
        self.value = value
    }

    public var description: String { value }

    /// Ordered lexicographically by raw value. Used for DETERMINISTIC tie-breaking — notably the
    /// relationship calculator's lowest-common-ancestor pick, where query.py was nondeterministic
    /// on ties (see DevelopmentPlan.md). A stable order here makes golden tests reproducible.
    public static func < (lhs: Xref, rhs: Xref) -> Bool {
        lhs.value < rhs.value
    }
}
