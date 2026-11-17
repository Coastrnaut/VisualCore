# Research: A21-P03 (feature 154)

- **D1 Crossfade of pictures for presets:** two moving skies mixed by `CrossfadeScene`, which already manages both
  children and survives a context loss. Alternative: extend the A21-P02 input blend; rejected because a picture mix is
  the manual's "multi-layer compositing" and keeps both skies moving.
- **D2 Cap by convexity:** each sky is capped in its shader and a display-space mix stays capped; the read-back test
  proves it. Alternative: a cap pass after the mix; not needed.
- **D3 Preferences as one experience value:** small, versioned, read before the first frame. Alternative: a file;
  rejected (4 KB suffices, and values are cleared with the experience's data).
- **D4 Quality is not a preference:** the host chooses the tier from the device's conditions.
