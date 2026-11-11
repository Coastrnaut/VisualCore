# Contract: app automation modes and the Fractal Explorer measurement modes

## VisualCoreAutomation (public)

- `AutomationRunner.AppMode`, `AutomationRunner.appModes`, `AutomationRunner.allModes`;
  `AutomationReport.measurements`, `AutomationReport.details`; `AutomationView(…, appModes:)`.
- Tests ≥ 4: an app mode runs and fills measurements; the domain check fails an app mode; an app mode named like a
  built-in is ignored and noted; unknown mode lists app modes; a report JSON without the new keys decodes.

## App modes (`VISUALCORE_AUTORUN`)

| Mode | Pass rule |
|---|---|
| `precision` | every reliable step agrees ≥ 99%; clamp step ≤ breakdown step (or no breakdown) |
| `tour` | every stop's capture agrees ≥ 99% at 64 points; all frames rendered; no capture file left |

Built-in `smoke`, `launch`, `lifecycle` run on the explorer's scene with the domain check "no shader error".

## FractalExplorerCore

`PrecisionLadder.zooms(steps:factor:)`, `PrecisionLadder.Step`, `PrecisionLadder.verdict(_:)`. Tests ≥ 4 (clamp
before, at and after the breakdown; no breakdown; reliable step below 99%).
