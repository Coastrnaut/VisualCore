# Research: A08-P03 (feature 063)

## 0. Verified facts (2026-11-14)

- `SpectrumAnalyzer(size: 4096).magnitudesDB` returns 2,048 values in dB relative to full scale (Hann window, coherent
  gain 0.5, floor −200 dB); `peakBin` ignores bin 0 and returns nil below −100 dB; `expectedBin` rounds f·N/fs.
- The 2D renderer draws shapes only; no text drawing exists in VisualCore (labels go to SwiftUI text and speech).
- `ScopeState.display` validates against `ScopeDisplay.allCases`, so adding a case widens the accepted range.

## 1. Decisions

- **D1 Readout tolerance:** frequency within one bin (fs/4,096 = 11.7 Hz at 48 kHz) and level within 1.5 dB (Hann
  scalloping ≤ 1.42 dB). Rejected: interpolated peak estimation (adds precision claims beyond the slice).
- **D2 Log columns (clarification 4):** strongest bin per pixel column; columns below the first bin's x are empty at low
  frequencies, so the curve has one point per non-empty column.
- **D3 Analysed channel:** left (or only) channel; the right channel's spectrum and channel choice are later work.
- **D4 Validity words (clarification 3):** "no signal", "clipping, level not valid", "filling"; the unit wording is
  always "dBFS, relative to full scale".
