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
