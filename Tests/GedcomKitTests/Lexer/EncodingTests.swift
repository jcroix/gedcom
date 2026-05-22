//
// EncodingTests.swift — behavior of EncodingDetector and the GedcomByteDecoder seam.
//
// These describe how the engine decides what bytes mean and how it degrades when it can't
// truly decode an encoding yet (ANSEL). They're the spec for the "no silent corruption" rule.
//

import XCTest
@testable import GedcomKit

final class EncodingTests: XCTestCase {

    // MARK: Detection

    /// Tracer: a plain `CHAR UTF-8` header (no BOM) is detected as UTF-8.
    func testDetectsUTF8FromCharHeader() {
        let data = Data("0 HEAD\n1 CHAR UTF-8\n0 TRLR\n".utf8)
        XCTAssertEqual(EncodingDetector.detect(data), .utf8)
    }

    /// The legacy GEDCOM default, `CHAR ANSEL`, is detected as .ansel (handled via the seam later).
    func testDetectsAnselFromCharHeader() {
        let data = Data("0 HEAD\n1 CHAR ANSEL\n0 TRLR\n".utf8)
        XCTAssertEqual(EncodingDetector.detect(data), .ansel)
    }

    /// A UTF-8 BOM is decisive: even if the header somehow claimed otherwise, the bytes win.
    func testUTF8BOMOverridesAndIsDecisive() {
        var data = Data([0xEF, 0xBB, 0xBF])              // UTF-8 BOM
        data.append(Data("0 HEAD\n1 CHAR ANSEL\n".utf8)) // contradictory CHAR — ignored
        XCTAssertEqual(EncodingDetector.detect(data), .utf8)
    }

    /// No CHAR line and no BOM → we can't tell; report .unknown (the decoder will default sensibly).
    func testNoCharDeclarationIsUnknown() {
        let data = Data("0 HEAD\n1 SOUR Foo\n0 TRLR\n".utf8)
        XCTAssertEqual(EncodingDetector.detect(data), .unknown)
    }

    /// A recognized-by-name but unsupported encoding is preserved verbatim in .other so the app
    /// can show exactly what the file declared.
    func testUnrecognizedCharValueIsReportedAsOther() {
        let data = Data("0 HEAD\n1 CHAR WINDOWS-1252\n0 TRLR\n".utf8)
        XCTAssertEqual(EncodingDetector.detect(data), .other("WINDOWS-1252"))
    }

    // MARK: Decoding (the GedcomByteDecoder seam)

    /// Tracer: UTF-8 bytes decode losslessly to the same text, with the encoding reported and no
    /// diagnostics. Includes a non-ASCII character to prove multibyte decoding actually works.
    func testDecodesUTF8LosslesslyWithNoDiagnostics() {
        let original = "0 HEAD\n1 CHAR UTF-8\n1 NOTE café — naïve\n0 TRLR\n"
        let result = GedcomByteDecoder.decode(Data(original.utf8))

        XCTAssertEqual(result.encoding, .utf8)
        XCTAssertEqual(result.text, original)
        XCTAssertEqual(result.diagnostics, [])
    }

    /// A UTF-8 BOM must be stripped so downstream lexing sees a clean "0 HEAD" first line rather
    /// than a leading U+FEFF glued to it.
    func testStripsUTF8BOMFromDecodedText() {
        var data = Data([0xEF, 0xBB, 0xBF])
        data.append(Data("0 HEAD\n1 CHAR UTF-8\n0 TRLR\n".utf8))
        let result = GedcomByteDecoder.decode(data)

        XCTAssertEqual(result.encoding, .utf8)
        XCTAssertTrue(result.text.hasPrefix("0 HEAD"), "BOM should be removed; text must start with the header record.")
        XCTAssertFalse(result.text.unicodeScalars.first == "\u{FEFF}")
    }

    /// ANSEL is not truly decoded yet (the seam). Decoding must still succeed via a Latin-1
    /// fallback AND raise exactly one diagnostic so the user is warned rather than silently shown
    /// wrong characters. This is the E1 "ANSEL-fallback-diagnostic" gate.
    func testAnselFallsBackToLatin1WithExactlyOneDiagnostic() {
        // 0xC5 is a byte that means different things in ANSEL vs Latin-1; we just need *a* high
        // byte present so the fallback path is meaningfully exercised.
        var data = Data("0 HEAD\n1 CHAR ANSEL\n1 NOTE x".utf8)
        data.append(0xC5)
        data.append(Data("y\n0 TRLR\n".utf8))

        let result = GedcomByteDecoder.decode(data)

        XCTAssertEqual(result.encoding, .ansel)
        XCTAssertFalse(result.text.isEmpty, "Fallback decoding must still produce text.")
        XCTAssertEqual(result.diagnostics.count, 1, "Exactly one ANSEL-fallback diagnostic expected.")
        XCTAssertEqual(result.diagnostics.first?.severity, .warning)
        XCTAssertTrue(result.diagnostics.first?.message.uppercased().contains("ANSEL") ?? false,
                      "The diagnostic should name ANSEL so the warning is actionable.")
    }
}
