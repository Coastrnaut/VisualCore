# Data Model: A23-P02 (feature 167)

Core (pure, `VisualProgrammingLabCore`):
- **GraphEditRefusal:** `notWhole`, `unknownNode(NodeID)`, `unknownPort`, `typeMismatch(from, to)`,
  `inputTaken(node, port)`, `cycle([GraphEdge])`, `tooManyNodes`, `oneOutput`; `rule` gives the rule id
  (`a23.not-whole` … `a23.one-output`).
- **GraphEditor:** `add(_ kind, at: CanvasPoint, to:) -> (VisualGraph, NodeID)`, `move(_ id, to:, in:)`,
  `remove(_ id, from:)`, `connect(source:outputIndex:target:inputIndex:in:)`, `disconnect(target:inputIndex:in:)`; each
  returns the new graph or throws a `GraphEditRefusal`. Positions are clamped to ±4,096.
- **CanvasLayout:** `boxWidth` 168, `titleHeight` 32, `rowHeight` 36, `portTarget` 44; `box(of node) -> Rect`,
  `inputPoint(node, index)`, `outputPoint(node, index)`, `wire(edge, in graph) -> (start, control1, control2, end)`,
  `hit(_ canvasPoint, in graph, zoom) -> CanvasHit` (`.input(node, index)`, `.output(node, index)`, `.node(id)`,
  `.empty`).
- **CanvasView:** wraps `PlaneViewport`; `zoom` 0.5…2 (default 1), centre clamped to ±4,096; `canvas(fromScreen:)`,
  `screen(fromCanvas:)`, `pinched(by:anchor:)`, `panned(by:)`, `resized(to:)`.
- **EditMessages:** `sentence(for: GraphEditRefusal) -> String`, `status(for: CheckResult, in graph) -> String`, and
  the spoken labels `label(node:)`, `label(port:)` and `label(edge:in:)`, used by the overlay and the list form.

Experience:
- **LabCore** (snapshot schema 1, digest `a23.visual-programming-lab.v1` over the graph): `graph`, `selection`
  (`NodeID?`); actions and rules per the spec's clarification Q1; the starter graph is Noise (id 1, at 40, 80) into
  Output (id 2, at 320, 80).
- **LabPresenter:** `view: CanvasView`, the grid scene, the drag state (`none`, `wire(from port, to point)`,
  `move(node, offset)`, `pan`, `pinch`), `feedback: String?`.
