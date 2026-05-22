//
// Diagnostic.swift — the engine's single, shared "something was off" record.
//
// WHY THIS TYPE EXISTS: the whole engine is DEFENSIVE by contract (see CLAUDE.md /
// DevelopmentPlan.md). A malformed line, a dangling xref, an unimplemented encoding, or an
// unparseable name must NEVER throw out the file — instead we keep going and append a
// Diagnostic. Every layer (lexer, tree builder, model projection, quality checker) produces
// the same Diagnostic type, so the app can surface them all in one list and a test can assert
// "exactly one diagnostic, of this severity, on this line".
//

import Foundation

/// A non-fatal note about something unexpected encountered while reading a GEDCOM file.
///
/// Diagnostics are accumulated, not thrown. `lineNumber` is 1-based and optional because some
/// diagnostics are file-wide (e.g. "declared encoding ANSEL not yet supported") rather than
/// tied to a specific physical line.
public struct Diagnostic: Equatable, Sendable {

    /// How serious the issue is. `info` = noteworthy but harmless, `warning` = data may be
    /// degraded, `error` = something was dropped/skipped. None of these abort parsing.
    public enum Severity: Sendable, Equatable {
        case info
        case warning
        case error
    }

    public let severity: Severity
    public let message: String

    /// 1-based source line this diagnostic refers to, or nil for file-wide diagnostics.
    public let lineNumber: Int?

    public init(severity: Severity, message: String, lineNumber: Int? = nil) {
        self.severity = severity
        self.message = message
        self.lineNumber = lineNumber
    }
}
