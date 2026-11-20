# Tasks: R02-F10 — Spectral color & non-color clue accessibility

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate R02-F10 (migration ledger). Evidence:
`python3 scripts/migration_ledger.py run-check --gate R02-F10 --name <check> -- <command>`. Commit after every task
(no trailers). No {owner} tasks. Every new public type name was checked against Packages and Apps for collisions
(the R02-F09 lesson). Fixture seed 2_010 (`SeededRandom`, tests only).

## Phase 1: Setup

- [X] T-R02F10-001 Baselines: `--name baseline-host -- swift test --package-path Packages/VisualCore` and — Verified 2026-11-19: 2026-11-19 .autonomy/migration/checks/R02-F10.baseline-host.json (exit 0, clean worktree of 19e37dae); rendering baseline = R02-F09.rendering-27-3.json (exit 0, 220 tests) at 9adce491, package sources unchanged since (no baseline rerun on an unchanged commit); the worktree attempt R02-F10.baseline-rendering exit 74 lacked the ANGLE binaries
  `--name baseline-rendering --` the VisualCoreRendering scheme on sim-27.2

## Phase 2: Foundational (pure colour science)

- [X] T-R02F10-002 [P] Create `Packages/VisualCore/Sources/VisualCoreParameters/ColorAccessError.swift` — Verified 2026-11-19: 2026-11-19 .autonomy/migration/checks/R02-F10.host.json (exit 0; PerceptualColorTests 9 passed, 0 failures in the run)
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
- [X] T-R02F10-003 [P] Create `Packages/VisualCore/Sources/VisualCoreParameters/ColorVision.swift` — Verified 2026-11-19: 2026-11-19 R02-F10.host.json (exit 0; ColorVisionTests 5 passed; grey error 4.4e-7 < 1e-6, research R13; presets have no separation issue)
  (`ColorVisionCondition` normal/protanopia/deuteranopia/tritanopia/achromatopsia with the Machado 2009 severity-1.0
  matrices in linear sRGB, achromatopsia = Y on all channels, clamp 0…1; `PaletteSeparation.threshold = 0.08`,
  `issues(_:)` over all pairs and five conditions; `ColorVisionPresets.warmCool`/`redCyan`/`lightness` as `Palette`s
  with ids `cvd-warm-cool`, `cvd-red-cyan`, `cvd-lightness`, six stops each, built from OKLCh ladders) with
  `Packages/VisualCore/Tests/VisualCoreParametersTests/ColorVisionTests.swift` (rows sum to 1; greys unchanged within
  1e-12; spot values from the published matrices within 1e-6; every preset has no issue; a red–green pair is reported
  under protanopia and deuteranopia; each preset's stops contrast ≥ 3:1 with their outline); `--name host`

## Phase 3: Story 1 — readable without colour (P1) 🎯

- [X] T-R02F10-004 [US1] Create `Packages/VisualCore/Sources/VisualCoreParameters/CodedState.swift` (`ClueShape` 8 cases — Verified 2026-11-19: 2026-11-19 R02-F10.host.json (exit 0; CodedStateTests 10 passed: empty/one/32 accepted, 33, shared clue, duplicates, blank/long names, NaN/out-of-range, Codable, shapes and patterns)
  Int 0…7, `CluePattern` 4 cases Int 0…3; `CodedState` id `^[a-z0-9-]{1,40}$`, colour sRGB 0…1, shape, pattern, name
  "1…40 characters after trimming", Codable schema 1; `CodedStateSet.maxStates = 32`, `init(_:) throws(ColorAccessError)`
  refusing repeated ids, repeated names, shared (shape, pattern) pairs, empty names, bad colours and more than 32;
  `separationIssues`; `ClueReference.distance/pattern/coverage` in −1…1 with coverage = 1 − smoothstep(−aa, aa, d)) with
  `Packages/VisualCore/Tests/VisualCoreParametersTests/CodedStateTests.swift` (at least five fixtures: empty set, one
  state, 32 distinct accepted; 33 refused; shared clue refused naming both; duplicate name and id refused; whitespace
  name refused; NaN colour refused; Codable round trip; shape distances negative at the centre and positive outside);
  `--name host`
- [X] T-R02F10-005 [US1] Create `Packages/VisualCoreRendering/Sources/VisualCoreRendering/GLSL/vc/clue.glsl` — Verified 2026-11-19: lead retest 2026-11-19: R02-F10/rendering-27 exit=0 (225 tests) incl. ClueShaderTests 2 passed (32 shape x pattern and 8 outlines, max 0/255); ShaderBundleTests with vc/clue.glsl passed
  (`vc_clueShape`, `vc_cluePattern`, `vc_clueCoverage`, `vc_clueOutline`, built on `vc/sdf.glsl`) with
  `Packages/VisualCoreRendering/Tests/VisualCoreRenderingTests/ClueShaderTests.swift` (every shape × pattern drawn to a
  64 × 64 target through `FullScreenShaderScene` matches `ClueReference.coverage` within 2/255 at every pixel; compiles
  alone and with the other includes; zero leaks); add `vc/clue.glsl` to the include list of
  `ShaderBundleTests.swift`

## Phase 4: Story 2 — colours stay apart (P1)

- [X] T-R02F10-006 [US2] [US3] Create `Packages/VisualCoreRendering/Sources/VisualCoreRendering/GLSL/vc/spectral.glsl` — Verified 2026-11-19: lead retest 2026-11-19: R02-F10/rendering-27 exit=0 incl. SpectralShaderTests 3 passed (OKLab forward 1/255, round trip, hue 0/π/2/2π and all five conditions 0/255)
  (`vc_linearToOklab`, `vc_oklabToLinear`, `vc_hueRotate`, `vc_simulateCVD(vec3, int)`) with
  `Packages/VisualCoreRendering/Tests/VisualCoreRenderingTests/SpectralShaderTests.swift` (a 64 × 64 ramp through each
  function equals the CPU reference within 2/255 per channel; every condition; hue rotations 0, 90°, 360°; zero leaks);
  add `vc/spectral.glsl` to the include list of `ShaderBundleTests.swift`

## Phase 5: Stories 3–4 — contrast, preference and settings (P2)

- [X] T-R02F10-007 [P] [US4] Edit `Packages/VisualCore/Sources/VisualCoreSimulation/AccessibilityPreferences.swift` — Verified 2026-11-19: 2026-11-19 R02-F10.host.json (exit 0; ColorVisionPreferenceTests 5 passed; AccessibilityPreferencesTests unchanged and passing)
  (`ColorVisionChoice` standard/warmCool/redCyan/lightness with `init(storedValue:)` and `title`; `colorVision` field
  defaulting to `.standard`; memberwise init gains `colorVision: ColorVisionChoice = .standard`; hand-written
  `init(from:)` with `decodeIfPresent`, unknown → `.standard`; `colorVisionKey(prefix:)` = `<prefix>.colorVision`;
  `keys(prefix:)` unchanged; load/save extended) with
  `Packages/VisualCore/Tests/VisualCoreSimulationTests/ColorVisionPreferenceTests.swift` (JSON from before the feature
  decodes with old choices kept and `.standard`; unknown raw value → `.standard`; storage round trip; the existing
  `AccessibilityPreferencesTests` unchanged and passing; SC-R02F10-005); `--name host`
- [X] T-R02F10-008 [US3] [US4] Create `Packages/VisualCoreRendering/Sources/VisualCoreUI/ClueBadge.swift` (`ClueBadge` — Verified 2026-11-19: lead retest 2026-11-19: R02-F10/rendering-27 and rendering-26 exit=0 incl. ClueBadgeTests 6 passed and AccessibilitySettingsSectionTests; host-2 exit=0 incl. ShellColorVisionTests; app-settings-2 exit=0 (app build, unit, UI chunk b incl. the new colour-vision relaunch test; first attempt app-settings exit 1: the quality row moved below the fold on iPhone 13 mini, fixed by scrolling)
  drawing the shape, pattern and outline with SwiftUI `Path`/`Canvas` from `ClueReference`, `@ScaledMetric` size,
  wrapping name, accessibility label = name; `ColorVisionChoice.palette`) and edit `AccessibilitySettingsSection.swift`
  (a colour-vision picker with identifier `<prefix>.colorVision`; `AccessibleColors.contrastRatio` delegates to
  `PerceptualColor.contrastRatio` with unchanged results) with
  the app wiring (research R12): `ShellPreferences.colorVision: ColorVisionChoice?` in
  `Packages/VisualCore/Sources/VisualCoreExperience/ShellModel.swift` (optional, `decodeIfPresent`, schema stays 1, as
  the haptics switch), `AppModel.setAccessibility` gains `colorVision`, `SettingsView`'s binding carries it,
  `ExperienceLaunch.colorVision` hands it to experiences, with a ShellModel test that schema-1 JSON without the key
  decodes as nil (`standard`) and a round trip;
  `Packages/VisualCoreRendering/Tests/VisualCoreUITests/ClueBadgeTests.swift` (label equals name; renders at the
  largest accessibility size in compact and regular widths without truncation via `ImageRenderer` size checks;
  `contrastRatio` gives the same values as before for the existing pairs; picker present)
- [X] T-R02F10-009 Simulator runs: `--name rendering-27` and `--name rendering-26` — Verified 2026-11-19: 2026-11-19 R02-F10.rendering-27.json and R02-F10.rendering-26.json (exit 0, 225 tests, 0 failures each)

## Phase 6: Regression, documentation and close

- [X] T-R02F10-010 No Stage One breakage: `--name experiences --` ExperiencesCreative on sim-27.2, and the app's — Verified 2026-11-19: 2026-11-19 R02-F10.experiences.json (exit 0) and R02-F10.app-settings-2.json (exit 0)
  settings tests (`--name app-settings -- python3 scripts/release_check.py --only app-build-for-testing-ios27
  app-unit-ios27 app-ui-ios27-b`, as R02-F26)
- [X] T-R02F10-011 API baseline and docs: `check_public_api.py --update`, `--name public-api`, `--name documented-api — Verified 2026-11-19: 2026-11-19 R02-F10.public-api.json and R02-F10.documented-api.json (exit 0; 3295 declarations, 0 undocumented); docs/architecture/color-accessibility.md with sources and licences; READMEs and section 13.4 note rendered; validate_autocreator PASS; no image/font/icon file in the feature's diff
  -- python3 scripts/check_documented_api.py --sources Apps/VisualCore`; new `docs/architecture/color-accessibility.md`
  (OKLab and Machado sources with licences, threshold, presets, clue set, reason codes); sections in
  `Packages/VisualCore/README.md` and `Packages/VisualCoreRendering/README.md`; section 13.4 row R02-F10 "As built"
  (home corrected: `AccessibilityPreferences` is in VisualCoreSimulation) in `docs/catalog/shared-feature-map.json` and
  `render_autocreator.py`; copyright scan: no image, font or icon file added (`git diff --stat` of the feature)
- [X] T-R02F10-012 Reference regression chunk 1 (`--name reference-1`) — Verified 2026-11-19: 2026-11-19 .autonomy/migration/checks/R02-F10.reference-1.json (exit 0)
- [X] T-R02F10-013 Reference regression chunk 2 (`--name reference-2`) — Verified 2026-11-19: 2026-11-19 .autonomy/migration/checks/R02-F10.reference-2.json (exit 0)
- [X] T-R02F10-014 Script tests (`--name script-tests`) — Verified 2026-11-19: 2026-11-19 R02-F10.script-tests-2.json (exit 0) after the module-import check learned scoped imports (first attempt R02-F10.script-tests exit 1: ShellModel's import enum VisualCoreSimulation.ColorVisionChoice read as module enum)
- [ ] T-R02F10-015 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record

## Device campaign (after ImplementationLock-100)

- [ ] T-R02F10-016 {device} View the three presets and the clue badges on D1–D3 in light and dark mode and record the
  rows in the device campaign; never before `guard-device` passes

## Dependencies and parallel work

001 → (002 ∥ 003 ∥ 007) → 004 → (005 ∥ 006) → 008 → 009 → 010 → 011 → 012 → 013 → 014 → 015. Agents: C (002, 003), P
(007), S (004 after 002), G (005, 006 after 003 and 004), U (008 after 004 and 007). Shared files (READMEs, API
baseline, `ShaderBundleTests.swift` list, feature map) stay with the lead. MVP: Story 1 (002, 004, 005).

## Phase 7: Convergence

- [X] T-R02F10-017 Make the clue outline meet 3:1 against both the state colour and the background per FR-R02F10-013 — Verified 2026-11-19: 2026-11-19 R02-F10.host-3.json (exit 0; outlineRingsReachThreeToOneEverywhere: worst inner 4.587, worst outermost 21.0 over 729 colours x 2 backgrounds) and R02-F10.rendering-27-2.json (exit 0; ClueBadgeTests.testALightColourOnDarkGetsAnOuterRing passed); public-api-2 and documented-api-2 exit 0
  (partial): add `PerceptualColor.outlineRings(for:on:) -> (inner: SIMD3<Double>, outer: SIMD3<Double>?)` in
  `Packages/VisualCore/Sources/VisualCoreParameters/PerceptualColor.swift` (inner = black or white with the larger
  contrast to the colour, always ≥ √21 ≈ 4.58; outer = the opposite of the background when inner < 3:1 against it, else
  nil), draw both rings in `Packages/VisualCoreRendering/Sources/VisualCoreUI/ClueBadge.swift`, and test in
  `PerceptualColorTests.swift` over a 9 × 9 × 9 sRGB sweep on black and white backgrounds that the inner ring is ≥ 3:1
  to the colour and the outermost ring ≥ 3:1 to the background; `--name host-3` and `--name rendering-27-2`
