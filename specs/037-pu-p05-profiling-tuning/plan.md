# Implementation Plan: Particle Universe — Phase 05 Profiling and low-end device tuning

**Branch**: `037-pu-p05-profiling-tuning` (spec directory only; work on `main`) | **Date**: 2026-11-13 | **Spec**: [spec.md](spec.md)

## Summary

Prove bounded resume through the real session, add a pure frame-time detail controller used by the presenter (drawing
only), and record a simulator-labelled profile plus a budgets entry. Research: [research.md](research.md).

## Technical Context

**Language**: Swift 6. **Dependencies**: existing packages (no VisualCore change). **Storage**: none. **Testing**:
ExperiencesCreative package tests on sim-27.2 and sim-26.5; PU interface chunks j2–j4 on the iOS 27.2 phone.
**Performance**: unit tests < 10 s. **Constraints**: detail control never touches the simulation; device numbers are
{device}.

## Constitution Check

I renderer PASS · II/II-a no VisualCore change PASS · III threads: presenter on the main actor, monitor is a value type
PASS · IV test-first PASS · V devices: {device} task PASS · VI evidence labelled simulator PASS · VII UI unchanged PASS ·
VIII–XIII PASS.

## Project Structure

```text
PU/Core/FrameBudgetMonitor.swift                         new
PU/CoreTests/FrameBudgetMonitorTests.swift               new
PU/Experience/ParticlePresenter.swift                    modify  monitor in draw; coarser of host and monitor tier
PU/ExperienceTests/ParticleResumeBoundTests.swift        new
PU/ExperienceTests/ParticleProfileTests.swift            new
docs/performance/budgets.md                              modify  Particle Universe row
```

Dependency: Core ← Presenter. Lifecycle: monitor restarts on pause and on scene-phase changes. Rollback: revert commits.

## Parallel work

Agent A: FrameBudgetMonitor + tests + presenter hook. Agent B: resume and profile tests. Lead: budgets row, runs, ticks.
