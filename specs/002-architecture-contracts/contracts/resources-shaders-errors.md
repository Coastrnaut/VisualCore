# Contract: resources, shaders, errors and logging (FR-F105–FR-F107)

## GPU resources (FR-F105)

* Kinds: `texture`, `buffer`, `framebuffer`, `renderbuffer`, `program`, `shader`, `vertexArray`.
* `GPUHandle { kind, name: UInt32, bytes: Int, generation: Int, label: String }`. It is created only
  through `ResourceRegistry` with the visible context current on the main thread.
* Budgets: per-kind byte limits plus a total limit (app-configurable; default total 256 MiB). An
  allocation over budget throws `ResourceError.overBudget(kind, requested, available)`, and nothing
  is allocated.
* Counters: live count and bytes per kind, peak bytes, `staleRejected`, `leaked` (live at teardown).
* Stale use: a handle whose `generation` ≠ current is never passed to GL; `staleRejected` +1.
* Cleanup: the owner (scene, effect, registry) releases its handles in `teardown`; the host asserts
  zero live handles after teardown (leak test, SC in F03).
* Memory pressure (U-F002): on memory warning the host calls `scene.trimCaches()`; registry-owned
  pools drop free targets. Verified in F03 simulator tests (device behavior in campaign II).
* GPU memory per scene (U-F003): reported from registry byte accounting (estimate, not driver
  truth). Labelled "estimated".

## Shaders (FR-F106)

* Sources: `.glsl` resources named `<name>.vert` / `<name>.frag` under each module's or app's
  `Resources/Shaders/`, GLSL ES 3.00 (`#version 300 es`) added by the library if absent.
* Includes: `#include "name.glsl"` from the same library. Max depth 8, no cycles, total expanded
  size ≤ 64 KiB. The line map records `(expandedLine → file, line)`.
* Diagnostics: `ShaderDiagnostic { file, line, stage: vertex|fragment|link, severity, message }`,
  parsed from ANGLE info logs (`ERROR: 0:<line>: …`) and mapped back through the line map.
* Programs are cached by `sha256(vertex+fragment+defines)` per context generation; the cache is
  cleared on recreation.
* Failure: a failed compile or link returns diagnostics and **never replaces** a working program.
* Untrusted source (Shader Studio and similar apps): the same limits plus a compile-time budget
  enforced by the caller (Constitution IX).

## Errors (FR-F107)

| Category | Examples | Recoverable | Behavior |
|---|---|---|---|
| `unsupported` | no ES3 config, missing GL entry points | no | host stays `uninitialized`; app shows native fallback UI |
| `allocation` | EGL context/surface creation failed | yes | `surfaceInvalid`, retry on next layout |
| `contextLost` | EGL_CONTEXT_LOST, forced recreation | yes | `reinitialized`, scene rebuilt |
| `resource` | over budget, stale handle | yes | operation refused, counter incremented |
| `shader` | compile/link failure | yes | previous program kept, diagnostic surfaced |
| `effect` | pass failure | yes | pass-through, reported once |
| `programming` | illegal lifecycle transition, wrong thread | n/a | rejected + recorded; debug precondition |

## Logging and diagnostics (FR-F107)

* `os.Logger` subsystem `org.visualcore.<module>`, category per component; no user content, file
  names from user documents, audio, identifiers or locations in logs.
* `DiagnosticsSnapshot` fields (units): `state`, `generation`, `frameIndex`, `frameTimeMedianMs`,
  `frameTimeP95Ms`, `missedRefreshSlots` (count), `fpsCap`, `renderScale`, `thermalState`,
  `lowPowerMode`, `liveHandles` per kind, `gpuBytesEstimated`, `rejectedTransitions`,
  `staleRejected`, `shaderFailures`. JSON-encodable for AutomationRunner reports.
