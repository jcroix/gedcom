//
// RelationshipPhrasing.swift — turn a relationship label into a full sentence for the UI (A7).
//
// RelationshipCalculator returns a bare label ("father", "1st cousin", "no known connection",
// "same person"). The relationship screen wants a full sentence with both names. This tiny helper
// owns that phrasing — including the special-case wordings — so it can be unit-tested apart from the
// view. "subject is the <label> of base" reads as e.g. "Henry is the son of John".
//
// STUB (TDD red phase): returns empty until the test drives it.
//

public enum RelationshipPhrasing {
    /// A full sentence describing how `subject` relates to `base`, given the calculator's `label`.
    public static func sentence(subject: String, base: String, label: String) -> String {
        switch label {
        case "no known connection": return "\(subject) and \(base) are not related."
        case "same person":         return "\(subject) and \(base) are the same person."
        default:                    return "\(subject) is the \(label) of \(base)."
        }
    }
}
