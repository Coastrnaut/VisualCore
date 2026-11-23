# Harmonic Bridges — device campaign plan (R02-G12-10, feature 420)

This is the written plan of feature 420 (FR-R02G1210-002 of
[spec.md](../../../specs/420-harmonic-bridges-device-automation-preparation/spec.md)). These rows need real devices.
They run only after `ImplementationLock-100` (CLAUDE.md rule 5), in the order D1 → D2 → D3, and D3 is not updated from
iPadOS 26.5; a campaign that finds D3 on another version is refused, not adapted. Until then every row is "pending
device campaign", and no launch, frame, memory, thermal, latency, sound, haptic or accessibility number is claimed
anywhere. Simulator results never stand in for these rows: the simulator evidence of features 418 and 419 (the
regression and the interface journeys) is a development signal, not device evidence. The campaign is UA-F13's
`scripts/run_device_campaign.py`, which reads [device-rows.json](device-rows.json); this page is its human-readable twin
and says the same things. `python3 scripts/check_device_rows.py --experience r02-g12.harmonic-bridges` checks the
definition: its shape, the scenario names against the manifest, the devices against the ledger, and that every deferred
{device} task is covered; `release_check.py` runs it as the step `device-rows-r02-g12`. Runs are short (minutes at most,
no soak) and a longer session is bounded by arithmetic from the short run (owner ruling of 2026-11-13), except the
30-minute round-two stress session that UA-F13 requires, which only the device campaign runs.

## Harmonic Bridges as built

Harmonic Bridges (`r02-g12.harmonic-bridges`, a free candidate until X-R02-G12) is a puzzle of islands joined by
suspended strings: tuning a string's peg until one of its harmonics matches a sounding tone swells it into a standing
wave, and where the wave's swing reaches the threshold at its sample points the string solidifies into a walkable
bridge; the player tunes strings within the action budget so the start reaches the goal in every step of the crossing
window, then tests the crossing. The panel has the string and peg steppers (naming the string, its islands and its
peg), Tune, Test, Undo, Redo, Next level, Reset view, Hint, the tutorial's Dismiss, the failure's Undo and Retry,
Campaign, Daily, Practice, the level picker with Play level, Replay best solution with Step and Stop, the Sound toggle
and a summary element. On the touch screen a tap on a string chooses it and auditions it without spending an action, a
drag of 16 points or more along an unlocked string previews its peg (one peg per 24 points) and tunes it on release, a
tap on the goal island or a step pip tests the crossing, two fingers orbit the camera and a double tap on empty space
restores the authored view. Level 1 is won by tuning string 0 from peg 11 to peg 12, then testing, with 3 of 3 stars. A
winning play can be replayed. Details: [harmonic-bridges.md](../../architecture/harmonic-bridges.md) (features 411 …
419).

## Devices

| Device | Model | Ledger row |
|---|---|---|
| D1 | iPhone 15 | DEV1-R02-G12 |
| D2 | iPad Pro 13-inch (M5) | DEV2-R02-G12 |
| D3 | iPad (A16) on iPadOS 26.5 (not updated) | DEV3-R02-G12 |

Every row runs on D1, D2 and D3, in that order.

## Device scenario set

The campaign runs these 12 scenarios of Harmonic Bridges's manifest by id on each device: `launch-first-frame`,
`input-response`, `completion`, `rejection`, `save-restore`, `reset`, `suspend-resume`, `teardown-reentry`,
`cancel-prepare`, `full-playthrough`, `hero` and `fixture-level-1-solved` (a stored win restored on the device). The 80
acceptance rows and the other two fixtures of the manifest (`fixture-budget-out`, `fixture-undo-redo`) stay
simulator-only: they are pure rule outcomes, which the host and the simulator already prove and which a device cannot
change.

## Owner actions

The devices in hand, unlocking them, trusting the computer, the developer-mode and signing steps, charging and
unplugging, the silent switch, the system haptics setting, turning VoiceOver and the text size on and off, plucking
strings, dragging pegs, tapping the goal island and step pips and the two-finger orbit, listening and feeling, and
ending the app from the app switcher are done by the owner. Each such step is recorded by the campaign as
`BLOCKED_OWNER_ACTION` with its exact steps when it reaches it, never waited for, and the other rows continue.

