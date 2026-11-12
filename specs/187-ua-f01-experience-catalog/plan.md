# Implementation Plan: UA-F01 — Experience catalog and stable identity

**Branch**: `187-ua-f01-experience-catalog` (spec directory only; work stays on `main`) | **Date**: 2026-11-12 |
**Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/187-ua-f01-experience-catalog/spec.md`; the UA-F01 `/speckit-plan`
prompt of Auto-Creator.md section 20, verbatim in the invocation. The clarification decisions are binding.

## Summary

A new pure module `VisualCoreExperience` in `Packages/VisualCore` gives every experience a parsed, immutable
identity and loads a validated catalog from bounded JSON with typed errors. A new tool `scripts/build_catalog.py`
generates the runtime manifest from the planning catalog, the migration ledger (availability) and a registrations
file, keeps a golden list of all 300 ids, and proves with a check mode that the committed files are what it would
write. The module also offers the category list, a locale-independent search and a pure registry check. Details of
the decisions are in [research.md](research.md).

## Technical Context

**Language/Version**: Swift 6 (toolchain 6.4.2, language mode 6, strict concurrency) for the module and its
tests; Python 3 (standard library only) for the build tool and its self-tests.

**Primary Dependencies**: Foundation only (rule for pure modules). No third-party package.

**Storage**: tracked JSON files under `Catalog/` (schema 1 each) and a text file with one id per line. The loader
takes `Data`; it reads no file itself.

**Testing**: Swift Testing in `Packages/VisualCore/Tests/VisualCoreExperienceTests` on the host
(`swift test`) and on the iOS 27.2 and iOS 26.5 simulators (`scripts/xcodebuild_package.py`);
`scripts/test_scripts.py` for the build tool. There is no user interface, so there are no app UI tests.

**Target Platform**: iOS and iPadOS 26.0 and macOS 15.0 (the package's platforms); the build tool runs on the
development Mac and in CI.

**Project Type**: library module in an existing Swift package, plus a repository tool.

**Performance Goals**: loading and validating the 100-entry manifest takes under 50 ms in the host tests
(SC-U01-010); a search over 100 entries is a linear scan of pre-folded text. Host figures, not device claims.

**Constraints**: pure module (Foundation only, no UIKit, no GPU, no network, no clock, no locale); input bounded
by 1,048,576 bytes and 400 entries; every public symbol documented; API baseline updated; reference regression
7 of 7; no app target; `External/projectm-ios` and `Vendor/angle` untouched; the tool only reads the ledger.

**Scale/Scope**: 1 new module (about 8 source files), 1 new test target, 1 new script, 5 new data files plus
their test copies, about 60 Swift tests and 12 script tests, 6 documents and lists updated.

## Constitution Check

*GATE: passed before Phase 0 research and re-checked after Phase 1 design (same result).*

| Principle | Result |
|---|---|
| I. Proven Renderer Only | pass: no rendering code |
| II. App-Neutral Public API | pass: generic catalog logic goes into VisualCore; tests, `///` documentation, API baseline update and the reference regression are tasks; no ProjectM type |
| II-a. Preserve the Reference | pass: submodule untouched; regression rerun in two chunks |
| III. GPU Lifecycle and Thread Ownership | pass (not applicable): value types, all `Sendable`, no shared mutable state |
| IV. Host-Testable Domain Logic, Test-First | pass: pure module, tests written before the code they prove |
| V. Implementation Before Devices | pass: no device action |
| VI. Evidence Over Assertion | pass: evidence through `migration_ledger.py run-check`; availability comes from the ledger, never from a typed flag |
| VII. Native, Accessible UI | pass (not applicable): no UI; the module supplies the stable accessibility prefix |
| VIII. Public Apple APIs, Privacy | pass: Foundation only; no network; nothing stored |
| IX. Bounded Untrusted Input | pass: size cap, entry cap, text and list limits, number ranges, versioned schema, typed errors |
| X. Licensing and Provenance | pass: no new dependency or asset; the manifest records the hash of its source catalog |
| XI. One App and Stable Experience Identity | pass: this feature implements the immutable id and the golden list; no app target added |
| XII. One Purchase and No Advertising | pass: the tier rule (50 free, 50 premium) is enforced; no store code |
| XIII. Code-Driven Visuals | pass (not applicable): tile colors and seed are data for code-drawn tiles |
| Development Workflow | pass: work on `main`, ids in the FR-U01 namespace, one commit per task, push after the scan |

No violation; Complexity Tracking stays empty.

## Project Structure

### Documentation (this feature)

```text
specs/187-ua-f01-experience-catalog/
├── plan.md, research.md, data-model.md, quickstart.md
├── contracts/
│   ├── visualcore-experience-api.md   # public API of the module
│   └── catalog-files.md               # the files under Catalog/ and the build tool
├── checklists/
└── tasks.md
```

### Source Code (repository root)

