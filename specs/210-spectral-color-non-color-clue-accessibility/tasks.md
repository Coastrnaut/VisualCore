# Tasks: R02-F10 — Spectral color & non-color clue accessibility

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate R02-F10 (migration ledger). Evidence:
`python3 scripts/migration_ledger.py run-check --gate R02-F10 --name <check> -- <command>`. Commit after every task
(no trailers). No {owner} tasks. Every new public type name was checked against Packages and Apps for collisions
(the R02-F09 lesson). Fixture seed 2_010 (`SeededRandom`, tests only).

## Phase 1: Setup

- [ ] T-R02F10-001 Baselines: `--name baseline-host -- swift test --package-path Packages/VisualCore` and
  `--name baseline-rendering --` the VisualCoreRendering scheme on sim-27.2

## Phase 2: Foundational (pure colour science)

- [ ] T-R02F10-002 [P] Create `Packages/VisualCore/Sources/VisualCoreParameters/ColorAccessError.swift`
  (`nonFinite(index:)`, `outOfRange(index:)`, `sameClue(String, String)`, `emptyName(index:)`, `duplicateName(String)`,
  `duplicateID(String)`, `tooManyStates(count:limit:)`; `reasonCode` `r2-f10.non-finite`, `r2-f10.out-of-range`,
  `r2-f10.same-clue`, `r2-f10.empty-name`, `r2-f10.duplicate-name`, `r2-f10.duplicate-id`, `r2-f10.too-many-states`) and
  `PerceptualColor.swift` (sRGB ↔ linear ↔ OKLab ↔ OKLCh with Ottosson's M1/M2; `relativeLuminance` Rec. 709;
  `lightness` = OKLab L; WCAG `contrastRatio`; `difference` = ΔE_OK; `rotateHue` keeps L, greys unchanged, sRGB inputs
  "finite, 0…1" else `ColorAccessError`; `intoGamut` bisects chroma 24 steps at constant L and h; `outline(for:on:)`
  black or white by larger minimum contrast) with
  `Packages/VisualCore/Tests/VisualCoreParametersTests/PerceptualColorTests.swift` (1,000 seeded colours round-trip
  within 1e-9; OKLab of sRGB white (1, 0, 0) and published reference points; hue 360° returns the colour within 1e-9;
  lightness kept within 1e-9 when in gamut; greys unchanged; out-of-gamut rotation lands in 0…1 with L and h kept;
  contrast black/white 21, equal colours 1; non-finite and out-of-range refused); `--name host`
