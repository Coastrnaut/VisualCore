# Feature Specification: Graphics Benchmark Lab — Phase 01 Measurement methodology and fixture statistics

**Feature Branch**: `173-gbl-p01-measurement-statistics` (spec directory only; work stays on `main`)

**Created**: 2026-11-19

**Status**: Draft

**Ledger gate**: A24-P01 (legacy ledger) · ID namespace FR-A24-1##, SC-A24-1##, T-A24-1##

**Input**: User description: archived manual `apps/24-graphics-benchmark-lab.md` §9 Phase 01 `/speckit-specify` prompt
(verbatim in the invocation).

Canonical overrides:
- **Phase gates (manual §9 Phase 01):**
  - MVP: repeatable baseline scenes (textured quads, shader ALU stress, particles). Here it is each scene's fixed,
    versioned benchmark case: its workload configuration, run phases and caps, as pure data. The scenes are drawn in
    A24-P02 and run in A24-P03;
  - regression fixture: the statistics p50, p95 and p99 match committed fixture samples, including edge cases;
  - graphics context ownership stays solely in the audited VisualCore host. The core issues no graphics call, and
    summarising samples creates no graphics resource, proved inside the host by tests that see no resource created.
- **Gaps built here:** G-MODEL and G-STATS of `docs/apps/graphics-benchmark-lab/visualcore-contract.json`, as a
  pending core in `Packages/ExperiencesCreative/GraphicsBenchmarkLab/Core` until A24-P02 adds the experience.
- **No VisualCore or ProjectM change.** Follow `specs/166-vpl-p01-graph-schema`.
- **No benchmark number:** fixtures are synthetic samples with hand-computed expectations, never device measurements.

## Clarifications

### Session 2026-11-19

Answered by the lead under the owner's standing delegation (the recommended option each time). The facts were checked
in code:
- **Fingerprint:** `DigestBuilder(domain:)` (VisualCoreExperience, pure) adds typed fields (`add(_:)` for Int, UInt64,
  Bool, String and bytes; `add(_ value: Double) throws(DigestError)`, which refuses NaN and infinity; `add(count:)`)
  and `finish()` gives a `StateDigest`.
- **Migration:** `MigrationChain(currentVersion:steps:)` (VisualCorePersistence, pure) migrates a JSON object payload
  with `migrate(_:from:)`.
- **Particles:** `ParticleSystem.maxCapacity` (VisualCoreSimulation) is 100,000 and `defaultCapacity` 10,000.
- **Host counts:** `RenderHost(scene:)` runs a `RenderScene` off screen, and `ResourceRegistry.stats` gives
  `liveCount` per kind and `totalBytes`, as the Visual Programming Lab core tests use (A23-P01).
- **Package layout:** a pending core is `<Name>Core` with `<Name>CoreTests` and no experience target (the pending-core
  allowance of `scripts/check_experience_packages.py`); its tests may depend on VisualCoreRendering.

- Q: What are the three built-in cases and their caps? → A: Version 1 of each, every value inside its cap:

  | Case id | Workload | Configuration (value; cap) | Resolution scale (value; cap) |
  |---|---|---|---|
  | `quads` | textured quads | 8 full-screen layers (1…64), a 256 × 256 texture made in code (64…1,024, power of two) | 1.0 (0.25…1.0) |
  | `alu` | shader ALU stress | 64 iterations per fragment (1…1,024) | 1.0 (0.25…1.0) |
  | `particles` | particles | 5,000 particles (1…100,000, `ParticleSystem.maxCapacity`) | 1.0 (0.25…1.0) |

  Every case has the run plan warm-up 3 s (1…30), measurement 10 s (1…60) and cool-down 5 s (0…120), so a run lasts
  at most 210 s. The fingerprint is a `DigestBuilder` in the domain `a24.benchmark-case.v1` over the id, the version,
  the workload, every configuration value, the resolution scale and the plan.
- Q: What exactly is a percentile here? → A: The nearest-rank percentile over the measured values sorted ascending:
  rank = ⌈p · n / 100⌉ computed in integers as (p · n + 99) / 100, value = the rank-th smallest. p50 needs n ≥ 1,
  p95 n ≥ 20 and p99 n ≥ 100; below that the percentile is absent and the summary is flagged. No interpolation, no
  mean as a headline.
