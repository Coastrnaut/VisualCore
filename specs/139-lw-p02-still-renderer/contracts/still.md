# Contract: VisualCore still additions (A19-P02)

- `StillImageEncoder.data(image, format: .png)` is byte-identical to `pngData(image)`.
- For each format with `isAvailable` true, the written data reads back at the image's width and height, with the
  colour space `kCGColorSpaceSRGB` and the format's type identifier. PNG pixels are equal; JPEG and HEIC pixels are
  within 8 per channel for a flat colour.
- An unavailable format throws `.encoding` and does no work.
- `renderStill(width:height:time:)` at times t1 ≠ t2 differs for a time-dependent scene, and is identical for the
  same t. The two-argument form equals time 0.
- The live frame and the registry's live counts are unchanged after a timed still (as for `renderOffscreen`).
