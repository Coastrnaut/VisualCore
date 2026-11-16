# Research: A17-P02 (feature 125)

- **D1 One renderer per mesh** (Q2). Each of the 20 meshes has its own geometry, so one `MeshRenderer` per mesh (20
  draws) is simplest and within the 32-draw budget. The renderers are made and released together, because they share
  one program. *Alternative:* unit primitives with scale matrices (rejected: the profiles differ per mesh).
- **D2 World-space picking** (Q4). Each item's triangles are transformed once by its model matrix when the scene is
  built, and kept for picking. A tap tests the visible items whose world bounding sphere the ray meets, then their
  triangles with `Ray3.intersect(triangle:)`. *Alternative:* transforming the ray into model space per item (rejected:
  scaled matrices make distances harder to compare).
- **D3 Two quality levels** (Q1). Level-0 is full and level-1 reduced. The host's quality governor picks the level;
  `Core.qualityTiers == 2` matches the presenter (lesson of X-A07).
- **D4 Framing** (Q3). The distance is r × 1.25 / sin(fov/2) on the narrower axis (the Molecular Explorer precedent),
  and the move is immediate, so Reduce Motion needs nothing extra in this phase.
- **D5 Layer toggles now, isolate later** (Q5). The manual's Phase 02 MVP and its regression fixture need visibility
  per layer now. Isolate and ghosts need G-GHOST (a VisualCore assessment) and stay in A17-P03.
- **D6 The candidate stand-in** (registration). `AppModelTests` used `a17.interactive-anatomy` as a synthetic
  candidate through `-vcCandidates`. Once A17 is a real candidate, the stand-in moves to the next unbuilt experience,
  `a18.*`, from the catalog.
- **D7 As built** (converge 2026-11-16). The implementation adds five things beyond the earlier decisions:
  - **Five fixtures, not three:** the content-counts audit requires the planning catalog's count, so
    `fixture-bones-only` and `fixture-acl-zoomed` join the three fixtures the tasks named.
  - **Outcome codes:** `selected-<part id with dots as hyphens>` while a part is selected, otherwise `viewing-knee`.
  - **Preparation failures:** `a17.scene-refused` for an unbuildable scene and `a17.content-refused` for refused
    content, each with the refusal's sentence.
  - **Background probe:** the presenter declares one at (0.5, 0.04), used only when that ray hits no visible part.
  - **Finger tracking:** the presenter tracks fingers, so a second finger cancels the tap the arbiter would still
    report.
