# Celestial Eclipse Lab — device campaign plan (R02-G17-10, feature 470)

This is the written plan of feature 470 (FR-R02G1710-002 of
[spec.md](../../../specs/470-celestial-eclipse-lab-device-automation-preparation/spec.md)). These rows need real
devices. They run only after `ImplementationLock-100` (CLAUDE.md rule 5), in the order D1 → D2 → D3, and D3 is not
updated from iPadOS 26.5; a campaign that finds D3 on another version is refused, not adapted. Until then every row is
"pending device campaign", and no launch, frame, memory, thermal, latency, sound, haptic or accessibility number is
claimed anywhere. Simulator results never stand in for these rows: the simulator evidence of features 468 and 469 (the
regression and the interface journeys) is a development signal, not device evidence. The campaign is UA-F13's
`scripts/run_device_campaign.py`, which reads [device-rows.json](device-rows.json); this page is its human-readable
twin and says the same things. `python3 scripts/check_device_rows.py --experience r02-g17.celestial-eclipse-lab` checks
the definition: its shape, the scenario names against the manifest, the devices against the ledger, and that every
deferred {device} task is covered; `release_check.py` runs it as the step `device-rows-r02-g17`. Runs are short
(minutes at most, no soak) and a longer session is bounded by arithmetic from the short run (owner ruling of
2026-11-13), except the 30-minute round-two stress session that UA-F13 requires, which only the device campaign runs.

## Celestial Eclipse Lab as built

Celestial Eclipse Lab (`r02-g17.celestial-eclipse-lab`, a free candidate until X-R02-G17) is a puzzle of miniature
bodies on periodic orbits seen from one side: the player turns the movable bodies to new phases, then runs the clock,
so that the eclipses (one body's disc passing in front of another's) come in exactly the target order, each inside its
window, with no other eclipse first. Every phase change spends one action; the run spends nothing and ends the level
won or failed. A run fails when an unwanted eclipse comes first, when a target eclipse falls outside its window, or
when the horizon is reached before the sequence is complete; a phase change of a fixed or unknown body, to an offset
outside the period or to the phase the body already has, is refused, and so is any phase change with no action left.
The panel has the planet stepper (Planet − and Planet +, naming the chosen body), the phase stepper (Phase − and
Phase +, moving a pending phase without spending an action), Set phase, Reset view, the tick stepper (Tick − and
Tick +, showing a tick of the timeline), Run, Undo, Redo, Next level, the tutorial's Dismiss tutorial, Hint, the
failure explanation, Campaign, Daily, Practice, the level picker with Play level, Replay best solution with Step and
Stop, the Sound toggle and a summary element. On the touch screen a tap on a planet chooses it, a drag of a movable
planet along its orbital ring (from 16 points of travel, while playing) previews the nearest phase with a dashed ghost
and the predicted timeline and sets that phase on release, a drag or tap on the timeline dial shows the nearest
projected tick, a drag on a fixed planet explains in words why nothing moves, two fingers orbit the camera and a double
tap on empty space restores the authored view. Level 1 is won by its certified plan, body 1 to phase 2 and then body 2
to phase 0, then Run, with 3 of 3 stars. A winning play can be replayed. Details:
[celestial-eclipse-lab.md](../../architecture/celestial-eclipse-lab.md) (features 461 … 469).

## Devices

| Device | Model | Ledger row |
|---|---|---|
| D1 | iPhone 15 | DEV1-R02-G17 |
| D2 | iPad Pro 13-inch (M5) | DEV2-R02-G17 |
| D3 | iPad (A16) on iPadOS 26.5 (not updated) | DEV3-R02-G17 |

Every row runs on D1, D2 and D3, in that order.

## Device scenario set

The campaign runs these 12 scenarios of Celestial Eclipse Lab's manifest by id on each device: `launch-first-frame`,
`input-response`, `completion`, `rejection`, `save-restore`, `reset`, `suspend-resume`, `teardown-reentry`,
`cancel-prepare`, `full-playthrough`, `hero` and `fixture-level-1-solved` (a stored win restored on the device). The 80
acceptance rows and the other two fixtures of the manifest (`fixture-run-fails`, `fixture-undo-redo`) stay
simulator-only: they are pure rule outcomes, which the host and the simulator already prove and which a device cannot
change.

## Owner actions

