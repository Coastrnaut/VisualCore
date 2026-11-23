# Echo Cartographer — device campaign plan (R02-G11-10, feature 410)

This is the written plan of feature 410 (FR-R02G1110-002 of
[spec.md](../../../specs/410-echo-cartographer-device-automation-preparation/spec.md)). These rows need real devices.
They run only after `ImplementationLock-100` (CLAUDE.md rule 5), in the order D1 → D2 → D3, and D3 is not updated from
iPadOS 26.5; a campaign that finds D3 on another version is refused, not adapted. Until then every row is "pending
device campaign", and no launch, frame, memory, thermal, latency, sound, haptic or accessibility number is claimed
anywhere. Simulator results never stand in for these rows: the simulator evidence of features 408 and 409 (the
regression and the interface journeys) is a development signal, not device evidence. The campaign is UA-F13's
`scripts/run_device_campaign.py`, which reads [device-rows.json](device-rows.json); this page is its human-readable twin
and says the same things. `python3 scripts/check_device_rows.py --experience r02-g11.echo-cartographer` checks the
definition: its shape, the scenario names against the manifest, the devices against the ledger, and that every deferred
{device} task is covered; `release_check.py` runs it as the step `device-rows-r02-g11`. Runs are short (minutes at most,
no soak) and a longer session is bounded by arithmetic from the short run (owner ruling of 2026-11-13), except the
30-minute round-two stress session that UA-F13 requires, which only the device campaign runs.

## Echo Cartographer as built

Echo Cartographer (`r02-g11.echo-cartographer`, a free candidate until X-R02-G11) is a puzzle in a dark chamber of
which only the entry is known: pulses sent from known open cells reveal the walls they strike and the floor they cross,
and the hidden beacons answer with echoes whose delays tell how far each one is along the open floor; the player works
out where every beacon must be and claims it before the energy runs out. The panel has the column and row steppers
(naming the cell and what is known of it), Pulse, Claim, Mark, Undo, Redo, Next level, Reset view, Hint, the
tutorial's Dismiss, the failure's Undo and Retry, Campaign, Daily and Practice, a level stepper, Replay with Step and
Stop, the Sound toggle and a summary element. On the touch screen a tap on a known open cell sends one pulse and a tap
on any other cell moves the cursor, a drag of 16 points or more places a marker or moves one, a press held still for
0.5 s claims the held cell on release (moving 10 points after it armed cancels it), two fingers orbit the camera and a
double tap on empty space restores the authored view. Level 1 is won with pulses from column 0, row 3 and column 0,
row 2, then a claim at column 1, row 2, with 3 of 3 stars. A winning play can be replayed. Details:
[echo-cartographer.md](../../architecture/echo-cartographer.md) (features 401 … 409).

## Devices

| Device | Model | Ledger row |
|---|---|---|
| D1 | iPhone 15 | DEV1-R02-G11 |
| D2 | iPad Pro 13-inch (M5) | DEV2-R02-G11 |
| D3 | iPad (A16) on iPadOS 26.5 (not updated) | DEV3-R02-G11 |

Every row runs on D1, D2 and D3, in that order.

## Device scenario set

The campaign runs these 12 scenarios of Echo Cartographer's manifest by id on each device: `launch-first-frame`,
`input-response`, `completion`, `rejection`, `save-restore`, `reset`, `suspend-resume`, `teardown-reentry`,
`cancel-prepare`, `full-playthrough`, `hero` and `fixture-level-1-solved` (a stored win restored on the device). The 80
acceptance rows and the other two fixtures of the manifest (`fixture-budget-out`, `fixture-undo-redo`) stay
simulator-only: they are pure rule outcomes, which the host and the simulator already prove and which a device cannot
change.

## Owner actions

The devices in hand, unlocking them, trusting the computer, the developer-mode and signing steps, charging and
unplugging, the silent switch, the system haptics setting, turning VoiceOver and the text size on and off, tapping
cells, dragging markers, holding cells to claim and the two-finger orbit, listening and feeling, and ending the app
from the app switcher are done by the owner. Each such step is recorded by the campaign as `BLOCKED_OWNER_ACTION` with
its exact steps when it reaches it, never waited for, and the other rows continue.

