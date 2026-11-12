# Research: UA-F00 — Governance tooling

**Date**: 2026-11-11 · **Gate**: UA-F00 · Everything below was read or run in the repository at commit `68f696b`.

## R0. Read-only audit

Sources read in full: Auto-Creator.md sections 19 and 25, ADR-0004, ADR-0009 (D-11, D-12, D-13),
`scripts/validate_docs.py` (146 lines), `scripts/tick_task.py` (61), `scripts/prepush_scan.py` (126),
`scripts/migration_ledger.py` (700), `scripts/speckit_prompts.py` (172), the prompt part of
`scripts/planning_index.py` (lines 640–840), `.github/workflows/ci.yml` (72), and the test classes `DocsTests`,
`MigrationLedgerTests`, `SteeringDocumentTests` and `PrepushScanTests` of `scripts/test_scripts.py` (1,226 lines,
103 tests, 6.9 s on this Mac).

### What already meets the specification (nothing here is rebuilt)

| Requirement | Verified fact |
|---|---|
| FR-U00-001 (seven directory forms) | `validate_docs.namespace()` returns the namespace for 001–010, 011–185, 186–200, 201–234, 301–550, `rNN-fFF-*`, `rNN-gGG-FF-*`; `test_unified_numbering_map` proves nine directory names. All 823 feature directories of the migration ledger map to 823 different namespaces (checked with a script on 2026-11-11). |
| FR-U00-005 (duplicates) | `validate()` reports a duplicated FR/SC definition and a duplicated task id across dossiers (`test_unified_namespaces_are_enforced`, `test_unverified_tick_and_duplicate`). |
| FR-U00-006 (existing checks) | Verified annotations, undefined references, ADR date and status, relative links, constitution version line and tokens: all present and tested. |
| FR-U00-007 | `python3 scripts/validate_docs.py` → "PASS: 36 feature dossiers checked, 0 problems" (35 sealed plus this one). |
| FR-U00-010, 013, 014 | `tick_task.py` matches the line prefix `- [ ] <id> `, which is namespace-neutral; commits with `git commit -q -m` (no trailer); pushes with `git push -q origin main` only when the branch is `main` and `prepush_scan.py` exits 0. |
| FR-U00-024 | `prepush_scan.scan()` returns "cannot read <range>" as a finding when `git diff` fails (reproduced in a depth-1 clone: exit 1). `--push` returns 1 on findings and on a branch other than `main`; it runs `git push origin main` without force. |
| FR-U00-030, 031, 032, 034, 035, 037 | `require_open()`, `cmd_run_check()`, `cmd_seal()`, `validate()` implement the refusals; tests: `test_order_is_enforced`, `test_attestations_are_single_use_and_logs_are_hashed`, `test_claude_cli_is_refused`, `test_evidence_commands_are_argument_lists`, `test_original_apps_need_their_legacy_gates`, `test_tampered_evidence_is_detected`, `test_reverification_keeps_every_revision`. |
| FR-U00-033 | `require_open()` refuses device rows and campaigns; `cmd_guard_device()` fails; `test_devices_are_guarded_by_the_lock` covers the guard and `run-check`. |
| FR-U00-040 (data) | The tracked manifest `docs/process/speckit-prompt-manifest.json` holds a non-empty archive prompt for all eight stages of each of the 150 pending phases 036–185 (0 empty, 0 supplemented; `python3 scripts/speckit_prompts.py --check` → "manifest up to date"). A cached walk over the 788 pending round features found 6,304 non-empty archived prompts in 0.17 s. The 15 unified-app features render eight prompts each (`test_briefs_and_prompts`). 150 + 788 + 15 = 953 features, 7,624 prompts. |
| FR-U00-050 (runnable in CI) | In a fresh `git clone --depth 1` without the submodule, `validate_autocreator.py`, `planning_archive.py verify`, `planning_index.py verify` and `migration_ledger.py validate` all exit 0. They need no untracked file. |
| FR-U00-060, 061 | The tools import only the standard library and call no model. |

### Gaps (each becomes work)