```text
Packages/VisualCore/
├── Package.swift                                   modify   module VisualCoreExperience, test target with Fixtures
├── README.md                                       modify   module row
├── Sources/VisualCoreExperience/                   new
│   ├── Module.swift                                         ExperienceInfo.version
│   ├── ExperienceID.swift                                   ExperienceCode, ExperienceID, ExperienceIDError, derived names
│   ├── ExperienceDescriptor.swift                           ExperienceDescriptor, ExperienceTier, ExperienceKind, ExperienceCategory, content facts
│   ├── CatalogError.swift                                   CatalogError
│   ├── CatalogManifest.swift                                CatalogManifest: load, validate, look up
│   ├── CategoryList.swift                                   CategoryList: load, order, titles
│   ├── CatalogSearch.swift                                  fold, search, ranking
│   ├── RegistryReport.swift                                 registry check
│   └── SourceMoveMap.swift                                  loader of Catalog/path-map.json
├── Tests/VisualCoreExperienceTests/                new      Swift Testing; Fixtures/Catalog (copies); damaged manifests are built in code by ManifestBuilder (as built: no Fixtures/Damaged folder)
└── Tests/VisualCoreScaffoldTests/ScaffoldTests.swift  modify  version of the new module

Catalog/                                            new
├── experiences.json                                         generated runtime manifest (schema 1)
├── categories.json                                          seven categories in order, with titles (schema 1)
├── registrations.json                                       registrations keyed by id (schema 1, empty)
├── path-map.json                                            executed source moves (schema 1, empty)
└── experience-ids.golden.txt                                300 ids, one per line, in catalog order

scripts/
├── build_catalog.py                                new      build, --check, --add-golden
├── test_scripts.py                                 modify   BuildCatalogTests; build_catalog.py as a reviewed ledger reader
└── validate_autocreator.py                         modify   PLANNED_SCRIPTS loses build_catalog.py

.github/workflows/ci.yml                            modify   step "Runtime catalog": python3 scripts/build_catalog.py --check
docs/api/visualcore-public-api.txt                  modify   by check_public_api.py --update
docs/getting-started.md, docs/release/support-matrix.md   modify   the new module
docs/migration/path-map.json                        modify   the two entries of UA-F01 become done
Auto-Creator.md                                     modify   section 11.2 states the schema as built (in place)
```

Not touched: `Apps/`, `Showcase/`, `Harnesses/`, `Packages/VisualCoreRendering`, `External/`, `Vendor/`,
`project.yml`, the legacy ledger, `docs/catalog/experience-catalog.json`.

**Structure Decision**: one new target in the existing pure package, as ADR-0009 D-06 and Auto-Creator.md
section 11.2 prescribe; the generated data lives in a new top-level `Catalog/` directory.

## Module and dependency direction

```text
VisualCoreExperience ──► Foundation            (no other VisualCore module)
VisualCoreExperienceTests ──► VisualCoreExperience, Fixtures
build_catalog.py ──► docs/catalog/experience-catalog.json, .autonomy/migration/ledger.json (read),
                     Catalog/registrations.json, Catalog/categories.json ──► Catalog/experiences.json and the test copies
later: app shell, session host, purchase, verification runner ──► VisualCoreExperience
```

Acyclic; the module is a leaf.

## Public API

See [contracts/visualcore-experience-api.md](contracts/visualcore-experience-api.md). All types are value types,
`Sendable`, `Equatable`; errors are typed (`throws(CatalogError)`, `throws(ExperienceIDError)`).

## Lifecycle and thread-ownership contracts

- Loading is a pure function from `Data` to a value or a typed error. It is synchronous, reentrant, and safe to
  call from any thread or actor; it holds no file handle, lock, cache or global state.
- A loaded `CatalogManifest` is immutable. Callers may share it freely across actors.
- Nothing in the module observes the app lifecycle; suspension during a load leaves nothing to resume.
- The build tool writes each output through a temporary file and a rename.

## Data schemas

See [data-model.md](data-model.md) and [contracts/catalog-files.md](contracts/catalog-files.md). Every file has
`"schema": 1`. There is no earlier version, so there is no migration. A later change of shape takes schema 2 and
a loader that reads both; the loader refuses any other version.

## Tests of each layer

| Layer | Tests | Command |
|---|---|---|
| Host | `VisualCoreExperienceTests` (identity, descriptor decoding, each error kind, allocation, categories, search, registry check, path map, golden list, timing) | `swift test --package-path Packages/VisualCore --filter VisualCoreExperienceTests`; the whole package with `swift test --package-path Packages/VisualCore` |
| Host | `BuildCatalogTests` in `scripts/test_scripts.py` (derivation, availability from a temporary ledger, registrations, check mode, determinism, golden list) | `python3 scripts/test_scripts.py` |
| Package tests on simulators | the same Swift tests on iOS 27.2 and iOS 26.5 | `python3 scripts/xcodebuild_package.py --package Packages/VisualCore --scheme VisualCore-Package --destination sim-27.2 --action test` and `--destination sim-26.5` |
| App UI tests | none: no user interface in this feature | not applicable |
| Framework obligations | API baseline, documented API of the consumers, reference regression in two chunks, consumers rebuilt for testing | see quickstart.md |

## Build and test commands

All in [quickstart.md](quickstart.md). Each evidence command is recorded with
`python3 scripts/migration_ledger.py run-check --gate UA-F01 --name <check-name> -- <command>`; simulator commands
get `--timeout 600`.

## Migration and rollback

- No existing file changes format; no data is migrated.
- Rollback: `git revert` of the feature's commits removes the module, the tool and `Catalog/`. No other module
  depends on the new one yet, so the revert cannot break a consumer. The API baseline is restored by the same
  revert.

## Complexity Tracking

No constitution violation to justify.