## Rows

### EC-D1 — Launch and first frame

- **Devices:** D1, D2, D3.
- **Procedure:** open Echo Cartographer from the catalog with the testing argument, 200 times per device across the
  three host tiers; the campaign records preparation, shader set-up and first present as stage times.
- **Measurements:** `launch`, `first-frame`.
- **Pass:** no shader program is compiled after the experience became interactive; stage times recorded for 200
  samples per device and tier (`docs/performance/budgets.md`, proposal).
- **Gating:** yes. **Covers:** UA-F13 `launch`, `first-frame`.
- **Owner steps:** the device in hand, unlocked, trusted and charged; the campaign installs the automation build
  (signing is the owner's).
- **Status:** pending device campaign.

### EC-D2 — Frame pacing and frame time per tier

- **Devices:** D1, D2, D3.
- **Procedure:** run the `hero` and `full-playthrough` scenarios pinned to tiers 0, 1 and 2 in turn, then with automatic
  levels; the campaign records each frame's interval.
- **Measurements:** `frame-pacing`, `frame-time-per-tier`.
- **Pass:** 60 frames per second with automatic levels (a documented 30 frames per second mode is acceptable on the last
  level), 200 samples per device; frame time per pinned tier recorded.
- **Gating:** yes. **Covers:** UA-F13 `frame-pacing`, T-R02G1103-012, T-R02G1108-012.
- **Owner steps:** the device in hand, unlocked, trusted and charged; the campaign installs the automation build
  (signing is the owner's).
- **Status:** pending device campaign.

### EC-D3 — Memory, thermal state and the round-two stress session

- **Devices:** D1, D2, D3.
- **Procedure:** run the 30-minute round-two stress session of UA-F13 (levels opened, pulses sent from known open cells,
  markers placed and dragged, beacons claimed, actions undone and redone, the camera orbited, levels retried and
  replayed in a loop) at automatic levels; the campaign samples the footprint and the thermal state.
- **Measurements:** `memory`, `thermal`, `stress`.
- **Pass:** memory flat within the declared resource budget over the session (the growth rule of feature 192), 200
  samples per device; thermal state and any tier change recorded.
- **Gating:** yes. **Covers:** UA-F13 `memory`, `thermal`, `stress`, T-R02G1108-012.
- **Owner steps:** the device in hand, unlocked, trusted and charged; the campaign installs the automation build
  (signing is the owner's). The owner keeps the device unplugged for the stress session and tells the campaign the
  starting battery level.
- **Status:** pending device campaign.

### EC-D4 — Touch feel and touch-to-frame latency

- **Devices:** D1, D2, D3.
- **Procedure:** tap known open cells to pulse, tap unknown cells to move the cursor, drag from a cell to place a marker
  and drag a marker to another cell, hold a cell to claim a beacon, orbit the camera with two fingers and double-tap
  empty space on each device; the campaign records the interval from touch to the first frame showing the change.
- **Measurements:** `touch-to-frame`.
- **Pass:** touch-to-frame latency recorded for 200 samples per device; a tap under 10 points and 0.5 s on a known open
  cell sends exactly one pulse and on any other cell only moves the cursor; a press held 0.5 s without moving 10 points
  claims that cell on release and moving after arming cancels it; a drag of 16 points or more places or moves exactly
  one marker on release; a double tap on empty space restores the authored camera.
- **Gating:** yes. **Covers:** T-R02G1104-011.
- **Owner steps:** the device in hand, unlocked, trusted and charged; the campaign installs the automation build
  (signing is the owner's). The owner taps cells, drags markers, holds cells to claim and orbits with two fingers; the
  campaign does not synthesise touches on hardware.
- **Status:** pending device campaign.

### EC-D5 — Sound heard and haptics felt

- **Devices:** D1, D2, D3.
- **Procedure:** turn the Sound toggle on and play a level to a win and to a failure with the haptics switch on,
  including one refused action (a pulse from an unknown cell); observe the chamber's ambient sound and the selection,
  success, warning and error haptics.
- **Measurements:** `sound-audible`, `haptics-felt`.
- **Pass:** the sound is audible only while it is on, the panel is shown and the scene is active, and follows the
  silent switch; each planned haptic is felt (where the device has no haptic engine, the haptic part is recorded as not
  applicable).
- **Gating:** yes. **Covers:** T-R02G1106-011.
- **Owner steps:** the device in hand, unlocked, trusted and charged; the campaign installs the automation build
  (signing is the owner's). The owner listens and feels, and sets the silent switch and the system haptics setting.
- **Status:** pending device campaign.

### EC-D6 — VoiceOver walk-through (manual, non-gating)

- **Devices:** D1, D2, D3.
- **Procedure:** with VoiceOver on and the largest accessibility text size, choose a cell with the adjustable column
  and row steppers, pulse and hear the echo described, place a marker, claim the beacon and hear the win; replay it.
- **Measurements:** `voiceover-observation`.
- **Pass:** every control and the summary element are read with their label and value; each pulse with its echo, each
  marker, claim, undo, redo, refusal and the win are announced; the panel stays readable at the largest accessibility
  text size; recorded as an observation.
- **Gating:** no (non-gating, P-08). **Covers:** T-R02G1106-011.
- **Owner steps:** the device in hand, unlocked, trusted and charged; the campaign installs the automation build
  (signing is the owner's). The owner turns VoiceOver and the text size on and off in Settings and performs the
  walk-through.
- **Status:** pending device campaign.

### EC-D7 — Progress across a real termination

- **Devices:** D1, D2, D3.
- **Procedure:** win level 1, leave the app to the background, end it from the app switcher, reopen Echo Cartographer.
- **Measurements:** `progress-kept`.
- **Pass:** level 1 is solved with its stars, level 2 is open and the replay of level 1 is offered after the reopen; an
  unfinished level restores to the same knowledge, markers, energy and records.
- **Gating:** yes. **Covers:** T-R02G1107-011.
- **Owner steps:** the device in hand, unlocked, trusted and charged; the campaign installs the automation build
  (signing is the owner's). The owner ends the app from the app switcher.
- **Status:** pending device campaign.

### EC-D8 — Panel journeys in the app

- **Devices:** D1, D2, D3.
- **Procedure:** run the device scenario set by id and the interface journeys of chunk `t3` (`ECGPlayUITests` and
  `ECGReplayUITests`: win level 1 with the column and row steppers, Pulse and Claim, replay, relaunch).
- **Measurements:** `scenarios`, `journeys`.
- **Pass:** every scenario of the device set passes; level 1 is won with its two certified pulses and one claim with 3
  of 3 stars, level 2 is open, progress survives the relaunch, the replay ends won.
- **Gating:** yes. **Covers:** T-R02G1109-011.
- **Owner steps:** the device in hand, unlocked, trusted and charged; the campaign installs the automation build
  (signing is the owner's).
- **Status:** pending device campaign.

## The earlier tasks these rows close

- T-R02G1103-012 (feature 403, renderer): frame time per tier on devices — EC-D2.
- T-R02G1104-011 (feature 404, spatial interaction): touch feel and touch-to-frame latency — EC-D4.
- T-R02G1106-011 (feature 406, polish and accessibility): sound heard, haptics felt (EC-D5) and the VoiceOver
  walk-through at the largest text size (EC-D6).
- T-R02G1107-011 (feature 407, persistence): progress kept across a real termination — EC-D7.
- T-R02G1108-012 (feature 408, regression): frame time and memory of the golden levels per tier — EC-D2, EC-D3.
- T-R02G1109-011 (feature 409, in the app): the panel journeys on devices — EC-D8.

Features 401, 402 and 405 have no {device} task.
