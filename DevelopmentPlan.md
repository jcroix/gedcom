# Mac-Native GEDCOM Viewer — Development Plan (v1)

## Context

The goal is a **standalone, Mac-native graphical application** to explore a GEDCOM
genealogy database — view people and relationships, surface interesting/insightful
information, and (later) edit notes and facts. The primary file is
`/Users/jcroix/Documents/Crox Book/family.ged`.

Key finding: that `.ged` is **not** a standalone file — it is the hand-maintained
research database behind an active LaTeX book project ("Crox Book", a git-LFS repo). Its
`CLAUDE.md` imposes strict rules that any future *writer* must honor: preserve the exact
`@ID@` set and all `@xref@` integrity, keep custom tags like `_FSFTID`, keep NOTEs as
facts/provenance only, and produce **clean, minimal git diffs**. Because of this, and per
the decisions below, **v1 is read-only**; editing is a deliberate phase 2 that builds a
lossless round-trip writer. We work against a **copy of `family.ged` placed in this repo as
a testbed**, so the live database is never touched.

File characteristics (drive all design + test fixtures): GEDCOM **5.5.1**, UTF-8, ~18.5k
lines, **2,000 INDI / 594 FAM**, no SOUR/OBJE/REPO records, heavy NOTEs (2,519), one custom
tag `_FSFTID` (FamilySearch IDs), `/Surname/` names, approximate dates (`ABT`/`BEF`/`BET..AND`),
free-text places, **no FAMC/FAMS back-pointers** (relationships only top-down via FAM).

### Decisions
- **Stack:** Swift + SwiftUI, standalone signed `.app`. A **portable, UI-free core engine**
  (`GedcomKit`, Foundation-only, no SwiftUI/AppKit) under a thin SwiftUI layer — so a future
  cross-platform/iOS port is a UI rewrite against an unchanged engine, not a from-scratch rebuild.
- **v1 = read-only** explorer. Editing = phase 2 (lossless writer; UI is built to accept it later).
- **Discovery priorities (v1):** (1) relationship calculator, (2) data-quality/consistency
  checks, (3) charts (pedigree / descendant / fan). Statistics & timelines deferred (slots noted).
- **App scope:** general-purpose GEDCOM reader — opens any 5.5.1/7.0 file, detects UTF-8/ANSEL,
  models sources/media/repositories when present — but designed and tested around `family.ged`.

> Working app name: **"GedReader"** (placeholder — easily renamed).

## Reusable existing logic

`/Users/jcroix/Documents/Crox Book/query.py` already implements a **relationship calculator**:
a parent→child directed graph, BFS ancestors, lowest-common-ancestor, and English relationship
labels (ancestor/descendant, sibling, aunt/uncle/niece/nephew with `great-` prefixes, Nth cousin
M× removed). We **port this algorithm to Swift** function-for-function (see `RelationshipCalculator`
below), capturing its current outputs as golden test expectations. One improvement: query.py's
`min(common, key=…)` LCA pick is nondeterministic on ties — add an xref tie-break for stable tests.

---

## Architecture

Two-layer repo: a Foundation-only SPM engine package + a SwiftUI app (separate `.xcodeproj`)
that depends on the engine as a local package. This mechanically enforces the UI-free core.

```
/Users/jcroix/programs/gedcom/
├── Package.swift                         # GedcomKit engine (library only)
├── Sources/GedcomKit/
│   ├── Lexer/        GedcomLine, GedcomLexer, EncodingDetector, AnselDecoder(seam)
│   ├── Tree/         GedcomNode, GedcomTree, GedcomTreeBuilder      # lossless, write-friendly
│   ├── Model/        GedcomDocument, Individual, Family, PersonalName, GedcomEvent,
│   │                 GedcomDate(+parser), Place, Source, Citation, MediaObject, Repository, Note
│   ├── Index/        RelationshipIndex                              # FAMC/FAMS + parent↔child graph
│   └── Analysis/     RelationshipCalculator (query.py port), QualityChecker, Issue
├── Tests/GedcomKitTests/   Fixtures/ + Lexer/Tree/Date/Name/Relationship/Quality tests
└── App/GedReader.xcodeproj  (SwiftUI app, local-package dependency on GedcomKit)
```

