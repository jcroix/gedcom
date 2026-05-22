//
// GedcomByteDecoder.swift — the decode SEAM: raw file bytes -> a Swift String, defensively.
//
// STUB (TDD red phase): returns empty text until tests drive the real per-encoding decoding.
//
// This is the single entry point the file loader calls. It detects the encoding (via
// EncodingDetector) and dispatches to the right decoding path. The guiding rule is "NEVER fail,
// NEVER silently corrupt": decoding always yields *some* String, and whenever we had to fall back
// or guess, we attach a Diagnostic so the app can warn the user instead of showing mojibake with
// no explanation. ANSEL specifically is delegated to AnselDecoder, the not-yet-complete seam.
//

import Foundation

/// The outcome of decoding file bytes: the text, the encoding we decided on, and any diagnostics
/// raised (e.g. an ANSEL fallback or invalid-UTF-8 recovery).
public struct DecodeResult: Equatable, Sendable {
    public let text: String
    public let encoding: GedcomEncoding
    public let diagnostics: [Diagnostic]

    public init(text: String, encoding: GedcomEncoding, diagnostics: [Diagnostic]) {
        self.text = text
        self.encoding = encoding
        self.diagnostics = diagnostics
    }
}

/// Decodes GEDCOM file bytes into text. Stateless caseless enum.
public enum GedcomByteDecoder {

    /// Detect the encoding of `data` and decode it to text, never failing.
    public static func decode(_ data: Data) -> DecodeResult {
        let encoding = EncodingDetector.detect(data)
        switch encoding {
        case .utf8:
            // Declared/BOM-detected UTF-8. Strip a leading BOM, then decode; if the bytes turn out
            // to be invalid UTF-8 anyway, recover via Latin-1 rather than failing.
            let (text, diagnostics) = decodeUTF8(stripBOM(data))
            return DecodeResult(text: text, encoding: .utf8, diagnostics: diagnostics)

        case .ansel:
            // Delegate to the ANSEL seam (currently a Latin-1 fallback + warning).
            let (text, diagnostics) = AnselDecoder.decode(data)
            return DecodeResult(text: text, encoding: .ansel, diagnostics: diagnostics)

        case .other(let name):
            // Recognized name we don't specially support: try UTF-8 first (a superset of ASCII),
            // and if that fails fall back to Latin-1 with a warning naming the declared encoding.
            let (text, diagnostics) = decodeUTF8(stripBOM(data),
                                                 fallbackNote: "declared encoding '\(name)' is not supported")
            return DecodeResult(text: text, encoding: encoding, diagnostics: diagnostics)

        case .unknown:
            // No declaration: assume UTF-8 (overwhelmingly the modern case). Recover via Latin-1 if
            // that's wrong; only emit a diagnostic when we actually had to fall back.
            let (text, diagnostics) = decodeUTF8(stripBOM(data),
                                                 fallbackNote: "no CHAR declaration; assumed UTF-8")
            return DecodeResult(text: text, encoding: .unknown, diagnostics: diagnostics)
        }
    }

    // MARK: - Helpers

    /// Drop a leading UTF-8 BOM (EF BB BF) if present, so the first line is clean.
    private static func stripBOM(_ data: Data) -> Data {
        guard data.starts(with: [0xEF, 0xBB, 0xBF]) else { return data }
        return data.subdata(in: data.index(data.startIndex, offsetBy: 3)..<data.endIndex)
    }

    /// Decode `data` as UTF-8. On success, no diagnostics. On failure (invalid byte sequences),
    /// fall back to Latin-1 (which always succeeds) and emit ONE warning. `fallbackNote` lets the
    /// caller explain WHY we were attempting UTF-8 (e.g. an unknown declaration) in that warning.
    private static func decodeUTF8(_ data: Data, fallbackNote: String? = nil)
        -> (text: String, diagnostics: [Diagnostic]) {
        if let text = String(data: data, encoding: .utf8) {
            return (text, [])
        }
        let recovered = String(data: data, encoding: .isoLatin1) ?? ""
        let reason = fallbackNote.map { " (\($0))" } ?? ""
        let diagnostic = Diagnostic(
            severity: .warning,
            message: "Text was not valid UTF-8\(reason); decoded as Latin-1. Some characters may be wrong.")
        return (recovered, [diagnostic])
    }
}