The devices in hand, unlocking them, trusting the computer, the developer-mode and signing steps, charging and
unplugging, the silent switch, the system haptics setting, turning VoiceOver and the text size on and off, tapping
planets to choose them, dragging planets along their orbits, dragging the timeline dial, double-tapping empty space and
the two-finger orbit, listening and feeling, and ending the app from the app switcher are done by the owner. Each such
step is recorded by the campaign as `BLOCKED_OWNER_ACTION` with its exact steps when it reaches it, never waited for,
and the other rows continue.

## Rows

### CEL-D1 — Launch and first frame

- **Devices:** D1, D2, D3.
- **Procedure:** open Celestial Eclipse Lab from the catalog with the testing argument, 200 times per device across the
  three host tiers; the campaign records preparation, shader set-up and first present as stage times.
- **Measurements:** `launch`, `first-frame`.
- **Pass:** no shader program is compiled after the experience became interactive; stage times recorded for 200
  samples per device and tier (docs/performance/budgets.md, proposal).
- **Gating:** yes. **Covers:** UA-F13 `launch`, `first-frame`.
- **Owner steps:** the owner has the device in hand, unlocked, trusted and charged; the automation build is installed
  by the campaign (signing is the owner's).
- **Status:** pending device campaign.

### CEL-D2 — Frame pacing and frame time per tier

- **Devices:** D1, D2, D3.
- **Procedure:** run the hero and full-playthrough scenarios pinned to tiers 0, 1 and 2 in turn, then with automatic
  levels; the campaign records each frame's interval.
- **Measurements:** `frame-pacing`, `frame-time-per-tier`.
- **Pass:** 60 frames per second with automatic levels (a documented 30 frames per second mode is acceptable on the
  last level), 200 samples per device; frame time per pinned tier recorded.
- **Gating:** yes. **Covers:** T-R02G1703-012, T-R02G1708-012; UA-F13 `frame-pacing`.
- **Owner steps:** the owner has the device in hand, unlocked, trusted and charged; the automation build is installed
  by the campaign (signing is the owner's).
- **Status:** pending device campaign.

### CEL-D3 — Memory, thermal state and the round-two stress session

- **Devices:** D1, D2, D3.
- **Procedure:** run the 30-minute round-two stress session of UA-F13 (levels opened, planets chosen with taps, phases
  set with orbit drags and the panel, the clock run, the timeline shown with the dial, actions undone and redone, the
  camera orbited, levels retried and replayed in a loop) at automatic levels; the campaign samples the footprint and
  the thermal state.
- **Measurements:** `memory`, `thermal`, `stress`.
- **Pass:** memory flat within the declared resource budget over the session (the growth rule of feature 192), 200
  samples per device; thermal state and any tier change recorded.
- **Gating:** yes. **Covers:** T-R02G1708-012; UA-F13 `memory`, `thermal`, `stress`.
- **Owner steps:** the owner has the device in hand, unlocked, trusted and charged; the automation build is installed
  by the campaign (signing is the owner's). The owner keeps the device unplugged for the stress session and tells the
  campaign the starting battery level.
- **Status:** pending device campaign.

### CEL-D4 — Touch feel and touch-to-frame latency

- **Devices:** D1, D2, D3.
- **Procedure:** tap planets to choose them, drag a planet along its orbit to preview and set its phase, drag the
  timeline dial to show a tick, orbit the camera with two fingers and double-tap empty space on each device; the
  campaign records the interval from touch to the first frame showing the change.
- **Measurements:** `touch-to-frame`.
- **Pass:** touch-to-frame latency recorded for 200 samples per device; a tap (travel under 10 points, lifted within
  0.5 s) on a planet chooses it; a drag of a movable planet (16 points or more) along its orbit shows the ghost preview
  at the nearest phase and sends exactly one orbit.phase on release; a drag on the timeline dial shows the nearest
  projected tick under the finger; a drag on a fixed planet explains why nothing moves; a double tap on empty space
  (within 0.35 s and 22 points) restores the authored orbit.
- **Gating:** yes. **Covers:** T-R02G1704-011.
- **Owner steps:** the owner has the device in hand, unlocked, trusted and charged; the automation build is installed
  by the campaign (signing is the owner's). The owner taps planets to choose them, drags planets along their orbits,
  drags the timeline dial, double-taps empty space and orbits with two fingers; the campaign does not synthesise
  touches on hardware.
- **Status:** pending device campaign.

### CEL-D5 — Sound heard and haptics felt

- **Devices:** D1, D2, D3.
- **Procedure:** turn the Sound toggle on and play a level to a win and to a failure with the haptics switch on,
  including one refused action (setting a planet to the phase it already has, which the rules refuse); choose planets
  to hear their auditions; observe the sky's ambient sound and the selection, success, warning and error haptics.
- **Measurements:** `sound-audible`, `haptics-felt`.
- **Pass:** the sound is audible only while it is on, the panel is shown and the scene is active, and follows the
  silent switch; each planned haptic is felt (where the device has no haptic engine, the haptic part is recorded as not
  applicable).
- **Gating:** yes. **Covers:** T-R02G1706-011.
- **Owner steps:** the owner has the device in hand, unlocked, trusted and charged; the automation build is installed
  by the campaign (signing is the owner's). The owner listens and feels, and sets the silent switch and the system
  haptics setting.
- **Status:** pending device campaign.

### CEL-D6 — VoiceOver walk-through (manual, non-gating)

- **Devices:** D1, D2, D3.
- **Procedure:** with VoiceOver on and the largest accessibility text size, choose a planet and its pending phase with
  the adjustable controls, set each phase with Set phase and run the clock with Run to hear each change and the win;
  replay it.
- **Measurements:** `voiceover-observation`.
- **Pass:** every control and the summary element are read with their label and value; each phase change, undo, redo,
  refusal, failure and the win are announced; the panel stays readable at the largest accessibility text size;
  recorded as an observation (non-gating, P-08).
- **Gating:** no (non-gating, P-08). **Covers:** T-R02G1706-011.
- **Owner steps:** the owner has the device in hand, unlocked, trusted and charged; the automation build is installed
  by the campaign (signing is the owner's). The owner turns VoiceOver and the text size on and off in Settings and
  performs the walk-through.
- **Status:** pending device campaign.

### CEL-D7 — Progress across a real termination

- **Devices:** D1, D2, D3.
- **Procedure:** win level 1, leave the app to the background, end it from the app switcher, reopen Celestial Eclipse
  Lab.
- **Measurements:** `progress-kept`.
- **Pass:** level 1 is solved with its stars, level 2 is open and the replay of level 1 is offered after the reopen; an
  unfinished level restores to the same phases, actions left and records.
- **Gating:** yes. **Covers:** T-R02G1707-012.
- **Owner steps:** the owner has the device in hand, unlocked, trusted and charged; the automation build is installed
  by the campaign (signing is the owner's). The owner ends the app from the app switcher.
- **Status:** pending device campaign.

### CEL-D8 — Panel journeys in the app

- **Devices:** D1, D2, D3.
- **Procedure:** run the device scenario set by id and the interface journeys of chunk z3 (`CELPlayUITests` and
  `CELReplayUITests`: win level 1 with its two phase changes set and the run, replay, relaunch).
- **Measurements:** `scenarios`, `journeys`.
- **Pass:** every scenario of the device set passes; level 1 is won with its certified plan (body 1 to phase 2, then
  body 2 to phase 0, then the run) with 3 of 3 stars, level 2 is open, progress survives the relaunch, the replay ends
  won.
- **Gating:** yes. **Covers:** T-R02G1709-011.
- **Owner steps:** the owner has the device in hand, unlocked, trusted and charged; the automation build is installed
  by the campaign (signing is the owner's).
- **Status:** pending device campaign.

## The earlier tasks these rows close

- T-R02G1703-012 (feature 463, renderer): frame time per tier on devices — CEL-D2.
- T-R02G1704-011 (feature 464, gestures): touch feel and touch-to-frame latency — CEL-D4.
- T-R02G1706-011 (feature 466, polish and accessibility): sound heard, haptics felt (CEL-D5) and the VoiceOver
  walk-through at the largest text size (CEL-D6).
- T-R02G1707-012 (feature 467, persistence): progress kept across a real termination — CEL-D7.
- T-R02G1708-012 (feature 468, regression): frame time and memory of the golden levels per tier — CEL-D2, CEL-D3.
- T-R02G1709-011 (feature 469, in the app): the panel journeys on devices — CEL-D8.

Features 461, 462 and 465 have no {device} task.
