# Research: UA-F01 — Experience catalog and stable identity

**Date**: 2026-11-12 · **Gate**: UA-F01 · Everything below was read or run in the repository at commit `5166d7d`
or later.

## R0. Read-only audit

Sources read: Auto-Creator.md sections 5 and 11.2; ADR-0009 D-01, D-02, D-06; the structure and the 300 entries of
`docs/catalog/experience-catalog.json`; `Packages/VisualCore/Package.swift`; `VisualCorePersistence`
(`DocumentStore.swift`, `Envelope.swift`); `VisualCoreParameters` (`Module.swift`); the tools
`scripts/check_public_api.py`, `scripts/xcodebuild_package.py`, `scripts/release_check.py`,
`scripts/run_reference_baseline.py`, `scripts/check_dependencies.py`, `scripts/validate_autocreator.py`.

| Fact | Where it was verified |
|---|---|
| `Packages/VisualCore` (tools version 6.0, Swift 6 language mode, platforms iOS 26.0 and macOS 15.0) lists its pure modules in the array `pure`; each is a library product and a target; tests are one test target per module | `Packages/VisualCore/Package.swift` |
| Tests use Swift Testing (`import Testing`, `@testable import`) and copy fixtures as resources (`resources: [.copy("Fixtures")]`) | `Tests/VisualCorePersistenceTests`, `VisualCoreEffectsGraphTests` in the manifest |
| A module has a `Module.swift` with an enum `<Name>Info` and `static let version = "1.0.0-rc.1"`; `VisualCoreScaffoldTests` lists the versions | `VisualCoreParameters/Module.swift`, `ScaffoldTests.swift:16` |
| Bounded decoding pattern: size check before reading, `JSONSerialization` into `[String: Any]`, field-by-field checks, one typed error enum (`StoreProblem`: `corrupt`, `wrongKind`, `newerVersion`, `tooLarge`, …) thrown with typed throws | `VisualCorePersistence/DocumentStore.swift:137-158`, `Envelope.swift:22-38` |
| Pure modules may import only `Foundation`, `Dispatch`, `os`, `Darwin`, `Glibc`, `Synchronization`, `simd` and other pure modules | `scripts/check_dependencies.py:24, 133` |
| The public API baseline is `docs/api/visualcore-public-api.txt`; `check_public_api.py --update` rewrites it; every public declaration needs `///` | `scripts/check_public_api.py --help`, the baseline file |
| Package tests on a simulator: `python3 scripts/xcodebuild_package.py --package Packages/VisualCore --scheme VisualCore-Package --destination sim-27.2 --action test` (and `sim-26.5`); the simulator is chosen by runtime | `scripts/xcodebuild_package.py --help` |
| The seven-step reference regression runs as two chunks of `scripts/release_check.py --only …`: three steps (`reference-engine-xcframework`, `reference-build-projectm-ios-sim`, `reference-clean`) and four steps (`reference-test-anglerendering-ios27`, `reference-test-anglerendering-ios26`, `projectm-reference-ios27`, `projectm-reference-ios26`) | attestations `A04-P03.t314-reference-a` and `-b`; `release_check.py --list` |
| A consumer is rebuilt for testing with `xcodebuild build-for-testing -project VisualCore.xcodeproj -scheme <App> -destination 'generic/platform=iOS Simulator' -derivedDataPath Build/DerivedData/<App> CODE_SIGNING_ALLOWED=NO` | attestation `A04-P03.t314-build-GenerativeArtStudio` |
| The prebuilt ANGLE frameworks exist (`External/projectm-ios/Build/ANGLEFrameworks`) | directory listing |
| Planning catalog: schema 1; 300 experiences; fields `code`, `name`, `slug`, `id`, `kind` (`creative-app` 25, `game` 275), `tier`, `release`, `family`, `launcher_category`, `order`; the summary is `design.summary` of a creative experience and `design.pitch` of a game; no summary is empty | script over the catalog, 2026-11-12 |
| Every id equals `code.lower() + "." + slug` and matches `(a\d\d|r\d\d-g\d\d)\.[a-z0-9]+(-[a-z0-9]+)*`; orders are 1 to 300 without repeats; no slug repeats; every slug is the slug form of the name | the same script |
| Longest title 23 characters, longest summary 136, longest family 33; 27 families; no title has a non-ASCII character | the same script |
| Launch categories: create 5, audio 4, play 4, learn 4, ambient 4, tools 4, puzzle 75 | the same script |
| No integration gate is pass in the migration ledger | `migration_ledger.py status` |
| `scripts/build_catalog.py` is listed in `PLANNED_SCRIPTS` of `validate_autocreator.py`, which fails once the file exists until the entry is removed; `docs/migration/path-map.json` has two entries by UA-F01 (`Catalog`, `scripts/build_catalog.py`) that are checked while they are pending | `PLANNED_SCRIPTS`, `check_links()` and `run_references()` of `validate_autocreator.py`; the path map |

### Corrections to names in the brief

