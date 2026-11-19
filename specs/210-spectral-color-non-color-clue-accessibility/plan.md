# Implementation Plan: R02-F10 — Spectral color & non-color clue accessibility

**Branch**: `210-spectral-color-non-color-clue-accessibility` (spec directory only; work on `main`) | **Date**:
2026-11-19 | **Spec**: [spec.md](spec.md)

## Summary

Pure colour science beside `Palette` in VisualCoreParameters (OKLab/OKLCh, luminance, contrast, hue rotation with chroma
bisection, Machado 2009 deficiency simulation, a ΔE_OK ≥ 0.08 palette check, three code-built presets) and coded
states with a non-colour clue (8 shapes × 4 patterns, a name, a set validator with `r2-f10.*` reason codes). Two shader
includes on the existing library (`vc/spectral.glsl`, `vc/clue.glsl` built on `vc/sdf.glsl`) matching the CPU within
2/255. A colour-vision choice added to `AccessibilityPreferences` with a backward-compatible decoder and its own key,
shown by `AccessibilitySettingsSection`, and a SwiftUI clue badge in VisualCoreUI. Research: [research.md](research.md).
Data: [data-model.md](data-model.md). API: [contracts/api.md](contracts/api.md). Quickstart: [quickstart.md](quickstart.md).

## Technical Context

**Language/Version**: Swift 6, GLSL ES 3.00, SwiftUI. **Primary dependencies**: VisualCoreParameters (`Palette`, no
dependencies), VisualCoreSimulation (`AccessibilityPreferences`, `AccessibilityChoice`), VisualCoreRendering
(`ShaderBundle.visualCoreLibrary`, `FullScreenShaderScene`/`FieldPass`, `RenderHost`), VisualCoreUI
(`AccessibilitySettingsSection`, `AccessibleColors`). No new module dependency; no Objective-C++ bridge (no new GL call).
**Seeds**: fixtures use `SeededRandom` from VisualCoreSimulation in tests only (seed 2_010), never in the pure model.
**Testing**: `swift test --package-path Packages/VisualCore` (colour science, presets, coded states, preferences);
VisualCoreRendering on sim-27.2 and sim-26.5 (shader parity, clue drawing, settings section); ExperiencesCreative on
sim-27.2; reference regression in two chunks; script tests.
**Performance**: bounded by arithmetic — a conversion is two 3 × 3 products and three cube roots; a palette check of 8
colours is 28 pairs × 5 conditions; the gamut bisection 24 steps; shader parity draws 64 × 64 targets; each test < 10 s.
**Shader limits**: no loops beyond fixed bounds; highp floats; all functions prefixed `vc_`.
**Constraints**: additive; existing palettes, sRGB functions, state signs, preferences, the two-key `keys(prefix:)` and
all their tests unchanged.

No NEEDS CLARIFICATION remains.

## Constitution Check

| Principle | Result |
|---|---|
| I Proven renderer only | PASS — includes for the existing shader library; no new context or GL path. |
| II App-neutral API · II-a reference | PASS — generic colour and clue API; `///`; API baseline; reference regression. |
| III GPU lifecycle | PASS — no new GPU object type; tests draw through `RenderHost` and check zero leaks. |
| IV Host-testable | PASS — all colour science and validation pure and host-tested. |
| VIII Accessibility | PASS — non-colour clue per coded state; names read by VoiceOver; colour-vision setting. |
| IX Bounded input | PASS — finite 0…1 components; ≤ 32 states; names 1…40 characters. |
| X Persistence compatibility | PASS — old preference files decode with defaults; unknown values become `standard`. |
| XIII Code-only visuals | PASS — shapes and patterns are signed distances; presets constructed in code. |

Post-design re-check: PASS.

## Project Structure

```text
Packages/VisualCore/Sources/VisualCoreParameters/PerceptualColor.swift        new  PerceptualColor (OKLab/OKLCh, luminance, contrast, hue, gamut)
Packages/VisualCore/Sources/VisualCoreParameters/ColorVision.swift            new  ColorVisionCondition, simulate, PaletteSeparation, ColorVisionPresets
Packages/VisualCore/Sources/VisualCoreParameters/CodedState.swift             new  ClueShape, CluePattern, CodedState, CodedStateSet, ClueReference
Packages/VisualCore/Sources/VisualCoreParameters/ColorAccessError.swift       new  ColorAccessError + reasonCode
Packages/VisualCore/Tests/VisualCoreParametersTests/PerceptualColorTests.swift, ColorVisionTests.swift, CodedStateTests.swift   new
Packages/VisualCore/Sources/VisualCoreSimulation/AccessibilityPreferences.swift   edit  ColorVisionChoice, colorVision field, decoder, colorVisionKey, load/save
Packages/VisualCore/Tests/VisualCoreSimulationTests/ColorVisionPreferenceTests.swift   new
Packages/VisualCoreRendering/Sources/VisualCoreRendering/GLSL/vc/spectral.glsl   new  vc_linearToOklab, vc_oklabToLinear, vc_hueRotate, vc_simulateCVD
Packages/VisualCoreRendering/Sources/VisualCoreRendering/GLSL/vc/clue.glsl       new  vc_clueShape, vc_cluePattern, vc_clueCoverage
Packages/VisualCoreRendering/Tests/VisualCoreRenderingTests/SpectralShaderTests.swift, ClueShaderTests.swift   new
Packages/VisualCoreRendering/Sources/VisualCoreUI/ClueBadge.swift              new  ClueBadge view, ColorVisionChoice → preset mapping
Packages/VisualCoreRendering/Sources/VisualCoreUI/AccessibilitySettingsSection.swift   edit  colour-vision picker; AccessibleColors.contrastRatio delegates to PerceptualColor
Packages/VisualCoreRendering/Tests/VisualCoreUITests/ClueBadgeTests.swift       new
docs/architecture/color-accessibility.md (new), docs/api/visualcore-public-api.txt, package READMEs, docs/catalog/shared-feature-map.json (lead)
```

**Migration**: stored preferences gain `<prefix>.colorVision`; absent → `standard` (no rewrite of old data). **Rollback**:
revert the commits; an app that stored `colorVision` ignores the extra key after a rollback.

## Parallel work

Agent C: PerceptualColor, ColorVision and their tests. Agent S: CodedState, ColorAccessError and tests. Agent P: the
preference change and its tests. Agent G (after C and S): the two shader includes and their parity tests. Agent U (after
P): ClueBadge, the settings picker and UI tests. Lead: docs, API baseline, runs, commits.
