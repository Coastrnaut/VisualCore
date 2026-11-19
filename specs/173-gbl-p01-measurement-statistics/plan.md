# Implementation Plan: Graphics Benchmark Lab — Phase 01 Measurement methodology and fixture statistics

**Branch**: `173-gbl-p01-measurement-statistics` (spec directory only; work on `main`) | **Date**: 2026-11-19 | **Spec**: [spec.md](spec.md)

## Summary

A pure, pending core for Graphics Benchmark Lab: the three built-in benchmark cases with their caps and fingerprints,
the frame sample and its validation, the nearest-rank statistics with quality flags, and the versioned run file. It is
tested by `swift test`-style package tests on the simulator with committed fixtures, and inside a running render host
to prove that none of it creates a graphics resource. Gaps G-MODEL and G-STATS close.

Research: [research.md](research.md). Data: [data-model.md](data-model.md). Contract:
[contracts/core.md](contracts/core.md). Quickstart: [quickstart.md](quickstart.md).

## Technical Context

- **Language:** Swift 6 (strict concurrency), Swift Testing.
- **Dependencies:** VisualCoreExperience (`DigestBuilder`, `StateDigest`) and VisualCorePersistence (`MigrationChain`)
  for the core; the core tests also VisualCoreRendering (`RenderHost`, `ResourceRegistry.stats`).
- **Storage:** none in this phase (the run file is encoded and decoded in memory; storage is A24-P04).
- **Testing:** `GraphicsBenchmarkLabCoreTests` on sim-27.2; committed JSON fixtures in `CoreTests/Fixtures`.
- **Performance:** each unit test under 10 s; the largest fixture is 20,000 samples.
- **Constraints:** no graphics call, no clock, no UIKit or SwiftUI in the core; no VisualCore change.

No NEEDS CLARIFICATION remains.

## Constitution Check

| Principle | Result |
|---|---|
| I | PASS: no renderer change |
| II | PASS: reused `DigestBuilder`, `MigrationChain`, `RenderHost`, `ResourceRegistry.stats`; statistics app-local by decision (A24-P00 clarification Q3) |
| II-a | PASS: no VisualCore change, so no regression rerun |
| III | PASS: the core holds no GL state |
| IV | PASS: pure and tested with fixtures |
| V | PASS: no device step |
| VI | PASS: synthetic fixtures with hand-computed expectations; no benchmark number |
| VII–X | PASS |
| XI | PASS: a pending core in the one app's package; no target, no registration |
| XII, XIII | PASS: no asset |

A24 rules (constitution 2.20.0): measurement truth pure; GPU percentile only with a GPU time on every sample;
distributions, not averages; bounded caps; refusal of non-finite and newer files. PASS. Post-design: PASS.

## Project Structure

```text
Packages/ExperiencesCreative/Package.swift                                              modify  GraphicsBenchmarkLabCore, GraphicsBenchmarkLabCoreTests
Packages/ExperiencesCreative/GraphicsBenchmarkLab/Core/BenchmarkCase.swift              new     Workload, WorkloadConfig, RunPlan, BenchmarkCase, CaseLimits, the built-in cases, fingerprint
Packages/ExperiencesCreative/GraphicsBenchmarkLab/Core/FrameSample.swift                new     RunPhase, FrameSample, SampleLimits, sample-set validation
Packages/ExperiencesCreative/GraphicsBenchmarkLab/Core/Statistics.swift                 new     Percentiles (nearest rank), Distribution, Summary, QualityFlag, Summary.make
Packages/ExperiencesCreative/GraphicsBenchmarkLab/Core/BenchmarkRun.swift               new     RunState, BenchmarkRun, RunDocument (encode, decode, refusals, migration hook)
Packages/ExperiencesCreative/GraphicsBenchmarkLab/CoreTests/{CaseTests,SampleTests,StatisticsTests,
  FixtureTests,RunDocumentTests,HostCountTests,FixtureSupport}.swift                    new
Packages/ExperiencesCreative/GraphicsBenchmarkLab/CoreTests/Fixtures/*.json             new     sample sets with expected summaries
docs/apps/graphics-benchmark-lab/visualcore-contract.json (G-MODEL, G-STATS closed)     modify
docs/apps/graphics-benchmark-lab/README.md (the core's sources)                         modify
```

- **Dependency direction:** core tests → core → VisualCore pure products; the core tests also → VisualCoreRendering.
- **Lifecycle:** the core has none; the A24-P03 runner fills samples and calls `Summary.make`.
- **Migration:** schema 1 only; `MigrationChain(currentVersion: 1)` is the hook. **Rollback:** revert the commits.
- **Build commands:** see [quickstart.md](quickstart.md).

## Parallel work

- **Agent M:** `BenchmarkCase.swift`, `FrameSample.swift`, `BenchmarkRun.swift` and their tests (CaseTests,
  SampleTests, RunDocumentTests), against [contracts/core.md](contracts/core.md).
- **Agent S:** `Statistics.swift`, the fixtures and their tests (StatisticsTests, FixtureTests, FixtureSupport,
  HostCountTests), against the same contract.
- **Lead:** Package.swift, the contract, the README, runs and commits.
