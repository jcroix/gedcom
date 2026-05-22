//
// GedcomLexer.swift — turns raw GEDCOM text into a flat stream of GedcomLine tokens.
//
// The lexer is the first parse layer. It does ONE thing: split each physical line into its
// (level, optional xref, tag, optional value) parts. It does NOT build a tree, resolve
// pointers, or assemble CONT/CONC continuation lines — those are later layers' jobs.
//
// Tokenization rule for one line, after stripping any trailing CR:
//
//     <level> SP [ @xref@ SP ] <tag> [ SP <value...> ]
//
//   * The level is the leading integer.
//   * If the token right after the level is wrapped in `@…@`, it's the record id (xref) this
//     line DEFINES. (A pointer that merely refers to another record — e.g. FAMC's `@F1@` — is
//     NOT this; it lands in `value`.)
//   * The next token is the tag.
//   * Everything after the tag's delimiting space is the value, kept VERBATIM (it may contain
//     spaces, slashes, parentheses, or be a pointer like `@F1@`). Verbatim preservation is what
//     keeps the future lossless writer feasible.
//

import Foundation  // for trimmingCharacters / CharacterSet used in diagnostic snippets

/// The result of lexing: the tokenized lines plus any non-fatal diagnostics gathered along the
/// way. Bundled in a struct (rather than a tuple) because diagnostics are a first-class part of
/// the lexer's contract and this keeps call sites self-documenting.
public struct LexResult: Equatable, Sendable {
    public let lines: [GedcomLine]
    public let diagnostics: [Diagnostic]

    public init(lines: [GedcomLine], diagnostics: [Diagnostic]) {
        self.lines = lines
        self.diagnostics = diagnostics
    }
}

/// Tokenizes GEDCOM text. Stateless — exposed as static functions on a caseless enum so there's
/// nothing to instantiate. Works on an already-decoded `String`; byte→String decoding (and
/// encoding detection) is a separate concern handled by the decoder seam.
public enum GedcomLexer {

    /// Tokenize `text` into one GedcomLine per meaningful physical line.
    /// Defensive: malformed lines append a Diagnostic and are skipped — never throws.
    public static func lex(_ text: String) -> LexResult {
        var lines: [GedcomLine] = []
        var diagnostics: [Diagnostic] = []
        var lineNumber = 0

        // Split on '\n' WITHOUT collapsing empties, so every physical line keeps its true
        // 1-based number even when we skip it. (CRLF files are handled by stripping a trailing
        // '\r' per line below.)
        for rawLine in text.split(separator: "\n", omittingEmptySubsequences: false) {
            lineNumber += 1
            var content = rawLine
            if content.hasSuffix("\r") { content = content.dropLast() }

            if let line = parseLine(content, number: lineNumber, into: &diagnostics) {
                lines.append(line)
            }
        }

        return LexResult(lines: lines, diagnostics: diagnostics)
    }

    // MARK: - Single line

    /// Parse one physical line's content (no trailing newline) into a GedcomLine, or return nil
    /// (appending a Diagnostic) if it's malformed. See the file header for the grammar.
    private static func parseLine(_ content: Substring,
                                  number: Int,
                                  into diagnostics: inout [Diagnostic]) -> GedcomLine? {
        // Tolerate stray leading spaces (some exporters indent); GEDCOM levels carry the real
        // nesting, so leading whitespace is not meaningful.
        var line = content
        while line.first == " " { line = line.dropFirst() }

        // Blank / whitespace-only lines are common between records (some exporters emit them).
        // They carry no data, so we skip them silently — no token, no diagnostic. The caller
        // still advanced the line counter, so later lines keep their true 1-based numbers.
        if line.isEmpty || line.allSatisfy({ $0 == " " || $0 == "\t" }) {
            return nil
        }

        // The leading integer level.
        let (levelToken, afterLevel) = splitFirstToken(line)
        guard let level = Int(levelToken), level >= 0 else {
            diagnostics.append(Diagnostic(
                severity: .error,
                message: "Malformed line: missing or non-numeric level (\(snippet(content))).",
                lineNumber: number))
            return nil
        }
        guard let afterLevel else {
            // A bare level with no tag (e.g. "0") is meaningless.
            diagnostics.append(Diagnostic(
                severity: .error,
                message: "Malformed line: level with no tag (\(snippet(content))).",
                lineNumber: number))
            return nil
        }

        // The token after the level is either the record id (@xref@) or the tag.
        let (firstToken, afterFirst) = splitFirstToken(afterLevel)
        if isXref(firstToken) {
            guard let afterFirst else {
                diagnostics.append(Diagnostic(
                    severity: .error,
                    message: "Malformed line: xref \(firstToken) with no tag (\(snippet(content))).",
                    lineNumber: number))
                return nil
            }
            let (tagToken, valueToken) = splitFirstToken(afterFirst)
            return GedcomLine(level: level,
                              xref: Xref(String(firstToken)),
                              tag: String(tagToken),
                              value: valueToken.map(String.init),
                              lineNumber: number)
        } else {
            // No xref: firstToken is the tag, the remainder (if any) is the value.
            return GedcomLine(level: level,
                              xref: nil,
                              tag: String(firstToken),
                              value: afterFirst.map(String.init),
                              lineNumber: number)
        }
    }

    // MARK: - Small helpers

    /// Split `s` at its first space into (firstToken, everythingAfterThatSpace). The remainder is
    /// nil when there is no space (i.e. `s` is a single token). The remainder is returned verbatim
    /// so a value's internal spaces are preserved.
    private static func splitFirstToken(_ s: Substring) -> (Substring, Substring?) {
        guard let space = s.firstIndex(of: " ") else { return (s, nil) }
        return (s[s.startIndex..<space], s[s.index(after: space)...])
    }

    /// True if `token` looks like a GEDCOM cross-reference id: `@…@` with something in between.
    private static func isXref(_ token: Substring) -> Bool {
        token.count >= 3 && token.hasPrefix("@") && token.hasSuffix("@")
    }

    /// A short, single-line preview of a raw line for diagnostic messages.
    private static func snippet(_ content: Substring) -> String {
        let s = content.trimmingCharacters(in: .whitespaces)
        return s.count <= 40 ? "'\(s)'" : "'\(s.prefix(40))…'"
    }
}
