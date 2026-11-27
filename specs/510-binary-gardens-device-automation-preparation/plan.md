# Implementation Plan: R02-G21-10 — Binary Gardens: device automation preparation

**Branch**: `510-binary-gardens-device-automation-preparation` (spec directory only; work on `main`) | **Date**:
2026-11-27 | **Spec**: [spec.md](spec.md)

## Summary

Write Binary Gardens' device contract without touching a device: `docs/apps/binary-gardens/device-rows.json` (schema 1
of feature 310: the device scenario set of 12 scenarios, the devices D1, D2, D3 tied to the ledger's DEV1/2/3-R02-G21
rows, and rows BG-D1 … BG-D8 with procedure, measurements, pass condition, gating, covered tasks, owner steps and status
"pending device campaign") and the written plan `docs/apps/binary-gardens/device-campaign.md` modelled on Mushroom
Weather's (`docs/apps/mushroom-weather/device-campaign.md`). The existing generic `scripts/check_device_rows.py`
validates it, unchanged, against the scenario manifest, the ledger and the open {device} tasks of features 501–509 (its
round-two numbering gives R02-G21 the range 501 … 509; no `EXTRA_ITEMS` entry is needed); `scripts/test_scripts.py`
gains `BinaryGardensDeviceRowsCheckTests` on the real definition and `release_check.py` a step `device-rows-r02-g21`.
Research: [research.md](research.md). Data: [data-model.md](data-model.md). Contract:
[contracts/api.md](contracts/api.md). Quickstart: [quickstart.md](quickstart.md).

## Technical Context

**Language/Version**: Python 3 (standard library) for the check and its tests; JSON and Markdown for the contract.
**Primary dependencies**: `Packages/ExperiencesRound02/BinaryGardens/scenario-manifest.json` (94 scenarios),
`.autonomy/migration/ledger.json` (read only), `specs/50[1-9]-binary-gardens-*/tasks.md`,
`docs/performance/budgets.md`, feature 310's check. **Testing**: `python3 scripts/test_scripts.py` (alone);
`python3 scripts/check_device_rows.py --experience r02-g21.binary-gardens`. **Constraints**: no device contact, no
device number, no Swift change, no change to the ledger, no change to the check's rules.

**Prerequisites**: R02-G21-05 … R02-G21-09 (features 505–509, planned or in progress) are recorded in the ledger
first; the coverage is read from their final task lists (today: T-R02G2103-012, T-R02G2104-011, T-R02G2106-011,
T-R02G2107-012, T-R02G2108-012, T-R02G2109-011). The definition may be drafted earlier; the check and the gate record
run after R02-G21-09 is recorded.

No NEEDS CLARIFICATION remains.

## Constitution Check

| Principle | Result |
|---|---|
| V Implementation Before Devices | PASS — nothing contacts a device; every row is pending; D3 stays on iPadOS 26.5. |
| VI Evidence Over Assertion | PASS — no device value is claimed; the check refuses a result field. |
| VIII Public Apple APIs, Privacy and Truthful Capabilities | PASS — the definition names no device identifier. |
| XI One App and Stable Experience Identity | PASS — the experience id and the ledger rows are matched exactly. |

Post-design re-check: PASS — the design adds two documents, one release step and one test class; no device is
contacted, installed or listed before ImplementationLock-100, and the DEV rows stay pending.

## Project Structure

```text
docs/apps/binary-gardens/device-rows.json            new   definition (lead)
docs/apps/binary-gardens/device-campaign.md          new   written plan (agent B, from the definition)
scripts/test_scripts.py                              edit  BinaryGardensDeviceRowsCheckTests (agent A, own file)
scripts/release_check.py                             edit  step device-rows-r02-g21 (lead)
docs/automatedtesting.md                             edit  device-rows entry (lead)
Packages/ExperiencesRound02/README.md                edit  device preparation line (lead)
docs/architecture/binary-gardens.md                  edit  device preparation section (lead)
README.md                                            edit  feature count and date at the record (lead)
```

**Dependency graph**: R02-G21-09 recorded → baselines → definition and release step (lead) → {tests (agent A), written
plan (agent B)} → check and script tests (lead, alone) → docs → Stage One and reference regression → converge → seal and
record.

**Owners**: the lead holds every shared file, every Spec Kit skill, the check, the runs and the commits; agent A the
test class, agent B the written plan. Every device handling step (unlock, trust, signing, settings, charging) is the
owner's, written in each row's `owner_steps` and recorded by the campaign as BLOCKED_OWNER_ACTION; none is done here.

**Migration**: none (no saved state, schema or ledger change). **Rollback**: revert the commits; nothing persists.

**CI**: `ci.yml`'s "Script tests" step runs the new class; no Swift job changes, so no round-two host chunk filter
changes. Pushes are batched so a CI run completes; a failure is fixed before the next gate.

## Parallel work

The lead writes the definition and the release step first; agent A writes the test class as a separate file that the
lead merges into `scripts/test_scripts.py`, and agent B writes the plan from the definition; the lead runs the check,
the script tests (alone, no run-check meanwhile), retests both results and records.
