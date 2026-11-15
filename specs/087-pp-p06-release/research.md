# Research: A11-P06 Final verification, privacy, packaging and release

Facts verified on 2026-11-15 (clarification session): release-document check and statuses; derived release steps;
shared copy denylist; `failNextDraw`; no permission in the a11 registration; four committed sample experiment files.

## D1 — Documents

- **Decision**: as Neon Arcade's (A10-P06): `privacy-and-credits.md` (stored: `experiment-0…3.json` — names and worlds
  of saved experiments, no personal data — in the experience's folder, and the app's session state; nothing sent; no
  permission; how to delete: clearing a slot, the app's Settings reset of the experience's data or removing the app;
  credits from `content-licenses.md`), `store-listing.md` (text plus a table claim → proving test), `release-checklist.md`
  (Item | Area | Status | Evidence; statuses `verified`, `pending-campaign-ii`, `owner-action`; artifact inventory;
  accessibility rows), `release.json` (schema 1; required documents; checklist; copy check over the store text and the
  controls and presenter Swift, `allow` empty).

## D2 — Scans

- **Decision**: source scan as a `run-check` with `grep -rnE` over the experience (Clarifications Q3); refused-words scan
  `specs/087-pp-p06-release/scan-claims-release.sh` (whole-word, case-insensitive; Clarifications Q2) over the store
  text and the interface Swift, and every test named in the store claim table must exist; exit 1 on a hit.

## D3 — Recovery

- **Decision**: `PlaygroundRecoveryDrawTests`: an experiment saved to slot 0 in a temporary storage, `failNextDraw`, a
  drawn frame puts the session into its failure state, `experiment-0.json` byte-identical, a new session draws; the
  sample-file and migration tests of A11-P04/P05 are re-run in the package run.

## D4 — Interface tests

- **Decision**: `PPSupport` (namespace `PP`, identifiers `experience.a11.physics-playground.<name>`, candidate launch as
  `NASupport`); `PPWorldUITests` (drop circle raises the body count in the status; pause, step, time scale picker; force
  arrows toggle value), `PPExperimentUITests` (preset Pendulum shown in the experiment line; tutorial start shows step 1
  and stop hides it); chunk `"s2": ["PPWorldUITests", "PPExperimentUITests"]` (serial).

## As built (2026-11-15)

- **Segmented pickers rebuilt per frame dropped taps.** `PPWorldUITests.testTimeScale` found that a tap on a time-scale
  segment was lost while the world ran (it worked while paused): the controls' body is re-evaluated every frame (the
  status line and the description change), and each pass gave the segmented control a new binding. The five segmented
  pickers (time scale, gravity, drag, spring stiffness, shape to add) are now one `PlaygroundSegmentedPicker`, an
  `Equatable` view compared without its handler and used with `.equatable()`, so a running world leaves the control
  alone until its selection or titles change. The labels, spoken values and identifiers are unchanged. Evidence:
  `.autonomy/checks/A11-P06.app-ui-4.json` (passes; `app-ui`, `-2`, `-3` before the fix fail at the time-scale step)
  and `.autonomy/checks/A11-P06.playground-ios27-2.json`. The UI test's segment helper also keeps a fallback tap by
  place and a check of the picker's spoken value.
