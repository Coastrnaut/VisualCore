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
