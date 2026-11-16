# Data model: A16-P04 (feature 120)

| Entity | Fields | Rules |
|---|---|---|
| Brush (`SimulationModel.paint(x:y:mode:)`) | x, y 0…63; mode tap 0 / drag 1 | automaton: tap toggles, drag sets alive; RD: u 0.25, v 0.5 in radius 2 (wrap); wave: height 1 in the cell and 4 neighbours, current and previous, edges stay 0; values rounded to the family's precision; step count unchanged |
| `SimulationHistogram` | bins [Int] (16), nonFinite Int, range (low, high) | automaton 0…1, RD v 0…1, wave −1…1; finite out-of-range values clamped to the end bins; Σbins + nonFinite = cells |
| `ExperimentPreset` (schema 1) | schema, name ≤ 60, spec, palette "standard", annotation ≤ 200, source, license ∈ {original, public-domain} | spec valid (`refusal() == nil`) and 64 × 64; JSON with sorted keys |
| Preset file | `preset-<uuid>.json` in `ExperienceStorage` | ≤ 24 files; damaged, newer (schema ≥ 2) or refused files are reported and skipped |
| Capture | `a16-captures/a16-capture-….png`, 1024 × 1024 | one file; a failure leaves none |
| Rule codes | `a16.reduced-motion` (new, presenter), `a16.invalid-choice`, `a16.unstable`, `a16.unsupported` | a refusal changes nothing |