- Q: What is a frame sample, and what are its caps? → A: `frameIndex` (an integer, strictly increasing within a run),
  `phase` (warm-up, measurement or cool-down; phases never go back), `intervalMs` (the time from the previous frame,
  absent for the run's first frame), `cpuMs` (the presenter's own submit time), `gpuMs` (absent unless a timer is
  confirmed) and `dropped`. Every duration is finite and within 0…1,000 ms. A run holds at most 20,000 samples
  (60 s at 120 Hz is 7,200). A measured sample without an interval is not counted in the interval percentiles.
- Q: What is the run record's file? → A: The envelope `{"body", "kind": "a24.benchmark-run", "version": 1}` with the
  body `{case, samples, summary, state}` (`state` ∈ completed, stopped, interrupted), at most 2,097,152 bytes, read
  through a `MigrationChain`. Refusal codes: `damaged` (not the envelope, the wrong kind or body, or a stored summary
  that differs from the one recomputed from the samples), `newer-version`, `too-large`, `not-finite`, `out-of-range`
  (with the field), `out-of-order` (frame index or phase) and `too-many-samples`.
- Q: How is "no graphics work" proved? → A: As in A23-P01: a core test runs a scene on `RenderHost` and, inside its
  callbacks, validates the cases, summarises every fixture and encodes a run, then compares `ResourceRegistry.stats`
  (`liveCount` per kind and `totalBytes`) before and after; they are equal. The core target depends only on the pure
  VisualCoreExperience and VisualCorePersistence products.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A benchmark case is a fixed, bounded recipe (Priority: P1) 🎯

An engineer picks one of three baseline cases (textured quads, shader ALU stress, particles). Each case names its
workload, its configuration and its run plan (warm-up, measurement and cool-down lengths) with a version and a
fingerprint, so two runs of the same case version are comparable and any change to the recipe is visible.

**Why this priority**: repeatability starts from a fixed recipe; every later phase draws and runs these cases.

**Independent Test**: build each built-in case; validate it; change one value and see a different fingerprint; give
an out-of-range value and see it refused.

**Acceptance Scenarios**:

1. **Given** the three built-in cases, **When** they are validated, **Then** each passes and has a distinct, stable
   fingerprint.
2. **Given** a case with a value outside its cap (for example a measurement longer than the maximum), **When** it is
   validated, **Then** it is refused naming the value.
3. **Given** a case whose configuration changes, **When** its fingerprint is taken, **Then** it differs from before.

---

### User Story 2 - Percentiles match the fixtures exactly (Priority: P1)

A reviewer gives the statistics a committed set of frame samples and reads p50, p95 and p99 of the frame interval and
of the CPU time, the sample count and the number of warm-up samples left out. The numbers equal the fixture's
hand-computed expectations exactly, including empty, single, tied and unsorted sets.

**Why this priority**: the manual's regression fixture; a result is only as honest as its statistics.

**Independent Test**: run the statistics over every committed fixture and compare with its expectations.

**Acceptance Scenarios**:

1. **Given** the samples 1 … 100 ms in any order, **When** summarised, **Then** p50 = 50, p95 = 95 and p99 = 99.
2. **Given** an empty measurement, **When** summarised, **Then** there are no percentiles and the summary is flagged
   "no samples".
3. **Given** warm-up samples before the measurement, **When** summarised, **Then** they are left out and counted.

---

### User Story 3 - Bad samples are refused, never averaged in (Priority: P1)

A sample with a negative, non-finite or impossible duration, or a set with frame indices out of order, is refused
with a reason, so a broken measurement never becomes a result.

**Why this priority**: the constitution refuses NaN, infinite and out-of-range values.

**Independent Test**: feed each kind of bad sample and read the refusal.

**Acceptance Scenarios**:

1. **Given** a sample with NaN, infinity or a negative interval, **When** validated, **Then** it is refused naming the
   frame and the field.
2. **Given** more samples than the cap, **When** validated, **Then** the set is refused before any statistic is taken.

---

### User Story 4 - A result says what it cannot claim (Priority: P2)

A summary carries quality flags: too few samples for a p99, dropped frames, no GPU timer, so a reader of a result
knows its limits. A GPU percentile appears only when every measured sample carries a GPU time.

**Why this priority**: measurement provenance is a requirement (constitution A24).

**Independent Test**: summarise fixtures with few samples, with dropped frames and without GPU times; read the flags.

**Acceptance Scenarios**:

1. **Given** fewer samples than the p99 minimum, **When** summarised, **Then** p99 is absent and the summary is
   flagged "too few samples for p99".
2. **Given** samples without GPU times, **When** summarised, **Then** there is no GPU percentile and the summary is
   flagged "GPU time not available".

---

