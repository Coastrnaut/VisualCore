# Research: A21-P01 (feature 152)

- **D1 One shader, three layers:** stars, clouds and ribbons are composited in one fragment pass. Rationale: the
  cheapest 2D form (manual risk 1) and one reference to compare. Alternative: three passes with additive blending into
  a render target; rejected for 0.1 (more GPU work, and the cap of A21-P02 needs one composite anyway).
- **D2 CPU reference by port:** the integer PCG hashes and polynomial noise of `vc/` port exactly to Swift `Float`.
  Alternative: `FractalNoise2D`; rejected, its hash differs from the GLSL one.
- **D3 Seamless loop:** the phase moves the noise sample along a circle, so a 600 s loop has no visible seam.
  Alternative: an unbounded time; rejected, a float time loses precision after hours.
- **D4 Reduced motion holds time:** the clock does not advance; `SceneClock`'s half speed is motion, not stillness.
- **D5 Refuse on decode, clamp on set:** a file out of range is suspicious and refused; a control value is clamped.
