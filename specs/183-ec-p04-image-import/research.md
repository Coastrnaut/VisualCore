# Research: A25-P04 (feature 183)

- **R1 Upload bytes into a target.** Decision: add `RenderTarget.upload(rgba:)`. Rationale: four floats per pixel would
  quadruple memory (A25-P00 Q2). Alternative: `Texture` input to `FieldPass` (rejected: a larger API change).
- **R2 ImageIO thumbnail with transform.** Decision: one call applies orientation and scaling. Rationale: public, tested
  by Apple, no manual EXIF handling. Alternative: UIImage drawing (rejected: main-thread UIKit in the decode path).
- **R3 sRGB at decode.** Decision: draw into an sRGB context. Rationale: one colour space before the passes; linear light
  is A25-P05's colour work.
- **R4 Generated fixtures.** Decision: write test pictures with ImageIO in the tests. Rationale: no bundled photograph.
