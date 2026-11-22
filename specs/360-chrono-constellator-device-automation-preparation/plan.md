# Implementation Plan: R02-G06-10 — Chrono Constellator: device automation preparation

**Branch**: `360-chrono-constellator-device-automation-preparation` (spec directory only; work on `main`) | **Date**:
2026-11-22 | **Spec**: [spec.md](spec.md)

## Summary

Write Chrono Constellator's device contract without touching a device: `docs/apps/chrono-constellator/device-rows.json`
(schema 1 of feature 310: the device scenario set of 12 scenarios, the devices D1, D2, D3 tied to the ledger's
DEV1/2/3-R02-G06 rows, and rows CR-D1 … CR-D8 with procedure, measurements, pass condition, gating, covered tasks, owner
steps and status "pending device campaign") and the written plan `docs/apps/chrono-constellator/device-campaign.md`
modelled on Colorfall Canyons's (`docs/apps/colorfall-canyons/device-campaign.md`). The existing generic `scripts/check_device_rows.py` validates it against the scenario
manifest, the ledger and the open {device} tasks of features 351–359; `scripts/test_scripts.py` gains tests on the real
Chrono Constellator definition and `release_check.py` a step `device-rows-r02-g06`. Research: [research.md](research.md). Data:
[data-model.md](data-model.md). Contract: [contracts/device-rows.md](contracts/device-rows.md). Quickstart:
[quickstart.md](quickstart.md).

## Technical Context

**Language/Version**: Python 3 (standard library) for the check and its tests; JSON and Markdown for the contract.
**Primary dependencies**: Chrono Constellator's `scenario-manifest.json`, `.autonomy/migration/ledger.json` (read only),
`specs/35[1-9]-chrono-constellator-*/tasks.md`, `docs/performance/budgets.md`, feature 310's check.
**Testing**: `python3 scripts/test_scripts.py` (alone); `python3 scripts/check_device_rows.py --experience
r02-g06.chrono-constellator`.
**Constraints**: no device contact, no device number, no Swift change, no change to the ledger, no change to the check's
rules.

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
docs/apps/chrono-constellator/device-rows.json      new   definition (lead)
docs/apps/chrono-constellator/device-campaign.md    new   written plan (agent B, from the definition)
scripts/test_scripts.py                              edit  tests on the real definition and two removals (agent A)
scripts/release_check.py                             edit  step device-rows-r02-g06 (lead)
docs/automatedtesting.md, Packages/ExperiencesRound02/README.md, docs/architecture/chrono-constellator.md   edit (lead)
```

**Rollback**: revert the commits; nothing persists.

## Parallel work

The lead writes the definition and the release step first; agent A writes the tests and agent B the plan from the
definition; the lead runs the check, the script tests (alone) and records.
