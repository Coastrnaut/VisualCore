# Data model: R02-F10

- **PerceptualColor** (enum namespace) over `SIMD3<Double>`: sRGB 0…1 ↔ linear ↔ OKLab (L 0…1, a, b) ↔ OKLCh (L, C ≥ 0,
  h radians 0…2π). All inputs finite; sRGB components in 0…1 (else `ColorAccessError`).
- **ColorVisionCondition**: `normal`, `protanopia`, `deuteranopia`, `tritanopia`, `achromatopsia` (String raw values,
  CaseIterable).
- **PaletteSeparationIssue**: `first: Int`, `second: Int`, `condition`, `distance: Double` (ΔE_OK < 0.08).
- **ColorVisionPresets**: `warmCool`, `redCyan`, `lightness` — `Palette`s with ids `cvd-warm-cool`, `cvd-red-cyan`,
  `cvd-lightness`, six stops each.
- **ClueShape**: circle, square, triangle, diamond, hexagon, plus, ring, star (Int raw 0…7). **CluePattern**: solid,
  stripes, dots, crosshatch (Int raw 0…3).
- **CodedState**: `id: String` (`^[a-z0-9-]{1,40}$`), `color: SIMD3<Double>` (sRGB 0…1), `shape`, `pattern`, `name`
  (1…40 characters after trimming). Codable, schema 1.
- **CodedStateSet**: `states: [CodedState]`, 0…32; validated by `init(_:) throws(ColorAccessError)`: unique ids, unique
  names, unique (shape, pattern) pairs; `separationIssues` reports colour pairs closer than 0.08 (advice, not refusal).
- **ColorAccessError**: `nonFinite(index:)`, `outOfRange(index:)`, `sameClue(String, String)`, `emptyName(index:)`,
  `duplicateName(String)`, `duplicateID(String)`, `tooManyStates(count:limit:)`; `reasonCode` `r2-f10.*`.
- **ColorVisionChoice** (VisualCoreSimulation): `standard`, `warmCool`, `redCyan`, `lightness`; stored at
  `<prefix>.colorVision`; absent or unknown → `standard`. `AccessibilityPreferences.colorVision` defaults to `standard`.