- **Deployment targets:** engine macOS 13 / iOS 16 (widest portability); app macOS 14 (for the
  `@Observable` macro). Do **not** chase the newest OS — nothing needs it.
- **Guardrail:** a test/CI grep fails if `Sources/GedcomKit` contains `import SwiftUI`/`import AppKit`.
- **No SwiftData/CoreData.** The `.ged` is the single source of truth; v1 is read-only; load is
  milliseconds. Persistence would be a redundant, drift-prone copy and would couple the engine to
  Apple frameworks — defeating the portable-core goal and complicating the future lossless writer.
  Everything is in-memory value types keyed by `Xref` in dictionaries (O(1) lookup).

### Engine design (key types)

- **Three parse layers:** `Lexer` (lines: `level [xref] tag value`) → `GedcomTree` (lossless node
  graph preserving original order, unknown tags, CONT/CONC splits, and `sourceLineRange` for future
  clean-diff writing) → typed **Model projection** that *references* the tree (doesn't own data).
  This both serves the read-only v1 and keeps a future lossless writer feasible.
- **Encoding:** BOM sniff + read the HEAD `CHAR` line; UTF-8 now. **ANSEL behind a `GedcomByteDecoder`
  seam** — v1 ships the dispatch path with a defined Latin-1 fallback + diagnostic (no silent
  corruption); the real 256-entry ANSEL table with combining-mark reordering is a later fill-in
  (the test file is UTF-8, so this doesn't block v1).
- **Version-lenient:** detect 5.5.1 vs 7.0 from `HEAD.GEDC.VERS`; parse the tree identically and
  branch only in projection where structure genuinely differs (notes/SNOTE, media nesting). Never
  reject a file for version surprises — degrade to tree access.
- **Defensive everywhere:** malformed lines, broken xrefs, and bad names produce a `Diagnostic`
  and are skipped/degraded — never throw out the whole file. Broken xref → visible diagnostic
  (query.py silently drops these).
- **`GedcomDate`:** parses `ABT/BEF/AFT/EST/CAL/INT`, `BET..AND`, `FROM..TO`, month names, partial
  dates; exposes a `sortKey` (range → midpoint) so lists, timelines, and quality rules can compare.
- **`PersonalName`:** parse `/Surname/` (given before first slash, surname between slashes, suffix
  after); degrade to display-only on malformed slashes (the file contains `John Crox (Henry's /father)/`).
- **`RelationshipIndex`:** built on load from FAM records — `parentsOf`/`childrenOf` adjacency dicts
  (replaces query.py's `DiGraph`; both directions kept natively, no `reverse()` needed) plus
  FAMC/FAMS back-links the file lacks.
- **`RelationshipCalculator`:** direct port of query.py `_ancestors`, `_path_up`, `find_relationship`,
  and the label helpers (`_ordinal`, `_ascend_label`, `_descend_label`, `_collateral_label`) — pure
  functions returning `RelationshipResult { label, path }`. Add deterministic LCA tie-break.
- **`QualityChecker`:** list of pure `(GedcomDocument) -> [Issue]` rules — child-before-parent,
  death-before-birth, parent too young/old, implausible lifespan, event-after-death, missing vital
  dates, broken xref, possible-duplicate (bucketed by surname + birth-decade to avoid O(n²)). Each
  `Issue` carries severity, involved `Xref`s, message, and optional `sourceLineRange` for jump-to.

### App design (SwiftUI)

- **Shell:** a **windowed app** (`WindowGroup(for: GedcomFileRef.self)`) with **`File ▸ Open`** and an
  async **parse-with-progress** pipeline — *not* `DocumentGroup` (no editing/autosave in v1, and we
  need off-main-thread parsing). `.ged` registered as a plain-text `UTType`; sandboxed via
  security-scoped bookmarks; multi-window (one file per window).
- **Layout:** `NavigationSplitView` 3-column — **Sidebar** (People, Families, Charts, Relationships,
  Quality, with badge counts; Sources/Media/Repositories rows shown only when present) → **Content**
  (section list) → **Detail** (person/family/issue).
- **State:** one `@Observable @MainActor DocumentModel` is the source of truth — loaded doc, current
  `focus` (detail pane), `homePerson`, and a **browser-style navigation history** (back/forward,
  `⌘[`/`⌘]`). Selection flows one way: lists/charts call `navigate(to:)`, detail reads `focus`.
- **People:** SwiftUI `Table` (sortable columns Name/Born/Died/Sex) fed precomputed `PersonRow`
  values (correct at 2k; an `NSTableView` swap stays behind a protocol seam only if 50k profiling
  needs it). `PersonDetailView` = sectioned `ScrollView` (vitals, events timeline, **clickable**
  parents/spouses/children, long selectable notes, and an **"Other Facts" section that shows
  `_FSFTID` and any unknown tags raw — nothing hidden**). Sections are built so phase-2 editing
  swaps `Text`→`TextField` in place.
- **Search:** `.searchable` over names **and** notes, debounced, with a Names/Notes/All scope and
  note-match snippets; index built off-main at load.
- **Charts:** hybrid renderer — compute layout off-main (`ChartLayoutEngine`), draw connectors in a
  `Canvas`, place node cards as real SwiftUI views (`.position`) for free hit-testing/tap→navigate,
  inside a zoom/scroll `ScrollView`. Pedigree (default 4 gens, 3–6 selectable) first, then descendant
  (capped depth), then fan (pure-`Canvas` polar wedges with polar→index hit-testing). Selectable
  home-person root; "recenter on this person".
- **Relationship UI:** two searchable person pickers (A pre-filled with home person), big result
  label, and a clickable path chain through the common ancestor.
- **Quality UI:** issues grouped by category/severity with counts in the sidebar; click jumps to the
  person/family (two-person issues show both side-by-side); laid out so a phase-2 Resolve/Ignore bar
  drops in.
- **Mac-native polish:** full File/Edit/View/Go menus, Open Recent, `⌘F` search focus, section jumps
  `⌘1–⌘5`, chart zoom `⌘±/⌘0`, `Settings` scene (`⌘,`), `@SceneStorage` state restoration, unified
  toolbar with back/forward chevrons + Set-Home.

> **Deferred (statistics & timelines):** add `.statistics`/`.timeline` sidebar cases later — the
> single-`DocumentModel` design absorbs them with no restructuring.

---

## Critical files to create

Engine (highest-leverage):
- `Package.swift`
- `Sources/GedcomKit/Tree/GedcomTreeBuilder.swift` — lossless tree
- `Sources/GedcomKit/Model/GedcomDate.swift` — date parse + sortKey
- `Sources/GedcomKit/Index/RelationshipIndex.swift` — back-links/graph
- `Sources/GedcomKit/Analysis/RelationshipCalculator.swift` — query.py port
- `Sources/GedcomKit/Analysis/QualityChecker.swift`

App (highest-leverage):
- `App/GedReader/GedReaderApp.swift` — `@main` scene + menus
- `App/GedReader/Model/DocumentModel.swift` — the load-bearing state
- `App/GedReader/Shell/ShellView.swift` — 3-column shell + sidebar
- `App/GedReader/People/PersonDetailView.swift`
- `App/GedReader/Charts/ChartLayoutEngine.swift` + `PedigreeChartView.swift`

Testbed:
- Copy `family.ged` → `Tests/GedcomKitTests/Fixtures/family.ged`
  (and a small hand-trimmed `family-subset.ged` with known relationships for golden tests).
- Synthetic fixtures: `dates.ged`, `names.ged` (incl. the malformed name), `broken.ged`,
  `ansel.ged`, `gedcom7.ged`.

---

## Milestones (interleaved engine → app; each has a verification gate)

**Engine (headless, `swift test`):**
- E0 Scaffold `Package.swift` + targets; copy fixtures. *Verify:* `swift build`/`swift test` green; UI-free grep guard passes.
- E1 Lexer + encoding detection (UTF-8; ANSEL fallback seam). *Verify:* full file lexes; CONT assembly + ANSEL-fallback-diagnostic tests pass.
- E2 Lossless tree + xref resolution. *Verify:* **2,000 INDI / 594 FAM**; `_FSFTID` preserved; broken-xref fixture → one diagnostic.
- E3 Typed model + `GedcomDate`/`PersonalName` parsers. *Verify:* Date/Name tests pass; spot-check a known person's projected birth/death/notes.
- E4 `RelationshipIndex` + `RelationshipCalculator`. *Verify:* **golden tests match query.py output** for chosen pairs; tie-break deterministic.
- E5 `QualityChecker` (9 rules). *Verify:* each rule fires only on its synthetic trigger; full-file run gives sane counts.
- E6 Perf/hardening (indexes, sortKey cache, synthetic 50k fixture). *Verify:* 2k all-relatives query and 50k load within a time budget.

**App (Xcode, then `xcodebuild`):**
- A0 Open & async parse pipeline + progress + error view. *Verify:* opening `family.ged` shows progress then "2,000 people · 594 families"; malformed file → failure view, no crash.
- A1 Shell + sidebar w/ counts (conditional record-type rows). *Verify:* sidebar counts correct; Sources/Media/Repositories hidden; `⌃⌘S` toggles sidebar.
- A2 People `Table` + `PersonDetailView`. *Verify:* select → detail fills; sort by name and birth year (ABT dates order sensibly); `_FSFTID`/unknown tags under Other Facts; long notes selectable.
- A3 Navigation (clickable relatives, back/forward `⌘[`/`⌘]`, Set Home `⌘H`, jumps `⌘1–5`). *Verify:* father→child→father then `⌘[`×2 retraces exactly.
- A4 Search (names+notes, scopes, snippets). *Verify:* `⌘F` focuses; Notes scope finds a person by a word only in their note.
- A5 Families browsing. *Verify:* family shows children in birth order; child click navigates.
- A6 Quality UI. *Verify:* issue count matches engine; "death before birth" jumps to person; duplicate shows both people.
- A7 Relationship calculator. *Verify:* known cousins → correct label; path clickable; unrelated → "Not related."
- A8 Charts (pedigree → descendant → fan). *Verify:* 4-gen pedigree of home person with connectors; clicking an ancestor navigates; fan wedge tap selects correct person; `⌘±/⌘0` zoom.
- A9 Mac-native polish + state restoration + packaging. *Verify:* relaunch reopens same file/section/home; second file → second window; `xcodebuild … build` produces a runnable, signed `.app`.

App A0–A2 only need E2–E3; A6 needs E5; A7 needs E4 — so the app can trail the engine without blocking.

## End-to-end verification

1. **Engine:** `cd /Users/jcroix/programs/gedcom && swift test` — all unit + golden + integration
   tests green, including the full-file load asserting 2,000/594 and spot relationship checks that
   match `query.py`.
2. **App:** build via Xcode (or `xcodebuild -project App/GedReader.xcodeproj -scheme GedReader build`),
   launch the `.app`, `File ▸ Open` the testbed `family.ged`, and manually walk A2–A8 checks above
   (browse a person, hop relatives with back/forward, search a note, open the quality list, compute a
   relationship, view a pedigree/fan chart).
3. **Cross-check correctness against ground truth:** for a handful of people, compare the app's
   relationship results and quality flags against `python3 query.py "Name A" "Name B"` and manual
   reading of `family.ged`.
