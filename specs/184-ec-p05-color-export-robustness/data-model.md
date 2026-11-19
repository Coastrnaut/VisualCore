# Data Model: Effects Composer — Phase 05

## ColorDomain (core)
- `enum ColorDomain { case linear, stored }`; `EffectID.colorDomain`: grade, blur, vignette → `.linear`; distort,
  posterize → `.stored`. Fixed per effect; not persisted (the chain document stays schema 1).

## StoragePrecision of the reference (core)
- `enum ReferenceStorage { case byte, half }`: how `EffectReference` stores values between nodes.

## ExportRequest (experience)
- `format: StillImageFormat` (png, jpeg, heic); `quality: Double = 0.9`; size = the source's width × height.
- Valid when `StillImageEncoder.isAvailable(format)` and the long edge ≤ `ExportGeometry(maxEdge: min(maxTextureSize,
  2048)).effectiveMaxEdge` and width × height ≤ its `maxPixels`.

## ExportRefusal (experience)
| Case | Code | Message |
|---|---|---|
| formatUnavailable | `a25.export-format-unavailable` | This format cannot be written here. |
| tooLarge | `a25.export-too-large` | This picture is too large to export. |
| memory | `a25.export-memory` | There is not enough memory to export this picture. |
| interrupted | `a25.export-interrupted` | The export was interrupted. Try again. |

## EffectsExportFile (experience)
- `url: URL` (`tmp/EffectsComposer/Look <W>x<H>.<ext>`), `format`; `Transferable` with a `FileRepresentation` of the
  format's content type.

## Export state (presenter)
`idle → exporting → exported(file) | refused(ExportRefusal)`; `exporting` ignores a second request; a new export or
closing the experience removes the earlier file.
