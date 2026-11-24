# Moonlit Mechanism — device campaign plan (R02-G14-10, feature 440)

This is the written plan of feature 440 (FR-R02G1410-002 of
[spec.md](../../../specs/440-moonlit-mechanism-device-automation-preparation/spec.md)). These rows need real devices.
They run only after `ImplementationLock-100` (CLAUDE.md rule 5), in the order D1 → D2 → D3, and D3 is not updated from
iPadOS 26.5; a campaign that finds D3 on another version is refused, not adapted. Until then every row is "pending
device campaign", and no launch, frame, memory, thermal, latency, sound, haptic or accessibility number is claimed
anywhere. Simulator results never stand in for these rows: the simulator evidence of features 438 and 439 (the
regression and the interface journeys) is a development signal, not device evidence. The campaign is UA-F13's
`scripts/run_device_campaign.py`, which reads [device-rows.json](device-rows.json); this page is its human-readable twin
and says the same things. `python3 scripts/check_device_rows.py --experience r02-g14.moonlit-mechanism` checks the
definition: its shape, the scenario names against the manifest, the devices against the ledger, and that every deferred
{device} task is covered; `release_check.py` runs it as the step `device-rows-r02-g14`. Runs are short (minutes at
most, no soak) and a longer session is bounded by arithmetic from the short run (owner ruling of 2026-11-13), except the
30-minute round-two stress session that UA-F13 requires, which only the device campaign runs.

## Moonlit Mechanism as built

Moonlit Mechanism (`r02-g14.moonlit-mechanism`, a free candidate until X-R02-G14) is a puzzle of interlocking gears in
front of a lamp: each gear carries open and solid blades whose shadows fall on a paper wall; turning the handle turns
the whole train, re-seating a gear (never the driver) shifts it by one tooth against its neighbours, and raising or
lowering the lamp moves every shadow by its gear's depth. The player sets up the machine within the action budget and
runs it: the run steps through the wall's key frames and wins when every meshing pair is aligned, every required key
frame's target is covered within the stray allowance and no key frame shadows a forbidden cell. The panel has the gear
stepper (naming the chosen gear) with its detail, Turn − and Turn +, the re-seat steppers (minus and plus), the lamp
stepper (Lamp − and Lamp +), the key-frame stepper, Run, Undo, Redo, Next level, Reset view, Hint, the tutorial's
Dismiss, the failure's Undo and Retry, Campaign, Daily, Practice, the level picker with Play level, Replay best
solution with Step and Stop, the Sound toggle and a summary element. On the touch screen a drag of 16 points or more
around a gear turns the train tooth for tooth the way the finger went (shown in words while dragging and sent on
release), a vertical drag on the lamp or its ladder steps it one rung per 24 points, a tap on a gear chooses it and a
double tap re-seats it by one tooth (the driver says why it cannot), a tap on a key-frame card shows its key frame, a
tap on the lamp runs, two fingers orbit the camera and a double tap on empty space restores the authored view. Level 1
is won with one handle turn (Turn +), one lamp step down (Lamp −) and the run, with 3 of 3 stars. A winning play can be
replayed. Details: [moonlit-mechanism.md](../../architecture/moonlit-mechanism.md) (features 431 … 439).

## Devices

| Device | Model | Ledger row |
|---|---|---|
| D1 | iPhone 15 | DEV1-R02-G14 |
| D2 | iPad Pro 13-inch (M5) | DEV2-R02-G14 |
| D3 | iPad (A16) on iPadOS 26.5 (not updated) | DEV3-R02-G14 |

Every row runs on D1, D2 and D3, in that order.

## Device scenario set

The campaign runs these 12 scenarios of Moonlit Mechanism's manifest by id on each device: `launch-first-frame`,
`input-response`, `completion`, `rejection`, `save-restore`, `reset`, `suspend-resume`, `teardown-reentry`,
`cancel-prepare`, `full-playthrough`, `hero` and `fixture-level-1-solved` (a stored win restored on the device). The 80
acceptance rows and the other two fixtures of the manifest (`fixture-budget-out`, `fixture-undo-redo`) stay
simulator-only: they are pure rule outcomes, which the host and the simulator already prove and which a device cannot
change.

## Owner actions

