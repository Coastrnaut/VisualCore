# Research: A23-P02 (feature 167)

- **D1 Edits in the core (clarification Q1):** `GraphEditor` applies each edit to an immutable `VisualGraph` and
  reuses `GraphChecker` for connections, so the canvas, the list form and the action engine give the same refusals.
  Alternatives: checking in the presenter (rejected: not testable without the host) and a second connection rule set
  (rejected: two sources of truth).
- **D2 New identities:** the smallest unused identity keeps identities small and deterministic; a removed node's
  identity can be reused, which is harmless because connections are removed with it.
- **D3 Layout (Q2):** fixed box sizes in canvas points make hit testing and wire geometry pure arithmetic. 44-point
  targets follow Apple's minimum hit target; at zoom 0.5 a target is 22 points, so the list form covers small views.
- **D4 View (Q3):** `PlaneViewport` gives the anchored pinch; the canvas's y-down coordinates are its plane with y
  negated. The view never enters the snapshot, so view changes cannot change the graph or its digest.
- **D5 Drawing (Q4):** the grid is the only GPU drawing in this phase, through `FullScreenShaderScene`; nodes and
  wires are native views, legible without colour (port shapes) and readable by VoiceOver. A GPU node renderer waits
  for the preview compiler (A23-P03).
- **D6 Registration (Q5):** the Shader Studio pattern of A22-P02.
