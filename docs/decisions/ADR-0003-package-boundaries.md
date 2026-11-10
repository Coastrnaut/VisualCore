# ADR-0003 — Package boundaries and dependency direction

**Date:** 2026-11-10 · **Status:** accepted · **Gate:** F01

## Decision

| Package / product | Platform | Contents | May depend on |
|---|---|---|---|
| `Packages/VisualCore` → `VisualCoreMath`, `VisualCoreScenes`, `VisualCoreSimulation`, `VisualCoreEffectsGraph`, `VisualCoreShaderSource`, `VisualCoreDiagnostics`, `VisualCoreAudioDSP`, `VisualCorePersistence`, `VisualCoreTestSupport` | macOS host + iOS | pure Swift, no GPU, no UIKit | Foundation only (TestSupport: test targets only) |
| `Packages/VisualCoreRendering` → `CVisualCoreEGL`, `CVisualCoreGL`, `VisualCoreRendering`, `VisualCoreEffects`, `VisualCoreUI`, `VisualCoreAudio`, `VisualCoreAutomation` | iOS 26+ | ANGLE binaries, GL table, render host, resources, shaders, GPU effects, SwiftUI view, AVAudioEngine bridge, automation runner | `VisualCore`, ANGLE XCFrameworks |
| `Showcase/`, `Apps/<Name>/` | iOS app targets | product UI, domain, scenes | both packages; never ProjectM |
| `Harnesses/ProjectMReference/` (own `.yml`) | iOS | reference adapter | VisualCoreRendering + reference `ProjectMBridge` |

Rules (enforced by `scripts/check_dependencies.py` and `scripts/check_compliance.py`):
no cycles; shared packages never import app targets; nothing outside `Harnesses/ProjectMReference`
imports `ProjectMBridge`, `Rendering`, `ANGLERendering`, `PresetLibrary` or links `ProjectM`;
`VisualCoreTestSupport` is never a dependency of an app's main target.

## Rationale

Pure modules keep 70%+ of logic host-testable with `swift test` (Constitution IV); a binary-target
package cannot be built on the macOS host, so GPU code is isolated in the iOS-only package.

## Correction 2026-11-10 (feature 002, T-F106)

The authoritative package map is now
[`specs/002-architecture-contracts/contracts/package-map.md`](../../specs/002-architecture-contracts/contracts/package-map.md).
It supersedes the table above. It traces every module to a Phase 0 finding or gap and adds two
modules this ADR omitted: `VisualCorePersistence` (Constitution IX) and the generated `CVisualCoreGL`
table. Enforced rules, checked by `scripts/check_dependencies.py`:

* **R1** only `Harnesses/ProjectMReference/` touches reference modules (`ProjectMBridge`,
  `ANGLERendering`, `Rendering`, `PresetLibrary`, `CaptureKit`, `CaptureUI`, `AudioCore`,
  `Diagnostics`, `CANGLE`, `CFlashLimiter`) or `ProjectM.xcframework`; module names match whole.
* **R2** pure `VisualCore` sources import only Foundation-level system modules and each other.
* **R3** the target graph is acyclic.
* **R4** packages never import app or harness modules.
* **R5** `VisualCoreTestSupport` serves test targets only.

The "check_compliance.py" reference above remains for non-dependency rules (private APIs,
dlopen/dlsym, ReplayKit, signing).
