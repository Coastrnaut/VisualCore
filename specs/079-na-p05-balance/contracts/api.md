# Contract: A10-P05 additions

## NeonArcadeCore
- `ArcadeBudget` — `static let levels = 3`; `static func level(_:) -> ArcadeBudget`; fields of data-model.md;
  `glowAlpha(base:pulse:) -> Double`; `burstCount(_:) -> Int`.
- `Contrast` — `static func luminance(_ rgb: Vec4) -> Double`; `static func ratio(_:_:) -> Double`;
  `static func composite(_ top: Vec4, over: Vec4) -> Vec4`.
- `SimulatedPlayer` — `enum Kind { idle, dodger, collector }`; `static func steering(_ kind:, run: GameRun) -> Double`;
  `static func play(_ kind:, seed:, maxSteps:) -> (waves: Int, score: Int)`.

## Experience
- `ArcadeCore.qualityTiers == ArcadeBudget.levels`; presenter reads the tier and Low Power Mode (injected).

## Catalog
- `Catalog/registrations.json` entries may carry `summary` (1…300 characters).