| Brief | Confirmed or corrected |
|---|---|
| `VisualCoreExperience`, `ExperienceID`, `ExperienceDescriptor`, `ExperienceTier`, `ExperienceCategory`, `CatalogManifest` | confirmed: none of the names exists in `docs/api/visualcore-public-api.txt` |
| "bounded decoding patterns" of `VisualCoreParameters` and `VisualCorePersistence` | the pattern is in `VisualCorePersistence`; `VisualCoreParameters` contributes the module layout and validation style, not a loader |
| "the registered experiences" as an input of `build_catalog.py` | no registration exists; the input is the file `Catalog/registrations.json` (Clarifications, question 2) |
| `Catalog/path-map.json` | a different file from `docs/migration/path-map.json`: the first records executed moves, the second is the plan |

Added names (new): `ExperienceCode`, `ExperienceKind`, `ExperienceIDError`, `CatalogError`, `CategoryList`,
`CatalogSearch`, `RegistryReport`, `SourceMoveMap`, `ExperienceInfo`.

## R1. Parse with JSONSerialization and check every field by hand

- **Decision**: the loader checks the byte count, parses with `JSONSerialization` and reads each entry from a
  dictionary with small helpers that throw `CatalogError` naming entry and field.
- **Rationale**: the repository's own bounded pattern; `Codable` reports failures as untyped, hard-to-compare
  errors and cannot tell "key not defined by the schema" apart; numbers need explicit checks (a Boolean is not a
  number, a fraction is not whole, a huge exponent parses as infinity).
- **Alternatives considered**: `JSONDecoder` with `Codable` (no typed field errors, silently ignores unknown keys).

## R2. Identity types

- **Decision**: `ExperienceCode` is a struct with two cases behind it (`original(number)` 1–99 and
  `round(round, game)` 2–99 and 1–99) and the text form `A05` or `R02-G01`; `ExperienceID` holds a code and a slug
  and is `RawRepresentable` by its text, `Hashable`, `Comparable` by text, `Codable` as a string and `Sendable`.
  Derived names are computed properties: `integrationGate` (`X-A05`), `storageNamespace` (the id),
  `accessibilityPrefix` (`experience.<id>`), `evidenceName` (the id).
- **Rationale**: FR-U01-001, 002, 005; one place that builds every derived name.
- **Alternatives considered**: a plain string (nothing stops a malformed id).

## R3. The launch allocation is a rule, not data

- **Decision**: `CatalogManifest` validation knows the rule: codes `A01`–`A25` and `R02-G01`–`R02-G25` are free,
  `R03-G01`–`R04-G25` are premium, all 100 present once; other entries only from rounds 5–12 and premium.
- **Rationale**: FR-U01-011, 012. The rule is the owner's constraint P-02; data that could be edited must not be
  able to redefine it.
- **Alternatives considered**: reading the allocation from a file (a wrong file would validate itself).

## R4. Search folding without locale

- **Decision**: `CatalogSearch.fold(_:)` = `decomposedStringWithCompatibilityMapping`, drop scalars of the
  general categories Mn, Mc and Me, `lowercased()` (the standard library's locale-independent mapping), replace
  `ı` by `i`, collapse white space. Each descriptor's folded title, tags and summary are computed once at load.
- **Rationale**: FR-U01-023, 024; Foundation's `folding(options:locale:)` and `localizedStandardContains` depend on
  a locale and are not used.
- **Alternatives considered**: `compare(_:options:[.caseInsensitive, .diacriticInsensitive])` (locale-aware).

## R5. One generated source, identical copies for the tests

- **Decision**: `scripts/build_catalog.py` writes `Catalog/experiences.json`, `Catalog/categories.json` (when
  missing; afterwards it only validates it), `Catalog/experience-ids.golden.txt` is committed by hand-run of
  `--add-golden` and never rewritten otherwise, and the tool copies the four catalog files and the golden list
  into `Packages/VisualCore/Tests/VisualCoreExperienceTests/Fixtures/Catalog/`. `--check` compares every file and
  copy with what it would write.
- **Rationale**: SwiftPM test resources must be inside the test target's directory; a copy that a check keeps
  identical is simpler and more portable than reading repository paths from a simulator test.
- **Alternatives considered**: locating the repository root from `#filePath` in tests (works on the host, fragile
  on a simulator and in CI caches).

## R6. Availability and registrations

- **Decision**: the tool reads the gate `X-<code>` of each launch experience from `.autonomy/migration/ledger.json`
  (read only). `available` is true only for status `pass`. `Catalog/registrations.json` (schema 1,
  `"registrations": {}`) supplies `capabilities`, `quality_tiers`, `palette` and `content` per id; an available
  entry without one is an error. `tile_seed` is the first four bytes of SHA-256 of the id as an unsigned number.
- **Rationale**: FR-U01-040 to 045; Clarifications, question 2.
- **Alternatives considered**: none that keeps the flag out of human hands.

## R7. Tooling that must follow the new files

- **Decision**: remove `scripts/build_catalog.py` from `PLANNED_SCRIPTS`; set the two path-map entries of this
  gate to `done`; add `scripts/build_catalog.py` to the reviewed ledger readers of `GovernanceTests`; add the
  step `python3 scripts/build_catalog.py --check` to `ci.yml`; add the module to `VisualCoreScaffoldTests`, to
  `Packages/VisualCore/README.md`, `docs/getting-started.md` and `docs/release/support-matrix.md`.
- **Rationale**: each of these checks or lists exists today and would fail or be stale otherwise.

## Unknowns

None remain.
