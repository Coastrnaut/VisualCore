# Feature Specification: Graphics Benchmark Lab — Phase 03 Runner/profiler and capability probing

**Feature Branch**: `175-gbl-p03-runner-probe` (spec directory only; work stays on `main`)

**Created**: 2026-11-19

**Status**: Draft

**Ledger gate**: A24-P03 (legacy ledger) · ID namespace FR-A24-3##, SC-A24-3##, T-A24-3##

**Input**: User description: archived manual `apps/24-graphics-benchmark-lab.md` §9 Phase 03 `/speckit-specify` prompt
(verbatim in the invocation).

Canonical overrides:
- **Phase gates (manual §9 Phase 03):**
  - MVP: frame-time percentiles, CPU submit time and an optional GPU timer where it is supported. Here the run gets its
    caps, stop and dropped-frame rule, the renderer's facts reach the experience, a capability probe decides whether a
    GPU timer is used, and a supported timer measures each measured frame's GPU time;
  - regression fixture: the measurement excludes the warm-up interval (and the cool-down);
  - graphics context ownership stays solely in the audited VisualCore host.
- **Gaps built here:** G-RUNNER, G-REPORT (app-local), U-RENDERINFO and U-GPUTIMER (VisualCoreRendering) of
  `docs/apps/graphics-benchmark-lab/visualcore-contract.json`.
- **VisualCore changes:** U-RENDERINFO and U-GPUTIMER change VisualCoreRendering, each with `///` documentation, tests,
  the public-API baseline update, both READMEs and the seven-step reference regression in two chunks (Principle II-a).
- **Probe fact (2026-11-19):** on the iOS 27.2 simulator the renderer's extension list contains
  `GL_EXT_disjoint_timer_query` (ANGLE 2.1.1, git hash 29d18232e803, Metal renderer), so U-GPUTIMER is built, not closed
  as unsupported. Simulator GPU times are never device evidence.
- **No benchmark number** is claimed; no device run before ImplementationLock-100. Follow
  `specs/174-gbl-p02-workload-renderers`.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - The run measures only the measurement window (Priority: P1) 🎯

A person runs a case. Warm-up and cool-down frames are drawn but not measured; the summary reports frame-interval and
CPU-time percentiles only over the measurement window, and the counts of excluded frames.

**Why this priority**: the phase's regression fixture.

**Independent Test**: drive a run with synthetic frame times and read the summary.

**Acceptance Scenarios**:

1. **Given** a run fed frames through warm-up, measurement and cool-down, **When** it finishes, **Then** every
   percentile is taken only from measured frames and the warm-up and cool-down counts match the frames fed.
2. **Given** a stop during warm-up, **When** the run ends, **Then** it is "Stopped" with no measured frames and the
   summary says so.

---

### User Story 2 - A GPU time only from a confirmed timer (Priority: P1)

Where the renderer offers a timer, each measured frame's GPU time comes from it; a frame whose timer result is
disjoint or not yet available has no GPU time. Where there is no timer, there is never a GPU time.

**Why this priority**: the MVP's optional supported GPU timer, and the constitution's provenance rule.

**Independent Test**: probe the renderer; time a known draw; force the unsupported path.

**Acceptance Scenarios**:

1. **Given** the simulator's renderer, **When** the probe runs, **Then** it reports the timer as supported and names
   the extension.
2. **Given** a supported timer, **When** a known draw is timed, **Then** a non-disjoint result is a finite,
   non-negative number of milliseconds within the sample cap.
3. **Given** a probe that reports no timer, **When** a run is recorded, **Then** no sample has a GPU time and the summary
   says GPU time is not available.

---

### User Story 3 - The report says where a result came from (Priority: P1)

A finished run carries a report: device model, OS version, app version and build, renderer and GL version strings,
quality tier, thermal state and Low Power Mode at the start and end, the timing source of each measure, and the case and
its fingerprint. Every field comes from a public source; nothing identifies the person or the device uniquely.

**Why this priority**: measurement provenance (constitution A24); version 0.1 feature 04.

**Independent Test**: build a report in a test host; validate it; scan the sources.

**Acceptance Scenarios**:

1. **Given** a run in the host, **When** its report is built, **Then** every field is filled from a public source and
   the timing sources read "frame time" and "presenter CPU time" (and "GPU timer" only when the probe confirms it).
2. **Given** the experience's sources, **When** they are scanned, **Then** no private API and no unique device
   identifier is used.

---

