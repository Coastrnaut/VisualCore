# Experiment UI Requirements Quality Checklist: Simulation Lab — Phase 04

**Purpose**: Unit tests for the requirements of A16-P04 (completeness, privacy, architecture ownership, iOS lifecycle,
testability, performance, release constraints)
**Created**: 2026-11-16
**Feature**: [spec.md](../spec.md) · [plan.md](../plan.md)

`[x]` means the reviewer judged the requirement's quality satisfied, not that work is done. Evaluated by the lead under
the owner's standing delegation on 2026-11-16 (depth standard, audience reviewer). Two items failed and were corrected
before this record (CHK004, CHK008).

## Completeness and clarity

- [x] CHK001 Is each family's brush defined with its cells and values, and the drag rule? [Clarifications Q1, FR-A16-401] — yes.
- [x] CHK002 Is "exactly one iteration" defined against a CPU reference for every family? [FR-A16-402, SC-A16-401] — yes.
- [x] CHK003 Are the histogram's bins, ranges, clamping and non-finite handling quantified? [Clarifications Q2, FR-A16-420] — yes.
- [x] CHK004 Is the approximation label's wording stated per family? [FR-A16-410] — failed (only its contents were named); FR-A16-410 now gives the three sentences.
- [x] CHK005 Are the step-rate caps and the refusal sentence quantified? [Clarifications Q3, FR-A16-412] — yes.

## Privacy

- [x] CHK006 Is it stated that capture needs no permission or usage string and writes nothing to Photos? [Clarifications Q5, Negative Requirements] — yes.
- [x] CHK007 Is the location of saved presets and captures stated (the app's storage and temporary folder only)? [Clarifications Q4–Q5, plan VIII] — yes.

## Data and lifecycle

- [x] CHK008 Are all library operations specified (save, load, delete, refusal at the cap)? [FR-A16-430] — failed (delete was only in the plan); FR-A16-430 now requires it.
- [x] CHK009 Are damaged, newer and refused preset files specified? [Clarifications Q4, Edge Cases] — yes.
- [x] CHK010 Are the capture's interaction with a running simulation and its failure path defined? [Clarifications Q5, Edge Cases] — yes.
- [x] CHK011 Is the effect of painting on determinism and replays defined? [Clarifications Q1, research D1] — yes (an action in the digest).

## Architecture ownership

- [x] CHK012 Is the device-dependent rule (motion caps) kept outside the deterministic core? [Clarifications Q3] — yes.
- [x] CHK013 Is capture required to use the host's context only? [Traceability, Clarifications Q5] — yes.

## Testability and performance

- [x] CHK014 Is the histogram's update rate measurable over a fixed number of frames? [SC-A16-402] — yes (at most 4 in 60).
- [x] CHK015 Are per-action and per-frame costs bounded? [plan Performance] — yes.

## Release constraints

- [x] CHK016 Are bundled presets required to carry a source and an allowed license? [FR-A16-430, Clarifications Q4] — yes.

## Notes

`/speckit-implement` reads this checklist and does not change its markers.
