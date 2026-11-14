# Research: A08-P01 (feature 061)

## 0. Verified facts (2026-11-14)

- `SampleRingBuffer`: single-writer, lock-free, `latest(_:into:)` and `totalWritten`; capacity 1,024…262,144, power
  of two. `DemoSignal`/`DemoAudioSource` (1,024-frame blocks at real-time pace from a main-run-loop timer) feed A06 and
  A07 digests and fixtures, so they stay unchanged.
- `FileAudioSource` decodes with `AVAudioFile` in 4,096-frame chunks and mixes to mono; `MicrophoneAudioSource` writes
  mono and owns the permission and interruption flow (`ResumableAudioSource`).
- `SpectrumAnalyzer.expectedBin(frequency:sampleRate:size:)`, `magnitudesDB`, `peakBin` exist and are tested.
- Music Lab draws its waveform as `.line` `SceneNode`s through `PrimitiveRenderer` with a `Camera2D`; the same path
  serves this slice (G-TRACESTRIP replaces it in A08-P02).
- Test targets: `Packages/VisualCore/Tests/VisualCoreAudioDSPTests` (host) and
  `Packages/VisualCoreRendering/Tests/VisualCoreAudioTests`.

## 1. Decisions

- **D1 New types beside the old (clarification 1):** keeps every A06/A07 digest byte-identical. Alternative rejected:
  new `DemoSignal.Mode` cases (breaks exhaustive switches and fixtures).
- **D2 Interleaved stereo buffer:** one lock-free buffer of 2 × frames with a frame counter published after each whole
  block, and `frames(from:count:left:right:)` by absolute position that returns how many frames are still inside the
  buffer. Alternative rejected: two separate rings (the two counters can disagree mid-write).
- **D3 Square wave:** a naive ±amplitude square (sign of the sine phase), documented as not band-limited; the scope
  shows the raw shape, and the spectrum fixture uses the sine. **Sweep:** logarithmic, f(t) = f0 · (f1/f0)^(t/T), phase
  integrated exactly, looping every T.
- **D4 Trigger (clarification 3):** hysteresis 2 % of full scale; search backward from the newest frame minus the span
  over one span of lookback; positions in whole samples; auto mode falls back to the newest span, normal mode keeps the
  last triggered window.
- **D5 Timebase and gain (clarification 4):** 10 divisions; 0.1/0.2/0.5/1/2/5 ms/div; ×0.5/1/2/5/10; window cap 4,096;
  buffer 16,384 frames.
- **D6 Microphone stays mono (assumption):** a one-channel window; route-dependent stereo capture is assessed in
  A08-P05 (G-STEREO's microphone part re-owned there in the contract).
- **D7 Five fixtures (convergence T-A08-119):** the scenario manifest carries five fixtures — display periods, spectrum
  bin, no trigger, clipping beyond full scale, the sweep on a falling trigger — because the planning catalog asks five
  for A08 (the audit's content-count check); `ScopeManifestTests` asserts the five. **Spectrum frames:** the spectrum bin
  of every offered frequency is proved on the newest 4,096 frames (the analyser's full frame), not on the timebase
  window, which a 100 Hz window of five periods would smear by a bin (convergence T-A08-118).
