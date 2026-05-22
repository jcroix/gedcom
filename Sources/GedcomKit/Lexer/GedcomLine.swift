//
// GedcomLine.swift — one tokenized physical line of a GEDCOM file.
//
// GEDCOM is a line-based format. Every meaningful line has the grammar:
//
//     level  [@xref@]  tag  [value]
//
// e.g.   "0 HEAD"                      -> level 0, tag HEAD
//        "0 @I001@ INDI"              -> level 0, xref @I001@, tag INDI   (defines a record)
//        "1 NAME John /Crox/"         -> level 1, tag NAME, value "John /Crox/"
//        "2 DATE ABT 1797"            -> level 2, tag DATE, value "ABT 1797"
//        "1 FAMC @F1@"                -> level 1, tag FAMC, value "@F1@"  (value is a pointer)
//        "1 _FSFTID L1AB-2CD"         -> level 1, tag _FSFTID, value ...   (custom tag, kept as-is)
//
// IMPORTANT distinction: the optional `xref` field is the id this line *defines* (it sits
// between the level and the tag). A pointer that REFERS to another record (like FAMC's @F1@)
// is just the `value` — we do not parse it into `xref`. Resolving value-pointers to records is
// the tree/index layer's job, not the lexer's.
//
// This is a pure token: the lexer emits one GedcomLine per physical line and does not assemble
// CONT/CONC continuation lines into multi-line text (that happens later, in model projection,
// where the parent/child structure is available).
//

/// A single tokenized line from a GEDCOM file. Value type, comparable by value for easy testing.
public struct GedcomLine: Equatable, Sendable {

    /// Nesting depth. 0 = a top-level record (HEAD, INDI, FAM, TRLR). Children are level+1.
    public let level: Int

    /// The id this line DEFINES, including `@` delimiters (e.g. `@I001@`), or nil for the common
    /// case of a line that defines no record. NOT used for pointer values — see the file header.
    public let xref: Xref?

    /// The GEDCOM tag (HEAD, INDI, NAME, DATE, _FSFTID, …). Kept verbatim, including leading
    /// underscore for custom/vendor tags, so unknown tags survive untouched.
    public let tag: String

    /// The trailing value after the tag, or nil if the line has none. May itself be a pointer
    /// like `@F1@`. Preserved verbatim (not trimmed beyond the single delimiting space).
    public let value: String?

    /// 1-based physical line number in the source file. Used for diagnostics and (later) for the
    /// lossless tree's sourceLineRange so the future writer can produce minimal diffs.
    public let lineNumber: Int

    public init(level: Int, xref: Xref? = nil, tag: String, value: String? = nil, lineNumber: Int) {
        self.level = level
        self.xref = xref
        self.tag = tag
        self.value = value
        self.lineNumber = lineNumber
    }
}
