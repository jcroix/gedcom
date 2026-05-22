//
// MediaObject.swift — an OBJE record (or inline multimedia link): a file attachment.
//
// A multimedia object references an external FILE with a FORM (format) and optional TITL. In
// 5.5.1 the structure is OBJE > FILE / FORM / TITL; in 7.0 the FORM nests under FILE. We read
// FORM from wherever it appears (direct child, else under FILE) so both versions work.
//
// STUB (TDD red phase): `from(node:)` returns an empty projection; fields filled in by tests.
//

/// A projection of a multimedia object (OBJE). `id` is nil for an inline OBJE (no xref).
public struct MediaObject: Identifiable, Equatable, Sendable {
    public let id: Xref?
    public let file: String?     // FILE (path/URL)
    public let format: String?   // FORM (jpg, pdf, …)
    public let title: String?    // TITL
    public let node: GedcomNode

    public init(id: Xref?, file: String?, format: String?, title: String?, node: GedcomNode) {
        self.id = id
        self.file = file
        self.format = format
        self.title = title
        self.node = node
    }

    /// Project an OBJE node into a MediaObject.
    public static func from(node: GedcomNode) -> MediaObject {
        let fileNode = node.firstChild(tag: "FILE")
        // FORM is a direct child in 5.5.1, but nests under FILE in 7.0 — accept either.
        let format = node.firstValue(tag: "FORM") ?? fileNode?.firstValue(tag: "FORM")
        return MediaObject(
            id: node.xref,
            file: fileNode?.value,
            format: format,
            title: node.firstValue(tag: "TITL"),
            node: node)
    }
}
