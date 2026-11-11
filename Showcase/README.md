# VisualCore Showcase

A standalone iOS/iPadOS app that proves VisualCore works on its own: it renders through the shared
ANGLE-backed `RenderHost` and uses only VisualCore packages — **no ProjectM engine, preset or reference-bridge
module at compile or run time** (feature 007, ledger gate F06; spec `specs/007-showcase-app/`).

> Developer showcase, not an App Store product. Bundle id `dev.visualcore.Showcase` and the name
> "VisualCore Showcase" are owner-approved (owner ruling 2026-11-10); device signing still uses only the owner's
> local `Configs/Signing.local.xcconfig`.

## Scenes

| Id | Scene | Shows | Interaction |
|---|---|---|---|
| `gradient-texture` | Shader Gradient and Texture | bundled `gradient.vert/.frag` with `#include "common.glsl"`, bundled `checker.png` via `Texture.upload(rgba:)` | — |
| `animated-geometry` | Animated Geometry | `MeshRenderer` cube + sphere, `OrbitCamera`, `Timeline` spin and bob | drag orbits |
| `distortion` | Touch Distortion | `stripes.frag` content → target → `ripple.frag` centered on the finger | touch/drag |
| `particles` | Particle System | fixed-step `ParticleSystem`, `ParticleRenderer`, `PrimitiveRenderer` | drag spawns, pinch zooms |
| `post-processing` | Multi-pass Post-processing | `EffectScene`: colorMatrix → bloom → distort, `flashLimit` with Reduce Flashing | effect switch, drag orbits |

Every scene has a VoiceOver description and hint; the UI supports Dynamic Type, Reduce Motion (animations stop
or jump to their end) and Reduce Flashing (scene list toggle; defaults to Reduce Motion).

## Diagnostics

The overlay (toolbar: Show/Hide diagnostics) shows
`frames=… fps=… state=… gen=… live=… bytes=… peak=… warnings=… leaked=… error=…`, refreshed at 4 Hz, plus the
scene status and a **Simulate context loss** button (recreates the GL context; the scene rebuilds its resources).
Each open scene owns one render host, destroyed when you leave it.

## Build and test

```sh
xcodegen generate                                   # root project.yml → VisualCore.xcodeproj (gitignored)
xcodebuild build -project VisualCore.xcodeproj -scheme Showcase -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO
xcodebuild test  -project VisualCore.xcodeproj -scheme Showcase -destination 'platform=iOS Simulator,id=<sim>' \
    -test-timeouts-enabled YES -default-test-execution-time-allowance 180 CODE_SIGNING_ALLOWED=NO
```

The test scheme runs the hosted unit/pixel tests (`Tests/Unit`) and the repeatable smoke test (`Tests/UI`):
every scene presents frames without errors, touch, effect toggle, context loss, background/foreground, rotation,
the injected shader error (`-showcaseInjectShaderError YES`, debug builds only) and the largest text size.
Launch argument `-uitestReduceMotion YES|NO` overrides Reduce Motion.

## Dependency audit

```sh
python3 scripts/audit_showcase_dependencies.py --app <DerivedData>/Build/Products/Debug-iphonesimulator/Showcase.app
```

Checks four layers — the `Showcase` target in `project.yml`, every reachable local Swift package manifest, the
imports in `Showcase/`, and every Mach-O in the built app (`otool -L`, `nm`) — against the rule-R1 deny-list.
The owner's ANGLE libEGL/libGLESv2 frameworks are the allowed renderer baseline. Exit 0 = clean, 1 = findings,
2 = usage error. Contaminated fixtures in `scripts/fixtures/showcase_audit/` are exercised by `scripts/test_scripts.py`.

## Layout

`App/` (SwiftUI app, scene host, diagnostics, `Scenes/`), `Shaders/` (bundled GLSL ES 3.00), `Resources/`
(`checker.png`, an original generated 64×64 checkerboard), `Tests/Unit`, `Tests/UI`.
