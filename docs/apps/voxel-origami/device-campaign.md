# Voxel Origami — device campaign plan (R02-G15-10, feature 450)

This is the written plan of feature 450 (FR-R02G1510-002 of
[spec.md](../../../specs/450-voxel-origami-device-automation-preparation/spec.md)). These rows need real devices. They
run only after `ImplementationLock-100` (CLAUDE.md rule 5), in the order D1 → D2 → D3, and D3 is not updated from iPadOS
26.5; a campaign that finds D3 on another version is refused, not adapted. Until then every row is "pending device
campaign", and no launch, frame, memory, thermal, latency, sound, haptic or accessibility number is claimed anywhere.
Simulator results never stand in for these rows: the simulator evidence of features 448 and 449 (the regression and the
interface journeys) is a development signal, not device evidence. The campaign is UA-F13's
`scripts/run_device_campaign.py`, which reads [device-rows.json](device-rows.json); this page is its human-readable twin
and says the same things. `python3 scripts/check_device_rows.py --experience r02-g15.voxel-origami` checks the
definition: its shape, the scenario names against the manifest, the devices against the ledger, and that every deferred
{device} task is covered; `release_check.py` runs it as the step `device-rows-r02-g15`. Runs are short (minutes at most,
no soak) and a longer session is bounded by arithmetic from the short run (owner ruling of 2026-11-13), except the
30-minute round-two stress session that UA-F13 requires, which only the device campaign runs.

## Voxel Origami as built

Voxel Origami (`r02-g15.voxel-origami`, a free candidate until X-R02-G15) is a puzzle of luminous cubes joined by hinges
beside a wireframe target solid: each hinge turns in quarter turns and swings every cube beyond it to a new place on the
cube lattice, and a turn that would put a cube inside another, or sweep one through another, fails. The player turns
hinges within the action budget and wins when the cubes occupy exactly the target's cells, in an orientation the level
allows and anywhere in space; a hinge that would swing nothing is refused. The panel has the hinge stepper (Hinge − and
Hinge +, naming the chosen hinge) with its detail, Turn − and Turn +, Undo, Redo, Next level, Reset view, Hint, the
tutorial's Dismiss, the failure's Undo and Retry, Campaign, Daily, Practice, the level picker with Play level, Replay
best solution with Step and Stop, the Sound toggle and a summary element. On the touch screen a tap on a cube other than
the root chooses its hinge, a drag from a turnable hinge's cube previews a quarter turn the way the swinging cubes
follow (pending from 24 points, shown in words while dragging) and sends one turn on release, a second tap on the same
cube within 0.35 s and 22 points turns its hinge forward a quarter (or says that nothing would move), two fingers orbit
the camera and a double tap on empty space restores the authored view. Level 1 is won with hinge 4 chosen and Turn −
twice (hinge 4 turned back a quarter twice), with 3 of 3 stars. A winning play can be replayed. Details:
[voxel-origami.md](../../architecture/voxel-origami.md) (features 441 … 449).

## Devices

| Device | Model | Ledger row |
|---|---|---|
| D1 | iPhone 15 | DEV1-R02-G15 |
| D2 | iPad Pro 13-inch (M5) | DEV2-R02-G15 |
| D3 | iPad (A16) on iPadOS 26.5 (not updated) | DEV3-R02-G15 |

Every row runs on D1, D2 and D3, in that order.

## Device scenario set

The campaign runs these 12 scenarios of Voxel Origami's manifest by id on each device: `launch-first-frame`,
`input-response`, `completion`, `rejection`, `save-restore`, `reset`, `suspend-resume`, `teardown-reentry`,
`cancel-prepare`, `full-playthrough`, `hero` and `fixture-level-1-solved` (a stored win restored on the device). The 80
acceptance rows and the other two fixtures of the manifest (`fixture-budget-out`, `fixture-undo-redo`) stay
simulator-only: they are pure rule outcomes, which the host and the simulator already prove and which a device cannot
change.

## Owner actions