### User Story 5 - Summarising happens before and apart from graphics work (Priority: P2)

Summarising samples, validating cases and encoding results touch no graphics state, proved inside a running VisualCore
host.

**Independent Test**: summarise every fixture inside a scene on the render host and compare the host's resource
statistics before and after.

**Acceptance Scenarios**:

1. **Given** a running host, **When** every fixture is summarised inside a scene callback, **Then** the host's live
   resource counts and bytes are unchanged.

### Edge Cases

- **One sample:** every available percentile equals it.
- **All samples equal:** every percentile equals that value.
- **Ties at a percentile boundary:** the nearest-rank rule picks the sample at the rank, so ties are stable.
- **Unsorted input:** the result equals that of the sorted input.
- **Only warm-up samples:** the measurement is empty and flagged "no samples".
- **A sample with a CPU time but no interval (the first frame):** the interval of the first measured frame is not
  defined and is not counted; its CPU time is.
- **A dropped frame:** counted and flagged, its interval still counts.
- **A result file that is damaged, of a newer version or holds non-finite numbers:** refused with a code, never
  partly read.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-A24-101**: The core MUST define three built-in benchmark cases (textured quads, shader ALU stress, particles),
  each with a stable identifier, a version, its workload configuration, its run plan (warm-up, measurement and
  cool-down durations) and a fingerprint over all of them.
- **FR-A24-102**: Validation MUST refuse a case or a sample set whose values lie outside the documented caps or are not
  finite, naming the field.
- **FR-A24-103**: The statistics MUST give exact nearest-rank p50, p95 and p99 of the frame interval and of the CPU
  time over the measured samples, with the warm-up left out and counted, and the sample count.
- **FR-A24-104**: The summary MUST carry quality flags (no samples, too few samples for p95 or p99, dropped frames,
  GPU time not available), and a GPU percentile only when every measured sample has a GPU time.
- **FR-A24-105**: A run record (case, samples, summary, state) MUST encode to a versioned file and decode back
  unchanged; a damaged, newer, oversized or non-finite file MUST be refused with a code.
- **FR-A24-106**: Committed fixtures with hand-computed expectations MUST cover the edge cases above, and the
  statistics MUST match them exactly.
- **FR-A24-107**: Summarising, validating and encoding MUST create no graphics resource, proved inside the host.
- **FR-A24-108**: Every public name MUST carry documentation; the contract's G-MODEL and G-STATS MUST be closed with
  evidence.

### Key Entities

- **Benchmark case**: identifier, version, workload kind and configuration, run plan, fingerprint.
- **Frame sample**: frame index, phase, interval, CPU time, optional GPU time, dropped flag.
- **Summary**: percentiles per measure, sample count, warm-up count, dropped count, quality flags.
- **Run record**: case, samples, summary, state (completed, stopped, interrupted), versioned.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-A24-101**: 100% of the committed fixtures match their expected percentiles exactly.
- **SC-A24-102**: 100% of the refusal fixtures are refused with the expected code and field.
- **SC-A24-103**: The three built-in cases validate and have three distinct fingerprints; a one-value change alters
  the fingerprint.
- **SC-A24-104**: A run record survives an encode and decode unchanged; every bad file is refused.
- **SC-A24-105**: The host's resource counts and bytes are unchanged after summarising every fixture inside it.
- **SC-A24-106**: Each unit test finishes in under 10 seconds.

## Assumptions

- The workload numbers of the cases (draw layers, iteration counts, particle counts, durations) are bounds for
  repeatability, not targets; they are drawn in A24-P02 and may be retuned there with a new case version.
- Device facts, run timing and storage come in A24-P03 and A24-P04; this phase defines the data they fill.

## Traceability

| Source | Requirement |
|---|---|
| MVP: repeatable baseline scenes | FR-A24-101, 102, US1 |
| Regression fixture: p50/p95/p99 match fixture samples including edge cases | FR-A24-103, 106, US2 |
| EGL/context ownership solely in the host | FR-A24-107, US5 |
| Manual §6 schemas: BenchmarkCase, BenchmarkRun, FrameMeasurement, Summary | FR-A24-101, 104, 105 |
| Manual §6 decisions: warm-up partition, distributions not averages, GPU time only if supported | FR-A24-103, 104 |
| Contract G-MODEL, G-STATS | FR-A24-101–108 |

## Negative Requirements

- No VisualCore or ProjectM change; no experience target, registration or interface; no graphics call in the core;
  no device measurement and no benchmark number; no average frame rate as a headline; no network.
