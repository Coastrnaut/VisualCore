# Research: R02-F04 — GPU resource ownership and pipeline lifetime

**Date**: 2026-11-13 · **Spec**: [spec.md](spec.md) · Section 13 disposition: **reuse** (ResourceRegistry, ResourceLedger, ResourceBudget, RenderLifecycle).

## 0. Read-only audit (`main` at `02b9620`; `Build/agent-notes/R02-F04-audit.md` re-verified)

| Source (`Packages/VisualCoreRendering/Sources/VisualCoreRendering/` unless stated) | Verified |
|---|---|
| `ResourceRegistry.swift:27-55` | `accept(generation:)` counts stale via `ledger.noteStale()`; `contextWillEnd()` trims pools, releases cached programs, calls `willEndContext()` (internal hook, never assigned), then `ledger.abandonAll()`; `contextDidStart(generation:)` |
| `ResourceRegistry.swift:188-269` | `program(vertex:fragment:defines:library:vertexName:fragmentName:)`; cache keyed by `ShaderCacheKey`, `maxCachedPrograms = 64`, `lru`; **eviction calls `release(evicted)` (`:235-237`), which deletes the GL program a scene may still hold**; `compileCount`, `cacheHits`, `cachedProgramCount`; `release(_ program:)` |
| `ResourceRegistry.swift:93,158-182` | `makeRenderTarget(width:height:format:label:)` colour-only; pool keyed by `PoolKey(width,height,format)`, `acquireTarget`, `recycle`, `trimPools` |
| `GPUObjects.swift:127-139` | `RenderTarget` (handle, `colorTexture`, size, format, weak registry, `released`) — no depth |
| `GLState.swift` | `GLState.resetForVisualCore(framebuffer:width:height:)` only; no apply of a described state |
| `VisualCoreDiagnostics/ResourceLedger.swift` | `ResourceKind` incl. `renderbuffer` (unused), `ResourceBudget`, `allocate/release`, `noteStale()`, `Snapshot.staleRejected/leaked/liveCount` |
| `VisualCoreShaderSource/` | pure module (ShaderLibrary, SHA256, InfoLogParser) — home of the pure `RenderState` |
| `Tests/VisualCoreRenderingTests/ProgramCacheTests.swift:35-` | `testCacheIsBoundedToSixtyFourWithLRUEviction` asserts the evicted program was deleted (live count 64) — amended per FR-R02F04-014 |
| `RenderHost.swift:352-389, 540-563` | recreateContext and destroy order; `assertMainThread` |

## 1. Decisions (clarifications binding)

- **D1 Retired programs**: `ResourceRegistry` keeps `retired: [ObjectIdentifier: ShaderProgram]`; eviction moves the
  program there (cache entry and LRU removed, no GL delete) and increments `evictionCount`; `release(_:)` of a retired
  program deletes it; `contextWillEnd()` releases retired programs before `abandonAll()`. Consumer: every game with
  more than 64 variants; A01's generative variants.
- **D2 RenderState** (pure, VisualCoreShaderSource): `BlendMode {none, alpha, premultiplied, additive}`, `CullMode
  {none, back, front}`, `depthTest`, `depthWrite`, `colorMask` (4 Bools); presets `opaque`, `alphaBlended`,
  `additive`, `opaque3D`; Hashable, Sendable, Codable not needed.
- **D3 Pipeline** (rendering): `struct Pipeline: Hashable { let program: ShaderProgram; let state: RenderState }`
  (equality by program identity); `GLState.apply(_ pipeline:, resources:) -> Bool` sets blend enable/func, depth
  enable/mask/func LESS, cull enable/face, colour mask, uses the program; false + `noteStale` for stale/released.
- **D4 Depth targets**: `makeRenderTarget(..., depth: Bool = false, label:)` and `acquireTarget(..., depth:)`;
  `RenderTarget.depthRenderbuffer: GLuint` (0 when none); `GL_DEPTH_COMPONENT24` renderbuffer counted as
  `.renderbuffer` with width×height×4 bytes; incomplete framebuffer → delete everything allocated, throw.
- **D5** `willEndContext` stays as is (internal, no consumer; not in scope).

## 2. Plan validation (`/speckit-plan`, 2026-11-13)

The plan artifacts drafted in 156576a8 were checked against the skill outline: technical context has no open
unknowns; the constitution check covers all principles; data model, contract and quickstart exist. Corrections: the
contract no longer shows a stored property inside an extension (it is added to the `RenderTarget` class); the
quickstart states expected outcomes. Verified dependencies: VisualCoreRendering and VisualCoreRenderingTests already
depend on VisualCoreShaderSource (`Packages/VisualCoreRendering/Package.swift`), and the host test target
`VisualCoreShaderSourceTests` exists.

## 3. Analysis record (`/speckit-analyze`, 2026-11-13)

Round 1: 0 critical, 0 high, 2 medium. C1: budget-exceeded depth target case added to T-R02F04-011 (FR-R02F04-032).
C2: T-R02F04-002 records the new test classes' durations (SC-R02F04-006). Round 2: 0 findings above low; 21 of 21
requirements and 6 of 6 success criteria covered.
