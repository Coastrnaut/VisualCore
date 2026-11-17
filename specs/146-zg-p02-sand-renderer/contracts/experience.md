# Contract: Digital Zen Garden experience (A20-P02)

- **Actions:** every action in range is accepted and changes the digest as specified; out of range, wrong counts and
  `stroke.add` or `stroke.end` without a `stroke.begin` are refused without a change.
- **No gaps:** a drag of three far-apart pointer events yields a committed stroke whose neighbouring points are at most
  0.004 + 1e-9 apart.
- **Sand:** the drawn target read back matches the CPU field within 1/1024 (`rgba16f`) or 1/255 (`rgba8`); undo, redo
  and restore rebuild it equal to a fresh replay; a context recreation draws the same frame.
- **Preview:** visible with the rake's width and tine count during a drag; hidden after the lift or a cancel.
- **Patterns:** each pattern commits one stroke through the same actions.
- **Registration:** candidate `a20.digital-zen-garden`; the manifest is valid with its fixtures.
