# API contract: R02-F02 (additive)

VisualCoreRendering: `RenderCapabilities` new optional properties (research R1); `func floorFindings() -> [FloorFinding]`;
`struct FloorFinding { name: String; minimum: Int; reported: Int }`. `RenderHost.capabilities` reflects the current
context generation.

VisualCoreExperience: `struct RendererRecord: Sendable, Equatable, Codable` (data-model); `EvidenceRecord.Environment
.renderer: RendererRecord?`.

VisualCoreExperienceHost: `extension RendererRecord { init(_ capabilities: RenderCapabilities) }`.