The devices in hand, unlocking them, trusting the computer, the developer-mode and signing steps, charging and
unplugging, the silent switch, the system haptics setting, turning VoiceOver and the text size on and off, tapping cubes
to choose hinges, dragging cubes to turn hinges, double-tapping cubes and the two-finger orbit, listening and feeling,
and ending the app from the app switcher are done by the owner. Each such step is recorded by the campaign as
`BLOCKED_OWNER_ACTION` with its exact steps when it reaches it, never waited for, and the other rows continue.

## Rows

### VO-D1 — Launch and first frame

- **Devices:** D1, D2, D3.
- **Procedure:** open Voxel Origami from the catalog with the testing argument, 200 times per device across the three
  host tiers; the campaign records preparation, shader set-up and first present as stage times.
- **Measurements:** `launch`, `first-frame`.
- **Pass:** no shader program is compiled after the experience became interactive; stage times recorded for 200 samples
  per device and tier (docs/performance/budgets.md, proposal).
- **Gating:** yes. **Covers:** UA-F13 `launch`, `first-frame`.
- **Owner steps:** the owner has the device in hand, unlocked, trusted and charged; the automation build is installed by
  the campaign (signing is the owner's).
- **Status:** pending device campaign.

### VO-D2 — Frame pacing and frame time per tier

- **Devices:** D1, D2, D3.
- **Procedure:** run the hero and full-playthrough scenarios pinned to tiers 0, 1 and 2 in turn, then with automatic
  levels; the campaign records each frame's interval.
- **Measurements:** `frame-pacing`, `frame-time-per-tier`.
- **Pass:** 60 frames per second with automatic levels (a documented 30 frames per second mode is acceptable on the last
  level), 200 samples per device; frame time per pinned tier recorded.
- **Gating:** yes. **Covers:** T-R02G1503-012, T-R02G1508-012; UA-F13 `frame-pacing`.
- **Owner steps:** the owner has the device in hand, unlocked, trusted and charged; the automation build is installed by
  the campaign (signing is the owner's).
- **Status:** pending device campaign.

### VO-D3 — Memory, thermal state and the round-two stress session

- **Devices:** D1, D2, D3.
- **Procedure:** run the 30-minute round-two stress session of UA-F13 (levels opened, hinges turned with drags, double
  taps and the panel, hinges chosen with taps, actions undone and redone, the camera orbited, levels retried and
  replayed in a loop) at automatic levels; the campaign samples the footprint and the thermal state.
- **Measurements:** `memory`, `thermal`, `stress`.
- **Pass:** memory flat within the declared resource budget over the session (the growth rule of feature 192), 200
  samples per device; thermal state and any tier change recorded.
- **Gating:** yes. **Covers:** T-R02G1508-012; UA-F13 `memory`, `thermal`, `stress`.
- **Owner steps:** the owner has the device in hand, unlocked, trusted and charged; the automation build is installed by
  the campaign (signing is the owner's). The owner keeps the device unplugged for the stress session and tells the
  campaign the starting battery level.
- **Status:** pending device campaign.

### VO-D4 — Touch feel and touch-to-frame latency

- **Devices:** D1, D2, D3.
- **Procedure:** tap cubes to choose hinges, drag cubes to turn hinges both ways, double-tap a cube to turn it forward,
  orbit the camera with two fingers and double-tap empty space on each device; the campaign records the interval from
  touch to the first frame showing the change.
- **Measurements:** `touch-to-frame`.
- **Pass:** touch-to-frame latency recorded for 200 samples per device; a tap (travel under 10 points, lifted within
  0.5 s) on a non-root cube chooses its hinge; a drag from a turnable hinge's cube while playing previews a quarter turn
  the way the swinging cubes follow (one step per 24 points of travel) and sends exactly one hinge.turn on release; a
  second tap on the same cube within 0.35 s and 22 points turns it forward once; a double tap on empty space restores
  the authored camera.
- **Gating:** yes. **Covers:** T-R02G1504-011.
- **Owner steps:** the owner has the device in hand, unlocked, trusted and charged; the automation build is installed by
  the campaign (signing is the owner's). The owner taps cubes to choose their hinges, drags cubes to turn hinges,
  double-taps cubes and orbits with two fingers; the campaign does not synthesise touches on hardware.
- **Status:** pending device campaign.

### VO-D5 — Sound heard and haptics felt

- **Devices:** D1, D2, D3.
- **Procedure:** turn the Sound toggle on and play a level to a win and to a failure with the haptics switch on,
  including one refused action (turning a hinge that would swing nothing, which the rules refuse); choose a hinge to
  hear its audition; observe the solid's ambient sound and the selection, success, warning and error haptics.
- **Measurements:** `sound-audible`, `haptics-felt`.
- **Pass:** the sound is audible only while it is on, the panel is shown and the scene is active, and follows the silent
  switch; each planned haptic is felt (where the device has no haptic engine, the haptic part is recorded as not
  applicable).
- **Gating:** yes. **Covers:** T-R02G1506-011.
- **Owner steps:** the owner has the device in hand, unlocked, trusted and charged; the automation build is installed by
  the campaign (signing is the owner's). The owner listens and feels, and sets the silent switch and the system haptics
  setting.
- **Status:** pending device campaign.

### VO-D6 — VoiceOver walk-through (manual, non-gating)

- **Devices:** D1, D2, D3.
- **Procedure:** with VoiceOver on and the largest accessibility text size, choose a hinge with the adjustable hinge,
  turn it with Turn + and Turn − to hear each turn and the win; replay it.
- **Measurements:** `voiceover-observation`.
- **Pass:** every control and the summary element are read with their label and value; each turn, undo, redo, refusal,
  failure and the win are announced; the panel stays readable at the largest accessibility text size; recorded as an
  observation (non-gating, P-08).
- **Gating:** no (non-gating, P-08). **Covers:** T-R02G1506-011.
- **Owner steps:** the owner has the device in hand, unlocked, trusted and charged; the automation build is installed by
  the campaign (signing is the owner's). The owner turns VoiceOver and the text size on and off in Settings and performs
  the walk-through.
- **Status:** pending device campaign.

### VO-D7 — Progress across a real termination

- **Devices:** D1, D2, D3.
- **Procedure:** win level 1, leave the app to the background, end it from the app switcher, reopen Voxel Origami.
- **Measurements:** `progress-kept`.
- **Pass:** level 1 is solved with its stars, level 2 is open and the replay of level 1 is offered after the reopen; an
  unfinished level restores to the same quarter turns, actions left and records.
- **Gating:** yes. **Covers:** T-R02G1507-011.
- **Owner steps:** the owner has the device in hand, unlocked, trusted and charged; the automation build is installed by
  the campaign (signing is the owner's). The owner ends the app from the app switcher.
- **Status:** pending device campaign.

### VO-D8 — Panel journeys in the app

- **Devices:** D1, D2, D3.
- **Procedure:** run the device scenario set by id and the interface journeys of chunk x3 (`VOPlayUITests` and
  `VOReplayUITests`: win level 1 with hinge 4 chosen and Turn − twice, replay, relaunch).
- **Measurements:** `scenarios`, `journeys`.
- **Pass:** every scenario of the device set passes; level 1 is won with its certified turns (hinge 4 turned back a
  quarter twice) with 3 of 3 stars, level 2 is open, progress survives the relaunch, the replay ends won.
- **Gating:** yes. **Covers:** T-R02G1509-011.
- **Owner steps:** the owner has the device in hand, unlocked, trusted and charged; the automation build is installed by
  the campaign (signing is the owner's).
- **Status:** pending device campaign.

## The earlier tasks these rows close

- T-R02G1503-012 (feature 443, renderer): frame time per tier on devices — VO-D2.
- T-R02G1504-011 (feature 444, spatial interaction): touch feel and touch-to-frame latency — VO-D4.
- T-R02G1506-011 (feature 446, polish and accessibility): sound heard, haptics felt (VO-D5) and the VoiceOver
  walk-through at the largest text size (VO-D6).
- T-R02G1507-011 (feature 447, persistence): progress kept across a real termination — VO-D7.
- T-R02G1508-012 (feature 448, regression): frame time and memory of the golden levels per tier — VO-D2, VO-D3.
- T-R02G1509-011 (feature 449, in the app): the panel journeys on devices — VO-D8.

Features 441, 442 and 445 have no {device} task.
