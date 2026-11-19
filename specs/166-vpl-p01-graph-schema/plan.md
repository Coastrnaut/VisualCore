# Implementation Plan: Visual Programming Lab — Phase 01 Graph schema and type-checking fixtures

**Branch**: `166-vpl-p01-graph-schema` (spec directory only; work on `main`) | **Date**: 2026-11-18 | **Spec**: [spec.md](spec.md)

## Summary

This phase adds Visual Programming Lab's pending core and closes G-MODEL and G-TYPES:
- **Model:** `VisualGraph` (nodes, connections, output) with `GraphLimits`.
- **Library:** `NodeKind` and `NodeLibrary`, the seven kinds with their typed ports and bounded parameters.
- **File:** `GraphDocument` (kind `a23.visual-graph`, schema 1) with its refusals, migration hook and fingerprint.
- **Checker:** `GraphChecker` returns the order and the nodes reaching the output, or every refusal with its node,
  port and cycle path.
- **Proof:** the core tests check every fixture inside a running `RenderHost` with its resource counts unchanged.

Research: [research.md](research.md). Data: [data-model.md](data-model.md). Contract:
[contracts/core.md](contracts/core.md). Quickstart: [quickstart.md](quickstart.md).

## Technical Context

- **Language:** Swift 6.
- **Dependencies:**
  - the core: `VisualCoreParameters` (`ParameterDefinition`), `VisualCorePersistence` (`MigrationChain`,
    `MigrationError`) and `VisualCoreExperience` (`DigestBuilder`, `StateDigest`, `DigestError`), all pure;
  - the core tests: also `VisualCoreRendering` (`RenderHost(scene:)`, `RenderScene`, `RenderContext`,
    `ResourceRegistry.stats`).
- **Testing:** `VisualProgrammingLabCoreTests` on sim-27.2 through `scripts/xcodebuild_package.py`; each test under
  10 s.
- **Performance:** checking a 32-node, 64-connection graph is linear in nodes plus connections; no wall-clock
  assertion.
- **Constraints:**
  - the core is pure: no GL, clock, network, UIKit or SwiftUI;
  - no VisualCore change and no registration.

No NEEDS CLARIFICATION remains.

## Constitution Check

| Principle | Result |
|---|---|
| I | PASS: the host-count test runs on the host's own context; the core issues no GL call |
| II | PASS: reuses `ParameterDefinition`, `MigrationChain`, `DigestBuilder`; nothing copied into VisualCore |
| IV | PASS: graph, library, file and checker are pure and tested without the GPU |
| VI | PASS: simulator tests only; no device claim |
| XIII | PASS: no assets |
| A23 (2.19.0) | PASS: pure graph truth; validation before GPU work; caps on nodes and connections; no feedback nodes; offline |

Post-design: PASS.

## Project Structure

```text
Packages/ExperiencesCreative/Package.swift                                          modify  VisualProgrammingLabCore, VisualProgrammingLabCoreTests
Packages/ExperiencesCreative/VisualProgrammingLab/Core/ValueType.swift              new     value types, port direction, port declarations
Packages/ExperiencesCreative/VisualProgrammingLab/Core/NodeLibrary.swift            new     NodeKind and the seven kinds' ports and parameters
Packages/ExperiencesCreative/VisualProgrammingLab/Core/VisualGraph.swift            new     NodeID, CanvasPoint, GraphNode, GraphEdge, VisualGraph, GraphLimits
Packages/ExperiencesCreative/VisualProgrammingLab/Core/GraphDocument.swift          new     file codec, refusals, migration hook, fingerprint
Packages/ExperiencesCreative/VisualProgrammingLab/Core/GraphChecker.swift           new     staged checks, Kahn order, cycle path, output rules
Packages/ExperiencesCreative/VisualProgrammingLab/CoreTests/{LibraryTests,GraphModelTests,DocumentTests,
  TypeCheckTests,CycleTests,OutputTests,HostCountTests,GraphFixtures}.swift        new
docs/apps/visual-programming-lab/visualcore-contract.json (G-MODEL, G-TYPES closed; rows updated)   modify
docs/apps/visual-programming-lab/README.md (the core's sources)                     modify
```

- **Dependency direction:** core tests → core → VisualCore pure products; the core tests also → VisualCoreRendering.
- **Lifecycle:** the core has none. The A23-P03 presenter owns compiling in the host's context after a graph passes.
- **Migration:** schema 1 only; `MigrationChain(currentVersion: 1)` is the hook. **Rollback:** revert the commits.
- **Build commands:** see [quickstart.md](quickstart.md).

## Parallel work

- **Agent M:** `ValueType.swift`, `NodeLibrary.swift`, `VisualGraph.swift`, `GraphDocument.swift` and their tests
  (LibraryTests, GraphModelTests, DocumentTests).
- **Agent C:** `GraphChecker.swift` and its tests (TypeCheckTests, CycleTests, OutputTests, GraphFixtures,
  HostCountTests), against the declarations in [contracts/core.md](contracts/core.md).
- **Lead:** Package.swift, the contract, the README, runs and commits.
