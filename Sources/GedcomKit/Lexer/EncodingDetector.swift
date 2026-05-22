//
// EncodingDetector.swift — figure out a GEDCOM file's character encoding from its bytes.
//
// Strategy:
//   1. A UTF-8 byte-order mark (EF BB BF) is decisive — return .utf8 immediately.
//   2. Otherwise scan only the HEADER for the `1 CHAR <value>` line and map its value. The CHAR
//      value is always plain ASCII, so we can read the header bytes as Latin-1 (which never fails
//      on any byte) regardless of the file's real encoding, then run it through the already-tested
//      lexer and look for the CHAR tag. We stop at the end of the HEAD record so a stray "CHAR"
//      inside later note text can't be mistaken for the declaration.
//
// Only a small header slice is read, so this stays cheap even on large files.
//

import Foundation

/// Sniffs a GEDCOM file's declared/detected encoding. Stateless caseless enum — nothing to make.
public enum EncodingDetector {

    /// How many leading bytes to inspect for the CHAR line. The header is a dozen short lines;
    /// 8 KB is far more than enough while bounding work on huge files.
    private static let headerByteScanLimit = 8192

    /// Determine the encoding of `data` (a whole GEDCOM file, or at least its header).
    public static func detect(_ data: Data) -> GedcomEncoding {
        // 1. UTF-8 BOM wins outright. (UTF-16/32 BOM handling is out of scope for v1; such files
        //    would currently fall through to the CHAR scan and likely end up .unknown/.other.)
        if data.starts(with: [0xEF, 0xBB, 0xBF]) {
            return .utf8
        }

        // 2. Read a header slice as Latin-1 (lossless byte→char map) so we can locate CHAR
        //    no matter the real encoding, then tokenize it with the lexer.
        let headerSlice = data.prefix(headerByteScanLimit)
        guard let headerText = String(data: headerSlice, encoding: .isoLatin1) else {
            return .unknown
        }

        for line in GedcomLexer.lex(headerText).lines {
            // Once we pass the HEAD record (a new level-0 record begins), CHAR can't appear.
            if line.level == 0 && line.tag != "HEAD" { break }
            if line.tag == "CHAR" {
                return mapCharValue(line.value ?? "")
            }
        }
        return .unknown
    }

    /// Map a raw CHAR value to a GedcomEncoding. Casing is normalized for matching but the
    /// original value is preserved in `.other` so the app can display exactly what the file said.
    private static func mapCharValue(_ value: String) -> GedcomEncoding {
        switch value.uppercased() {
        case "UTF-8", "UTF8": return .utf8
        case "ANSEL":         return .ansel
        case "":              return .unknown
        default:              return .other(value)
        }
    }
}
