# Research: A16-P03 (feature 119)

- **D1 Wave on the GPU** (Q1): one RGBA16F pair, (uⁿ, uⁿ⁻¹) in (red, green). The step writes (uⁿ⁺¹, uⁿ), so one pass
  per step and no third target; the border is zero by cell index. *Alternative:* three single-channel targets (rejected:
  more passes, and the pair already exists).
- **D2 Tolerance** (Q2): 16 × 16, 10 steps, ≤ 0.01 against the `float16` and `float16TowardZero` references, as in
  A16-P02. The wave edge test runs 100 steps.
- **D3 Reload** (Q3): load from the CPU after 64 GPU steps. Ten steps measured at ≤ 0.0032 (A16-P02), so the drift
  arithmetic stays under the tolerance with margin. *Alternative:* never reload (rejected: unbounded drift).
- **D4 Time step** (Q4): `sim.timestep` declared 0.05…2.0, so values beyond the limits reach the core and get their
  sentences; the existing `SimulationSpec.refusal()` gives the words.
- **D5 Legend and probe** (Q5): the canvas overlay draws the legend; the probe runs per context generation (cached by
  VisualCore). The no-support refusal is in the presenter, because the deterministic core does not know the device.
- **D6 Display on the GPU:** the float fields are coloured in GLSL with the palette stops as uniforms, rounded to bytes
  in the shader. The CPU palette stays the reference (±1 per channel).
