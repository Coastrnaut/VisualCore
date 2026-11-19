# Research: R02-F10

- **R1 Perceptual space.** Decision: OKLab/OKLCh (Ottosson 2020) from linear sRGB with the published M1/M2 matrices.
  Rationale: near-uniform hue, cheap, same code on CPU and GPU. Alternatives: CIELAB + CIEDE2000 (costly), HSL/HSV (not
  perceptual).
- **R2 Deficiency model.** Decision: Machado, Oliveira, Fernandes (2009), severity 1.0 matrices for protanopia,
  deuteranopia, tritanopia in linear sRGB; achromatopsia → Rec. 709 luminance on all channels; clamp 0…1. Rationale:
  single matrix per condition, rows sum to 1 (greys kept). Alternatives: Brettel–Viénot 1997/1999 (branching),
  Coblis-style LMS daltonisation (no single published matrix).
- **R3 Separation threshold.** Decision: ΔE_OK ≥ 0.08 in all five conditions. Rationale: about four times the OKLab
  just-noticeable difference, suitable for small marks. Alternatives: 0.05 (too close under achromatopsia), 0.10 (six
  colours no longer fit a lightness ladder in sRGB).
- **R4 Presets.** Decision: three six-colour presets built in code from OKLCh ladders (lightness 0.35…0.95 in steps of at
  least 0.10, hues on the blue–orange, red–cyan and neutral axes) and pinned as sRGB stops after a passing check.
  Rationale: original, provable, deterministic. Alternatives: copying a published palette (originality rule).
- **R5 Gamut rule.** Decision: bisect chroma at constant L and h for 24 steps, keep the largest in-gamut chroma.
  Rationale: keeps lightness and hue, deterministic, error < 2⁻²⁴ of the start chroma. Alternatives: per-channel clip
  (shifts hue and lightness).
- **R6 Clues.** Decision: 8 shapes from `vc/sdf.glsl` primitives and folds (circle, square, triangle, diamond, hexagon,
  plus, ring, star) and 4 patterns (solid, stripes at 45°, dots, crosshatch) inside the shape, unit cell −1…1, coverage
  = 1 − smoothstep(−aa, aa, d) with aa = 1.5 / size in pixels; CPU reference is the same signed distance in Double.
  Rationale: closed, learnable, drawable in code. Alternatives: emoji or glyph fonts (assets, platform-dependent).
- **R7 Preference storage.** Decision: `ColorVisionChoice` in VisualCoreSimulation, hand-written `init(from:)` with
  `decodeIfPresent`, new key `<prefix>.colorVision`, `keys(prefix:)` unchanged. Rationale: source and data compatible.
  Alternatives: a third tuple element (breaks callers), storing in VisualCoreParameters (Simulation cannot see it).
- **R8 Contrast.** Decision: `PerceptualColor.contrastRatio(_:_:)` on sRGB triples per WCAG 2.x; `AccessibleColors`
  keeps its signature and converts its `UIColor`s to call it. Rationale: one formula. Alternatives: two copies.
