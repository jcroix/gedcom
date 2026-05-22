# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project status

**Pre-implementation.** The only file so far is `DevelopmentPlan.md` — the authoritative
design and milestone plan. Read it before doing anything; it defines the architecture,
the v1 scope, the per-milestone verification gates, and the names of the files to create.
There is no source code, no `Package.swift`, and no git repo yet.

This is a **standalone, Mac-native (Swift + SwiftUI) GEDCOM genealogy viewer**. v1 is a
**read-only** explorer (browse people/families, search, relationship calculator,
data-quality checks, pedigree/descendant/fan charts). Editing is a deliberate phase 2.

## The two non-negotiable constraints

1. **The engine must stay UI-free.** Architecture is a Foundation-only Swift package
   (`GedcomKit`: GEDCOM parsing, model, relationship math, analysis) under a thin SwiftUI
   app. `Sources/GedcomKit` must **never** `import SwiftUI` or `import AppKit` — a CI/test
   grep enforces this. The whole point is that a future cross-platform/iOS port is a UI
   rewrite against an unchanged engine. Keep all platform coupling in the app target.

2. **Never write to the real source database.** The user's GEDCOM lives at
   `/Users/jcroix/Documents/Crox Book/family.ged` and is the **hand-maintained research
   DB behind an active book project** (its own git-LFS repo with strict rules in that
   project's `CLAUDE.md`). Always work against a **copy** placed in this repo as a test
   fixture. When a future writer (phase 2) eventually targets the live file, it must be
   **lossless**: preserve the exact `@ID@` set, all `@xref@` integrity, custom tags
   (`_FSFTID`), unknown tags, and line order, and produce **minimal git diffs**. The
   lossless tree layer (preserving original order + `sourceLineRange`) exists for this reason.

## Architecture (big picture)

Three engine layers, each independently testable:

- **Lexer** → tokenizes lines (`level [xref] tag value`), detects encoding (UTF-8 now;
  ANSEL behind a `GedcomByteDecoder` seam with a defined Latin-1 fallback + diagnostic).
- **Lossless tree** (`GedcomTree`/`GedcomNode`) → preserves *everything* (order, unknown
  tags, CONT/CONC splits, source line ranges). This is the source of truth and the
  foundation for the future writer.
- **Typed model projection** (`Individual`, `Family`, `GedcomDate`, `PersonalName`, etc.)
  → references the tree, doesn't own data. `RelationshipIndex` synthesizes the FAMC/FAMS
  back-links the source file lacks (it only stores relationships top-down via FAM).

The SwiftUI app is a **windowed app with `File ▸ Open`** (not `DocumentGroup` — v1 writes
nothing and parsing runs off-main with progress). A single `@Observable @MainActor
DocumentModel` is the source of truth; lists/charts call `navigate(to:)`, the detail pane
reads `focus`; browser-style back/forward history. `NavigationSplitView` 3-column layout.

Everything is **in-memory**, dictionary-keyed by `Xref`. **Do not add SwiftData/CoreData** —
it would couple the engine to Apple frameworks, duplicate the file as a drift-prone store,
and complicate the lossless writer.

## Reusing existing logic

The relationship calculator is **ported function-for-function from
`/Users/jcroix/Documents/Crox Book/query.py`** (parent→child graph, BFS ancestors, LCA,
cousin/removed/aunt-uncle labels). Run that script to capture expected outputs as **golden
tests** for the Swift port. Known fix to apply during the port: its `min(common, key=…)`
LCA selection is nondeterministic on ties — add an `Xref` tie-break so test output is stable.

## Commands (planned workflow — toolchain verified: Swift 6.3.2, Xcode 26.5)

The engine is built/tested headlessly with no Xcode:

```bash
swift build                                    # build GedcomKit
swift test                                     # all engine tests
swift test --filter RelationshipTests          # one test class
swift test --filter RelationshipTests/testFirstCousins   # one test
```

The app is a separate Xcode project depending on `GedcomKit` as a local package:

```bash
xcodebuild -project App/GedReader.xcodeproj -scheme GedReader -configuration Release build
# product: build/Build/Products/Release/GedReader.app   (with -derivedDataPath build)
```

## Test fixtures

`Tests/GedcomKitTests/Fixtures/` holds a copy of `family.ged` (the integration fixture:
assert **2,000 INDI / 594 FAM** on full load — these counts track the current fixture copy and
will change when `family.ged` is re-copied, since the source DB is actively regenerated) plus a small hand-trimmed `family-subset.ged`
with known relationships for golden tests, and synthetic edge cases: `dates.ged`,
`names.ged` (include the real malformed name `John Crox (Henry's /father)/`), `broken.ged`
(dangling xref), `ansel.ged`, `gedcom7.ged`. The parser must be **defensive** — malformed
lines/xrefs/names produce a `Diagnostic` and degrade gracefully; never throw out the file.
