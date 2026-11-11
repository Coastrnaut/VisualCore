# Data Model: Fluid Art Playground — Phase 04

## FluidPalette (app Core)

| Field | Type | Notes |
|---|---|---|
| id | String | `ink`, `smoke`, `glow` |
| name | String | "Ink", "Smoke", "Glowing dye" |
| mode | DisplayMode | `.ink`, `.smoke`, `.glow` (shader `uMode` 0/1/2) |
| background | SIMD3<Float> | ink paper (0.96, 0.94, 0.88); smoke (0.04, 0.04, 0.05); glow (0, 0, 0) |
| splatColors | [SIMD3<Float>] | exactly 6, each channel 0…1 |
| glow | Bool | true only for glow |

`FluidPalette.all`, `FluidPalette.named(_ id:)` (unknown ids fall back to glow), and
`displayColor(dye:)` (a CPU reference of the display shader).

## FluidConfiguration addition

`paletteID: String = "glow"`; validated, so an unknown id becomes `"glow"` and is reported.

## Capture

`CaptureModel { state: idle/working/done(URL)/failed(String), lastURL }`.

## FieldPass.Run (VisualCoreRendering)

`label: String`, `output: UInt32` (a color texture name, or a framebuffer name for screen output),
`inputs: [String: UInt32]` (color texture names).
