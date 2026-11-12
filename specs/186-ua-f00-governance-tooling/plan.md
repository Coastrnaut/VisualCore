# Implementation Plan: UA-F00 — Governance tooling: feature numbering, validators and ledger operation

**Branch**: `186-ua-f00-governance-tooling` (spec directory only; work stays on `main`) | **Date**: 2026-11-11 |
**Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/186-ua-f00-governance-tooling/spec.md`; the UA-F00 `/speckit-plan`
prompt of Auto-Creator.md section 20, verbatim in the invocation. The clarification decisions are binding.

## Summary

The repository tooling already knows the unified numbering map; the audit ([research.md](research.md), R0) found
nineteen gaps between it and the specification. This plan closes them in five tools and one workflow, with the test
written before each change:

1. `scripts/validate_docs.py`: one exact id shape per directory form, task ids in their namespace, every directory
   under `specs/` inside the map (FR-U00-001 to FR-U00-008).
2. `scripts/tick_task.py`: refuse early, restore the task list when validation fails, testable on a temporary
   repository (FR-U00-010 to FR-U00-015).
3. `scripts/prepush_scan.py`: one labelled pattern per kind, labelled forbidden path classes, simulator identifiers
   accepted by a tracked list of hashes, a command that records them (FR-U00-020 to FR-U00-026).
4. `scripts/migration_ledger.py`: clean failure for damaged files; self-tests for the seal and record refusals, for
   the single writer and for an untouched real ledger (FR-U00-030 to FR-U00-039).
5. `scripts/planning_index.py`: prompt coverage as a function and a command; the exact directory and ids in the
   override note of archived round features (FR-U00-040 to FR-U00-042).
6. CI: four validator steps in `ci.yml` and the scan of the pushed range in its own workflow (FR-U00-050 to
   FR-U00-053).

No app or framework source changes (FR-U00-060). The legacy ledger and its tool are not touched.

## Technical Context

**Language/Version**: Python 3 (minimum 3.10, development Mac 3.15.2; the CI scan runs on the runner's Python 3),
GitHub Actions workflow syntax.

**Primary Dependencies**: Python standard library only (`argparse`, `hashlib`, `json`, `os`, `re`, `subprocess`,
`tempfile`, `unittest`); Git. No package is installed (FR-U00-061).

**Storage**: tracked files. New: `Configs/simulator-identifier-hashes.json` (schema 1) and
`.github/workflows/push-scan.yml`. Unchanged formats: the migration ledger (schema 1), attestations, evidence files,
the feature index, the prompt manifest.

**Testing**: `python3 scripts/test_scripts.py` (`unittest`, 103 tests today). Tests that need Git build a temporary
repository with a bare remote. There is no Swift code in this feature, so there are no package tests on the
iOS 27.x or iOS 26.5 simulators and no app UI tests; the host self-tests are the only layer, and CI is the
integration layer.

**Target Platform**: the development Mac (macOS, Xcode 27.2 toolchain) and GitHub-hosted runners (`macos-latest` for
`ci.yml`, `ubuntu-latest` for the scan).

**Project Type**: repository tooling (command-line scripts and CI workflows).

**Performance Goals**: the complete self-test suite finishes in under 5 minutes on the development Mac
(SC-U00-009; 6.9 s today). The prompt coverage walk over 953 features takes under 5 seconds (0.17 s measured for
the archived part). These are host timings, not device or app performance.

**Constraints**: no network use by any tool except `git push`; no Claude CLI, no model; no change under `Apps/`,
`Packages/`, `Showcase/`, `Harnesses/`, `External/`, `Vendor/`, to `.autonomy/state.json` or to
`Tools/python/desktop_runbook.py`; the 35 sealed dossiers stay byte-identical; every command of the evidence runs
in under ten minutes.

**Scale/Scope**: 5 scripts modified, 1 test file extended (about 35 new tests), 1 data file and 1 workflow added,
1 workflow modified, 4 documents updated in place. 953 pending launch features and 7,624 prompts are walked by the
coverage check; 823 ledger directories by the numbering test.

## Constitution Check

*GATE: passed before Phase 0 research and re-checked after Phase 1 design (same result).*

| Principle | Applies | Result |
|---|---|---|
| I. Proven Renderer Only | no rendering code is touched | pass (not applicable) |
| II. App-Neutral Public API | no VisualCore module or public symbol changes; no API baseline update, no reference regression needed | pass (not applicable) |
| II-a. Preserve the Reference | `External/projectm-ios` is not touched | pass |
| III. GPU Lifecycle and Thread Ownership | no GPU or thread code; the tools are single-process commands (see Lifecycle contracts) | pass (not applicable) |
| IV. Host-Testable Domain Logic, Test-First | every change is a pure host function with a self-test written first | pass |
| V. Implementation Before Devices | no device action; FR-U00-033 keeps the device guard and adds tests for it | pass |
| VI. Evidence Over Assertion | gate evidence only through `migration_ledger.py run-check`; ticks through `tick_task.py`; the feature strengthens both | pass |
| VII. Native, Accessible UI | no UI | pass (not applicable) |
| VIII. Public Apple APIs, Privacy, Truthful Capabilities | no Apple API; the scan keeps identifiers out of pushes; no readable identifier is tracked (FR-U00-025) | pass |
| IX. Bounded Untrusted Input | the scan prints at most 40 findings and the count; damaged JSON stops the tool with a message (FR-U00-036); the hash list has a schema version | pass |
| X. Licensing and Provenance | no new dependency, asset or dataset | pass |
| XI. One App and Stable Experience Identity | no target is added; the numbering map that carries every experience's features is enforced | pass |
| XII. One Purchase and No Advertising | no store, advertising or tracking code | pass (not applicable) |
| XIII. Code-Driven Visuals | no visuals | pass (not applicable) |
| Development Workflow | work on `main`, one feature per gate, ids in the FR-U00 namespace, commits without trailers, push only through the scan | pass |

No violation; the Complexity Tracking table stays empty.

## Project Structure

### Documentation (this feature)

```text
specs/186-ua-f00-governance-tooling/
├── plan.md              # this file
├── research.md          # audit R0 and decisions R1–R10
├── data-model.md        # numbering map, id shapes, scan patterns, hash list, coverage report
├── quickstart.md        # evidence commands and validation scenarios
├── contracts/
│   ├── tools.md         # command-line contracts of the five tools
│   └── ci.md            # the two workflows
├── checklists/          # requirements.md (specify); governance.md (checklist)
└── tasks.md             # /speckit-tasks
```

### Source Code (repository root)

```text
scripts/
├── validate_docs.py            modify    id_shape(), strict round directories, every directory under specs/
├── tick_task.py                modify    main(argv, root), early refusals, restore on failed validation
├── prepush_scan.py             modify    labelled PATTERNS and FORBIDDEN, hash list, --record-simulators
├── migration_ledger.py         modify    read_json() fails cleanly on damaged or unreadable files
├── planning_index.py           modify    prompt_coverage(), `coverage` command, override_ids()
├── speckit_prompts.py          existing  read only (its manifest is the source for phases 036–185)
├── validate_autocreator.py     existing  read only (run by CI as a step)
├── planning_archive.py         existing  read only (run by CI as a step)
└── test_scripts.py             modify    about 35 new tests; ledger tree hash before and after the suite