### User Story 4 - Bounded and stoppable (Priority: P2)

A run never lasts longer than its plan's 210 s cap, stops at once on request, ends as interrupted on a stall, resize,
context rebuild or leaving, and flags frames it judges dropped by a documented rule.

**Independent Test**: drive the runner with synthetic times; stop mid-run; feed a late frame.

**Acceptance Scenarios**:

1. **Given** a run, **When** stop is requested, **Then** no further sample is recorded after the next frame.
2. **Given** a measured frame whose interval exceeds the documented dropped-frame threshold, **Then** it is flagged
   dropped and counted, and its interval still counts.

### Edge Cases

- **A timer result not yet available when the frame ends:** read on a later frame; if still not available when the run
  ends, that frame has no GPU time.
- **A disjoint event (the GPU was interrupted):** every pending timer result is discarded; those frames have no GPU time.
- **A context rebuild:** timer queries of the old context are never read; the run ends as interrupted.
- **Thermal state changes during a run:** both the start and end states are recorded and the report flags the change.
- **Low Power Mode on:** recorded; the run still measures.
- **The extension missing on a device:** the probe reports unsupported and nothing is timed.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-A24-301**: The runner MUST measure only measurement-phase frames; warm-up and cool-down frames are drawn,
  counted and excluded.
- **FR-A24-302**: The runner MUST stop at once on request, end as interrupted on a stall, resize, rebuild or leaving,
  bound every run by its plan, and flag dropped frames by a documented rule.
- **FR-A24-303**: VisualCore MUST give a presenter a read-only copy of the renderer's capabilities (version strings,
  renderer, extension list, limits), refreshed after a context rebuild.
- **FR-A24-304**: A capability probe MUST decide whether a GPU timer is supported from the renderer's extension list.
- **FR-A24-305**: VisualCore MUST offer a GPU timer over the disjoint timer query extension that returns a frame's
  elapsed GPU time only when the result is available and not disjoint, and nothing otherwise.
- **FR-A24-306**: Measured samples MUST carry a GPU time only from that timer when the probe confirms support.
- **FR-A24-307**: A finished run MUST carry a provenance report from public sources only, encoded with the run.
- **FR-A24-308**: VisualCore changes MUST carry `///` docs, tests, the API baseline update, README updates and the
  reference regression; G-RUNNER, G-REPORT, U-RENDERINFO and U-GPUTIMER MUST be closed with evidence.

### Key Entities

- **Renderer facts**: version strings, renderer, extension list, limits, context generation.
- **Timer capability**: supported or not, with the reason (extension present or absent).
- **GPU frame timer**: queries per frame, their results, the disjoint state.
- **Run report**: device, OS, app build, renderer, quality tier, thermal and Low Power Mode at start and end, timing
  sources, case and fingerprint.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-A24-301**: 100% of the warm-up and cool-down fixtures are excluded from the summary and counted.
- **SC-A24-302**: The probe reports the timer as supported on the iOS 27.2 simulator; a forced-unsupported run has 0
  GPU times.
- **SC-A24-303**: Every GPU time recorded is finite, non-negative and within the sample cap; 0 values are taken from a
  disjoint or unavailable result.
- **SC-A24-304**: The report validates with every field filled; the source scan finds 0 private APIs or identifiers.
- **SC-A24-305**: The reference regression passes 7 of 7 steps after the VisualCore change; the API baseline matches.
- **SC-A24-306**: Each unit test finishes in under 10 seconds.

## Assumptions

- The ANGLE build exposes the extension's entry points through its procedure lookup, as it does the core functions.
- Simulator GPU times prove the mechanism, not a device's speed.

## Traceability

| Source | Requirement |
|---|---|
| MVP: frame-time percentile, CPU submit time and optional supported GPU timer | FR-A24-304–306 |
| Regression fixture: measurement excludes warm-up | FR-A24-301, US1 |
| EGL/context ownership solely in the host | FR-A24-303, 305 |
| Version 0.1 feature 04: device and context report | FR-A24-307, US3 |
| Manual risk 2: GL timing extension availability | FR-A24-304, 305, US2 |
| Contract G-RUNNER, G-REPORT, U-RENDERINFO, U-GPUTIMER | FR-A24-301–308 |

## Negative Requirements

- No CPU time labelled GPU time; no GPU time from a disjoint or unavailable result; no private API or unique device
  identifier; no network; no benchmark number in copy; no ProjectM change; no second renderer or EGL path.
