# Sound and Device Requirements Quality Checklist: Aurora — Phase 05

**Purpose**: Unit tests for the requirements of A21-P05 (completeness, privacy, architecture ownership, iOS lifecycle,
testability, performance, release constraints)
**Created**: 2026-11-17
**Feature**: [spec.md](../spec.md) · [plan.md](../plan.md)

`[x]` means the reviewer judged the requirement's quality satisfied, not that work is done. Evaluated by the lead under
the owner's standing delegation on 2026-11-17 (depth standard, audience reviewer). One item failed and was corrected
before this record (CHK004).

## Completeness

- [x] CHK001 Are the sound's default, its on/off effect and where the choice is kept specified? [Spec §FR-A21-501, 502, Q1] — yes.
- [x] CHK002 Are the conditions under which the loop plays and stops all listed (on screen, active scene, sound on, self-stop)? [Spec §Q1, FR-A21-504] — yes.
- [x] CHK003 Are the drawing events that must not affect the sound enumerated? [Spec §FR-A21-503, contracts/sound.md] — yes (setup, resize, draw, teardown, shed caches, preset, still view, reduced flashing).
- [x] CHK004 Are the spoken hints of the sound controls required to describe the playing loop? [Spec §FR-A21-502] — corrected: the A21-P04 hint said nothing plays; FR-A21-502 now requires the new wording.
- [x] CHK005 Are the interface journeys and their chunk named? [Spec §Q3, FR-A21-506] — yes (`c3`, two classes).
- [x] CHK006 Are all campaign rows listed with their measurements? [Spec §Q4, FR-A21-507] — yes (AU-D1 to AU-D8).

## Clarity and measurability

- [x] CHK007 Is "no visible time jump" quantified? [Spec §FR-A21-505, SC-A21-502, Q2] — yes (same sky time to 1e-6 s, identical pixels at shared instants, step ≤ 0.1 s × speed).
- [x] CHK008 Is the low-power frame cap stated as a number? [Spec §US2/AC1, FR-A21-505] — yes (30 frames per second).
- [x] CHK009 Is "independent of the drawing's life" measurable? [Spec §SC-A21-501] — yes (100 % of lifecycle samples unchanged).
- [x] CHK010 Are time limits for unit and interface tests stated? [Spec §SC-A21-503, 505] — yes (10 s, 60 s).

## Consistency

- [x] CHK011 Do the spec, plan and contract agree that the sound choice is outside the state, digest and manifest? [Spec §FR-A21-503, data-model] — yes.
- [x] CHK012 Is the "no VisualCore change" statement consistent with the dependencies the plan adds? [Plan §Technical Context] — yes (existing products only).

## Scenario and edge coverage

- [x] CHK013 Are failure paths of the audio output specified? [Spec §Edge Cases, FR-A21-504] — yes (choice stays, nothing plays, no crash).
- [x] CHK014 Are interruptions, the silent switch and the background addressed? [Spec §Edge Cases] — yes.
- [x] CHK015 Are a long stall and Low Power Mode toggled mid-motion addressed? [Spec §Edge Cases] — yes.
- [x] CHK016 Are damaged or newer stored choices addressed? [Spec §Edge Cases] — yes (off at the default volume).

## Privacy, ownership and release

- [x] CHK017 Are the microphone, background audio, sound files and network excluded? [Spec §Negative Requirements] — yes.
- [x] CHK018 Is ownership of the loop (experience) versus the player (VisualCoreAudio) stated? [Plan §Project Structure, research D1–D2] — yes.
- [x] CHK019 Is the licence record of the synthesised loop required? [Spec §FR-A21-508] — yes.
- [x] CHK020 Are device facts barred from simulator evidence and tied to ImplementationLock-100? [Spec §FR-A21-508, Negative Requirements] — yes.

## Notes

- `/speckit-implement` reads these markers and does not change them.