| Id | Gap | Requirement |
|---|---|---|
| G-01 | The round-directory pattern accepts every two-digit round (`r00`–`r99`). Rounds outside 03–12, a game number outside 01–25 and a feature number outside 01–10 must be outside the map. | FR-U00-002 |
| G-02 | `000-x` maps to the namespace `F-1`. A directory under `specs/` that matches neither glob (for example `specs/r3-g1-x` or `specs/notes`) is ignored instead of reported. | FR-U00-002 |
| G-03 | The namespace test is `startswith(ns)`: an id with a longer feature number that begins with the same characters passes. | FR-U00-003 |
| G-04 | Task ids are checked for uniqueness only, not for their namespace. | FR-U00-004 |
| G-05 | The final line of `validate_docs.py` counts numbered directories only; round directories are not counted. | FR-U00-001 |
| G-06 | Namespace fixtures: accepted dossiers exist for U, R02F, R02G and RnnG; a rejected dossier exists only for U. Missing: accepted RnnF, rejected R02F, R02G, RnnF, RnnG. No test walks the ledger's feature directories. | FR-U00-008, FR-U00-001 |
| G-07 | `tick_task.py` writes the task list before validating and leaves it changed when validation fails. | FR-U00-012 |
| G-08 | `tick_task.py` accepts evidence with a line break (it would split the task line) and fails with a traceback when the task list does not exist. | FR-U00-011 |
| G-09 | `tick_task.py` has no self-test, and `main()` takes neither arguments nor a root, so it cannot be tested on a temporary repository. | FR-U00-010–014 |
| G-10 | The scan lists four token forms under one pattern and one regex for all forbidden paths, so a test cannot enumerate them. Fixtures are missing for three token forms, for `.autonomy/reports/`, `.p8` and `.cer`. No test fails when a pattern has no fixture. | FR-U00-020, 022, 023 |
| G-11 | The scan accepts simulator identifiers by asking the simulator list of the machine it runs on. A CI runner has other simulators, so the same commit would fail there. | FR-U00-025, 026 |
| G-12 | No test for an unreadable range or for the three `--push` outcomes. | FR-U00-024 |
| G-13 | `seal` and `record` refusals for an unmet dependency and for a device gate are not tested (only `run-check` is). | FR-U00-030, 033, 038 |
| G-14 | A damaged ledger, attestation or evidence file ends in a Python traceback from `json.loads`; an unknown schema has a message but no test. | FR-U00-036 |
| G-15 | Nothing proves that the self-tests leave the real `.autonomy/migration/` tree unchanged. | FR-U00-038 |
| G-16 | No test proves that only `migration_ledger.py` writes the ledger, or that only the two tools push. Today the readers are `validate_autocreator.py`, `render_autocreator.py` and `build_traceability_matrix.py`; the only `git push` calls are in `tick_task.py:55` and `prepush_scan.py:121`. | FR-U00-039, 015 |
| G-17 | No test walks every pending launch feature for its eight prompts, and no command reports the counts. | FR-U00-040, 041 |
| G-18 | The override note of an archived round feature (`OVERRIDE_GAME`, `OVERRIDE_SHARED`) refers to section 19 instead of naming the directory and the id forms. | FR-U00-042 |
| G-19 | `ci.yml` does not run the four validators as steps (the steering validator runs only inside the script tests), and nothing in CI scans the pushed range. The workflow's concurrency group cancels a running workflow when a newer push arrives. | FR-U00-050, 051 |

### Corrections to names in the brief

The brief names no new type. Two statements were checked against the code and corrected:

- "extend scripts/validate_docs.py namespaces": the namespaces were added during the consolidation; what remains is
  G-01 to G-06.
- "scripts/speckit_prompts.py for 036-185": that tool reads the untracked extraction `.autonomy/context/`, which a
  CI runner does not have. Its tracked output `docs/process/speckit-prompt-manifest.json` is what the coverage
  check reads; where the extraction exists, the check also proves that the manifest is what the tool produces.

## R1. One id shape per directory form

- **Decision**: `validate_docs.py` gets `id_shape(feature_dir)`, which returns a compiled pattern for the part after
  `FR-`, `SC-` or `T-`: `F<k>\d{2}` for 001–010, `A<nn>-<p>\d{2}` for 011–185 and `<ns>-\d{3}` for every other form.
  Definitions and task ids must match it completely.
- **Rationale**: the 35 sealed dossiers conform already (0 deviations among their definitions and task ids), so
  one rule serves all dossiers and none of them changes (Clarifications, question 4).
- **Alternatives considered**: keeping the prefix test for old dossiers and the exact shape for new ones (two rules
  for no benefit).

## R2. Directories outside the map

- **Decision**: every directory directly under `specs/` is examined. Round directories must match
  `r(0[3-9]|1[0-2])-f(0[1-9]|[1-9]\d)-…` or `r(0[3-9]|1[0-2])-g(0[1-9]|1\d|2[0-5])-(0[1-9]|10)-…`; numbered directories
  must be 001–234 or 301–550. Anything else is reported as outside the map.
- **Rationale**: ADR-0009 D-11 and Auto-Creator.md section 19.1 name exactly these forms; each round has 25 games
  with ten features. A directory that is silently ignored would hide a dossier from every check.
- **Alternatives considered**: reporting only directories that look like features (a misspelled directory would
  stay invisible).

## R3. Tick tool: validate before it is too late, restore on refusal

- **Decision**: `tick_task.main(argv=None, root=ROOT)`. It reads the task list, refuses early (missing file, missing
  or repeated task, empty or multi-line evidence), writes the new text through a temporary file and `os.replace`,
  calls `validate_docs.validate(root)` in process and, on any problem, writes the saved bytes back and exits with
  the first problems. Commit and push are unchanged, except that the scan is called in process with the same root.
- **Rationale**: the task list must never be left half-ticked (FR-U00-012); an in-process call makes the tool
  testable on a temporary repository.
- **Alternatives considered**: validating a copy before writing (the validator reads the repository, so the copy
  would need the whole tree).

## R4. Scan patterns that a test can enumerate

