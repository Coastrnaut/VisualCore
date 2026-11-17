# Contract: Digital Zen Garden library, accessibility and still (A20-P04)

- **Library:** save then open is exact; rename and delete update the list; a 13th save is refused with its message;
  damaged, newer and oversized files are listed as unreadable with their codes and stay on disk; opening restarts the
  history and the digest equals the opened document's.
- **Accessibility:** every control has a label; the description names tone, strokes, stones and the selection; undo,
  redo, save, open and delete announce; at `.accessibility5` the controls grow in height and fit the width.
- **Bounded history:** 10,000 seeded commands leave at most 100 undoable commands, an encoded history under 2,457,600
  bytes, and a document within its caps.
- **Still:** a 1600 × 1200 PNG is written and handed to `ShareLink`; a failure leaves no file; a second export
  replaces the first.
