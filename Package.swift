// swift-tools-version: 6.0
//
// Package.swift — Swift Package Manager manifest for the GedcomKit engine.
//
// WHY THIS FILE EXISTS / DESIGN NOTES (for future maintenance):
//
//   * This package contains ONLY the engine ("GedcomKit"): GEDCOM parsing, the lossless
//     tree, the typed model, relationship math, and quality analysis. It is intentionally
//     Foundation-only. The SwiftUI app ("GedReader") lives in a SEPARATE Xcode project
//     under App/ and depends on this package locally. Keeping the engine in its own SPM
//     package is what mechanically lets us build/test it headlessly (`swift test`, no Xcode)
//     and is the structural guarantee behind the "engine must stay UI-free" rule.
//
//   * UI-FREE INVARIANT: nothing under Sources/GedcomKit may `import SwiftUI`, `import AppKit`,
//     or `import UIKit`. This is enforced by a test (see Tests/.../PackageGuardTests.swift),
//     not just by convention. The payoff is that a future iOS / cross-platform port is a UI
//     rewrite against an unchanged engine.
//
//   * tools-version 6.0 => Swift 6 language mode (strict concurrency). The engine is built
//     from value types (structs) that are naturally Sendable, so this should stay friction-free.
//     If strict-concurrency errors ever appear here, the fix is almost always "make the type a
//     value type / mark it Sendable", NOT "lower the tools version".
//
//   * Deployment targets are deliberately OLD (macOS 13 / iOS 16) for the widest portability.
//     The engine needs nothing newer. (The app target, defined in its own Xcode project, uses
//     macOS 14 for the @Observable macro — that constraint does not belong here.)

import PackageDescription

let package = Package(
    name: "GedcomKit",

    // Lowest OS versions the engine supports. Keep these low on purpose — see note above.
    platforms: [
        .macOS(.v13),
        .iOS(.v16),
    ],

    // Public libraries other code (the app, future tools) links against.
    products: [
        .library(name: "GedcomKit", targets: ["GedcomKit"]),
        .library(name: "GedReaderCore", targets: ["GedReaderCore"]),
    ],

    targets: [
        // The engine itself. Source files live under Sources/GedcomKit/, organized into
        // subdirectories (Lexer/, Tree/, Model/, Index/, Analysis/) per the development plan.
        // SPM compiles every .swift file under this directory into one module regardless of
        // subdirectory, so the folders are purely for human organization.
        .target(
            name: "GedcomKit"
        ),

        // The app's TESTABLE logic layer: DocumentModel (@Observable @MainActor), navigation
        // history, person-row building, search index, chart layout. It depends on the engine and
        // uses Foundation + Observation, but — like the engine — NEVER imports SwiftUI/AppKit, so
        // it can be unit-tested headlessly with `swift test`. The Xcode app target holds only thin
        // SwiftUI views on top of this. (Observation's @Observable needs macOS 14, so the few types
        // that use it are annotated @available(macOS 14, *); the package minimum stays at 13.)
        .target(
            name: "GedReaderCore",
            dependencies: ["GedcomKit"]
        ),

        // The engine's test suite. Depends on the engine and bundles the GEDCOM test fixtures
        // (real `family.ged` copy + synthetic edge-case files) as resources so tests can load
        // them at runtime via `Bundle.module`. The `.copy` rule keeps the directory structure
        // intact in the test bundle (we read them by name + subdirectory "Fixtures").
        .testTarget(
            name: "GedcomKitTests",
            dependencies: ["GedcomKit"],
            resources: [
                .copy("Fixtures"),
                // Third-party public GEDCOM files for the system tests (see SystemFixtures/README.md).
                .copy("SystemFixtures"),
            ]
        ),

        // Tests for the app's logic layer. To exercise DocumentModel against the real family.ged
        // without duplicating the 400KB fixture, these tests locate it on disk via #filePath
        // (SPM resources can't reference another target's folder), so no resources rule is needed.
        .testTarget(
            name: "GedReaderCoreTests",
            dependencies: ["GedReaderCore", "GedcomKit"]
        ),
    ]
)
