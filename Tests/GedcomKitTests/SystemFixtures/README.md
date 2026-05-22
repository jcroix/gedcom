# System-test GEDCOM corpus (third-party public files)

These are **public, third-party** GEDCOM files used by the system tests (`SystemTests.swift`) to
validate the engine against diverse real-world data beyond the project's own `family.ged`. Each is
included verbatim as downloaded. They are deliberately varied — different GEDCOM versions, encodings,
line endings, and structures — so the parser is exercised broadly.

| File | Source | Version / encoding | Why it's here |
|------|--------|--------------------|----------------|
| `minimal70.ged` | gedcom.io test files (FamilySearch GEDCOM project) — <https://gedcom.io/testfiles/gedcom70/minimal70.ged> | 7.0, UTF-8 | The smallest valid 7.0 file (HEAD+TRLR only); checks the empty-but-valid path. |
| `maximal70.ged` | gedcom.io test files — <https://gedcom.io/testfiles/gedcom70/maximal70.ged> | 7.0, UTF-8 **with BOM** | Exercises a wide range of 7.0 structures; the leading BOM tests our BOM stripping. |
| `royal92.ged` | Denis R. Reid, 1992 (public domain). Mirror: arbre-app/public-gedcoms — <https://raw.githubusercontent.com/arbre-app/public-gedcoms/master/files/royal92.ged> | 5.5, **ANSEL** | 3,010 individuals / 1,422 families of European royalty; exercises the ANSEL decode path and a large connected relationship graph. |
| `TGC551.ged` | John A. Nair, "GEDCOM 5.5 Torture Test". Mirror: frizbog/gedcom4j — <https://raw.githubusercontent.com/frizbog/gedcom4j/master/sample/TGC551.ged> | 5.5, **CR-only line endings** | Deliberately uses every allowed 5.5 tag and classic-Mac CR line endings; stress-tests the lexer/tree and the line-ending normalization. |

## Licensing / provenance notes

- **royal92.ged** is widely distributed as public-domain genealogical sample data (European royalty,
  compiled by Denis R. Reid in 1992).
- **TGC551.ged** is the long-standing, freely distributable GEDCOM 5.5 torture-test file authored by
  John A. Nair (GEDitCOM) for the express purpose of testing GEDCOM software.
- **minimal70.ged / maximal70.ged** are official test files published by the FamilySearch GEDCOM
  project at gedcom.io for validating GEDCOM 7.0 implementations.

These files are used here solely as **test inputs**; the engine never modifies them.
