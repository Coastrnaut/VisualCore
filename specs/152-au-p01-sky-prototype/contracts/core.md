# Contract: Aurora core (A21-P01)

- **Scene:** each preset round-trips exactly; each refusal sample gives its code; setters clamp to the bounds of
  data-model.md.
- **Sky:** the shader compiles through `ShaderBundle`; each preset at level 0 and 1 matches `SkyReference` within the
  tolerances; brightness within range; level 1 uses fewer octaves.
- **Clock:** a one-hour delta moves time by at most 0.25 s × speed; under Reduce Motion or speed 0 two frames are
  identical; the phase loops without a seam (phase 0 and phase 1 give the same picture).
- **Purity:** the core imports no UIKit, SwiftUI, OpenGLES or Network and reads no clock.
