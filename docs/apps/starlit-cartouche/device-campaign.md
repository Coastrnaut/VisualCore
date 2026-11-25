# Starlit Cartouche — device campaign plan (R02-G16-10, feature 460)

This is the written plan of feature 460 (FR-R02G1610-002 of
[spec.md](../../../specs/460-starlit-cartouche-device-automation-preparation/spec.md)). These rows need real devices.
They run only after `ImplementationLock-100` (CLAUDE.md rule 5), in the order D1 → D2 → D3, and D3 is not updated
from iPadOS 26.5; a campaign that finds D3 on another version is refused, not adapted. Until then every row is "pending
device campaign", and no launch, frame, memory, thermal, latency, sound, haptic or accessibility number is claimed
anywhere. Simulator results never stand in for these rows: the simulator evidence of features 458 and 459 (the
regression and the interface journeys) is a development signal, not device evidence. The campaign is UA-F13's
`scripts/run_device_campaign.py`, which reads [device-rows.json](device-rows.json); this page is its human-readable twin
and says the same things. `python3 scripts/check_device_rows.py --experience r02-g16.starlit-cartouche` checks the
definition: its shape, the scenario names against the manifest, the devices against the ledger, and that every deferred
{device} task is covered; `release_check.py` runs it as the step `device-rows-r02-g16`. Runs are short (minutes at
most, no soak) and a longer session is bounded by arithmetic from the short run (owner ruling of 2026-11-13), except the
30-minute round-two stress session that UA-F13 requires, which only the device campaign runs.

## Starlit Cartouche as built

Starlit Cartouche (`r02-g16.starlit-cartouche`, a free candidate until X-R02-G16) is a puzzle of a sapphire ship among
stars that drift on periodic orbits: the ship flies corridors between stars, and each leg waits whole beats until its
two stars have drifted into range. Every leg flown along a stroke of the symbol draws that stroke with the meteor-gold
trail on a cartouche, an ancient symbol drawn as strokes. The player flies legs within the action budget and wins when
the whole symbol is drawn and the ship rests at the beacon by the deadline; a leg fails when a star is outside its time
window, when it crosses a hazard tube, when it arrives after the deadline or when it draws a stray stroke, and the level
fails when the budget is spent without a win; a leg to a star no corridor joins is refused. The panel has the
destination stepper (Star − and Star +, naming the chosen star), the wait stepper (Wait − and Wait +), Fly, Undo, Redo,
Next level, Reset view, Hint, the tutorial's Dismiss, the failure explanation with its Undo and Retry, Campaign, Daily,
Practice, the level picker with Play level, Replay best solution with Step and Stop, the Sound toggle and a summary
element. On the touch screen a tap on a star chooses it as the destination, a second tap on the same star within 0.35 s
and 22 points flies there with the chosen wait, a drag of the ship (from 16 points of travel) previews the star under
the finger and flies there on release, a drag on the time slider sets the wait, two fingers orbit the camera and a
double tap on empty space restores the authored view. Level 1 is won by its certified legs, star 4 after 1 beat and then
star 5 after 0 beats, with 3 of 3 stars. A winning play can be replayed. Details:
[starlit-cartouche.md](../../architecture/starlit-cartouche.md) (features 451 … 459).

## Devices

| Device | Model | Ledger row |
|---|---|---|
| D1 | iPhone 15 | DEV1-R02-G16 |
| D2 | iPad Pro 13-inch (M5) | DEV2-R02-G16 |
| D3 | iPad (A16) on iPadOS 26.5 (not updated) | DEV3-R02-G16 |

Every row runs on D1, D2 and D3, in that order.

## Device scenario set

The campaign runs these 12 scenarios of Starlit Cartouche's manifest by id on each device: `launch-first-frame`,
`input-response`, `completion`, `rejection`, `save-restore`, `reset`, `suspend-resume`, `teardown-reentry`,
`cancel-prepare`, `full-playthrough`, `hero` and `fixture-level-1-solved` (a stored win restored on the device). The 80
acceptance rows and the other two fixtures of the manifest (`fixture-leg-fails`, `fixture-undo-redo`) stay
simulator-only: they are pure rule outcomes, which the host and the simulator already prove and which a device cannot
change.

## Owner actions

