# Research: A22-P03 (feature 161)

- **D1 Editor (clarification Q1):** the iOS 26 `TextEditor` over an `AttributedString`, recoloured from the A22-P01
  tokens, with a separate gutter. Alternatives considered:
  - a `UITextView` wrapper (rejected: it adds UIKit text plumbing to the experience for no gain);
  - a read-only highlighted view beside a plain editor (rejected: it shows the text twice).
- **D2 Oversized proof (Q2):** the registry's `compileCount` gives the "no GPU work" evidence without a GPU counter.
- **D3 Textures (Q4):** `FieldPass` already samples named render targets and draws to a framebuffer, so no
  VisualCore change is needed. Alternatives considered:
  - extending `FullScreenShaderScene` with samplers (rejected: a VisualCore change for one user);
  - binding units on a cached program (rejected: it relies on cache identity).
- **D4 Snapshot (Q5):** an optional field keeps schema 1, and no migration example is needed.
