# Research: A22-P02 (feature 160)

- **D1 Source outside the core (clarification Q1):** engine actions carry numbers only, and a shader source is text.
  The core therefore keeps what numbers describe (template, values, run count), and the presenter keeps the document.
  - The A22-P04 library persists the document.
  - Alternative: encoding text into actions (rejected: the 24-value cap and no text values).
- **D2 Last-good swap (Q2):** compile first through `context.resources.program`, which gives every diagnostic. Only
  then build a `FullScreenShaderScene` for the same entry; its setup is a program-cache hit.
  - This keeps the drawing inside a VisualCore scene and never shows a grey failed scene.
  - Alternative: rebuilding a scene per run and reading `errorMessage` (rejected: it keeps one diagnostic and draws
    grey).
- **D3 Queue (Q2):** the run count is the request signal, and the newest document wins. The compile happens in the
  next `draw`, so a control never compiles (constitution 2.18.1).
- **D4 Uniforms (Q3):** normalized 0…1 in the core, denormalized by the live project's definitions. This makes the
  engine's ranges uniform across templates.
- **D5 One tier (Q3):** `level-0` only. There is no lower level to declare until device data exists (the A22-P05
  quality tiers).
