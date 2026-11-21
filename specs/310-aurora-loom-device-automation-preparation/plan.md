# Implementation Plan: R02-G01-10 — Aurora Loom: device automation preparation

**Branch**: `310-aurora-loom-device-automation-preparation` (spec directory only; work on `main`) | **Date**: 2026-11-21 |
**Spec**: [spec.md](spec.md)

## Summary

Write Aurora Loom's device contract without touching a device: `docs/apps/aurora-loom/device-rows.json` (schema 1: the
device scenario set of 12 scenarios, the devices D1, D2, D3 tied to the ledger's DEV rows, and rows AL-D1 … AL-D8 with
procedure, measurements, pass condition, gating, covered tasks, owner steps and status "pending device campaign"), the
written plan `docs/apps/aurora-loom/device-campaign.md` modelled on A21's, and `scripts/check_device_rows.py`, which
validates the definition against the scenario manifest, the ledger and the open {device} tasks of features 301–309,
with tests in `scripts/test_scripts.py` and a `device-rows` step in `release_check.py`. Research:
[research.md](research.md). Data: [data-model.md](data-model.md). Contract: [contracts/device-rows.md](contracts/device-rows.md).
Quickstart: [quickstart.md](quickstart.md).

## Technical Context

**Language/Version**: Python 3 (standard library) for the check; JSON and Markdown for the contract.
**Primary dependencies**: Aurora Loom's `scenario-manifest.json`, `.autonomy/migration/ledger.json` (read only),
`specs/30[1-9]-aurora-loom-*/tasks.md` (features 301–309), `docs/performance/budgets.md`.
**Testing**: `python3 scripts/test_scripts.py` (alone); `python3 scripts/check_device_rows.py --experience r02-g01.aurora-loom`.
**Constraints**: no device contact, no device number, no Swift change, no change to the ledger.

No NEEDS CLARIFICATION remains.

## Constitution Check

| Principle | Result |
|---|---|
| V Implementation Before Devices | PASS — nothing contacts a device; every row is pending; D3 stays on iPadOS 26.5. |
| VI Evidence Over Assertion | PASS — no device value is claimed; the check refuses a result field. |
| VIII Public Apple APIs, Privacy and Truthful Capabilities | PASS — the definition names no device identifier. |
| XI One App and Stable Experience Identity | PASS — the experience id and the ledger rows are matched exactly. |

Post-design re-check: PASS.

## Project Structure

```text
docs/apps/aurora-loom/device-rows.json        new   definition (lead)
docs/apps/aurora-loom/device-campaign.md      new   written plan (agent B, from the definition)
scripts/check_device_rows.py                  new   the check (agent A)
scripts/test_scripts.py                       edit  tests of the check (agent A)
scripts/release_check.py                      edit  step device-rows (lead)
docs/automatedtesting.md, Packages/ExperiencesRound02/README.md, docs/architecture/aurora-loom.md   edit (lead)
```

**Rollback**: revert the commits; nothing persists.

## Parallel work

The lead writes the definition first; agent A writes the check and its tests against it; agent B writes the plan from
it; the lead runs the check, the script tests (alone) and records.
