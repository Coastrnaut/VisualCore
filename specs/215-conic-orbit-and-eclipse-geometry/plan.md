# Implementation Plan: R02-F15 — Conic orbit and eclipse geometry

**Branch**: `215-conic-orbit-and-eclipse-geometry` (spec directory only; work on `main`) | **Date**:
2026-11-19 | **Spec**: [spec.md](spec.md)

## Summary

In VisualCoreMath, beside the unchanged `KeplerOrbit`: a `KeplerSolver` for the elliptic (reusing
`KeplerOrbit.eccentricAnomaly`), hyperbolic and parabolic Kepler equations; a `ConicOrbit` (elliptic, parabolic,
hyperbolic) giving an `OrbitState` (position, velocity, true anomaly) at any time with an adapter to `KeplerOrbit`; a
drift-free `PhaseStepper` with phases and `Passage` listings; `DiskOverlap` (analytic lens area); and `EclipseGeometry`
classifying an observer's view as an `EclipseClass` in an `EclipseVerdict`. `ConicOrbit` is `Codable` (schema 1).
Failures are `OrbitError` with `r2-f15.*` codes. Research: [research.md](research.md). Data:
[data-model.md](data-model.md). API: [contracts/api.md](contracts/api.md). Quickstart: [quickstart.md](quickstart.md).

## Technical Context

**Language/Version**: Swift 6. **Primary dependencies**: VisualCoreMath only (`KeplerOrbit`, `Vec3`), which depends on
nothing. No new module, dependency, GPU, GLSL or Objective-C++ code (nothing renders; the consumers draw orbits and disks
with the existing mesh and SDF paths).
**Seeds**: VisualCoreMathTests has no seeded generator, so each test file keeps a `fileprivate` SplitMix64-style fixture
generator seeded 2_015 (no public name).
**Testing**: `swift test --package-path Packages/VisualCore`; ExperiencesCreative on sim-27.2 and VisualCoreRendering on
sim-27.2 and sim-26.5 as regression (Solar System Explorer uses its own `OrbitElements`, unchanged); reference regression
in two chunks; script tests.
**Performance**: bounded by arithmetic — at most 32 + 8 Newton steps elliptic, 64 hyperbolic, closed form parabolic;
overlap and classification are a few transcendental calls; passage listings ≤ 1,000,000. 1,000-case fixtures take
milliseconds; each test < 10 s and light (the R02-F05 timed budget test runs in the same process).
**Constraints**: additive; `KeplerOrbit` and its tests unchanged; ticks ≤ 1,000,000,000.

No NEEDS CLARIFICATION remains.

## Constitution Check

| Principle | Result |
|---|---|
| I Proven renderer only | PASS — no rendering. |
| II App-neutral API · II-a reference | PASS — generic geometry, no body data; `///`; API baseline; reference regression. |
| III GPU lifecycle | PASS — none. |
| IV Host-testable | PASS — pure, host-tested. |
| IX Bounded input | PASS — bounded solver steps, ticks ≤ 1e9, passages ≤ 1e6, finite inputs checked. |
| X Licensing and provenance | PASS — textbook two-body formulas (Kepler, Barker), lens area; original code, no data. |
| XI Stable identity | PASS — schema 1 stored form; newer refused. |

Post-design re-check: PASS.

## Project Structure

```text
Packages/VisualCore/Sources/VisualCoreMath/OrbitError.swift        new  OrbitError + reasonCode
Packages/VisualCore/Sources/VisualCoreMath/KeplerSolver.swift      new  KeplerSolver (elliptic reuse, hyperbolic, parabolic)
Packages/VisualCore/Sources/VisualCoreMath/ConicOrbit.swift        new  ConicKind, ConicOrbit, OrbitState, Codable schema 1
Packages/VisualCore/Sources/VisualCoreMath/PhaseStepper.swift      new  PhaseStepper, Passage
Packages/VisualCore/Sources/VisualCoreMath/DiskOverlap.swift       new  DiskOverlap
Packages/VisualCore/Sources/VisualCoreMath/EclipseGeometry.swift   new  EclipseBody, EclipseClass, EclipseVerdict, EclipseGeometry
Packages/VisualCore/Tests/VisualCoreMathTests/KeplerSolverTests.swift, ConicOrbitTests.swift, PhaseStepperTests.swift,
  DiskOverlapTests.swift, EclipseGeometryTests.swift, ConicOrbitCodingTests.swift   new
docs/architecture/conic-orbits.md (new), docs/api/visualcore-public-api.txt, Packages/VisualCore/README.md, docs/catalog/shared-feature-map.json (lead)
```

**Migration**: none of existing data. **Rollback**: revert the commits (additive files only).

## Parallel work

Agent A: OrbitError, KeplerSolver, ConicOrbit (+ coding) and tests. Agent B: DiskOverlap, EclipseGeometry and tests
(uses only `Vec3` and OrbitError's cases from contracts/api.md; lead merges after A). Agent C (after A): PhaseStepper and
tests. Lead: docs, API baseline, runs, commits.