## Rows

### HB-D1 — Launch and first frame

- **Devices:** D1, D2, D3.
- **Procedure:** open Harmonic Bridges from the catalog with the testing argument, 200 times per device across the three
  host tiers; the campaign records preparation, shader set-up and first present as stage times.
- **Measurements:** `launch`, `first-frame`.
- **Pass:** no shader program is compiled after the experience became interactive; stage times recorded for 200 samples
  per device and tier (docs/performance/budgets.md, proposal).
- **Gating:** yes. **Covers:** UA-F13 `launch`, `first-frame`.
- **Owner steps:** the owner has the device in hand, unlocked, trusted and charged; the automation build is installed by
  the campaign (signing is the owner's).
- **Status:** pending device campaign.

### HB-D2 — Frame pacing and frame time per tier

- **Devices:** D1, D2, D3.
- **Procedure:** run the hero and full-playthrough scenarios pinned to tiers 0, 1 and 2 in turn, then with automatic
  levels; the campaign records each frame's interval.
- **Measurements:** `frame-pacing`, `frame-time-per-tier`.
- **Pass:** 60 frames per second with automatic levels (a documented 30 frames per second mode is acceptable on the last
  level), 200 samples per device; frame time per pinned tier recorded.
- **Gating:** yes. **Covers:** T-R02G1203-012, T-R02G1208-012; UA-F13 `frame-pacing`.
- **Owner steps:** the owner has the device in hand, unlocked, trusted and charged; the automation build is installed by
  the campaign (signing is the owner's).
- **Status:** pending device campaign.

### HB-D3 — Memory, thermal state and the round-two stress session

- **Devices:** D1, D2, D3.
- **Procedure:** run the 30-minute round-two stress session of UA-F13 (levels opened, strings plucked and tuned with peg
  drags and the panel, crossings tested, actions undone and redone, the camera orbited, levels retried and replayed in a
  loop) at automatic levels; the campaign samples the footprint and the thermal state.
- **Measurements:** `memory`, `thermal`, `stress`.
- **Pass:** memory flat within the declared resource budget over the session (the growth rule of feature 192), 200
  samples per device; thermal state and any tier change recorded.
- **Gating:** yes. **Covers:** T-R02G1208-012; UA-F13 `memory`, `thermal`, `stress`.
- **Owner steps:** the owner has the device in hand, unlocked, trusted and charged; the automation build is installed by
  the campaign (signing is the owner's). The owner keeps the device unplugged for the stress session and tells the
  campaign the starting battery level.
- **Status:** pending device campaign.

### HB-D4 — Touch feel and touch-to-frame latency

- **Devices:** D1, D2, D3.
- **Procedure:** tap a string to pluck it, drag along an unlocked string to tune its peg, tap the goal island or a step
  pip to test the crossing, orbit the camera with two fingers and double-tap empty space on each device; the campaign
  records the interval from touch to the first frame showing the change.
- **Measurements:** `touch-to-frame`.
- **Pass:** touch-to-frame latency recorded for 200 samples per device; a tap under 10 points and 0.5 s on a string
  chooses it and auditions it without spending an action; a drag of 16 points or more from an unlocked string previews
  the peg (one peg per 24 points, clamped to 1 … 12) and tunes exactly once on release when the peg differs; a tap on
  the goal island or a step pip while playing sends exactly one test; a double tap on empty space restores the authored
  camera.
- **Gating:** yes. **Covers:** T-R02G1204-011.
- **Owner steps:** the owner has the device in hand, unlocked, trusted and charged; the automation build is installed by
  the campaign (signing is the owner's). The owner plucks strings, drags pegs, taps the goal island and step pips and
  orbits with two fingers; the campaign does not synthesise touches on hardware.
- **Status:** pending device campaign.

### HB-D5 — Sound heard and haptics felt

- **Devices:** D1, D2, D3.
- **Procedure:** turn the Sound toggle on and play a level to a win and to a failure with the haptics switch on,
  including one refused action (a tune of a locked string); pluck strings to hear their audition; observe the strings'
  ambient sound and the selection, success, warning and error haptics.
- **Measurements:** `sound-audible`, `haptics-felt`.
- **Pass:** the sound is audible only while it is on, the panel is shown and the scene is active, and follows the silent
  switch; each planned haptic is felt (where the device has no haptic engine, the haptic part is recorded as not
  applicable).
- **Gating:** yes. **Covers:** T-R02G1206-011.
- **Owner steps:** the owner has the device in hand, unlocked, trusted and charged; the automation build is installed by
  the campaign (signing is the owner's). The owner listens and feels, and sets the silent switch and the system haptics
  setting.
- **Status:** pending device campaign.

### HB-D6 — VoiceOver walk-through (manual, non-gating)

- **Devices:** D1, D2, D3.
- **Procedure:** with VoiceOver on and the largest accessibility text size, choose a string and a peg with the
  adjustable string and peg steppers, tune and hear the string described, test the crossing and hear the win; replay it.
- **Measurements:** `voiceover-observation`.
- **Pass:** every control and the summary element are read with their label and value; each tuning, test, undo, redo,
  refusal, failure and the win are announced; the panel stays readable at the largest accessibility text size; recorded
  as an observation (non-gating, P-08).
- **Gating:** no (non-gating, P-08). **Covers:** T-R02G1206-011.
- **Owner steps:** the owner has the device in hand, unlocked, trusted and charged; the automation build is installed by
  the campaign (signing is the owner's). The owner turns VoiceOver and the text size on and off in Settings and performs
  the walk-through.
- **Status:** pending device campaign.

### HB-D7 — Progress across a real termination

- **Devices:** D1, D2, D3.
- **Procedure:** win level 1, leave the app to the background, end it from the app switcher, reopen Harmonic Bridges.
- **Measurements:** `progress-kept`.
- **Pass:** level 1 is solved with its stars, level 2 is open and the replay of level 1 is offered after the reopen; an
  unfinished level restores to the same pegs, actions left and records.
- **Gating:** yes. **Covers:** T-R02G1207-011.
- **Owner steps:** the owner has the device in hand, unlocked, trusted and charged; the automation build is installed by
  the campaign (signing is the owner's). The owner ends the app from the app switcher.
- **Status:** pending device campaign.

### HB-D8 — Panel journeys in the app

- **Devices:** D1, D2, D3.
- **Procedure:** run the device scenario set by id and the interface journeys of chunk u3 (win level 1 with the string
  and peg steppers, Tune and Test, replay, relaunch).
- **Measurements:** `scenarios`, `journeys`.
- **Pass:** every scenario of the device set passes; level 1 is won with its one certified tuning (string 0 to peg 12)
  and the test with 3 of 3 stars, level 2 is open, progress survives the relaunch, the replay ends won.
- **Gating:** yes. **Covers:** T-R02G1209-011.
- **Owner steps:** the owner has the device in hand, unlocked, trusted and charged; the automation build is installed by
  the campaign (signing is the owner's).
- **Status:** pending device campaign.

## The earlier tasks these rows close

- T-R02G1203-012 (feature 413, renderer): frame time per tier on devices — HB-D2.
- T-R02G1204-011 (feature 414, spatial interaction): touch feel and touch-to-frame latency — HB-D4.
- T-R02G1206-011 (feature 416, polish and accessibility): sound heard, haptics felt (HB-D5) and the VoiceOver
  walk-through at the largest text size (HB-D6).
- T-R02G1207-011 (feature 417, persistence): progress kept across a real termination — HB-D7.
- T-R02G1208-012 (feature 418, regression): frame time and memory of the golden levels per tier — HB-D2, HB-D3.
- T-R02G1209-011 (feature 419, in the app): the panel journeys on devices — HB-D8.

Features 411, 412 and 415 have no {device} task.
