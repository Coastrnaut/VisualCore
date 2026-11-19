# Data Model: A23-P03 (feature 168)

Core (pure):
- **PreviewSize:** 256 × 256 pixels; **SlotLimit:** 6; bytes per slot 256 × 256 × 4.
- **Operator:** `noise`, `gradient`, `mix`, `blurH`, `blurV`, `output`.
- **PassInput:** sampler name → slot index. **PassValue:** a parameter name → `scalar(Double)`, `colour(r, g, b)`,
  `time(rate)`, `frameTime` (resolved per frame by `PreviewValues`).
- **Pass:** `node`, `operator`, `inputs`, `values`, `output` (a slot, or the framebuffer for `output`), `key`.
- **PassSchedule:** `passes`, `slotCount`, `bytes`, `keys` (node → key).
- **CompileRefusal:** `invalid(String)` (the checker's status), `overBudget(slots: Int)`; sentence "This graph needs N
  textures; the preview allows 6."
- **GraphCompiler:** `compile(_ graph) -> Result<PassSchedule, CompileRefusal>`, `keys(of graph)`,
  `changed(from old: VisualGraph, to new: VisualGraph) -> Set<NodeID>`.
- **PreviewValues:** `uniforms(for pass, time: Double) -> [String: Double or (r, g, b, a)]`.

Experience:
- **PreviewState:** `ready`, `invalid(String)`, `refused(String)`, `failed(String)`, `hidden`.
- **PreviewPipeline:** `programs` (one `FieldPass` per operator), `slots` (`RenderTarget`s), `schedule`,
  `compileCount`, `state`; `compile(graph, context)`, `draw(context, time, inset)`, `release()`.
- **As built (A23-P03):**
  - `PreviewValues.colours(for:)` gives `PassColour` (r, g, b); `Pass` and `PassSchedule` have public initialisers;
    blur passes carry `radius`, `directionX` and `directionY`; the output pass has no values.
  - Keys use resolved parameter values (a stored default and a missing parameter give one key), exclude positions and
    identities, and mark an input that closes a loop "loop" (only refused graphs have one).
  - Slots: the writer takes the lowest slot free before it runs; the journey graph needs 3 slots; `GraphFixtures.atLimits`
    needs 7 and is refused.
  - The pipeline keeps the earlier slots when a compile is refused or invalid; the failed message is "The preview could
    not be drawn: <diagnostic>"; a node move recompiles once (the fingerprint holds positions) without changing slots or
    programs; a context rebuild restores programs and slots without counting a compile.
  - Test seams: the presenter's `graphOverride`, the pipeline's `fragmentOverrides` and `runCount`; `LabTest.open` hides
    the preview by default so A23-P02's grid tests see the grid alone.
