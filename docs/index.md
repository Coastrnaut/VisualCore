# VisualCore documentation

VisualCore is a reusable OpenGL ES (ANGLE/Metal) rendering framework for iOS and iPadOS apps. It is the base for the
Showcase and the 25 VisualCore apps. Start with [Getting started](getting-started.md).

## Use the framework

| Topic | Document |
|---|---|
| Getting started (modules, first scene, samples) | [getting-started.md](getting-started.md) |
| Pure modules: math, simulation, scenes, shader source, effects graph, diagnostics | [Packages/VisualCore/README.md](../Packages/VisualCore/README.md) |
| Rendering: RenderHost, resources, shaders, effects, drawing, touches, automation | [Packages/VisualCoreRendering/README.md](../Packages/VisualCoreRendering/README.md) |
| Public API baseline (every public declaration) | [api/visualcore-public-api.txt](api/visualcore-public-api.txt) |
| Color space | [rendering/color-space.md](rendering/color-space.md) |

## Samples

| Sample | What it shows |
|---|---|
| [Showcase](../Showcase/README.md) | Five scenes: bundled shaders and texture, 3D geometry, touch distortion, particles, multi-pass effects. Also diagnostics, context loss and accessibility. |
| [Lumen Garden](../Harnesses/SecondConsumer/README.md) | A second, independent consumer built only from documented APIs |
| [InteractiveDemo](../Harnesses/InteractiveDemo/InteractiveDemo.yml) | Input, animation and particles |
| [ProjectMReference](../Harnesses/ProjectMReference/README.md) | Reference adapter: the ProjectM engine on a VisualCore host (harness only, not distributed) |

## Release

| Topic | Document |
|---|---|
| Support matrix (what is verified where) | [release/support-matrix.md](release/support-matrix.md) |
| Known limitations | [release/known-limitations.md](release/known-limitations.md) |
| Release notes | [release/](release/) |
| Performance baselines (host and simulator, not device evidence) | [performance/README.md](performance/README.md) |
| Third-party notices and LGPL analysis | [legal/THIRD_PARTY_NOTICES.md](legal/THIRD_PARTY_NOTICES.md), [legal/lgpl-analysis.md](legal/lgpl-analysis.md) |

## Architecture and decisions

- [Architecture](architecture/visualcore-architecture.md), [gap analysis](architecture/visualcore-gap-analysis.md),
  [migration log](architecture/migration-log.md)
- Decisions: [ADR-0001](decisions/ADR-0001-ledger-and-repository-state.md) … [ADR-0006](decisions/ADR-0006-unbuilt-readme-modules.md)
- Package map and dependency rules: [package-map](../specs/002-architecture-contracts/contracts/package-map.md)
- Feature specifications: [`specs/`](../specs/)

## Checks

`python3 scripts/release_check.py --list` lists every release gate. Run them all with
`python3 scripts/release_check.py`.
