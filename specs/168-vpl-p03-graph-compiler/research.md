# Research: A23-P03 (feature 168)

- **D1 Own schedule over FieldPass (clarification Q1):** as decided at A23-P00 (research D5), the experience compiles
  into its own passes; `EffectGraphDescription` is not used.
- **D2 Fixed preview size (Q2):** a 256 × 256 preview keeps the budget a static count of slots, independent of the
  device; the manual asks for a low-resolution preview while editing.
- **D3 Interval slots:** lowest-free-slot assignment in pass order is optimal enough for chains (two slots) and
  bounded by the 6-slot limit; a full register allocator is not needed for 32 nodes.
- **D4 Keys (Q3):** content digests over the node and its inputs' keys give downstream invalidation for free.
- **D5 Inset (Q4):** a framebuffer pass with a smaller width and height draws at the bottom-left because `FieldPass`
  sets the viewport from the origin; no VisualCore change.
- **D6 References (Q4):** gradient, mix, flat colour, blur-of-ramp and copy have closed-form CPU references; noise is
  tested for determinism and dependence on its parameters, not against a CPU port.
- **D7 Viewport (analyze, corrected at implement):** the analyze step read that the host never resets the viewport, but
  `RenderHost` sets it to the whole drawable before each frame (`RenderHost.swift` line 419, and `renderOffscreen`), so
  an inset's viewport never carries into the next frame. The grid drawn by a full-framebuffer `FieldPass` was kept: it
  is harmless, and its test (`afterAnInsetFrameTheNextGridCoversTheWholeDrawable`) holds either way.