- **Decision**: `PATTERNS` becomes one entry per kind with its own label: hardware identifier, device or simulator
  UUID, ECID, serial number, development team setting, development team id, e-mail address, absolute home path,
  private key, GitHub token, GitHub fine-grained token, Anthropic API key, AWS access key id. `FORBIDDEN` becomes a
  list of labelled patterns: private device data, logs, result bundles, reports, local signing file, provisioning
  profile, key store, signing key, certificate. A table in the self-tests holds one finding and one clean line per
  label, and a coverage test compares the labels of the scanner with the keys of the table.
- **Rationale**: FR-U00-023 needs the list of what the scanner claims to be data, not prose.
- **Alternatives considered**: parsing the module docstring for the claims (fragile).

## R5. Simulator identifiers by hash

- **Decision**: `Configs/simulator-identifier-hashes.json` (schema 1) holds the sorted SHA-256 hashes of the
  upper-case identifiers of this Mac's simulators. `python3 scripts/prepush_scan.py --record-simulators` adds the
  hashes of the current simulators and never removes one. The scan accepts an identifier of the 8-4-4-4-12 form only
  when it is synthetic or its hash is in the list. On the Mac, an identifier that the simulator list knows but the
  hash list does not is reported as "simulator identifier not recorded" with the command to run.
- **Rationale**: Clarifications, question 1. Physical devices have identifiers of the same form in `devicectl`, so
  a rule by file path would let one through. A hash cannot be turned back into an identifier or copied into a
  command, which respects the rule that simulators are chosen by runtime.
- **Alternatives considered**: tracking the identifiers (rejected in clarification); skipping `.autonomy/` in CI
  (the place where a device identifier is most likely to appear).

## R6. The CI scan is its own workflow

- **Decision**: a second workflow `.github/workflows/push-scan.yml` on `ubuntu-latest`, with
  `fetch-depth: 0`, a ten-minute timeout and the concurrency group `push-scan-<commit>` without cancellation. For a
  push the range is `<before>..<after>`; for a pull request `<base>...<head>` (the commits since the merge base).
  The values reach the script through environment variables. An all-zero or unreachable earlier commit makes
  `git diff` fail, which the scan reports as a finding.
- **Rationale**: Clarifications, question 2. `ci.yml` cancels in progress by its concurrency group, which is right
  for state checks and wrong for a range scan. Auto-Creator.md section 24.1 asks for a timeout and a concurrency
  group on every job; a group per commit satisfies it without ever cancelling. The scan needs only Git and Python,
  so the cheapest runner is enough.
- **Alternatives considered**: a job inside `ci.yml` (cancelled with it); `cancel-in-progress: false` on one shared
  group (GitHub then drops the pending run in the middle when a third push arrives).

## R7. Prompt coverage as a function with a command

- **Decision**: `planning_index.prompt_coverage(root)` returns the number of features, the number of prompts and a
  list of problems. It takes the pending original-app phases from the legacy ledger and their prompts from the
  tracked manifest; the pending unified-app, shared and game features from the migration ledger and their prompts
  from the briefs and the feature index (the archive file of a round is read once). `python3
  scripts/planning_index.py coverage` prints the counts and exits 1 on a problem. The self-test calls the function on
  the repository and on a temporary copy with one prompt removed.
- **Rationale**: FR-U00-041 (the list comes from the ledgers) and SC-U00-007 (both numbers are reported).
- **Alternatives considered**: a test that shells out to `prompt` 953 times (slow, and it would not name the stage).

## R8. Exact directory and ids in the override note

- **Decision**: `planning_index.override_ids(root, feature)` returns the sentence
  "Canonical override: feature directory <dir>; requirement ids FR-<ns>-###, success criteria SC-<ns>-###, task ids
  T-<ns>-###." with the directory of the ledger gate (or the proposed directory of the index for a round that is
  not in the ledger yet) and the namespace from `validate_docs.namespace()`. `cmd_prompt --override` prints it after
  the existing override paragraph of an archived round feature.
- **Rationale**: Clarifications, question 5; one rule for the validator and for the prompt.
- **Alternatives considered**: editing the three override paragraphs (they are cited by the validator and by
  section 21.2 and would have to carry 788 different values).

## R9. Proving that the self-tests do not touch the real ledger

- **Decision**: `scripts/test_scripts.py` hashes every file under `.autonomy/migration/` before the tests and again
  after them, and exits with a failure when the two differ. The ledger tests keep working on a temporary root.
- **Rationale**: FR-U00-038 and SC-U00-006 ask for the hash to be identical before and after.
- **Alternatives considered**: one test method (it cannot run after all the others in a reliable way).

## R10. Clean messages for damaged files

- **Decision**: `migration_ledger.read_json()` raises the tool's own failure "cannot read <file>: <reason>" for
  invalid JSON and for a file that cannot be read; `load()` keeps its messages for a missing ledger and an unknown
  schema. Nothing is written before the ledger loaded.
- **Rationale**: FR-U00-036. The tool is the only writer, so a damaged file means outside interference and must
  stop every command.
- **Alternatives considered**: repairing the ledger from Git (never automatic; the session recovers by hand,
  Auto-Creator.md section 25.4).

## Unknowns

None remain. No NEEDS CLARIFICATION marker is left in the technical context.
