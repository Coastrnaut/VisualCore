# Contract: Shader Studio experience (A22-P02)

- Opening shows template 0 (`gradient`) drawn; status `Compiled` after the first frame.
- `template.select [i]` makes template i's project the document and requests a run; `shader.run` requests a run of the
  current document; neither compiles in the action — the next draw does, once.
- A refused source (validator) or a compile/link failure leaves the live scene drawing: the read-back pixels before and
  after are byte-identical; the status carries the mapped diagnostics or issues.
- A success replaces the live scene; the status becomes `Compiled`; diagnostics are empty.
- `uniform.set [k, v]` changes the live scene's `u_<name>` to the denormalized value next frame with no compile.
- `recreateContext` and a resize redraw the last good source with the current values.
- Controls: identifiers `template`, `run`, `uniform-<k>`, `status`, `diagnostics`; every control has a spoken label.
- Candidate registration; not available.
- As built: a successful compile carries no warnings (VisualCore returns no log for a linked program); the probe program
  is kept, not released, when the new scene reuses it; a teardown drops a pending request; the frame probe
  `warm-corner` (red) is declared for the opening template; the manifest has five fixtures (see data-model.md).
