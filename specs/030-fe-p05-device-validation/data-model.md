# Data Model: Fractal Explorer — Phase 05

## AutomationReport (VisualCoreAutomation, schema 1)

Existing fields plus `measurements: {name: number}?` and `details: {name: text}?`.

Precision mode measurements: `highpBits`, `highpRangeMax`, `mediumpBits`, `mantissaBitsUsed`, `maxRenderSize`,
`steps`, `clampStep` (−1 none), `breakdownStep` (−1 none), `clampZoom`, `breakdownZoom`, `minReliableAgreement`.
Details: `fallback` (the precision source text), `ladder` ("step zoom level agreement; …").

Tour mode measurements: `tours`, `stops`, `minStopAgreement`, `captureLongEdge`; frame-time statistics in
`frameTimeMs`, frames in `frames`. Details: per tour agreement list.

## PrecisionLadder.Step (FractalExplorerCore)

| Field | Type |
|---|---|
| index | Int (0…23) |
| zoom | Double (4^index) |
| level | PrecisionMode.Level |
| clamped | Bool |
| agreement | Double (0…1) |

Verdict: pass/fail, clampStep?, breakdownStep?, reason.
