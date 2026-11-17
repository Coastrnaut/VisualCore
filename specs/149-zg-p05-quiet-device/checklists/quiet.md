# Quiet and Device Requirements Quality Checklist: Digital Zen Garden — Phase 05

**Purpose**: Unit tests for the requirements of A20-P05 (completeness, privacy, architecture ownership, lifecycle,
testability, performance, release constraints)
**Created**: 2026-11-17
**Feature**: [spec.md](../spec.md) · [plan.md](../plan.md)

`[x]` means the reviewer judged the requirement's quality satisfied, not that work is done. Evaluated by the lead under
the owner's standing delegation on 2026-11-17 (depth standard, audience reviewer). One item failed and was corrected
before this record (CHK009).

## Completeness

- [x] CHK001 Are the three calm switches, their defaults and where they are kept specified? [Spec §FR-A20-501, Q1] — yes.
- [x] CHK002 Is the drift defined precisely (what moves, how fast, what never moves)? [Spec §Q2, data-model] — yes.
- [x] CHK003 Are the sound and haptic events and their conditions specified? [Spec §Q3] — yes.
- [x] CHK004 Are the interface journeys and their chunk named? [Spec §Q4] — yes (`b3`).
- [x] CHK005 Are all campaign rows listed with their measurements? [Spec §Q5, FR-A20-505] — yes (ZG-D1 to ZG-D8).

## Clarity and measurability

- [x] CHK006 Is "no incidental animation" measurable (two frames identical)? [Spec §SC-A20-501, Q2] — yes.
- [x] CHK007 Are campaign thresholds required without claiming numbers? [Spec §FR-A20-506, SC-A20-503] — yes.

## Consistency

- [x] CHK008 Are the calm switches kept out of the digest consistently with the document-only digest? [Spec §Q1] — yes.

## Edge cases and lifecycle

- [x] CHK009 Is behaviour when the app moves to the background during a tone or the drift specified? [Spec §Edge Cases] — failed (not covered); the edge cases now stop both.
- [x] CHK010 Are the silent switch, the person's haptic switch and Reduce Motion during the drift covered? [Spec §Edge Cases] — yes.

## Privacy and release

- [x] CHK011 Are sound files, network and permissions excluded? [Spec §Negative Requirements, Q3] — yes (procedural tones, ambient session, no microphone).
- [x] CHK012 Are device steps excluded before ImplementationLock-100, with D3 kept on iPadOS 26.5? [Spec §Assumptions, Negative Requirements] — yes.

## Architecture

- [x] CHK013 Is the audio dependency named and owned by VisualCore (no new audio code)? [Plan §Technical Context] — yes (`SoundEffectPlayer`).

## Testability and performance

- [x] CHK014 Are interface and unit test time limits stated? [Spec §SC-A20-502, SC-A20-504] — yes.
- [x] CHK015 Are long-duration measurements left to the campaign (no soak test here)? [Spec §Q5] — yes (ZG-D4, ZG-D5).

## Notes

- `/speckit-implement` reads these markers and does not change them.
