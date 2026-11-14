# Research: A06-P02

- **D1 Allocation-free analysis.** Decision: `FeatureExtractor` (final class, render-thread only) owns window, FFT input,
  split-complex, power and band buffers, created once; `SpectrumAnalyzer.powerSpectrum(_:into:workspace:)` writes linear
  power into caller memory using a `SpectrumWorkspace`. Rationale: the existing `magnitudesDB(_:)` allocates four arrays
  per call (checked). Alternatives: reuse `magnitudesDB` and convert (allocates); global scratch (not thread-safe).
- **D2 Power scale.** Decision: power[k] = (|X[k]| · scale)², with A06-P01's scale, so a full-scale bin-centred sine
  gives ≈ 1 and 10·log10(power) equals `magnitudesDB`. Rationale: one consistent scale; band sums are plain sums.
- **D3 Band layout.** Decision: 16 edges log-spaced 40 Hz…min(16 kHz, fs/2); bin k (1…N/2−1) belongs to the band whose
  [low, high) holds k·fs/N; a band narrower than one bin is widened to take the next unused bin so every band has ≥ 1
  bin and ranges stay contiguous and increasing. Rationale: at N = 1,024, fs = 48 kHz the bin width (46.9 Hz) exceeds the
  lowest bands. Alternative: mel bands (more code, no need now).
- **D4 Flux and onset.** Decision: flux = Σ max(0, E_b − E_b,prev); threshold = 1.5 · mean(previous 43 fluxes) + 1e-4;
  minimum interval 0.1 s by timestamps; history in a fixed ring. Rationale: standard adaptive-threshold onset detection,
  deterministic and cheap. Alternative: per-band peak picking (overkill for the slice).
- **D5 Smoother.** Decision: one-pole, coefficient 1 − exp(−Δt/τ) with τ = attack when rising, release when falling;
  beat energy = smoother(attack 0.01, release 0.25) over the onset pulse. Rationale: frame-rate independent (SC-A06-204).
- **D6 Display mapping.** Decision: `AnalysisDisplay` (Core) maps dB in [−80, 0] linearly to [0, 1] (clamped) for bars
  and the level meter; beat energy is drawn as is. Rationale: GPU-free and host-testable; −80 dB is below the demo noise.
- **D7 Layout.** Decision: waveform keeps the upper band (10 %…50 % of the height), bars occupy 58 %…90 %, the level and
  beat meters are two narrow columns at the right edge; the A06-P01 background probe (top-left corner) stays valid.
