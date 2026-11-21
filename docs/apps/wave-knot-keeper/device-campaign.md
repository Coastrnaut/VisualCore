# Wave Knot Keeper — device campaign plan (R02-G03-10, feature 330)

This is the written plan of feature 330 (FR-R02G0310-002 of
[spec.md](../../../specs/330-wave-knot-keeper-device-automation-preparation/spec.md)). These rows need real devices.
They run only after `ImplementationLock-100` (CLAUDE.md rule 5), in the order D1 → D2 → D3, and D3 is not updated from
iPadOS 26.5; a campaign that finds D3 on another version is refused, not adapted. Until then every row is "pending
device campaign", and no launch, frame, memory, thermal, latency, sound, haptic or accessibility number is claimed
anywhere. Simulator results never stand in for these rows: the simulator evidence of features 328 and 329 (the
regression and the interface journeys) is a development signal, not device evidence. The campaign is UA-F13's
`scripts/run_device_campaign.py`, which reads [device-rows.json](device-rows.json); this page is its human-readable twin
and says the same things. `python3 scripts/check_device_rows.py --experience r02-g03.wave-knot-keeper` checks the
definition: its shape, the scenario names against the manifest, the devices against the ledger, and that every deferred
{device} task is covered. Runs are short (minutes at most, no soak) and a longer session is bounded by arithmetic from
the short run (owner ruling of 2026-11-13), except the 30-minute round-two stress session that UA-F13 requires, which
only the device campaign runs.

## Wave Knot Keeper as built

Wave Knot Keeper (`r02-g03.wave-knot-keeper`) is a puzzle of a closed glowing rope: the player moves one control point
one lattice step at a time along ±x, ±y or ±z, never passing the rope through itself except inside the level's crossing
gates, until the rope's projected crossings and writhe match the target. The kernel decides every move and the win by
exact integer arithmetic, never by the renderer. The catalog holds 100 certified levels in five bands of 20, each with a
witness file. The scene draws the rope as a glass tube with glow shells, handle icospheres and gate cubes with GLSL ES
3.00 shaders on the OpenGL ES → ANGLE → Metal path in three tiers, `level-0`, `level-1` and `level-2` (richest first,
coordinates never change); a program that does not compile falls back to the minimal tube drawn unlit. A point is moved
by dragging its handle (one move of one lattice step per gesture, sent on release), the camera orbits with two fingers,
and the panel's point picker and six direction buttons send the same moves. Level 1 is won in 1 move (point 2, +x) with
3 stars. A winning play can be replayed move by move. Progress is kept in saved-state snapshot schema 3 (level, mode,
progress with the verified winning trace per level, records, tutorial). An ambient Sound toggle is off by default;
announcements and haptics go through the shared feedback route; Reduce Motion holds the caustic pulse still and Reduce
Flashing slows the crossing, target and win fades. Details:
[wave-knot-keeper.md](../../architecture/wave-knot-keeper.md).

## Devices

| Device | Model | Ledger row |
|---|---|---|
| D1 | iPhone 15 | DEV1-R02-G03 |
| D2 | iPad Pro 13-inch (M5) | DEV2-R02-G03 |
| D3 | iPad (A16) on iPadOS 26.5 (not updated) | DEV3-R02-G03 |

Every row runs on D1, D2 and D3, in that order.

## Device scenario set

The campaign runs these 12 scenarios of Wave Knot Keeper's manifest by id on each device: `launch-first-frame`,
`input-response`, `completion`, `rejection`, `save-restore`, `reset`, `suspend-resume`, `teardown-reentry`,
`cancel-prepare`, `full-playthrough`, `hero` and `fixture-level-1-solved` (a stored win restored on the device). The 80
acceptance rows and the other two fixtures of the manifest (`fixture-allowance-spent`, `fixture-undo-redo`) stay
simulator-only: they are pure rule outcomes, which the host and the simulator already prove and which a device cannot
change.

## Owner actions

The devices in hand, unlocking them, trusting the computer, the developer-mode and signing steps, charging and
unplugging, the silent switch, the system haptics setting, turning VoiceOver and the text size on and off, dragging the
handles and the two-finger orbit, listening and feeling, and ending the app from the app switcher are done by the
owner. Each such step is recorded by the campaign as `BLOCKED_OWNER_ACTION` with its exact steps when it reaches it,
never waited for, and the other rows continue.

## Rows

### WK-D1 — Launch and first frame

- **Devices:** D1, D2, D3.
- **Procedure:** open Wave Knot Keeper from the catalog with the testing argument, 200 times per device across the
  three host tiers; the campaign records preparation, shader set-up and first present as stage times.
- **Measurements:** `launch`, `first-frame`.
- **Pass:** no shader program is compiled after the experience became interactive; stage times recorded for 200
  samples per device and tier (`docs/performance/budgets.md`, proposal).
