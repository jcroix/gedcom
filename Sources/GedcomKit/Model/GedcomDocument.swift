//
// GedcomDocument.swift — the top-level entry point: bytes/text in, a fully projected model out.
//
// This is the one type the app (and most tests) actually call. It runs the whole pipeline —
// decode -> lex -> build tree -> project typed records — and collects EVERY diagnostic from all
// stages into one list. It keeps the lossless `tree` (source of truth) plus xref-keyed
// dictionaries of the typed projections for O(1) lookup, and exposes file-ordered accessors for
// display. It also records the detected GEDCOM version and encoding so the app can adapt/warn.
//
// It does NOT build the relationship graph — that's RelationshipIndex (E4), which consumes this.
//
// STUB (TDD red phase): `parse`/`load` build the tree but project nothing; filled in by tests.
//

import Foundation

/// A fully parsed GEDCOM document: lossless tree + typed projections + all diagnostics.
public struct GedcomDocument: Sendable {
    public let tree: GedcomTree
    public let individuals: [Xref: Individual]
    public let families: [Xref: Family]
    public let sources: [Xref: Source]
    public let repositories: [Xref: Repository]
    public let mediaObjects: [Xref: MediaObject]   // top-level OBJE records (not inline links)
    public let diagnostics: [Diagnostic]

    /// GEDCOM version from HEAD.GEDC.VERS (e.g. "5.5.1", "7.0"), or nil if absent. Used for
    /// version-lenient projection where 5.5.1 and 7.0 genuinely differ.
    public let gedcomVersion: String?
    /// The encoding the bytes were decoded with (.unknown when parsed from a String directly).
    public let encoding: GedcomEncoding

    public init(tree: GedcomTree,
                individuals: [Xref: Individual],
                families: [Xref: Family],
                sources: [Xref: Source],
                repositories: [Xref: Repository],
                mediaObjects: [Xref: MediaObject],
                diagnostics: [Diagnostic],
                gedcomVersion: String?,
                encoding: GedcomEncoding) {
        self.tree = tree
        self.individuals = individuals
        self.families = families
        self.sources = sources
        self.repositories = repositories
        self.mediaObjects = mediaObjects
        self.diagnostics = diagnostics
        self.gedcomVersion = gedcomVersion
        self.encoding = encoding
    }

    // MARK: File-ordered accessors (map the tree's record order onto the typed projections)

    public var allIndividuals: [Individual] { ordered(tag: "INDI", from: individuals) }
    public var allFamilies: [Family] { ordered(tag: "FAM", from: families) }
    public var allSources: [Source] { ordered(tag: "SOUR", from: sources) }
    public var allRepositories: [Repository] { ordered(tag: "REPO", from: repositories) }

    /// Records of `tag` in file order, looked up in the given projection dictionary by xref.
    private func ordered<V>(tag: String, from dict: [Xref: V]) -> [V] {
        tree.records.compactMap { $0.tag == tag ? $0.xref.flatMap { dict[$0] } : nil }
    }

    // MARK: Loading

    /// Parse from already-decoded text (encoding reported as .unknown). Used mostly by tests.
    public static func parse(_ text: String) -> GedcomDocument {
        let lex = GedcomLexer.lex(text)
        let built = GedcomTreeBuilder.build(from: lex.lines)
        return project(tree: built.tree,
                       priorDiagnostics: lex.diagnostics + built.diagnostics,
                       encoding: .unknown)
    }

    /// Load from raw file bytes: detect encoding, decode, then parse. The real app entry point.
    public static func load(_ data: Data) -> GedcomDocument {
        let decoded = GedcomByteDecoder.decode(data)
        let lex = GedcomLexer.lex(decoded.text)
        let built = GedcomTreeBuilder.build(from: lex.lines)
        return project(tree: built.tree,
                       priorDiagnostics: decoded.diagnostics + lex.diagnostics + built.diagnostics,
                       encoding: decoded.encoding)
    }

    /// Project every top-level record into its typed form and assemble the document.
    private static func project(tree: GedcomTree,
                                priorDiagnostics: [Diagnostic],
                                encoding: GedcomEncoding) -> GedcomDocument {
        var individuals: [Xref: Individual] = [:]
        var families: [Xref: Family] = [:]
        var sources: [Xref: Source] = [:]
        var repositories: [Xref: Repository] = [:]
        var mediaObjects: [Xref: MediaObject] = [:]

        // One pass over top-level records, dispatching each to its projection by tag. Records
        // without an xref (HEAD/TRLR) and tags we don't model stay only in the tree (still
        // reachable losslessly), which is correct per the "nothing hidden" rule.
        for record in tree.records {
            guard let xref = record.xref else { continue }
            switch record.tag {
            case "INDI": individuals[xref] = Individual.from(node: record)
            case "FAM":  families[xref] = Family.from(node: record)
            case "SOUR": sources[xref] = Source.from(node: record)
            case "REPO": repositories[xref] = Repository.from(node: record)
            case "OBJE": mediaObjects[xref] = MediaObject.from(node: record)
            default:     break
            }
        }

        // HEAD.GEDC.VERS, used for version-lenient behavior downstream.
        let version = tree.records.first { $0.tag == "HEAD" }?
            .firstChild(tag: "GEDC")?.firstValue(tag: "VERS")

        return GedcomDocument(tree: tree,
                              individuals: individuals,
                              families: families,
                              sources: sources,
                              repositories: repositories,
                              mediaObjects: mediaObjects,
                              diagnostics: priorDiagnostics,
                              gedcomVersion: version,
                              encoding: encoding)
    }
}
