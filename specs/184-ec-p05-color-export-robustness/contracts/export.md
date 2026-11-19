# Contract: still export (G-EXPORT)

- `StillExport.validate(width:height:format:maxTextureSize:available:) -> ExportRefusal?` (pure; `available`
  defaults to `StillImageEncoder.isAvailable`).
- `PreviewRenderer.exportPicture(_ chain:) throws(ExportRefusal) -> RGBAImage`: draws the plan into a fresh `.rgba8`
  target of the source's size, runs `beforeReadBack`, reads back; an empty or short read-back is `.interrupted`; a
  pool or registry refusal is `.memory`; the target is released in every case.
- `StillExport.write(_ picture:, format:, in folder:) async throws(ExportRefusal) -> EffectsExportFile`: encodes at
  quality 0.9 off the main actor and writes atomically; an encoder failure is `.formatUnavailable`.
- `ComposerPresenter.export(format:) async`: refuses before drawing; status "Exporting…", then "Exported" or the
  refusal's message; removes the earlier file first; ignores a call while exporting; `exportFile` is the share item.
- Controls: `export-png`, `export-jpeg`, `export-heic` ("Export as PNG" …), and `share` (`ShareLink`, "Share the
  exported picture") while a file exists.
- Tests: each format writes a decodable file of the source size tagged sRGB; the PNG equals the preview read-back
  within 1/255 everywhere (regression fixture, 96 × 64 gradient, chain grade, blur, vignette); JPEG and HEIC within a
  mean of 3/255; an unavailable format and a too-large size are refused with no draw (render count unchanged) and no
  file; a second export removes the first file; a second call while exporting is ignored.