Configs/
└── simulator-identifier-hashes.json    new    schema 1, sorted SHA-256 hashes

.github/workflows/
├── ci.yml                      modify    four validator steps in the job `checks`
└── push-scan.yml               new       scan of the pushed range, never cancelled

Auto-Creator.md                 modify    sections 19.4, 21.2, 24.1 and 25.3 describe the tools as built (edited in place)
README.md                       modify    workflow list and CI paragraph
setup.md                        modify    section 5.1: recording simulator identifiers before a push
docs/migration/path-map.json    modify    state of the entries of this gate
```

Not touched: `Apps/`, `Packages/`, `Showcase/`, `Harnesses/`, `External/`, `Vendor/`, `Tools/python/`,
`.autonomy/state.json`, `specs/001`–`035`, `docs/archive/`.

**Structure Decision**: the feature lives in the existing `scripts/` directory and its one test file, as every
governance tool does. No new script is added: each gap belongs to a tool that exists.

## Module and dependency direction

```text
test_scripts.py ──► validate_docs, tick_task, prepush_scan, migration_ledger, planning_index, speckit_prompts
tick_task ──► validate_docs, prepush_scan
planning_index ──► validate_docs (namespace of a directory)
validate_autocreator ──► migration_ledger, planning_index, planning_archive, migration_baseline   (existing)
prepush_scan, validate_docs, migration_ledger ──► standard library only
```

No cycle. `migration_ledger.py` imports none of the others and stays the only module that writes
`.autonomy/migration/ledger.json`.

## Public interface

There is no Swift API. The interface is the command line of the tools and the functions the self-tests call; both
are in [contracts/tools.md](contracts/tools.md). The workflows are in [contracts/ci.md](contracts/ci.md).

## Lifecycle contracts

- **Processes and threads**: every tool is one short process with one thread. No daemon, no background job, no
  shared state between runs except tracked files.
- **One writer**: one integration session runs the tools at a time (Auto-Creator.md section 18.5). The tools take
  no lock of their own.
- **Atomic writes**: the ledger tool already writes through a temporary file and `os.replace`. The tick tool and
  the hash-list recorder do the same. A process killed before the replace leaves the old file; a process killed
  after it leaves the complete new file.
- **Tick sequence**: read → refuse or write → validate → restore and fail, or stage, commit, scan, push. The task
  list on disk is either the old bytes or the complete ticked text at every moment.
- **Ledger sequence**: `run-check` (log, then attestation) → `seal` (re-hash logs, write evidence) → `record` (write
  the ledger). A log without an attestation is ignored by `seal`; evidence that was sealed and never recorded is
  replaced by the next seal; recorded evidence is never replaced.
- **CI**: `ci.yml` may be cancelled by a newer push (its checks describe the state of the newest commit). The scan
  workflow runs once per pushed commit and is never cancelled.

## Data schemas

See [data-model.md](data-model.md). One new format: `Configs/simulator-identifier-hashes.json`, schema 1. A reader
that finds another schema number stops with a message. There is no earlier version, so there is no migration. The
ledger, attestation, evidence, index and manifest formats do not change.

## Tests of each layer

| Layer | Tests | Command |
|---|---|---|
| Host | `scripts/test_scripts.py`: `DocsTests` (numbering, id shapes, five namespaces accepted and rejected, ledger directories), new `TickTaskTests` (seven directory forms, refusals, restore, three push situations), `PrepushScanTests` (fixture table per label, coverage of labels, hash list, recording, unreadable range, push outcomes), `MigrationLedgerTests` (seal and record refusals, damaged files, single writer), new `PromptCoverageTests` (repository and a broken copy, override sentence), new `GovernanceTests` (who pushes, CI steps present) and the ledger tree hash around the suite | `python3 scripts/test_scripts.py` |
| Package tests on the iOS 27.x and iOS 26.5 simulators | none: no Swift code changes | not applicable |
| App UI tests | none: no UI | not applicable |
| Integration | real runs of both workflows on the pushed commit | `gh run watch <id> --exit-status` |

## Build and test commands

Nothing is built. Evidence commands (all in [quickstart.md](quickstart.md)):

```bash
python3 scripts/test_scripts.py
python3 scripts/validate_docs.py
python3 scripts/validate_autocreator.py
python3 scripts/migration_ledger.py validate
python3 scripts/prepush_scan.py
python3 scripts/planning_index.py coverage
python3 scripts/planning_archive.py verify
python3 scripts/planning_index.py verify
```

Each is recorded with `python3 scripts/migration_ledger.py run-check --gate UA-F00 --name <check-name> -- <command>`.
VisualCore does not change, so `check_public_api.py --update`, `check_documented_api.py` and the ProjectM reference
regression are not part of this feature.

## Migration and rollback

- **Order**: tests first, then each tool; the hash list is recorded before the scan starts to rely on it; the
  workflows last, because their real run is the final evidence.
- **No data migration**: no existing file changes its format.
- **Rollback**: `git revert` of the feature's commits. Without the hash list the scan reports every simulator
  identifier, so a partial rollback fails closed. Reverting the workflow commit removes the scan workflow and the
  four steps and nothing else. The ledger is never rolled back by hand; a recorded gate stays recorded.

## Complexity Tracking

No constitution violation to justify.
