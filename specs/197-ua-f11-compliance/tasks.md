# Tasks: UA-F11 — Privacy, licensing, no-advertising audit and distinctiveness

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/cli.md](contracts/cli.md), [quickstart.md](quickstart.md)

Evidence: `python3 scripts/migration_ledger.py run-check --gate UA-F11 --name <check> -- <command>`. Commit after each
task (`scripts/tick_task.py`). Tests are written before the code they prove. Agents write only their own files; the
lead owns `scripts/release_check.py`, `.github/workflows/ci.yml`, `scripts/test_scripts.py`, `Auto-Creator.md`, the
interface test, every build and every retest. VisualCore packages do not change (research D10): no API-baseline,
documented-API or ProjectM-regression task unless a task below changes a package, in which case T-U11-036 applies.
Device-only items: none, so no {device} task.

## Phase 1: Setup

- [X] T-U11-001 Baseline before changes: `python3 scripts/test_scripts.py` and `python3 scripts/check_compliance.py` — Verified 2026-11-13: check_compliance PASS (baseline-compliance) and test_scripts PASS (baseline-scripts) before changes; research.md section 0 audit re-verified at ecf2946
  pass (checks `baseline-scripts`, `baseline-compliance`); research.md §0 audit re-verified on the current revision.

## Phase 2: Foundational

- [X] T-U11-002 [P] Tests first in `scripts/tests/test_report_meta.py`: `meta(app, configuration)` returns — Verified 2026-11-13: scripts/tests/test_report_meta.py 7 tests OK (meta fields, digest, interrupted write leaves no file, schema 2/missing/bool/unparsable refused)
  `schema` 1, 40-hex `revision`, boolean `clean`, `configuration`, 64-hex `executable_sha256` of the app's main
  executable (null without an app); `write_report(path, report)` leaves no file when interrupted before rename; `read_versioned` refuses schema 2, a
  missing schema and unparsable JSON. Every later tool test module also plants a schema-2 input and a missing app or
  input file (exit 2, path named) (FR-U11-081, spec edge cases).
- [X] T-U11-003 Write `scripts/report_meta.py` (`meta`, `write_report` atomic via temp file + `os.replace`, — Verified 2026-11-13: scripts/report_meta.py meta, write_report (temp file + os.replace), read_versioned; its 7 tests pass; used by every UA-F11 tool
  `read_versioned(path, schema=1)` refusing a missing, non-integer or higher schema and unparsable JSON with the path).

## Phase 3: User Story 1 — The privacy manifest is true of the built app (P1)

- [X] T-U11-004 [P] [US1] Tests first in `scripts/tests/test_privacy_report.py`: the `--json` report of — Verified 2026-11-13: scripts/tests/test_privacy_report.py 15 tests OK (undeclared, unused, tracking, tracking domains, collected data, report shape, exit 2)
  `check_privacy_manifest.py` contains `meta` and `verdict`; the three planted defects (undeclared category, unused
  category, tracking true) each fail (FR-U11-004).
- [X] T-U11-005 [US1] Modify `scripts/check_privacy_manifest.py`: `--json` writes data-model §7 with `meta` through — Verified 2026-11-13: check_privacy_manifest.py --json writes schema 1 report with meta via write_report; old fields kept; script-tests PASS (script-tests)
  `report_meta.write_report`; also fail on non-empty tracking domains or collected data types (FR-U11-002).
- [X] T-U11-006 [US1] Acceptance: `python3 scripts/check_privacy_manifest.py --app "$APP" --json — Verified 2026-11-13: check_privacy_manifest.py --app on the Release app built in release-check-app at d711921 (clean): PASS, 3 categories detected and declared, 0 undeclared, 0 unused (privacy-manifest, release-check-app)
  .autonomy/logs/ua-f11/privacy.json` on the local Release app passes with 0 undeclared and 0 unused (check
  `privacy-manifest`) (SC-U11-001).

## Phase 4: User Story 2 — Permission prompts only for what experiences use (P1)

- [X] T-U11-007 [P] [US2] Tests first in `scripts/tests/test_usage_descriptions.py`: extra key, missing key, — Verified 2026-11-13: scripts/tests/test_usage_descriptions.py 18 tests OK (extra key, missing key, unknown word, differing text, --app, schema 2, missing plist; build_catalog permissions rules)
  unknown word, a text different from the vocabulary's each fail; the real repository passes with 1 key; `build_catalog` rejects `permissions`
  that is not a list of 0–8 distinct vocabulary words and accepts its absence.
