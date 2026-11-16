# GPU Parity Requirements Quality Checklist: Simulation Lab — Phase 02

**Purpose**: Unit tests for the requirements of A16-P02 (completeness, architecture ownership, iOS lifecycle,
testability, performance, release constraints)
**Created**: 2026-11-16
**Feature**: [spec.md](../spec.md) · [plan.md](../plan.md)

`[x]` means the reviewer judged the requirement's quality satisfied, not that work is done. Evaluated by the lead under
the owner's standing delegation on 2026-11-16 (depth standard, audience reviewer); one item failed and was corrected
before this record (CHK008).

## Completeness and clarity

- [x] CHK001 Is "parity" defined exactly (every cell equal after N steps) with the step counts? [FR-A16-201, SC-A16-201] — yes.
- [x] CHK002 Is the automaton's GPU encoding and boundary stated? [Clarifications Q3] — yes.
- [x] CHK003 Are the Gray-Scott fixture's grid, step count and tolerance quantified? [Clarifications Q4, FR-A16-210] — yes (16 × 16, 10 steps, 0.01).
- [x] CHK004 Is the source of truth (CPU) and the mirror rule stated? [Clarifications Q1–Q2] — yes.

## Architecture ownership

- [x] CHK005 Is reuse of the ping-pong pair, field passes, observer and float probe required, with no VisualCore change? [Assumptions, plan] — yes.
- [x] CHK006 Is the experience the owner of the step shaders and the mirror? [Plan Project Structure] — yes.

## Lifecycle and recovery

- [x] CHK007 Are loading triggers (setup, recreation, resize, family, preset, reset, restore, step jumps) enumerated? [Clarifications Q2, FR-A16-202] — yes.
- [x] CHK008 Is the behaviour defined when a step program fails to compile or a target is incomplete? [Gap → Edge Cases] — failed (not stated); the edge case now fails the session through the host's failure state and keeps the CPU state.

## Testability and performance

- [x] CHK009 Is pass isolation observable and measurable over a stated number of frames? [Clarifications Q5, SC-A16-203] — yes.
- [x] CHK010 Is the GPU work per frame bounded? [Clarifications Q2, plan Performance] — yes (≤ 128 steps).
- [x] CHK011 Is the fixture's behaviour without float targets explicit rather than a silent skip? [Clarifications Q4] — yes.

## Release constraints

- [x] CHK012 Are accuracy claims beyond parity and tolerance excluded? [Negative Requirements] — yes.
- [x] CHK013 Is graphics context ownership kept in the host? [Traceability] — yes.

## Notes

- `/speckit-implement` reads these markers and does not change them.
