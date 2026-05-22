//
// GedcomEncoding.swift — the character encodings the engine knows how to talk about.
//
// GEDCOM files declare their encoding in the header (`1 CHAR <name>`), and may also carry a
// byte-order mark. v1 fully supports UTF-8 (the real family.ged) and ships a SEAM for ANSEL
// (the legacy GEDCOM 5.5.1 default) that currently falls back to Latin-1 with a diagnostic
// rather than corrupting data silently. Anything else is recorded by name so the app can warn.
//

/// A character encoding a GEDCOM file may declare or that we detect from a BOM.
public enum GedcomEncoding: Equatable, Sendable {
    /// UTF-8 — detected from a UTF-8 BOM or a `CHAR UTF-8` header. Fully supported.
    case utf8
    /// ANSEL — the legacy 5.5.1 default. SEAM: not yet truly decoded (Latin-1 fallback for now).
    case ansel
    /// A recognized-by-name but not specially handled encoding (e.g. "ASCII", "ANSI"). The
    /// associated value is the verbatim CHAR value so the app can show what the file claimed.
    case other(String)
    /// No `CHAR` declaration was found in the header and no BOM was present.
    case unknown
}
