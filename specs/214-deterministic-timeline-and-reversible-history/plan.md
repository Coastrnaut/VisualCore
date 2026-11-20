# Implementation Plan: R02-F14 — Deterministic timeline and reversible history

**Branch**: `214-deterministic-timeline-and-reversible-history` (spec directory only; work on `main`) | **Date**:
2026-11-19 | **Spec**: [spec.md](spec.md)

## Summary

In VisualCoreSimulation: an editable `EventLog` of commands by step, a bounded `SnapshotRing`, a `ReplayHash` chain over
every step's checksum, and a `ReversibleTimeline` that steps any `FixedStepSimulation` value type, seeks backwards by
restoring the nearest snapshot and replaying, and recomputes after edits. In VisualCoreExperience: the stored form
`TimelineRunDocument` (schema 1) with a `MigrationChain` step from schema 0, verified by replaying to its hash. No
change to the existing runner, clock, stream, timeline or snapshot types. Research: [research.md](research.md). Data:
[data-model.md](data-model.md). API: [contracts/api.md](contracts/api.md). Quickstart: [quickstart.md](quickstart.md).

## Technical Context

**Language/Version**: Swift 6. **Primary dependencies**: VisualCoreMath (`StableHash.sha256`), VisualCoreSimulation
(`FixedStepSimulation`, `FixedStepClock`), VisualCorePersistence (`MigrationChain`), VisualCoreExperience (home of the
document). No new module, dependency, GPU or Objective-C++ code.
**Seeds**: fixtures use `SeededRandom` (VisualCoreSimulation) with seed 2_014 for the test simulation and commands.
**Testing**: `swift test --package-path Packages/VisualCore`; ExperiencesCreative on sim-27.2 and VisualCoreRendering on
sim-27.2 and sim-26.5 as regression (nothing renders); reference regression in two chunks; script tests.
**Performance**: bounded by arithmetic — a seek replays at most interval − 1 = 63 steps from a kept snapshot (or from the
start when dropped); 1,000-step test runs with a toy simulation take milliseconds; each test < 10 s and light.
**Constraints**: additive; existing types and tests unchanged; the simulation must be a value type (copy = snapshot).

No NEEDS CLARIFICATION remains.

## Constitution Check

| Principle | Result |
|---|---|
| I Proven renderer only | PASS — no rendering. |
| II App-neutral API · II-a reference | PASS — generic over any simulation and command; `///`; API baseline; reference regression. |
| III GPU lifecycle | PASS — none. |
| IV Host-testable | PASS — pure, host-tested. |
| IX Bounded input | PASS — steps ≤ 10,000,000, log ≤ 1,048,576, ring 1…1,024, interval 1…65,536. |
| X Licensing and provenance | PASS — SHA-256 (FIPS 180-4) via the existing helper; original code. |
| XI Stable identity | PASS — schema 1 with a migration from schema 0; newer refused. |

Post-design re-check: PASS.

## Project Structure

```text
Packages/VisualCore/Sources/VisualCoreSimulation/TimelineError.swift        new  TimelineError + reasonCode
Packages/VisualCore/Sources/VisualCoreSimulation/EventLog.swift             new  EventLog<Command>
Packages/VisualCore/Sources/VisualCoreSimulation/SnapshotRing.swift         new  SnapshotRing<State>
Packages/VisualCore/Sources/VisualCoreSimulation/ReplayHash.swift           new  ReplayHash
Packages/VisualCore/Sources/VisualCoreSimulation/ReversibleTimeline.swift   new  ReversibleTimeline<Simulation, Command>
Packages/VisualCore/Sources/VisualCoreExperience/TimelineRunDocument.swift  new  TimelineRunDocument (schema 1, migration from 0)
Packages/VisualCore/Tests/VisualCoreSimulationTests/EventLogTests.swift, SnapshotRingTests.swift, ReplayHashTests.swift, ReversibleTimelineTests.swift   new
Packages/VisualCore/Tests/VisualCoreExperienceTests/TimelineRunDocumentTests.swift   new
docs/architecture/reversible-timeline.md (new), docs/api/visualcore-public-api.txt, Packages/VisualCore/README.md, docs/catalog/shared-feature-map.json (lead)
```

**Migration**: none of existing data. **Rollback**: revert the commits.

## Parallel work

Agent A: TimelineError, EventLog, SnapshotRing, ReplayHash and tests. Agent B (after A): ReversibleTimeline and tests.
Agent C (after B): TimelineRunDocument and tests. Lead: docs, API baseline, runs, commits.