The devices in hand, unlocking them, trusting the computer, the developer-mode and signing steps, charging and
unplugging, the silent switch, the system haptics setting, turning VoiceOver and the text size on and off, dragging
around gears, dragging and tapping the lamp, double-tapping gears and the two-finger orbit, listening and feeling, and
ending the app from the app switcher are done by the owner. Each such step is recorded by the campaign as
`BLOCKED_OWNER_ACTION` with its exact steps when it reaches it, never waited for, and the other rows continue.

## Rows

### MM-D1 — Launch and first frame

- **Devices:** D1, D2, D3.
- **Procedure:** open Moonlit Mechanism from the catalog with the testing argument, 200 times per device across the
  three host tiers; the campaign records preparation, shader set-up and first present as stage times.
- **Measurements:** `launch`, `first-frame`.
- **Pass:** no shader program is compiled after the experience became interactive; stage times recorded for 200 samples
  per device and tier (docs/performance/budgets.md, proposal).
- **Gating:** yes. **Covers:** UA-F13 `launch`, `first-frame`.
- **Owner steps:** the owner has the device in hand, unlocked, trusted and charged; the automation build is installed by
  the campaign (signing is the owner's).
- **Status:** pending device campaign.

### MM-D2 — Frame pacing and frame time per tier

- **Devices:** D1, D2, D3.
- **Procedure:** run the hero and full-playthrough scenarios pinned to tiers 0, 1 and 2 in turn, then with automatic
  levels; the campaign records each frame's interval.
- **Measurements:** `frame-pacing`, `frame-time-per-tier`.
- **Pass:** 60 frames per second with automatic levels (a documented 30 frames per second mode is acceptable on the last
  level), 200 samples per device; frame time per pinned tier recorded.
- **Gating:** yes. **Covers:** T-R02G1403-012, T-R02G1408-012; UA-F13 `frame-pacing`.
- **Owner steps:** the owner has the device in hand, unlocked, trusted and charged; the automation build is installed by
  the campaign (signing is the owner's).
- **Status:** pending device campaign.

### MM-D3 — Memory, thermal state and the round-two stress session

- **Devices:** D1, D2, D3.
- **Procedure:** run the 30-minute round-two stress session of UA-F13 (levels opened, the train turned with drags and
  the panel, gears re-seated with double taps and the panel, the lamp stepped, the machine run, actions undone and
  redone, the camera orbited, levels retried and replayed in a loop) at automatic levels; the campaign samples the
  footprint and the thermal state.
- **Measurements:** `memory`, `thermal`, `stress`.
- **Pass:** memory flat within the declared resource budget over the session (the growth rule of feature 192), 200
  samples per device; thermal state and any tier change recorded.
- **Gating:** yes. **Covers:** T-R02G1408-012; UA-F13 `memory`, `thermal`, `stress`.
- **Owner steps:** the owner has the device in hand, unlocked, trusted and charged; the automation build is installed by
  the campaign (signing is the owner's). The owner keeps the device unplugged for the stress session and tells the
  campaign the starting battery level.
- **Status:** pending device campaign.

### MM-D4 — Touch feel and touch-to-frame latency

- **Devices:** D1, D2, D3.
- **Procedure:** drag around a gear to turn the train, drag the lamp up and down, tap the lamp to run, double-tap a gear
  to re-seat it, orbit the camera with two fingers and double-tap empty space on each device; the campaign records the
  interval from touch to the first frame showing the change.
- **Measurements:** `touch-to-frame`.
- **Pass:** touch-to-frame latency recorded for 200 samples per device; a drag around a gear while playing turns the
  train one tooth per 360° ÷ T swept (T the gear's teeth) the way the finger went and sends that many handle turns on
  release; a vertical drag on the lamp or its ladder steps it one rung per 24 points; a tap on the lamp while playing
  sends exactly one run; a second tap on a gear other than the driver within 0.35 s and 22 points re-seats it once; a
  double tap on empty space restores the authored camera.
- **Gating:** yes. **Covers:** T-R02G1404-011.
- **Owner steps:** the owner has the device in hand, unlocked, trusted and charged; the automation build is installed by
  the campaign (signing is the owner's). The owner turns gears by dragging around them, drags and taps the lamp,
  double-taps gears and orbits with two fingers; the campaign does not synthesise touches on hardware.
- **Status:** pending device campaign.

### MM-D5 — Sound heard and haptics felt

- **Devices:** D1, D2, D3.
- **Procedure:** turn the Sound toggle on and play a level to a win and to a failure with the haptics switch on,
  including one refused action (re-seating the driver, which the rules refuse); choose a gear to hear its audition;
  observe the clockwork's ambient sound and the selection, success, warning and error haptics.
- **Measurements:** `sound-audible`, `haptics-felt`.
- **Pass:** the sound is audible only while it is on, the panel is shown and the scene is active, and follows the silent
  switch; each planned haptic is felt (where the device has no haptic engine, the haptic part is recorded as not
  applicable).
- **Gating:** yes. **Covers:** T-R02G1406-011.
- **Owner steps:** the owner has the device in hand, unlocked, trusted and charged; the automation build is installed by
  the campaign (signing is the owner's). The owner listens and feels, and sets the silent switch and the system haptics
  setting.
- **Status:** pending device campaign.

### MM-D6 — VoiceOver walk-through (manual, non-gating)

- **Devices:** D1, D2, D3.
- **Procedure:** with VoiceOver on and the largest accessibility text size, choose a gear with the adjustable gear, turn
  the handle, step the lamp and run to hear the win; show another key frame with the adjustable key frame; replay it.
- **Measurements:** `voiceover-observation`.
- **Pass:** every control and the summary element are read with their label and value; each turn, re-seat, lamp step,
  run, undo, redo, refusal, failure and the win are announced; the panel stays readable at the largest accessibility
  text size; recorded as an observation (non-gating, P-08).
- **Gating:** no (non-gating, P-08). **Covers:** T-R02G1406-011.
- **Owner steps:** the owner has the device in hand, unlocked, trusted and charged; the automation build is installed by
  the campaign (signing is the owner's). The owner turns VoiceOver and the text size on and off in Settings and performs
  the walk-through.
- **Status:** pending device campaign.

### MM-D7 — Progress across a real termination

- **Devices:** D1, D2, D3.
- **Procedure:** win level 1, leave the app to the background, end it from the app switcher, reopen Moonlit Mechanism.
- **Measurements:** `progress-kept`.
- **Pass:** level 1 is solved with its stars, level 2 is open and the replay of level 1 is offered after the reopen; an
  unfinished level restores to the same gear phases, lamp height, actions left and records.
- **Gating:** yes. **Covers:** T-R02G1407-011.
- **Owner steps:** the owner has the device in hand, unlocked, trusted and charged; the automation build is installed by
  the campaign (signing is the owner's). The owner ends the app from the app switcher.
- **Status:** pending device campaign.

### MM-D8 — Panel journeys in the app

- **Devices:** D1, D2, D3.
- **Procedure:** run the device scenario set by id and the interface journeys of chunk w3 (`MMPlayUITests` and
  `MMReplayUITests`: win level 1 with Turn +, Lamp − and Run, replay, relaunch).
- **Measurements:** `scenarios`, `journeys`.
- **Pass:** every scenario of the device set passes; level 1 is won with its certified actions (one handle turn, one
  lamp step down, the run) with 3 of 3 stars, level 2 is open, progress survives the relaunch, the replay ends won.
- **Gating:** yes. **Covers:** T-R02G1409-011.
- **Owner steps:** the owner has the device in hand, unlocked, trusted and charged; the automation build is installed by
  the campaign (signing is the owner's).
- **Status:** pending device campaign.

## The earlier tasks these rows close

- T-R02G1403-012 (feature 433, renderer): frame time per tier on devices — MM-D2.
- T-R02G1404-011 (feature 434, spatial interaction): touch feel and touch-to-frame latency — MM-D4.
- T-R02G1406-011 (feature 436, polish and accessibility): sound heard, haptics felt (MM-D5) and the VoiceOver
  walk-through at the largest text size (MM-D6).
- T-R02G1407-011 (feature 437, persistence): progress kept across a real termination — MM-D7.
- T-R02G1408-012 (feature 438, regression): frame time and memory of the golden levels per tier — MM-D2, MM-D3.
- T-R02G1409-011 (feature 439, in the app): the panel journeys on devices — MM-D8.

Features 431, 432 and 435 have no {device} task.
