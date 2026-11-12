# Contract: CI workflows (UA-F00)

## 1. `.github/workflows/ci.yml`, job `checks` (modified)

Triggers, runner, timeout and concurrency group stay as they are (push to `main`, pull requests; `macos-latest`;
30 minutes; a newer push cancels a running workflow). Four steps are added after the step "Docs":

| Step name | Command | Requirement |
|---|---|---|
| Steering documents | `python3 scripts/validate_autocreator.py` | FR-U00-050 |
| Planning archive | `python3 scripts/planning_archive.py verify` | FR-U00-050 |
| Planning index | `python3 scripts/planning_index.py verify` | FR-U00-050 |
| Migration ledger | `python3 scripts/migration_ledger.py validate` | FR-U00-050 |

Each step fails the job when its command exits with an error. None needs signing, a secret or the network
(FR-U00-052).

## 2. `.github/workflows/push-scan.yml` (new)

| Property | Value | Requirement |
|---|---|---|
| Triggers | push to `main`; pull requests | FR-U00-051 |
| Permissions | `contents: read` | FR-U00-052 |
| Concurrency | group `push-scan-<commit>`, `cancel-in-progress: false`: one run per commit, never cancelled by a newer push | FR-U00-051 |
| Runner and timeout | `ubuntu-latest`, 10 minutes | FR-U00-052 |
| Checkout | full history (`fetch-depth: 0`), no submodule | FR-U00-051 |
| Range for a push | `<commit before the push>..<pushed commit>` | FR-U00-051 |
| Range for a pull request | `<base commit>...<head commit>` (the commits since the merge base) | FR-U00-051 |
| Command | `python3 scripts/prepush_scan.py --range "$RANGE"`; the commit ids reach the step through environment variables | FR-U00-051 |
| Failure | a finding, a forbidden tracked path, an all-zero or unreachable earlier commit, an unreadable range | FR-U00-051 |

The scan in CI uses the tracked hash list and never asks for a simulator list, so it gives the verdict of the
development Mac (FR-U00-025).

## 3. Confirmation by a real run

After the commit that changes the workflows is pushed, both workflows run on it. Their run identifiers are read with
`gh run list --branch main --workflow <name> --limit 1` and each run is watched to its end with
`gh run watch <id> --exit-status`, recorded through `migration_ledger.py run-check` (FR-U00-053).
