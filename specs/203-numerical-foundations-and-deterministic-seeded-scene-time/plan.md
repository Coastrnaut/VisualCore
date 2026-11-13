# Implementation Plan: R02-F03 — Numerical foundations and deterministic seeded scene time

**Branch**: `203-numerical-foundations-and-deterministic-seeded-scene-time` (spec directory only; work on `main`) | **Date**: 2026-11-13 | **Spec**: [spec.md](spec.md)

## Summary

Reuse the existing fixed-step clocks, seeded generators and scenario replay unchanged (section 13: reuse) and add the
missing pure helpers: named sub-seed derivation, owned shuffle/pick/weighted choice with a fixed draw count, a
versioned saved generator state, a CPU twin of the shader hash with a simulator parity test, numeric hygiene helpers,
and one determinism and conventions document with a name check. Audit: [research.md](research.md) §0.

## Technical Context

**Language/Version**: Swift 6 (language mode 6, typed throws); Python 3 for the document name check.
**Primary Dependencies**: none new; `VisualCoreSimulation` and `VisualCoreMath` (pure, no UIKit, no GL).
**Storage**: none; the saved generator state is a Codable value embedded by consumers in their own snapshots.
**Testing**: `swift test --package-path Packages/VisualCore` (host); `VisualCoreRenderingTests` on the iOS 27.2 and
26.5 simulators for the parity test; script tests for the name check. No app interface change.
**Target Platform**: iOS 26+ app; host macOS for pure tests.
**Performance Goals**: every new test under 1 s on the host (SC-R02F03-008); derivation and index mapping are
O(1), shuffle O(n).
**Constraints**: existing generator outputs and committed digests byte-identical (FR-R02F03-002); short tests.
**Scale/Scope**: 4 new source files, 4 new test files, 1 document, 1 script.

## Constitution Check

| Principle | Result |
|---|---|
| I Proven renderer only | PASS — parity test uses the existing ANGLE path through `FullScreenShaderScene`. |
| II App-neutral public API | PASS — generic numeric helpers, no app types; `///` docs and API baseline update. |
| II-a Preserve the reference | PASS — seven-step ProjectM reference regression in two chunks after the change. |
| III GPU lifecycle and threads | PASS — pure value types, `Sendable`, no shared state; the GPU test uses the existing host lifecycle. |
| IV Host-testable, test-first | PASS — golden tests written before each helper. |
| V Implementation before devices | PASS — no device step. |
| VI Evidence over assertion | PASS — golden values committed; every task ticked from a run. |
| VII Native, accessible UI | N/A — no interface. |
| VIII Public APIs, privacy | PASS — Swift standard library only. |
| IX Bounded untrusted input | PASS — saved state and weights validated, typed errors. |
| X Licensing and provenance | PASS — public-domain algorithms, implemented here, credited in comments. |
| XI One app | PASS — package additions only. |
| XII No advertising | PASS. |
| XIII Code-driven visuals | PASS. |

Post-design re-check: unchanged.

## Project Structure

```text
Packages/VisualCore/Sources/VisualCoreSimulation/SeedDerivation.swift          new   SeedDerivation; SeededRandom.init(seed:label:), init(seed:index:)
Packages/VisualCore/Sources/VisualCoreSimulation/SeededRandom+Choice.swift     new   index(below:), shuffle, shuffled, pick, weightedIndex, RandomChoiceError
Packages/VisualCore/Sources/VisualCoreSimulation/SeededRandom+State.swift      new   SeededRandom.State, state, init(restoring:), RandomStateError
Packages/VisualCore/Sources/VisualCoreSimulation/SeededRandom.swift            modify only if the state extension needs internal access to s0…s3 (fileprivate → internal), no output change
Packages/VisualCore/Sources/VisualCoreMath/ShaderHash.swift                    new   pcg, hash11, hash21, hash22
Packages/VisualCore/Sources/VisualCoreMath/NumericHygiene.swift                new   finite, normalizedAngle, wrapped, quantized, NumericError
Packages/VisualCore/Tests/VisualCoreSimulationTests/SeedDerivationTests.swift  new
Packages/VisualCore/Tests/VisualCoreSimulationTests/SeededRandomChoiceTests.swift new
Packages/VisualCore/Tests/VisualCoreSimulationTests/SeededRandomStateTests.swift new
Packages/VisualCore/Tests/VisualCoreMathTests/ShaderHashTests.swift            new
Packages/VisualCore/Tests/VisualCoreMathTests/NumericHygieneTests.swift        new
Packages/VisualCoreRendering/Tests/VisualCoreRenderingTests/ShaderHashParityTests.swift new  (simulator, 27.2 and 26.5)
docs/architecture/determinism.md                                               new
scripts/check_doc_names.py, scripts/tests/test_check_doc_names.py              new
docs/api/visualcore-public-api.txt                                             modify (check_public_api.py --update)
Packages/VisualCore/README.md                                                  modify (section "Numerical foundations (feature 203, R02-F03)")
docs/catalog/shared-feature-map.json, Auto-Creator.md §13                      modify (as built)
```

**Dependency direction**: VisualCoreSimulation → VisualCoreMath (existing, );
the new files use only the standard library within their module. VisualCoreRenderingTests already depends on the
VisualCoreMath product (), so no manifest change is needed.

**Public API**: see [contracts/api.md](contracts/api.md). **Data**: [data-model.md](data-model.md).

**Lifecycle and threads**: all new types are value types or caseless enums, `Sendable`, without global state; a
generator is owned by one simulation and advanced on its thread, as today.

**Schemas and migrations**: `SeededRandom.State` version 1; restoring any other version throws. No existing schema
changes; consumers that embed the state version their own snapshots (MigrationChain), as today.

## Tests by layer

- Host: the five new test files (golden vectors, edge values, ≤ 10,000 draws) plus the existing `SeededRandomTests`
  unchanged.
- Package tests on simulators: `VisualCoreRendering` package on sim-27.2 and sim-26.5 (parity test included).
- App: no interface change; A01–A04 verification on iOS 27 proves committed digests unchanged (FR-R02F03-002).

## Commands

See [quickstart.md](quickstart.md); evidence via `python3 scripts/migration_ledger.py run-check --gate R02-F03 --name <check> -- <command>`.

## Rollback

Additive files only; revert the feature's commits. No data format of existing saved state changes.

## Parallel work (one writer per file)

Agent A: SeedDerivation + tests. Agent B: Choice + tests. Agent C: State + tests (sole writer of `SeededRandom.swift`
if access must change). Agent D: ShaderHash + tests + parity test. Agent E: NumericHygiene + tests. Agent F: document
+ name-check script + test. Lead: API baseline, README, section 13, builds, regression, ledger.

## Complexity Tracking

None.
