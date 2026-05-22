//
// AnselDecoder.swift — the ANSEL decoding SEAM.
//
// ANSEL is the legacy character set GEDCOM 5.5.1 declares by default. A correct decoder needs a
// 256-entry mapping table PLUS combining-mark reordering (ANSEL puts the diacritic byte BEFORE
// the base letter, the reverse of Unicode). The real family.ged is UTF-8, so building that table
// is deliberately deferred (DevelopmentPlan.md E1) — but the dispatch path ships now so an ANSEL
// file degrades predictably instead of crashing or being silently mangled.
//
// CURRENT BEHAVIOR (the seam): decode the bytes as Latin-1 (ISO-8859-1), which maps every byte to
// some character and so never fails, and emit ONE warning diagnostic. ASCII (0x00–0x7F) is
// identical across ANSEL/Latin-1/UTF-8, so the structural parts of the file (levels, tags, xrefs)
// come through correctly; only high-byte accented characters may be wrong, and the warning says so.
//
// TO FINISH LATER: replace the Latin-1 fallback with the real ANSEL table + combining-mark
// reordering, and drop (or downgrade) the diagnostic. The seam's public shape should not need to
// change — callers already treat the text as best-effort and surface diagnostics.
//

import Foundation

/// Best-effort ANSEL decoding. Stateless caseless enum.
enum AnselDecoder {

    /// Decode ANSEL-declared `data`. Returns Latin-1 text plus one warning diagnostic explaining
    /// that true ANSEL support is not implemented yet. Never fails.
    static func decode(_ data: Data) -> (text: String, diagnostics: [Diagnostic]) {
        // Latin-1 maps all 256 byte values, so this initializer cannot return nil; the
        // `?? ""` is just to satisfy the optional and keeps us crash-proof regardless.
        let text = String(data: data, encoding: .isoLatin1) ?? ""
        let diagnostic = Diagnostic(
            severity: .warning,
            message: "File declares ANSEL encoding, which is not yet fully supported; decoded as "
                   + "Latin-1. ASCII text is correct, but accented/non-ASCII characters may be wrong.")
        return (text, [diagnostic])
    }
}
