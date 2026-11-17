# Research: A21-P02 (feature 153)

- **D1 Limit in the shader:** the cap is the last step of the one composite (knee 0.83 × limit to the limit).
  Alternative: a separate cap pass over a render target; rejected for 0.1 (one pass suffices and the reference can
  prove it).
- **D2 Blend inputs, not pictures:** the change between presets blends shader inputs, so every intermediate frame is
  a valid capped sky. Alternative: `CrossfadeScene` of two pictures; kept for A21-P03's multi-layer compositing.
- **D3 Chrome outside the state:** hiding controls is presentation; a snapshot never restores hidden controls.
- **D4 Hue as a shift:** one hue control rotates every palette colour, which keeps presets recognisable.
