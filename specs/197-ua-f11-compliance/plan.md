# Implementation Plan: UA-F11 — Privacy, licensing, no-advertising audit and distinctiveness

**Branch**: `197-ua-f11-compliance` (spec directory only; work on `main`) | **Date**: 2026-11-13 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/197-ua-f11-compliance/spec.md` (five clarifications, binding).

## Summary

Turn the store-facing promises of the one app (no advertising or tracking, a true privacy manifest, only needed
permissions, every license bundled and shown, no ProjectM, 100 distinct experiences, truthful metadata inputs) into
short, deterministic checks with planted-defect self-tests, run them in the release check (built-app checks on the
Release app) and, where they need no real ANGLE, in CI. No app or framework Swift source changes except one new app
interface test; the work is build tooling, versioned configuration and generated documents. Audit: [research.md](research.md) §0.

## Technical Context

**Language/Version**: Python 3 (host tools, standard library only; Linux and macOS); Swift 6 for one XCUITest.
**Primary Dependencies**: Xcode command-line tools `nm`, `otool`, `strings`, `plutil` on macOS (built-app checks);
none on Linux (catalog and source checks).
**Storage**: repository files: `Configs/*.json` (versioned configuration), `docs/legal/distinctiveness-matrix.*`,
`docs/release/metadata-inputs.json`, JSON reports under `.autonomy/logs/` (never committed).
**Testing**: per-tool script tests in `scripts/tests/test_<tool>.py` (collected by `scripts/test_scripts.py`), the
release check, one app interface test on the iOS 27.x phone simulator.
**Target Platform**: reference macOS host and GitHub Actions (`ubuntu-latest` checks job, macOS app-build job).
**Project Type**: build and compliance tooling for the one iOS app.
**Performance Goals**: each check under 60 s on the reference host (SC-U11-008); measured, not assumed.
**Constraints**: no network, no model calls, no App Store Connect; tests short; system accessibility audits deferred.
**Scale/Scope**: 100 launch experiences (4,950 pairs); one app with two embedded ANGLE frameworks.

## Constitution Check

| Principle | Check | Result |
|---|---|---|
| I Proven renderer only | No renderer change. | PASS |
| II App-neutral public API | No public API change (research D10). | PASS |
| II-a Preserve the reference | `External/projectm-ios` read-only; ProjectM audit proves absence from the app. | PASS |
| III GPU lifecycle and threads | No GPU code. Tools are single-threaded processes; reports written whole via temp-file rename. | PASS |
| IV Host-testable, test-first | Every tool's self-tests are written before the tool (tasks order). | PASS |
| V Implementation before devices | No device action; device-only items: none. | PASS |
| VI Evidence over assertion | Reports carry revision, clean flag, executable digest; gate evidence only from release-check runs. | PASS |
| VII Native, accessible UI | Acknowledgements test checks labels/identifiers; system audits wait for devices (owner ruling). | PASS |
| VIII Public APIs, privacy, truthful capabilities | Core of this feature (stories 1–3, 7). | PASS |
| IX Bounded untrusted input | Tools refuse newer schema versions and unparsable files; byte scans stream files. | PASS |
| X Licensing and provenance | Stories 4–5; license texts never edited by the agent. | PASS |
| XI One app, stable identity | Distinctiveness never merges, drops or reorders (D-16). | PASS |
| XII One purchase, no advertising | Story 3 makes advertising a failing check. | PASS |
| XIII Code-driven visuals | Unchanged; no assets added. | PASS |

Post-design re-check (after Phase 1): unchanged, all PASS.

## Project Structure

### Documentation (this feature)

```text
specs/197-ua-f11-compliance/
├── spec.md, plan.md, research.md, data-model.md, quickstart.md
├── contracts/cli.md          # command-line contracts of the new and changed tools
├── checklists/requirements.md
├── owner-review.md           # BLOCKED_OWNER_ACTION steps (new, written by implement)
└── tasks.md                  # /speckit-tasks
```

### Source Code (repository root)

```text
scripts/report_meta.py                         new     revision, clean flag, configuration, executable digest
scripts/check_no_tracking.py                   new     built-app advertising/analytics/tracking scan (story 3)
Configs/tracking-denylist.json                 new     schema 1: frameworks, symbols, library names, allowances
scripts/check_compliance.py                    modify  one RULES entry: AdSupport/AppTrackingTransparency/identifier APIs
Configs/permission-vocabulary.json             new     schema 1: word -> usage-description key
Catalog/registrations.json                     modify  a01: "permissions": ["photo-library-add"]
scripts/build_catalog.py                       modify  optional `permissions` key validated against the vocabulary
scripts/check_usage_descriptions.py            new     Info.plist usage keys == union of declared permissions (story 2)
scripts/check_licenses.py                      modify  `--app`: bundled Licenses/ equals shipped inventory, byte-equal (story 4)
scripts/check_privacy_manifest.py              modify  `--json` report includes report_meta (story 1)
scripts/check_distinctiveness.py               new     generate/check the matrix (story 6)
Configs/known-game-titles.json                 new     schema 1: well-known commercial game titles (no web lookup)
docs/legal/distinctiveness-matrix.json         new     generated, 4,950 rows
docs/legal/distinctiveness-matrix.md           new     generated summary
scripts/metadata_inputs.py                     new     metadata inputs from pass X gates (story 7)
docs/release/metadata-inputs.json              new     generated
scripts/release_check.py                       modify  new steps (quickstart)
.github/workflows/ci.yml                       modify  checks job and app-build job steps (research D8)
scripts/tests/test_no_tracking.py              new
scripts/tests/test_compliance_tracking.py      new
scripts/tests/test_usage_descriptions.py       new     includes the build_catalog `permissions` validation
scripts/tests/test_licenses_app.py             new
scripts/tests/test_privacy_report.py           new
scripts/tests/test_distinctiveness.py          new
scripts/tests/test_metadata_inputs.py          new
scripts/tests/test_report_meta.py              new
scripts/test_scripts.py                        modify  `LEDGER_READERS` += metadata_inputs.py
Apps/VisualCore/Tests/UI/AcknowledgementsUITests.swift   new   About -> Acknowledgements lists every shipped license
Auto-Creator.md                                modify  §15.2 and §15.4 as built
```

**Module and dependency direction**: tools import only the standard library and, where named, `report_meta.py`,
`check_release_symbols.binaries` and `bundle_licenses.bundle`/inventory loading; nothing in `Packages/` or `Apps/`
imports a tool. The interface test depends only on the app's accessibility identifiers.

**Public API**: none changed. The command-line contracts are in [contracts/cli.md](contracts/cli.md).

**Lifecycle and threads**: each tool is a single process with no shared state; outputs are written to a temporary file
in the same directory and renamed (an interruption leaves no partial file, spec edge case); binaries are read with
`nm`/`otool` subprocesses and files are byte-scanned in 1 MiB chunks (memory pressure edge case).

**Schemas and migrations**: every new configuration and output has `"schema": 1`; a reader refuses a higher or
missing version and an unparsable file (FR-U11-081). No existing schema changes version: `permissions` is an optional
registration key accepted by `build_catalog.py` under registration schema 1 (absent means no permission). Data model:
[data-model.md](data-model.md).

## Tests by layer

- **Host (script tests)**: one module per tool with planted defects (quickstart "Self-tests"); run by
  `python3 scripts/test_scripts.py` on macOS and in CI on Linux (built-app tests use fixtures, not real binaries).
- **Package tests (iOS 27.x and 26.5 simulators)**: no package changes; not run for this feature.
- **App interface test**: `AcknowledgementsUITests` once on the iOS 27.x phone through `scripts/xcodebuild_app.py`.
- **Built-app checks**: release-check steps on the local Release app; CI app-build job on the stand-in Release app.

## Commands

See [quickstart.md](quickstart.md); every evidence command is recorded with
`python3 scripts/migration_ledger.py run-check --gate UA-F11 --name <check> -- <command>`.

## Rollback

Every change is additive tooling, configuration and generated documents plus one optional registration key: revert
the feature's commits (`git revert`, never history rewrite). Removing the `permissions` key restores the old
registrations exactly; the release-check and CI steps are removed with their commits.

## Parallel work (owner ruling of 2026-11-13)

Independent files go to parallel agents, one writer per file: (A) tracking scan + deny list + its tests + compliance
rule; (B) vocabulary + usage check + build_catalog key + registration + tests; (C) distinctiveness tool, title list,
generated matrix, tests; (D) metadata inputs + tests; (E) licenses `--app` + tests; (F) report_meta + privacy report +
tests. The lead owns `release_check.py`, `ci.yml`, `test_scripts.py`, the interface test, Auto-Creator.md, builds and
every retest.

## Complexity Tracking

No constitution violations to justify.
