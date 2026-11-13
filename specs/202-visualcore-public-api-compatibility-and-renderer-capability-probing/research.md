# Research: R02-F02

## 1. Audit (2026-11-13; names re-verified by the lead)

The read-only audit (agent note `Build/agent-notes/R02-F02-audit.md`, verified against the source) found:
- `RenderCapabilities` (VisualCoreRendering/RenderCapabilities.swift): `glVersion`, `glslVersion`, `renderer`, `vendor`,
  `eglVendor`, `extensions`, `maxTextureSize`, `maxViewport` (`Size`), `maxRenderbufferSize`, optional
  `fragmentHighp`/`fragmentMediump` (`ShaderPrecision`); static `query(display:)` (line 94), `currentExtensions()`.
- `RenderHost.capabilities` set only in init (line 113); `recreateContext()` (line 344) reloads with
  `_ = vcglLoadFromEGL()` (line 367), ignoring the missing count, and does not re-query; init throws
  `RenderHostError.unsupported` when the count is above 0 (line 104).
- `FloatRenderSupport` re-detects per generation.
- GL constants for samples, draw buffers, colour attachments and limits are declared in `CVisualCoreGL.h`.
- `EvidenceRecord.Environment` (VisualCoreExperience) has `kind`, `osVersion`, `osBuild`, `deviceType`, `xcode`,
  `swift`, `sdk`, `hostOS`, `signing`; built in `EvidenceRecordObservation.swift:58`; the app writes evidence in
  `ScenarioLaunch` (line 132).
- `check_evidence.py` validates `environment` (line 256).
- Name clash to avoid: `ExperienceDescriptor.capabilities` is the catalog list, not GPU capabilities.

## 2. Decisions

- **R1 Fields**: optional `Int?` for limits (`maxSamples`, `maxDrawBuffers`, `maxColorAttachments`,
  `maxVertexAttribs`, `maxVertexUniformVectors`, `maxFragmentUniformVectors`, `maxTextureImageUnits`,
  `maxVaryingVectors`), `ShaderPrecision?` for `vertexHighp`, `vertexMediump`, `fragmentHighInt`, `String?`
  `eglVersion`, `[String]?` `eglExtensions`, `Int?` `missingEntryPoints`, `Int?` `generation`. A query that leaves a
  GL error gives nil. Alternatives: a dictionary (untyped, rejected).
- **R2 Refresh**: `recreateContext` re-queries after a successful reload and sets `generation` from the lifecycle;
  a missing count above 0 reports `RenderHostError.unsupported` and enters the surface-invalid path like a failed
  context creation.
- **R3 Floors**: `RenderCapabilities.floorFindings() -> [FloorFinding]` with the ES 3.0 minima: draw buffers 4, colour
  attachments 4, samples 4, texture size 2048, renderbuffer 2048, vertex attribs 16, texture image units 16, vertex
  uniform vectors 256, fragment uniform vectors 224, varying vectors 15.
- **R4 Evidence**: pure `RendererRecord` (strings and ints, all optional) in VisualCoreExperience;
  `Environment.renderer`; mapping in VisualCoreExperienceHost; `ScenarioLaunch` fills it from the open session's host.

## 3. Corrections during implementation

(none yet)