- **Gating:** yes. **Covers:** UA-F13 `launch`, `first-frame`.
- **Owner steps:** the device in hand, unlocked, trusted and charged; the campaign installs the automation build
  (signing is the owner's).
- **Status:** pending device campaign.

### WK-D2 — Frame pacing and frame time per tier

- **Devices:** D1, D2, D3.
- **Procedure:** run the `hero` and `full-playthrough` scenarios pinned to tiers 0, 1 and 2 in turn, then with automatic
  levels; the campaign records each frame's interval.
- **Measurements:** `frame-pacing`, `frame-time-per-tier`.
- **Pass:** 60 frames per second with automatic levels (a documented 30 frames per second mode is acceptable on the last
  level), 200 samples per device; frame time per pinned tier recorded.
- **Gating:** yes. **Covers:** UA-F13 `frame-pacing`, T-R02G0303-012, T-R02G0308-012.
- **Owner steps:** the device in hand, unlocked, trusted and charged; the campaign installs the automation build
  (signing is the owner's).
- **Status:** pending device campaign.

### WK-D3 — Memory, thermal state and the round-two stress session

- **Devices:** D1, D2, D3.
- **Procedure:** run the 30-minute round-two stress session of UA-F13 (levels opened, played, undone and replayed in a
  loop) at automatic levels; the campaign samples the footprint and the thermal state.
- **Measurements:** `memory`, `thermal`, `stress`.
- **Pass:** memory flat within the declared resource budget over the session (the growth rule of feature 192), 200
  samples per device; thermal state and any tier change recorded.
- **Gating:** yes. **Covers:** UA-F13 `memory`, `thermal`, `stress`, T-R02G0308-012.
- **Owner steps:** the device in hand, unlocked, trusted and charged; the campaign installs the automation build
  (signing is the owner's). The owner keeps the device unplugged for the stress session and tells the campaign the
  starting battery level.
- **Status:** pending device campaign.

### WK-D4 — Gesture feel and touch-to-frame latency

- **Devices:** D1, D2, D3.
- **Procedure:** drag control-point handles one lattice step each and orbit the camera with two fingers on each device;
  the campaign records the interval from touch to the first frame showing the change.
- **Measurements:** `touch-to-frame`.
- **Pass:** touch-to-frame latency recorded for 200 samples per device; dragging a handle previews the best-aligned
  direction under the finger and exactly one move of one lattice step is sent on release.
- **Gating:** yes. **Covers:** T-R02G0304-011.
- **Owner steps:** the device in hand, unlocked, trusted and charged; the campaign installs the automation build
  (signing is the owner's). The owner drags the handles and orbits with two fingers; the campaign does not synthesise
  touches on hardware.
- **Status:** pending device campaign.

### WK-D5 — Sound heard and haptics felt

- **Devices:** D1, D2, D3.
- **Procedure:** turn the Sound toggle on and play a level to a win and to a failure with the haptics switch on,
  including one refused move; observe the ambient loop and the selection, success, warning and error haptics.
- **Measurements:** `sound-audible`, `haptics-felt`.
- **Pass:** the loop is audible only while the sound is on, the panel is shown and the scene is active, and follows the
  silent switch; each planned haptic is felt (where the device has no haptic engine, the haptic part is recorded as not
  applicable).
- **Gating:** yes. **Covers:** T-R02G0306-012.
- **Owner steps:** the device in hand, unlocked, trusted and charged; the campaign installs the automation build
  (signing is the owner's). The owner listens and feels, and sets the silent switch and the system haptics setting.
- **Status:** pending device campaign.

### WK-D6 — VoiceOver walk-through (manual, non-gating)

- **Devices:** D1, D2, D3.
- **Procedure:** with VoiceOver on and the largest accessibility text size, select level 1's point with the adjustable
  point picker, press the +x button and hear the win; replay it.
- **Measurements:** `voiceover-observation`.
- **Pass:** every control is read with its label and value, each move, refusal and the win are announced; the panel
  stays readable at the largest accessibility text size; recorded as an observation.
- **Gating:** no (non-gating, P-08). **Covers:** T-R02G0306-012.
- **Owner steps:** the device in hand, unlocked, trusted and charged; the campaign installs the automation build
  (signing is the owner's). The owner turns VoiceOver and the text size on and off in Settings and performs the
  walk-through.
- **Status:** pending device campaign.

### WK-D7 — Progress across a real termination

- **Devices:** D1, D2, D3.
- **Procedure:** win level 1, leave the app to the background, end it from the app switcher, reopen Wave Knot Keeper.
- **Measurements:** `progress-kept`.
- **Pass:** level 1 is solved with its stars, level 2 is open and the replay of level 1 is offered after the reopen.
- **Gating:** yes. **Covers:** T-R02G0307-011.
- **Owner steps:** the device in hand, unlocked, trusted and charged; the campaign installs the automation build
  (signing is the owner's). The owner ends the app from the app switcher.
- **Status:** pending device campaign.

### WK-D8 — Panel journeys in the app

- **Devices:** D1, D2, D3.
- **Procedure:** run the device scenario set by id and the interface journeys of chunk `l3` (`WKPlayUITests` and
  `WKReplayUITests`: win level 1 with the point picker to point 2 and the +x button, replay, relaunch).
- **Measurements:** `scenarios`, `journeys`.
- **Pass:** every scenario of the device set passes; level 1 is won with 3 of 3 stars in 1 move, level 2 is open,
  progress survives the relaunch, the replay ends won.
- **Gating:** yes. **Covers:** T-R02G0309-011.
- **Owner steps:** the device in hand, unlocked, trusted and charged; the campaign installs the automation build
  (signing is the owner's).
- **Status:** pending device campaign.

## The earlier tasks these rows close

- T-R02G0303-012 (feature 323, renderer): frame time per tier on devices — WK-D2.
- T-R02G0304-011 (feature 324, spatial interaction): gesture feel and touch-to-frame latency — WK-D4.
- T-R02G0306-012 (feature 326, polish and accessibility): sound heard, haptics felt (WK-D5) and the VoiceOver
  walk-through at the largest text size (WK-D6).
- T-R02G0307-011 (feature 327, persistence): progress kept across a real termination — WK-D7.
- T-R02G0308-012 (feature 328, regression): frame time and memory per tier — WK-D2, WK-D3.
- T-R02G0309-011 (feature 329, in the app): the panel journeys on devices — WK-D8.
