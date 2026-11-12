# Quickstart: validate UA-F00

Run from the repository root on `main`. Nothing is built; every command finishes in well under ten minutes.

## Prerequisites

- `python3 scripts/verify_environment.py` prints `PASS`.
- `python3 scripts/migration_ledger.py show --gate UA-F00` prints `UNMET: none`.
- `gh auth status` succeeds (needed only for scenario 7).

## Evidence commands

Each is recorded for the gate with
`python3 scripts/migration_ledger.py run-check --gate UA-F00 --name <check-name> -- <command>`.

| Check name | Command | Expected |
|---|---|---|
| `script-tests` | `python3 scripts/test_scripts.py` | `OK`, exit 0, under 5 minutes |
| `docs` | `python3 scripts/validate_docs.py` | `PASS: … 0 problems` |
| `steering` | `python3 scripts/validate_autocreator.py` | `PASS: steering documents, 16 checks, 0 problems` |
| `ledger` | `python3 scripts/migration_ledger.py validate` | `PASS: migration ledger, 0 problems` |
| `prepush-scan` | `python3 scripts/prepush_scan.py` | `PASS: pre-push scan of … 0 findings` |
| `prompt-coverage` | `python3 scripts/planning_index.py coverage` | `PASS: <features> pending launch features, <prompts> stage prompts, 0 problems` |
| `archive` | `python3 scripts/planning_archive.py verify` | `PASS: planning archive, 0 problems` |
| `index` | `python3 scripts/planning_index.py verify` | `PASS: planning index, 0 problems` |

## Validation scenarios

1. **Numbering (US1)**: `python3 scripts/validate_docs.py` passes with the 35 sealed dossiers and this one.
   `git diff --stat <commit before the feature> -- specs/0[0-2]* specs/03[0-5]*` prints nothing.
2. **Tick (US2)**: the `TickTaskTests` of the self-tests pass; ticking the tasks of this feature with
   `python3 scripts/tick_task.py specs/186-ua-f00-governance-tooling <task-id> "<evidence>" "<subject>"` produces one
   pushed commit per task.
3. **Scan (US3)**: the `PrepushScanTests` pass. `python3 scripts/prepush_scan.py --record-simulators` run twice:
   the second run reports 0 added and `git status --short Configs/` prints nothing new.
4. **Ledger (US4)**: the `MigrationLedgerTests` pass and the suite reports the same hash of `.autonomy/migration/`
   before and after.
5. **Prompts (US5)**: `python3 scripts/planning_index.py coverage` prints the two counts;
   `python3 scripts/planning_index.py prompt --feature R02-G01-01 --stage specify --override` ends with the sentence
   that names `specs/301-aurora-loom-playable-rule-kernel` and the three id forms.
6. **Scope (boundaries)**: `git diff --stat <commit before the feature> -- Apps Packages Showcase Harnesses External
   Vendor Tools .autonomy/state.json` prints nothing.
7. **CI (US6)**: after the push of the workflow commit,
   `gh run list --branch main --workflow ci --limit 1` and
   `gh run list --branch main --workflow push-scan --limit 1` show a run for that commit;
   `gh run watch <id> --exit-status` ends with success for both.
   The pull-request path of `push-scan.yml` (range `<base>...<head>`) is proven by the self-test
   `test_three_dot_range_reads_the_commits_since_the_merge_base`; it has not run on GitHub, because the repository
   has no pull request. Its first real run happens with the first pull request.

Details of the commands are in [contracts/tools.md](contracts/tools.md) and [contracts/ci.md](contracts/ci.md); the
data formats are in [data-model.md](data-model.md).