The devices in hand, unlocking them, trusting the computer, the developer-mode and signing steps, charging and
unplugging, the silent switch, the system haptics setting, turning VoiceOver and the text size on and off, tapping stars
to choose destinations, double-tapping stars to fly, dragging the ship onto stars, dragging the time slider,
double-tapping empty space and the two-finger orbit, listening and feeling, and ending the app from the app switcher are
done by the owner. Each such step is recorded by the campaign as `BLOCKED_OWNER_ACTION` with its exact steps when it
reaches it, never waited for, and the other rows continue.

## Rows

### SC-D1 — Launch and first frame

- **Devices:** D1, D2, D3.
- **Procedure:** open Starlit Cartouche from the catalog with the testing argument, 200 times per device across the
  three host tiers; the campaign records preparation, shader set-up and first present as stage times.
- **Measurements:** `launch`, `first-frame`.
- **Pass:** no shader program is compiled after the experience became interactive; stage times recorded for 200 samples
  per device and tier (docs/performance/budgets.md, proposal).
- **Gating:** yes. **Covers:** UA-F13 `launch`, `first-frame`.
- **Owner steps:** the owner has the device in hand, unlocked, trusted and charged; the automation build is installed by
  the campaign (signing is the owner's).
- **Status:** pending device campaign.

### SC-D2 — Frame pacing and frame time per tier

- **Devices:** D1, D2, D3.
- **Procedure:** run the hero and full-playthrough scenarios pinned to tiers 0, 1 and 2 in turn, then with automatic
  levels; the campaign records each frame's interval.
- **Measurements:** `frame-pacing`, `frame-time-per-tier`.
- **Pass:** 60 frames per second with automatic levels (a documented 30 frames per second mode is acceptable on the last
  level), 200 samples per device; frame time per pinned tier recorded.
- **Gating:** yes. **Covers:** T-R02G1603-012, T-R02G1608-012; UA-F13 `frame-pacing`.
- **Owner steps:** the owner has the device in hand, unlocked, trusted and charged; the automation build is installed by
  the campaign (signing is the owner's).
- **Status:** pending device campaign.

### SC-D3 — Memory, thermal state and the round-two stress session

- **Devices:** D1, D2, D3.
- **Procedure:** run the 30-minute round-two stress session of UA-F13 (levels opened, legs flown with double taps, ship
  drags and the panel, destinations chosen with taps and waits with the slider, actions undone and redone, the camera
  orbited, levels retried and replayed in a loop) at automatic levels; the campaign samples the footprint and the
  thermal state.
- **Measurements:** `memory`, `thermal`, `stress`.
- **Pass:** memory flat within the declared resource budget over the session (the growth rule of feature 192), 200
  samples per device; thermal state and any tier change recorded.
- **Gating:** yes. **Covers:** T-R02G1608-012; UA-F13 `memory`, `thermal`, `stress`.
- **Owner steps:** the owner has the device in hand, unlocked, trusted and charged; the automation build is installed by
  the campaign (signing is the owner's). The owner keeps the device unplugged for the stress session and tells the
  campaign the starting battery level.
- **Status:** pending device campaign.

### SC-D4 — Touch feel and touch-to-frame latency

- **Devices:** D1, D2, D3.
- **Procedure:** tap stars to choose destinations, double-tap a star to fly, drag the ship onto a star, drag the time
  slider, orbit the camera with two fingers and double-tap empty space on each device; the campaign records the
  interval from touch to the first frame showing the change.
- **Measurements:** `touch-to-frame`.
- **Pass:** touch-to-frame latency recorded for 200 samples per device; a tap (travel under 10 points, lifted within
  0.5 s) on a star chooses it as the destination; a second tap on the same star within 0.35 s and 22 points flies there
  with the chosen wait while playing; a ship drag (16 points or more from the ship) previews the star under the finger
  and sends exactly one route.fly on release over a star joined by a corridor; a slider drag sets the wait under the
  finger; a double tap on empty space restores the authored orbit.
- **Gating:** yes. **Covers:** T-R02G1604-011.
- **Owner steps:** the owner has the device in hand, unlocked, trusted and charged; the automation build is installed by
  the campaign (signing is the owner's). The owner taps stars to choose a destination, double-taps stars to fly, drags
  the ship onto stars, drags the time slider, double-taps empty space and orbits with two fingers; the campaign does not
  synthesise touches on hardware.
- **Status:** pending device campaign.

### SC-D5 — Sound heard and haptics felt

- **Devices:** D1, D2, D3.
- **Procedure:** turn the Sound toggle on and play a level to a win and to a failure with the haptics switch on,
  including one refused action (flying to a star no corridor joins, which the rules refuse); choose a destination to
  hear its audition; observe the firmament's ambient sound and the selection, success, warning and error haptics.
- **Measurements:** `sound-audible`, `haptics-felt`.
- **Pass:** the sound is audible only while it is on, the panel is shown and the scene is active, and follows the silent
  switch; each planned haptic is felt (where the device has no haptic engine, the haptic part is recorded as not
  applicable).
- **Gating:** yes. **Covers:** T-R02G1606-011.
- **Owner steps:** the owner has the device in hand, unlocked, trusted and charged; the automation build is installed by
  the campaign (signing is the owner's). The owner listens and feels, and sets the silent switch and the system haptics
  setting.
- **Status:** pending device campaign.

### SC-D6 — VoiceOver walk-through (manual, non-gating)

- **Devices:** D1, D2, D3.
- **Procedure:** with VoiceOver on and the largest accessibility text size, choose a destination and a wait with the
  adjustable controls, fly each leg with Fly to hear each leg and the win; replay it.
- **Measurements:** `voiceover-observation`.
- **Pass:** every control and the summary element are read with their label and value; each leg, undo, redo, refusal,
  failure and the win are announced; the panel stays readable at the largest accessibility text size; recorded as an
  observation (non-gating, P-08).
- **Gating:** no (non-gating, P-08). **Covers:** T-R02G1606-011.
- **Owner steps:** the owner has the device in hand, unlocked, trusted and charged; the automation build is installed by
  the campaign (signing is the owner's). The owner turns VoiceOver and the text size on and off in Settings and performs
  the walk-through.
- **Status:** pending device campaign.

### SC-D7 — Progress across a real termination

- **Devices:** D1, D2, D3.
- **Procedure:** win level 1, leave the app to the background, end it from the app switcher, reopen Starlit Cartouche.
- **Measurements:** `progress-kept`.
- **Pass:** level 1 is solved with its stars, level 2 is open and the replay of level 1 is offered after the reopen; an
  unfinished level restores to the same legs, actions left and records.
- **Gating:** yes. **Covers:** T-R02G1607-011.
- **Owner steps:** the owner has the device in hand, unlocked, trusted and charged; the automation build is installed by
  the campaign (signing is the owner's). The owner ends the app from the app switcher.
- **Status:** pending device campaign.

### SC-D8 — Panel journeys in the app

- **Devices:** D1, D2, D3.
- **Procedure:** run the device scenario set by id and the interface journeys of chunk y3 (`SCPlayUITests` and
  `SCReplayUITests`: win level 1 with its two legs chosen and flown, replay, relaunch).
- **Measurements:** `scenarios`, `journeys`.
- **Pass:** every scenario of the device set passes; level 1 is won with its certified legs (star 4 after 1 beat, then
  star 5 after 0 beats) with 3 of 3 stars, level 2 is open, progress survives the relaunch, the replay ends won.
- **Gating:** yes. **Covers:** T-R02G1609-011.
- **Owner steps:** the owner has the device in hand, unlocked, trusted and charged; the automation build is installed by
  the campaign (signing is the owner's).
- **Status:** pending device campaign.

## The earlier tasks these rows close

- T-R02G1603-012 (feature 453, renderer): frame time per tier on devices — SC-D2.
- T-R02G1604-011 (feature 454, gestures): touch feel and touch-to-frame latency — SC-D4.
- T-R02G1606-011 (feature 456, polish and accessibility): sound heard, haptics felt (SC-D5) and the VoiceOver
  walk-through at the largest text size (SC-D6).
- T-R02G1607-011 (feature 457, persistence): progress kept across a real termination — SC-D7.
- T-R02G1608-012 (feature 458, regression): frame time and memory of the golden levels per tier — SC-D2, SC-D3.
- T-R02G1609-011 (feature 459, in the app): the panel journeys on devices — SC-D8.

Features 451, 452 and 455 have no {device} task.
