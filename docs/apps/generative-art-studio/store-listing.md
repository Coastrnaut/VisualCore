# Generative Art Studio — store listing draft

Draft for the owner. The name, subtitle and keywords are placeholders until the owner chooses store branding (the
bundle ID `dev.visualcore.GenerativeArtStudio` is the approved placeholder). Every claim below maps to a passing
test. A claim that cannot be traced is removed, not softened.

**Name:** Generative Art Studio
**Subtitle:** Seeded art you can tune and keep

**Description:**

> Make generative art from four families: flowing gradient noise, raymarched 3D shapes, geometric tilings and a
> particle fountain. Pick a preset, change the palette, shuffle the seed and tune each parameter with live preview.
> The same seed always makes the same picture.
>
> Pause, scrub and replay time. Save compositions to your library, mark favorites, duplicate and rename them. Export
> stills up to 4096 pixels in square, portrait, landscape or story shapes, then share or save them.
>
> Reduce Motion and Reduce Flashing follow your device settings or your own choice, and the app works with VoiceOver
> and large text. Everything stays on your device: no account, no tracking, no network.

## Claim traceability

| Claim | Test |
|---|---|
| Four families (gradient noise, raymarched shapes, geometric tiling, particles) | `RenderDeterminismTests.testEveryFamilyRendersNonBlank`; `GalleryUITests.testGalleryListsFourFamiliesAndEachOpensACanvas`; `FamilyDistinctnessTests` |
| Presets, palette, seed, parameter tuning with live preview | `ControlsUITests.testPresetPaletteSeedAndParameters`; `ControlsRenderTests` |
| Same seed → same picture | `RenderDeterminismTests.testSameDocumentAndRoundTripRenderIdenticallyWithinTolerance` |
| Pause, scrub, replay time | `ControlsUITests.testTimeControls`; `SceneClock` tests (VisualCoreSimulation) |
| Library: save, favorites, duplicate, rename | `LibraryUITests.testSaveReopenAndOrganize`; `CompositionLibraryTests` |
| Export up to 4096 px in 4 shapes; share or save | `ExportRenderTests.testTwelveCombinationsHaveExactDimensionsNoAlphaAndSRGB`; `ExportUITests.testExportSheetFlow` |
| Reduce Motion / Reduce Flashing follow device or own choice | `AccessibilityApplyTests`; `SettingsUITests.testChoicesPersistAndFooterExplainsOverride`; `AccessibilityPreferencesTests` |
| Works with VoiceOver and large text | `AccessibilityAuditUITests` (both text sizes, 7 screens); `testCanvasDescriptionFollowsEdits` |
| On device only; no account, tracking or network | `check_privacy_manifest.py` (Data Not Collected); `check_compliance.py` (no networking APIs) |

**Removed:** performance and device-compatibility wording (no device evidence before campaign II), and any "quality
settings" (not built).
