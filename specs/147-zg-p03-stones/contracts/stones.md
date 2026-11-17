# Contract: Digital Zen Garden stones (A20-P03)

- **Commands:** each stone action undone and redone gives an equal document; actions needing a selection without one
  are refused unchanged; placing at 24 stones is refused with its message; a move is clamped inside the tray.
- **Selection:** in every overlap sample the topmost stone is selected; empty sand clears; cycling wraps in depth
  order; removing the selected stone clears the selection.
- **Drawing:** the stone layer equals a CPU rasterization; the drawn target reads back within 1/1024; the sand under a
  stone's shadow is darker than the same sand without the stone; undo, redo, restore and a context recreation rebuild
  the same picture.
- **Orientation:** 390 × 844 and 844 × 390 views give the same document and layers; mapped positions round-trip
  within 1/480 tray widths.
- **Gestures:** gesture actions ⊆ native actions.
- **As built:** the encoding, selection, refusal, clamping, rotation-direction, tap, cycle, lifetime, shadow and
  manifest rules of data-model.md "As built" (StoneActionTests, StoneGestureTests, StoneRenderTests,
  GardenManifestTests).
