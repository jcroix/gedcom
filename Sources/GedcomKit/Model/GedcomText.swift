//
// GedcomText.swift — assemble a node's multi-line value from its CONT/CONC continuation children.
//
// GEDCOM splits long text values (NOTE, and any long value) across several physical lines using
// two continuation tags, which the lexer/tree keep as separate child nodes (losslessly):
//   * CONT = a hard line break: the child's value starts a NEW line.
//   * CONC = a concatenation: the child's value is glued onto the previous text with NO separator
//            (used when a single logical line was wrapped to fit a line-length limit).
//
// This is the "CONT assembly" that the milestone plan listed under E1 but which truly belongs
// here, at the model layer, because it needs the parent node's CHILD structure (which the flat
// lexer doesn't have). It is intentionally one tiny function doing one thing.
//

/// Reassembles multi-line GEDCOM text. Stateless caseless enum.
public enum GedcomText {

    /// The full text of `node`: its own value followed by each CONT (newline-joined) and CONC
    /// (directly appended) child, in order. Non-continuation children are ignored (they are
    /// sub-structure, not text). Returns "" if the node has no value and no continuations.
    public static func assemble(from node: GedcomNode) -> String {
        var text = node.value ?? ""
        for child in node.children {
            switch child.tag {
            case "CONT": text += "\n" + (child.value ?? "")   // hard line break
            case "CONC": text += (child.value ?? "")          // glued on, no separator
            default: break                                    // sub-structure, not text
            }
        }
        return text
    }

    /// Collect the assembled text of every direct NOTE child of `node`, in order. Inline notes
    /// (with their CONT/CONC continuations) become their full multi-line text. NOTE values that are
    /// pointers (`@N1@`) are returned as-is here; resolving them to NOTE-record text needs the whole
    /// tree and is done at the document level. Used by every projection that can carry notes.
    public static func notes(of node: GedcomNode) -> [String] {
        node.children(tag: "NOTE").map { assemble(from: $0) }
    }
}
