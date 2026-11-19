# Data Model: A23-P01 (feature 166)

- **ValueType:** `scalar`, `colour`, `texture`, `time` (raw strings). **PortDirection:** `input`, `output`.
- **PortDeclaration:** `name` (lowercase letters, 1…16), `direction`, `type`, `required` (inputs only; outputs are
  never required).
- **NodeKind:** `time`, `constant`, `noise`, `gradient`, `mix`, `blur`, `output` (raw strings); each with `inputs`,
  `outputs` and `parameters` (`[ParameterDefinition]`, at most 6) as in the spec's clarification table.
- **NodeID:** an integer 1…9,999. **CanvasPoint:** `x`, `y` in canvas points, finite, each within −4,096…4,096.
- **GraphNode:** `id`, `kind`, `parameters` (`[String: Double]`, finite), `position`.
- **GraphEdge:** `sourceNode`, `sourcePort`, `targetNode`, `targetPort`.
- **GraphLimits:** `maxNodes` 32, `maxEdges` 64.
- **VisualGraph:** `nodes` (in identity order when encoded), `edges` (in target, port, source order when encoded),
  `output` (`NodeID?`).
- **GraphDocument** (kind `a23.visual-graph`, schema 1, ≤ 65,536 bytes encoded, canonical JSON with sorted keys):
  envelope `kind`, `version`, `body` (the graph). Refusal codes: `damaged`, `newer-version`, `too-large`,
  `not-finite`, `out-of-range`. `fingerprint(of:)` gives a `StateDigest`.
- **GraphIssue:** `too-many-nodes(n)`, `too-many-edges(n)`, `duplicate-node(id)`, `unknown-parameter(node, name)`,
  `parameter-out-of-range(node, name)`, `unknown-node(id)`, `unknown-port(node, port)`, `wrong-direction(node, port)`,
  `type-mismatch(edge, from, to)`, `input-already-connected(node, port)`, `duplicate-edge(edge)`, `cycle([edge])`,
  `no-output`, `multiple-outputs([id])`, `output-disconnected(id)`, `input-unconnected(node, port)`.
- **CheckResult:** `accepted(order: [NodeID], reaching: Set<NodeID>)` or `refused([GraphIssue])`.
- **As built (A23-P01):**
  - **`VisualGraph`** stores `nodes` and `edges` only. `outputNodes` (the identities of the nodes of kind `output`,
    ascending) and `output` (the single one, or nil) are derived, so the fingerprint covers the output through the
    nodes.
  - **`NodeKind`** has `input(_:)`, `output(_:)` and `parameter(_:)` in place of `port(_:)`, because blur has an input
    and an output named `image`. `GraphNode.value(of:)` gives the stored value or the kind's default.
  - **`GraphDocument`** also refuses an edge end outside 1…9,999 as `out-of-range`, reads `"NaN"`, `"Infinity"` and
    `"-Infinity"` strings as `not-finite`, and refuses a non-finite value of any parameter, declared or not (undeclared
    names stay the checker's). `GraphDocumentRefusal.code` gives the code.
  - **`GraphChecker`** reports a duplicated identity once; a missing source and a missing target node of one edge are
    both reported; a repeated edge gives only `duplicate-edge`; `input-unconnected` covers nodes that do not reach the
    output, and the output's own empty input is `output-disconnected`.
