//
// PackageGuardTests.swift — structural guardrails for the whole package.
//
// These aren't behavior tests; they protect the two project-level invariants from
// DevelopmentPlan.md / CLAUDE.md so a future change can't quietly break them:
//
//   1. The engine stays UI-FREE: no file under Sources/GedcomKit may import a UI framework.
//      This is THE structural guarantee behind the portable-core design. If someone ever adds
//      `import SwiftUI` to the engine (e.g. to grab a Color or a layout helper), this test fails
//      loudly instead of silently coupling the engine to Apple's UI stack.
//
//   2. The real GEDCOM fixture is present and loadable. Everything downstream (lexer, tree,
//      model, relationship/quality tests) reads this file, so if it's missing we want a single
//      clear failure here rather than confusing failures everywhere.
//

import XCTest
@testable import GedcomKit

final class PackageGuardTests: XCTestCase {

    // MARK: UI-free invariant

    /// Walk every .swift file under Sources/GedcomKit and assert none import a UI framework.
    ///
    /// HOW IT FINDS THE SOURCES: we can't rely on the current working directory (it varies by
    /// how `swift test` is invoked), so we derive the package root from THIS test file's own
    /// compile-time path (`#filePath` = <root>/Tests/GedcomKitTests/PackageGuardTests.swift)
    /// and walk up to <root>, then into Sources/GedcomKit. This stays correct no matter where
    /// the package is checked out.
    func testEngineHasNoUIImports() throws {
        let thisFile = URL(fileURLWithPath: #filePath)
        // <root>/Tests/GedcomKitTests/PackageGuardTests.swift -> up 3 -> <root>
        let packageRoot = thisFile
            .deletingLastPathComponent()   // .../GedcomKitTests
            .deletingLastPathComponent()   // .../Tests
            .deletingLastPathComponent()   // <root>
        let engineDir = packageRoot
            .appendingPathComponent("Sources")
            .appendingPathComponent("GedcomKit")

        let fm = FileManager.default
        XCTAssertTrue(fm.fileExists(atPath: engineDir.path),
                      "Could not locate Sources/GedcomKit at \(engineDir.path) — did the layout move?")

        // Imports that would couple the engine to a UI / Apple-app framework. Matched as
        // substrings of each source line after trimming, so "import SwiftUI" and
        // "@_exported import AppKit" are both caught.
        let forbidden = ["import SwiftUI", "import AppKit", "import UIKit"]

        guard let walker = fm.enumerator(at: engineDir,
                                         includingPropertiesForKeys: nil) else {
            return XCTFail("Could not enumerate \(engineDir.path)")
        }

        var scannedCount = 0
        for case let fileURL as URL in walker where fileURL.pathExtension == "swift" {
            scannedCount += 1
            let source = try String(contentsOf: fileURL, encoding: .utf8)
            for line in source.split(whereSeparator: \.isNewline) {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                for needle in forbidden where trimmed.contains(needle) {
                    XCTFail("UI-free invariant violated: \(fileURL.lastPathComponent) contains '\(needle)'. "
                            + "The engine must never import a UI framework — keep platform code in the app target.")
                }
            }
        }

        // Sanity: if we scanned zero files the test would pass vacuously and stop protecting us.
        XCTAssertGreaterThan(scannedCount, 0, "Expected to scan at least one engine source file.")
    }

    // MARK: Fixture availability

    /// The real GEDCOM database copy must be bundled and readable. We only check it loads and is
    /// non-trivially sized here; the exact record-count gate (2,000 INDI / 594 FAM) is asserted in
    /// E2 once the tree builder exists.
    func testRealFixtureIsBundledAndLoadable() throws {
        let url = try XCTUnwrap(
            Bundle.module.url(forResource: "family", withExtension: "ged", subdirectory: "Fixtures"),
            "family.ged fixture not found in test bundle — check Package.swift resources rule."
        )
        let contents = try String(contentsOf: url, encoding: .utf8)
        XCTAssertTrue(contents.hasPrefix("0 HEAD"), "family.ged should start with the GEDCOM header record.")
        XCTAssertGreaterThan(contents.count, 100_000, "family.ged looks unexpectedly small.")
    }
}
