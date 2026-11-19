# Contract: VisualProgrammingLabCore (A23-P01)

Public declarations, each with `///` documentation:

```text
enum ValueType: String { scalar, colour, texture, time }
enum PortDirection: String { input, output }
struct PortDeclaration { name, direction, type, required }
enum NodeKind: String, CaseIterable { time, constant, noise, gradient, mix, blur, output }
  var inputs: [PortDeclaration]; var outputs: [PortDeclaration]; var parameters: [ParameterDefinition]
  func input(_ name: String) -> PortDeclaration?; func output(_ name: String) -> PortDeclaration?
  func parameter(_ name: String) -> ParameterDefinition?
struct NodeID: Comparable { rawValue: Int; init(_:); validRange 1…9,999; isValid }
struct CanvasPoint { x, y }
struct GraphNode { id, kind, parameters, position }
struct GraphEdge: Comparable { sourceNode, sourcePort, targetNode, targetPort }
struct GraphLimits { static maxNodes = 32; static maxEdges = 64 }
struct VisualGraph { nodes, edges; outputNodes: [NodeID] (derived); output: NodeID? (derived) }
enum GraphDocument {
  static kind = "a23.visual-graph"; static schemaVersion = 1; static maxEncodedBytes = 65_536
  static migrations: MigrationChain
  static func encode(_ graph: VisualGraph) throws(GraphDocumentRefusal) -> Data
  static func decode(_ data: Data) throws(GraphDocumentRefusal) -> VisualGraph
  static func fingerprint(of graph: VisualGraph) throws(GraphDocumentRefusal) -> StateDigest
}
enum GraphDocumentRefusal: String, Error { damaged, newerVersion, tooLarge, notFinite, outOfRange; code }
enum GraphIssue: Error, Equatable, Hashable  (cases as data-model; code)
enum CheckResult { accepted(order:reaching:), refused([GraphIssue]) }
enum GraphChecker { static func check(_ graph: VisualGraph) -> CheckResult }
```

The checker runs the stages of the spec's clarification Q4 in order and stops after a stage that refused.

VisualCore names this core and its tests use (all public, unchanged): `ParameterDefinition`, `ParameterError`
(VisualCoreParameters); `MigrationChain`, `MigrationError` (VisualCorePersistence); `DigestBuilder`, `DigestError`,
`StateDigest` (VisualCoreExperience); and, in the tests only, `RenderHost`, `RenderScene`, `RenderContext`,
`FrameInfo`, `ResourceRegistry` and `ResourceLedger` (VisualCoreRendering).
