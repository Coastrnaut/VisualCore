# VisualCore support matrix (feature 010 T-F910; FR-F903)

Status as of 1.0.0-rc.1, 2026-11-10. A support claim needs evidence on the exact device and OS listed. **No
physical device has been tested yet.** Device rows stay "pending campaign II" until real D1–D3 reports exist
(constitution V, CLAUDE.md §6).

## Platforms and toolchain

| Item | Value | Evidence |
|---|---|---|
| Minimum deployment target | iOS / iPadOS 26.0 | Package manifests, `project.yml` |
| Host-testable modules | macOS 15+ (`Packages/VisualCore`) | `swift test` (host) |
| Renderer | OpenGL ES 3.0 through the owner's ANGLE fork, Metal backend (prebuilt `libEGL`/`libGLESv2`) | ADR-0002, reference pin `d93edd1` (ADR-0005) |
| Toolchain used | Xcode 27.2, Swift 6.4.2, XcodeGen 2.46.0 | `scripts/verify_environment.py` |

## Simulators: verified (development evidence, not device support)

| Runtime | Simulator | Status | Verified |
|---|---|---|---|
| iOS 27.2 | iPhone 18 Pro | verified (simulator) | VisualCoreRendering/Effects/Automation tests, Showcase, InteractiveDemo, Lumen Garden, ProjectMReference tests; automation smoke/launch/lifecycle |
| iOS 26.5 | iPhone 17 Pro Max | verified (simulator) | Same set |

## Physical devices: pending campaign II

| ID | Device | OS | Status | Evidence |
|---|---|---|---|---|
| D1 | iPhone 15 (`iPhone15,4`) | iOS 27.0.1 (24A446) | pending campaign II | none yet (campaign II) |
| D2 | iPad Pro 13-inch M5 (`iPad17,3`) | iPadOS 27.2 (24B119) | pending campaign II | none yet (campaign II) |
| D3 | iPad A16 (`iPad15,7`) | iPadOS 26.5 (23F77), never updated | pending campaign II | none yet (campaign II) |
| other | any other device | any other OS | unsupported | untested |

Other devices and OS versions are **unsupported (untested)**. The ProjectM-iOS reference app's earlier device
results describe that app, not VisualCore (CLAUDE.md §12).

## Capabilities

| Capability | Status (`verified (simulator)` / `unsupported` / not built) |
|---|---|
| Render host lifecycle, context loss and recreation, resource budgets | verified (simulator) |
| Shader library (includes, defines, file/line diagnostics) | verified (simulator) |
| Effects graph (8 pass types, pooled targets, Reduce Flashing limiter) | verified (simulator) |
| 2D/3D primitives, particles, meshes, touch input | verified (simulator) |
| AutomationRunner (`DEBUG \|\| VISUALCORE_AUTOMATION` only) | verified (simulator); zero symbols in Release verified |
| Audio acquisition and DSP features | **Not implemented** (placeholder modules). See known limitations. |
| Game-controller input | **Not implemented**. See known limitations. |
| SwiftUI render surface (`VisualCoreUI.RenderSurface`) | verified (simulator), A01-P01 |
| Parameter schemas, palettes, presets (`VisualCoreParameters`) | verified (host), A01-P01 |
| Bundled shaders, GLSL library, full-screen scenes | verified (simulator), A01-P01 |
| Scene clock (`VisualCoreSimulation.SceneClock`), parameter editing (`ParameterEditor`) | verified (host), A01-P02 |
| SwiftUI parameter panel (`VisualCoreUI.ParameterPanel`) | verified (simulator), A01-P02 |
| Versioned document store (`VisualCorePersistence.DocumentStore`) | verified (host), A01-P03 |
| Offscreen still export (`RenderHost.renderOffscreen`, `StillImageEncoder` opaque sRGB PNG, `ExportGeometry`) | verified (simulator and host), A01-P04; device size limits pending campaign II |
| System/App audio capture | unsupported (not offered). On D3 (iPadOS 26.5) it must show as unavailable. |
| Live home-screen wallpaper | unsupported (no public API) |
