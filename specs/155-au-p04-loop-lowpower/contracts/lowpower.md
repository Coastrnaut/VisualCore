# Contract: Aurora low power (A21-P04)

- Still view: over 100 frames without a change the sky is drawn once; a change draws once more.
- Reduced flash: every consecutive frame's mean-luminance step < 0.02, also during a change between skies.
- Fallback: a forced compile failure or a forced missing highp shows the gradient sky and the message, under the limit.
- Target release: live render-target, texture and buffer bytes after ten finished preset changes equal the baseline.
