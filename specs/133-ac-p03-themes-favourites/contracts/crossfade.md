# Contract: CrossfadeScene (VisualCoreRendering, A18-P03)

- **Progress:**
  - at `progress` 0 the frame equals the `from` scene's frame (byte for byte);
  - at 1 it equals the `to` scene's;
  - at 0.5 each channel is within 2 of the average of the two.
- **No black frame:** with two non-black inputs, no output pixel is darker than both inputs.
- **Lifecycle:**
  - `resize` and a repeated `setup` (context recreation) rebuild both targets, and the frame afterwards equals the
    frame before;
  - `teardown` leaves no GPU object of the scene.
- **Reduce Motion:** the caller uses `transitionDuration(1.2, reduceMotion: true) == 0`, a cut.