- [X] T-U11-008 [P] [US2] Write `Configs/permission-vocabulary.json` (schema 1; word "lower-case kebab, 3–40 chars, — Verified 2026-11-13: Configs/permission-vocabulary.json schema 1: photo-library-add (project.yml text), microphone, camera; validated by build_catalog load_vocabulary
  unique" → `key` matching `^NS[A-Za-z]+UsageDescription$`, each key used once, and `text` of 20–200 characters):
  `photo-library-add` with the current `project.yml` text, `microphone`, `camera`.
- [X] T-U11-009 [US2] Modify `scripts/build_catalog.py`: optional `permissions` registration key validated against — Verified 2026-11-13: build_catalog.py accepts optional permissions (0-8 distinct vocabulary words, not in runtime catalog); a01 declares photo-library-add; build_catalog --check PASS (build-catalog); 390 VisualCoreExperienceTests pass
  the vocabulary, not copied into the runtime catalog; add `"permissions": ["photo-library-add"]` to
  `a01.generative-art-studio` in `Catalog/registrations.json`; `python3 scripts/build_catalog.py --check` passes.
- [X] T-U11-010 [US2] Write `scripts/check_usage_descriptions.py` (`--plist` default — Verified 2026-11-13: scripts/check_usage_descriptions.py per contracts/cli.md; its tests pass (script-tests)
  `Apps/VisualCore/Generated/Info.plist`, `--app`, `--registrations`, `--vocabulary`, `--json`) per contracts/cli.md.
- [X] T-U11-011 [US2] Acceptance: `python3 scripts/check_usage_descriptions.py` and `--app "$APP"` pass with 1 key — Verified 2026-11-13: check_usage_descriptions.py PASS with 1 key on the generated plist (usage-descriptions) and on the Release app (usage-descriptions-app)
  (checks `usage-descriptions`, `usage-descriptions-app`) (SC-U11-002).

## Phase 5: User Story 3 — No advertising, analytics or tracking (P1)

- [X] T-U11-012 [P] [US3] Tests first in `scripts/tests/test_no_tracking.py`: fixture apps (directories with a — Verified 2026-11-13: scripts/tests/test_no_tracking.py 14 tests OK (framework link, symbol, library name, identifier bytes, unused allowance, whole identifiers, chunk boundary, schema 2, missing app)
  fake executable, `--symbols-file`, `--libraries-file`) planting a linked `AdSupport` framework, an
  `ASIdentifierManager` symbol, a deny-listed library name in a bundled file, and an unused allowance; each fails and
  names its file; a clean fixture passes; a schema-2 deny list is refused.
- [X] T-U11-013 [P] [US3] Write `Configs/tracking-denylist.json` (data-model §3): frameworks, symbols, and libraries — Verified 2026-11-13: Configs/tracking-denylist.json schema 1: 4 frameworks, 5 symbols, 5 libraries in each of advertising, analytics, attribution, crash-reporting (all identifiers of 6+ characters), no allowances
  covering advertising, analytics, attribution and crash reporting with at least three each (FR-U11-020); texts
  "case-sensitive literals, 3–80 chars"; library names "distinctive module identifiers of at least 6 characters,
  matched as whole identifiers"; allowances need a reason.
- [X] T-U11-014 [US3] Write `scripts/check_no_tracking.py` (reuses `check_release_symbols.binaries`; `otool -L`, — Verified 2026-11-13: scripts/check_no_tracking.py (otool -L, nm -m, 1 MiB chunked byte scan, allowances, --json via report_meta); its tests pass (script-tests)
  `nm -m`, 1 MiB chunked byte scan of every bundled file; `--json` via report_meta).
- [X] T-U11-015 [P] [US3] Tests first in `scripts/tests/test_compliance_tracking.py`: a fixture source importing — Verified 2026-11-13: scripts/tests/test_compliance_tracking.py 4 tests OK (AdSupport/ATT imports and APIs, deny-listed library imports, comments ignored, repository passes)
  `AdSupport` or `AppTrackingTransparency`, or calling `ASIdentifierManager`/`ATTrackingManager`, fails
  `check_compliance.scan(root)`; the repository passes.
- [X] T-U11-016 [US3] Modify `scripts/check_compliance.py`: one `RULES` entry "advertising or tracking API — Verified 2026-11-13: check_compliance.py RULES entry for advertising/tracking APIs plus deny-listed library imports read from Configs/tracking-denylist.json; repository PASS (compliance)
  (Constitution XII)".
- [ ] T-U11-017 [US3] Acceptance: `python3 scripts/check_compliance.py` (check `compliance`) and
  `python3 scripts/check_no_tracking.py --app "$APP" --json .autonomy/logs/ua-f11/tracking.json` (check `no-tracking`)
  pass with 0 findings (SC-U11-003).

## Phase 6: User Story 4 — Every license is bundled, complete and shown (P2)

- [ ] T-U11-018 [P] [US4] Tests first in `scripts/tests/test_licenses_app.py`: a fixture app whose `Licenses/` lacks a
  shipped text, has an extra text, or has a differing text or index fails naming it; an exact bundle passes.
- [ ] T-U11-019 [US4] Modify `scripts/check_licenses.py`: `--app APP` compares `APP/Licenses` with the files
  `bundle_licenses.bundle()` produces for shipped entries (generated into a temporary directory), byte for byte; `--json` report.
- [ ] T-U11-020 [US4] Write `Apps/VisualCore/Tests/UI/AcknowledgementsUITests.swift`: About → Acknowledgements shows
  one row per shipped id of `docs/legal/third-party.json` (read through `#filePath`), each with a non-empty label
  and a 44-point target; one row opens non-empty text; `xcodegen generate` adds it to the project.
- [ ] T-U11-021 [US4] Acceptance: `python3 scripts/check_licenses.py` (check `licenses`), `python3
  scripts/check_licenses.py --app "$APP"` (check `licenses-app`) and the interface test once on the iOS 27.x phone:
  `python3 scripts/xcodebuild_app.py --scheme VisualCore --runtime 27.2 --kind phone --only-testing
  VisualCoreUITests/AcknowledgementsUITests --sources Apps/VisualCore/Tests/UI` (check `app-ui-acknowledgements`)
  (SC-U11-004).

## Phase 7: User Story 5 — ProjectM is not in the app (P2)

- [ ] T-U11-022 [US5] Acceptance: `python3 scripts/audit_showcase_dependencies.py --target VisualCore --sources
  Apps/VisualCore --app "$APP"` (check `projectm-audit`) and `python3 scripts/check_release_symbols.py --app "$APP"`
  (check `release-symbols`) pass; the audit's existing planted-defect tests pass in the script tests (SC-U11-005).

## Phase 8: User Story 6 — No two launch experiences share a mechanic (P2)

- [ ] T-U11-023 [P] [US6] Tests first in `scripts/tests/test_distinctiveness.py`: normalization of each schema
  (clarification 2), Jaccard words (clarification 3), a planted equal-action pair and a planted pair at 0.5 fail with
  "redesign <later code> inside its concept"; a known title and a duplicate slug fail; a changed catalog makes the
  matrix stale; close pairs are rows 1–6; two generations are byte-identical; the message never says merge, drop or
  remove.
- [ ] T-U11-024 [P] [US6] Write `Configs/known-game-titles.json` (schema 1, at least 50 well-known commercial game
  titles, no web lookup).
- [ ] T-U11-025 [US6] Write `scripts/check_distinctiveness.py` (`--write`, `--check`, `--catalog`, `--titles`)
  and `--json`, producing `docs/legal/distinctiveness-matrix.json` (data-model §5: score "rounded to 4 decimals", close pairs first)
  and `docs/legal/distinctiveness-matrix.md`; generate both.
- [ ] T-U11-026 [US6] Acceptance: `python3 scripts/check_distinctiveness.py --check` passes with 4,950 pairs and 0
  shared (check `distinctiveness`) (SC-U11-006).

## Phase 9: User Story 7 — Metadata inputs list only integrated experiences (P3)

- [ ] T-U11-027 [P] [US7] Tests first in `scripts/tests/test_metadata_inputs.py`: a fixture ledger with X-A01 pass
  and X-A02 pending lists only A01; privacy answers are `"unproven"` without reports, with a failing report, or with
  reports of different executable digests; proven with two passing reports of one digest; `--check` fails on a
  stale file.
- [ ] T-U11-028 [US7] Write `scripts/metadata_inputs.py` (`--write`, `--check`, `--privacy-report`,
  `--tracking-report`, `--json`) and generate `docs/release/metadata-inputs.json` from the T-U11-006 and T-U11-017 reports;
  add it to `LEDGER_READERS` in `scripts/test_scripts.py`.
- [ ] T-U11-029 [US7] Acceptance: `python3 scripts/metadata_inputs.py --check` passes with 3 experiences (check
  `metadata-inputs`) (SC-U11-007).

## Phase 10: Polish and cross-cutting

- [ ] T-U11-030 Modify `scripts/release_check.py`: steps `usage-descriptions`, `distinctiveness`, `metadata-inputs`;
  after `app-release-build`: `app-no-tracking`, `app-licenses`, `app-usage-descriptions`, `app-projectm-audit`, and
  `app-privacy-manifest`/`app-no-tracking` with `--json` into `.autonomy/logs/`; `scripts/tests/test_release_steps.py`
  covers the names; run the new steps (check `release-check-ua-f11`).
- [ ] T-U11-031 Modify `.github/workflows/ci.yml` (research D8): checks job runs `check_usage_descriptions.py` and
  `check_distinctiveness.py --check`; app-build job runs `check_no_tracking.py --app` and `check_licenses.py --app` on
  its Release build.
- [ ] T-U11-032 Script tests: `python3 scripts/test_scripts.py` passes with every new module (check `script-tests`);
  each new check's elapsed time under 60 s recorded (SC-U11-008).
- [ ] T-U11-033 Auto-Creator.md §15.2 and §15.4 as built (tools, files, where they run); `python3
  scripts/validate_autocreator.py`, `python3 scripts/validate_docs.py`, `python3 scripts/migration_baseline.py verify`
  pass (check `docs`).
- [ ] T-U11-034 Write `specs/197-ua-f11-compliance/owner-review.md` with the exact steps of T-U11-037..039 and record
  them as BLOCKED_OWNER_ACTION.
- [ ] T-U11-035 CI of a commit with all UA-F11 changes finished with success (`gh run list --workflow ci --limit 1`).
- [ ] T-U11-036 Only if a VisualCore package changed: `python3 scripts/check_public_api.py --update`, `python3
  scripts/check_documented_api.py`, the seven-step ProjectM reference regression in two chunks; otherwise record
  "no package change" with `git diff --stat` of the feature's commits over `Packages/`.
- [ ] T-U11-037 {owner} Legal review: the owner reviews `docs/legal/third-party.json`, `THIRD_PARTY_NOTICES.md`,
  `lgpl-analysis.md`, the Release app's `Licenses/` and the privacy answers of `docs/release/metadata-inputs.json`,
  and records approval in `owner-review.md` (FR-U11-090).
- [ ] T-U11-038 {owner} Trademark and name clearance with the age rating for the app name and the 100 launch names
  (FR-U11-091).
- [ ] T-U11-039 {owner} Human distinctiveness review of `docs/legal/distinctiveness-matrix.md`, non-gating (D-17,
  FR-U11-092).
- [ ] T-U11-040 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record
  UA-F11 (`python3 scripts/migration_ledger.py seal --gate UA-F11 && python3 scripts/migration_ledger.py record --gate
  UA-F11`).

## Dependencies

- T-U11-001 → T-U11-002..003 (report_meta) → stories. Stories 2, 4 (scripts part), 6, 7 (tests and tool) are
  independent of each other. Built-app acceptances (006, 011 app part, 017, 021, 022) need one local Release build
  (`release_check.py --only app-release-build`). 028 needs the reports of 006 and 017. 030–031 after all tools; 035
  after 031; 040 last. Owner tasks never block the gate.

## Parallel execution (agents, one writer per file)

- Agent A: T-U11-012, 013, 014, 015, 016. Agent B: T-U11-007, 008, 009, 010. Agent C: T-U11-023, 024, 025.
  Agent D: T-U11-027 and the tool of 028 (lead edits `test_scripts.py`). Agent E: T-U11-018, 019.
  Agent F: T-U11-002, 003, 004, 005 (first, since others import `report_meta`; agents A–E code against the contract
  in data-model §7 and plan.md).
- Lead: 001, 020, all acceptance tasks, 030–036, 040.

## Implementation strategy

MVP: stories 1–3 (P1: privacy manifest, permissions, no tracking). Then licenses and ProjectM (evidence mostly from
existing tools), distinctiveness, metadata inputs. Review checkpoint after each phase: rerun its acceptance command
before ticking.
