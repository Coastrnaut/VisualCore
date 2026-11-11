# Lumen Garden — the second VisualCore consumer

A small, calm game that proves VisualCore is a reusable framework and not a refactoring of ProjectM (feature 009,
ledger gate F08). Tap the night field to plant seeds; after four seconds they bloom and shed light; tap a bloom to
harvest it (+1); drag to blow a breeze through the drifting light.

## What it uses (all documented VisualCore APIs)

| Capability | VisualCore API |
|---|---|
| Rendering host, lifecycle, touches | `RenderHost`, `RenderScene`, `RenderHost.pointerHandler` |
| Resources and shaders | `ResourceRegistry.program(vertex:fragment:library:vertexName:fragmentName:)`, `ShaderLibrary`, bundled `Shaders/field.vert/.frag` |
| 2D primitives and particles | `SceneNode`, `PrimitiveRenderer`, `ParticleSystem`, `Emitter`, `ParticleRenderer` |
| Effects | `EffectScene` with a bloom glow (`EffectGraphDescription`) |
| Input and coordinates | `PointerTracker`, `TapRecognizer`, `DragRecognizer`, `ViewMetrics`, `Camera2D` |
| Deterministic timing | `FixedStepClock`, `SeededRandom` (in `GardenKit`) |

Game rules live in the host-tested local package `GardenKit` (`swift test --package-path Harnesses/SecondConsumer/GardenKit`),
the pattern the 25 apps follow: domain logic in a package, rendering in the app.

## Checks (run in every build)

```sh
python3 scripts/audit_showcase_dependencies.py --spec Harnesses/SecondConsumer/SecondConsumer.yml --target SecondConsumer --sources Harnesses/SecondConsumer
python3 scripts/check_documented_api.py --sources Harnesses/SecondConsumer
```

The first proves there is no ProjectM engine, preset or bridge dependency (project spec, packages, imports, built
binary). The second proves every VisualCore type or free function the game references is named in a VisualCore
README or feature contract. Both also run as a post-build phase of the app target, so a violation fails the build.

## Build and smoke test

```sh
xcodegen generate --spec Harnesses/SecondConsumer/SecondConsumer.yml
xcodebuild test -project Harnesses/SecondConsumer/SecondConsumer.xcodeproj -scheme SecondConsumer \
  -destination 'platform=iOS Simulator,id=<sim>' -test-timeouts-enabled YES -default-test-execution-time-allowance 180 CODE_SIGNING_ALLOWED=NO
```

The smoke test plants, blooms, harvests (score 1), blows a breeze, rotates, and checks Reduce Motion (no bursts).
Harness only (`dev.visualcore.harness.SecondConsumer`); no storage, network or permissions.
