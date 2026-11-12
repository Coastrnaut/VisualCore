# Contract: command-line tools (UA-F00)

Every tool is a Python 3 script that uses only the standard library. Exit code 0 means success; any other code means
a refusal or a failed check. A refusal prints one message that names what was refused and changes nothing.
Functions listed under "For tests" take the repository root as a parameter so that a self-test can run them on a
temporary copy.

## 1. `python3 scripts/validate_docs.py`

| Situation | Output and exit code | Requirement |
|---|---|---|
| Every dossier is inside the map and every id has its shape | `PASS: <n> feature dossiers checked, 0 problems`, exit 0; `<n>` counts numbered and round directories | FR-U00-001, FR-U00-007 |
| A directory under `specs/` is outside the map | `PROBLEM: specs/<name>: feature directory outside the numbering map (ADR-0009 D-11)`, exit 1 | FR-U00-002 |
| A defined id does not match the id shape of its directory | `PROBLEM: specs/<dir>/spec.md: <id> outside namespace <ns>`, exit 1 | FR-U00-003 |
| A task id does not match the id shape of its directory | `PROBLEM: specs/<dir>/tasks.md: <id> outside namespace <ns>`, exit 1 | FR-U00-004 |
| An id is defined twice | `PROBLEM: <id> defined in <place> and <place>` or `PROBLEM: task <id> duplicated (<place>)`, exit 1 | FR-U00-005 |
| Existing checks (verified tick, undefined reference, decision record header, link, constitution) | unchanged messages, exit 1 | FR-U00-006 |

For tests: `namespace(feature_dir) -> str` (empty outside the map), `id_shape(feature_dir) -> re.Pattern | None`,
`validate(root) -> list[str]`.

## 2. `python3 scripts/tick_task.py <feature_dir> <task_id> "<evidence>" "<commit subject>" [--no-push]`

| Situation | Behavior | Requirement |
|---|---|---|
| One open task with that id; validation passes | the line becomes `- [X] <id> … — Verified <today>: <evidence>`; one commit with the given subject and no trailer; exit 0 | FR-U00-010, FR-U00-013 |
| Task list missing; task missing, ticked or matched twice; evidence empty or with a line break | message, no file changed, no commit, exit not 0 | FR-U00-011 |
| Validation fails after the tick | the task list is restored to its previous bytes; the first problems are printed; no commit; exit not 0 | FR-U00-012 |
| Branch is not `main` | commit made; `not pushed: branch <name> is not main (ADR-0009 D-13)`; exit 0 | FR-U00-014 |
| Branch is `main`, scan clean, no `--no-push` | commit made and pushed with `git push origin main` (no force); exit 0 | FR-U00-014 |
| Branch is `main`, scan has a finding | commit stays local; `committed but NOT pushed: …`; exit not 0 | FR-U00-014 |

For tests: `main(argv, root) -> int`.

## 3. `python3 scripts/prepush_scan.py [--range A..B] [--push] [--record-simulators]`

| Situation | Behavior | Requirement |
|---|---|---|
| No finding in the added lines of the range and no forbidden tracked path | `PASS: pre-push scan of <n> commits (<range>), 0 findings`, exit 0 | FR-U00-020 |
| An added line holds a value of a pattern | `FINDING: <file>: <label>: <text>` (at most 40 lines, then the count), exit 1 | FR-U00-020 |
| An added line holds only allowed look-alikes | nothing reported | FR-U00-021 |
| A tracked path belongs to a forbidden class | `FINDING: <path>: this path must never be tracked (<label>)`, exit 1 | FR-U00-022 |
| The range cannot be read | `FINDING: cannot read <range>: <reason>`, exit 1 | FR-U00-024 |
| An identifier of the simulator form whose hash is not in the list | on any machine: finding `device or simulator UUID`; on a machine whose simulator list contains it: finding `simulator identifier not recorded` that names `python3 scripts/prepush_scan.py --record-simulators`; exit 1 | FR-U00-025 |
| The hash list is damaged or of another schema | `FINDING: Configs/simulator-identifier-hashes.json: cannot be read (<reason>)`, exit 1 | FR-U00-025 |
| `--push` with findings, or on a branch other than `main` | nothing is pushed; exit 1 | FR-U00-024 |
| `--push`, clean, on `main` | `git push origin main`; its exit code | FR-U00-024 |
| `--record-simulators` | adds the hashes of the machine's simulators to the list, keeps the recorded ones, writes sorted; prints how many were added; a second run adds 0 and changes no byte; where the simulator list cannot be read it writes nothing and exits 1 | FR-U00-026 |

For tests: `PATTERNS` and `FORBIDDEN` (lists of label and pattern), `scan_line(line, allowed_hashes)`,
`scan_diff(diff, allowed_hashes)`, `forbidden(paths)`, `load_hashes(root)`, `record_simulators(root, identifiers)`,
`scan(root, commits)`, `main(argv, root)`.

## 4. `python3 scripts/migration_ledger.py <command>`

The commands and their arguments do not change. Refusals that this feature tests or adds:

| Situation | Message contains | Requirement |
|---|---|---|
| `run-check`, `seal` or `record` for a gate with an unmet dependency | `is not ready; unmet: <gates>` | FR-U00-030 |
| `run-check` with a name already used for the gate | `check already recorded` | FR-U00-031 |
| `seal` when a log of a passing check is missing or changed | `log missing or changed since the command ran` | FR-U00-032 |
| `run-check`, `seal` or `record` of a device row or campaign before the lock; `guard-device` | `not ready; unmet: ImplementationLock-100` or `no physical-device install, launch or test` | FR-U00-033 |
| Evidence command is the Claude CLI, a shell or an inline script | `Claude CLI is prohibited`, `no shell wrapper`, `no inline script` | FR-U00-034 |
| Integration gate of an original app with open legacy phase gates | `unmet: legacy:<gate>` | FR-U00-035 |
| Ledger missing, of an unknown schema, or not valid JSON; an attestation or evidence file not valid JSON | `migration ledger missing`, `unexpected migration ledger schema`, `cannot read <file>` | FR-U00-036 |
| `validate` finds a pass or fail without evidence, changed or missing evidence, a device gate before the lock | one `PROBLEM:` line each, exit 1 | FR-U00-037 |

The self-tests run every refusal on a temporary root, and the suite compares the hash of every file under
`.autonomy/migration/` before and after (FR-U00-038). A self-test fails when a tracked script or workflow other than
the reviewed readers names the ledger file, or when a reader writes to it (FR-U00-039).

## 5. `python3 scripts/planning_index.py coverage` and `prompt --override`

| Situation | Behavior | Requirement |
|---|---|---|
| Every pending launch feature has eight non-empty prompts | `PASS: <features> pending launch features, <prompts> stage prompts, 0 problems`, exit 0 | FR-U00-040, FR-U00-041 |
| A prompt is missing or empty | `PROBLEM: <feature> <stage>: <reason>` and `FAIL: …`, exit 1 | FR-U00-041 |
| `prompt --feature <round feature> --override` | after each stage prompt: the existing canonical override paragraph, then the override sentence of data-model.md section 8 | FR-U00-042 |
| `prompt --feature UA-F<kk>` | unchanged: the override sentence is already part of each prompt | FR-U00-042 |

For tests: `prompt_coverage(root) -> tuple[int, int, list[str]]`, `override_ids(root, feature) -> str`.

## 6. Who pushes

Only `scripts/tick_task.py` and `scripts/prepush_scan.py` contain a Git push. A self-test reads every tracked
script and workflow and fails when another one does (FR-U00-015). No Git hook is installed.