- [ ] T-R02F10-003 [P] Create `Packages/VisualCore/Sources/VisualCoreParameters/ColorVision.swift`
  (`ColorVisionCondition` normal/protanopia/deuteranopia/tritanopia/achromatopsia with the Machado 2009 severity-1.0
  matrices in linear sRGB, achromatopsia = Y on all channels, clamp 0…1; `PaletteSeparation.threshold = 0.08`,
  `issues(_:)` over all pairs and five conditions; `ColorVisionPresets.warmCool`/`redCyan`/`lightness` as `Palette`s
  with ids `cvd-warm-cool`, `cvd-red-cyan`, `cvd-lightness`, six stops each, built from OKLCh ladders) with
  `Packages/VisualCore/Tests/VisualCoreParametersTests/ColorVisionTests.swift` (rows sum to 1; greys unchanged within
  1e-12; spot values from the published matrices within 1e-6; every preset has no issue; a red–green pair is reported
  under protanopia and deuteranopia; each preset's stops contrast ≥ 3:1 with their outline); `--name host`

## Phase 3: Story 1 — readable without colour (P1) 🎯

- [ ] T-R02F10-004 [US1] Create `Packages/VisualCore/Sources/VisualCoreParameters/CodedState.swift` (`ClueShape` 8 cases
  Int 0…7, `CluePattern` 4 cases Int 0…3; `CodedState` id `^[a-z0-9-]{1,40}$`, colour sRGB 0…1, shape, pattern, name
  "1…40 characters after trimming", Codable schema 1; `CodedStateSet.maxStates = 32`, `init(_:) throws(ColorAccessError)`
  refusing repeated ids, repeated names, shared (shape, pattern) pairs, empty names, bad colours and more than 32;
  `separationIssues`; `ClueReference.distance/pattern/coverage` in −1…1 with coverage = 1 − smoothstep(−aa, aa, d)) with
  `Packages/VisualCore/Tests/VisualCoreParametersTests/CodedStateTests.swift` (at least five fixtures: empty set, one
  state, 32 distinct accepted; 33 refused; shared clue refused naming both; duplicate name and id refused; whitespace
  name refused; NaN colour refused; Codable round trip; shape distances negative at the centre and positive outside);
  `--name host`
- [ ] T-R02F10-005 [US1] Create `Packages/VisualCoreRendering/Sources/VisualCoreRendering/GLSL/vc/clue.glsl`
  (`vc_clueShape`, `vc_cluePattern`, `vc_clueCoverage`, `vc_clueOutline`, built on `vc/sdf.glsl`) with
  `Packages/VisualCoreRendering/Tests/VisualCoreRenderingTests/ClueShaderTests.swift` (every shape × pattern drawn to a
  64 × 64 target through `FullScreenShaderScene` matches `ClueReference.coverage` within 2/255 at every pixel; compiles
  alone and with the other includes; zero leaks); add `vc/clue.glsl` to the include list of
  `ShaderBundleTests.swift`

## Phase 4: Story 2 — colours stay apart (P1)

- [ ] T-R02F10-006 [US2] [US3] Create `Packages/VisualCoreRendering/Sources/VisualCoreRendering/GLSL/vc/spectral.glsl`
  (`vc_linearToOklab`, `vc_oklabToLinear`, `vc_hueRotate`, `vc_simulateCVD(vec3, int)`) with
  `Packages/VisualCoreRendering/Tests/VisualCoreRenderingTests/SpectralShaderTests.swift` (a 64 × 64 ramp through each
  function equals the CPU reference within 2/255 per channel; every condition; hue rotations 0, 90°, 360°; zero leaks);
  add `vc/spectral.glsl` to the include list of `ShaderBundleTests.swift`

## Phase 5: Stories 3–4 — contrast, preference and settings (P2)

- [ ] T-R02F10-007 [P] [US4] Edit `Packages/VisualCore/Sources/VisualCoreSimulation/AccessibilityPreferences.swift`
  (`ColorVisionChoice` standard/warmCool/redCyan/lightness with `init(storedValue:)` and `title`; `colorVision` field
  defaulting to `.standard`; memberwise init gains `colorVision: ColorVisionChoice = .standard`; hand-written
  `init(from:)` with `decodeIfPresent`, unknown → `.standard`; `colorVisionKey(prefix:)` = `<prefix>.colorVision`;
  `keys(prefix:)` unchanged; load/save extended) with
  `Packages/VisualCore/Tests/VisualCoreSimulationTests/ColorVisionPreferenceTests.swift` (JSON from before the feature
  decodes with old choices kept and `.standard`; unknown raw value → `.standard`; storage round trip; the existing
  `AccessibilityPreferencesTests` unchanged and passing); `--name host`
- [ ] T-R02F10-008 [US3] [US4] Create `Packages/VisualCoreRendering/Sources/VisualCoreUI/ClueBadge.swift` (`ClueBadge`
  drawing the shape, pattern and outline with SwiftUI `Path`/`Canvas` from `ClueReference`, `@ScaledMetric` size,
  wrapping name, accessibility label = name; `ColorVisionChoice.palette`) and edit `AccessibilitySettingsSection.swift`
  (a colour-vision picker with identifier `<prefix>.colorVision`; `AccessibleColors.contrastRatio` delegates to
  `PerceptualColor.contrastRatio` with unchanged results) with
  `Packages/VisualCoreRendering/Tests/VisualCoreUITests/ClueBadgeTests.swift` (label equals name; renders at the
  largest accessibility size in compact and regular widths without truncation via `ImageRenderer` size checks;
  `contrastRatio` gives the same values as before for the existing pairs; picker present)
- [ ] T-R02F10-009 Simulator runs: `--name rendering-27` and `--name rendering-26`

## Phase 6: Regression, documentation and close

- [ ] T-R02F10-010 No Stage One breakage: `--name experiences --` ExperiencesCreative on sim-27.2, and the app's
  settings tests (`--name app-settings --` the app test chunk that covers `SettingsView`)
- [ ] T-R02F10-011 API baseline and docs: `check_public_api.py --update`, `--name public-api`, `--name documented-api
  -- python3 scripts/check_documented_api.py --sources Apps/VisualCore`; new `docs/architecture/color-accessibility.md`
  (OKLab and Machado sources with licences, threshold, presets, clue set, reason codes); sections in
  `Packages/VisualCore/README.md` and `Packages/VisualCoreRendering/README.md`; section 13.4 row R02-F10 "As built"
  (home corrected: `AccessibilityPreferences` is in VisualCoreSimulation) in `docs/catalog/shared-feature-map.json` and
  `render_autocreator.py`; copyright scan: no image, font or icon file added (`git diff --stat` of the feature)
- [ ] T-R02F10-012 Reference regression chunk 1 (`--name reference-1`)
- [ ] T-R02F10-013 Reference regression chunk 2 (`--name reference-2`)
- [ ] T-R02F10-014 Script tests (`--name script-tests`)
- [ ] T-R02F10-015 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record

## Device campaign (after ImplementationLock-100)

- [ ] T-R02F10-016 {device} View the three presets and the clue badges on D1–D3 in light and dark mode and record the
  rows in the device campaign; never before `guard-device` passes

## Dependencies and parallel work

001 → (002 ∥ 003 ∥ 007) → 004 → (005 ∥ 006) → 008 → 009 → 010 → 011 → 012 → 013 → 014 → 015. Agents: C (002, 003), P
(007), S (004 after 002), G (005, 006 after 003 and 004), U (008 after 004 and 007). Shared files (READMEs, API
baseline, `ShaderBundleTests.swift` list, feature map) stay with the lead. MVP: Story 1 (002, 004, 005).
