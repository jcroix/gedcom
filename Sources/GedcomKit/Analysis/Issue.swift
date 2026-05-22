//
// Issue.swift — one finding from the data-quality checker.
//
// An Issue is a CONSISTENCY/PLAUSIBILITY finding about the genealogical data (e.g. a child born
// before its parent), as opposed to a Diagnostic, which is about FILE/PARSE problems (a malformed
// line, a bad encoding). They're separate types because they drive separate UI: Diagnostics are
// "this file has problems"; Issues are "this research has problems worth reviewing".
//
// Each Issue names the people involved (so the Quality UI can jump to them) and, when it stems
// from a single record, carries that record's source line range for "jump to source".
//

/// A data-quality finding produced by the QualityChecker.
public struct Issue: Equatable, Sendable {

    /// Which rule produced the issue. Stable raw values double as grouping keys for the UI.
    public enum Category: String, Sendable, CaseIterable {
        case childBeforeParent      // a child's birth precedes a parent's birth
        case deathBeforeBirth       // an individual's death precedes their birth
        case parentTooYoung         // a parent was implausibly young at a child's birth
        case parentTooOld           // a parent was implausibly old at a child's birth
        case implausibleLifespan    // an individual lived implausibly long
        case eventAfterDeath        // a (non-postmortem) event dated after the individual's death
        case missingBirthDate       // an individual has no usable birth date
        case brokenReference        // a relationship pointer names a record that doesn't exist
        case possibleDuplicate      // two individuals look like the same person
    }

    public let category: Category
    public let severity: Diagnostic.Severity     // reuse the shared severity scale
    public let message: String
    public let individuals: [Xref]               // people involved (1 or 2)
    public let sourceLineRange: ClosedRange<Int>?

    public init(category: Category,
                severity: Diagnostic.Severity,
                message: String,
                individuals: [Xref],
                sourceLineRange: ClosedRange<Int>? = nil) {
        self.category = category
        self.severity = severity
        self.message = message
        self.individuals = individuals
        self.sourceLineRange = sourceLineRange
    }
}
