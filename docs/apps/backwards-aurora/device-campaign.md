# Backwards Aurora — device campaign plan (R02-G10-10, feature 400)

This is the written plan of feature 400 (FR-R02G1010-002 of
[spec.md](../../../specs/400-backwards-aurora-device-automation-preparation/spec.md)). These rows need real devices.
They run only after `ImplementationLock-100` (CLAUDE.md rule 5), in the order D1 → D2 → D3, and D3 is not updated from
iPadOS 26.5; a campaign that finds D3 on another version is refused, not adapted. Until then every row is "pending
device campaign", and no launch, frame, memory, thermal, latency, sound, haptic or accessibility number is claimed
anywhere. Simulator results never stand in for these rows: the simulator evidence of features 398 and 399 (the
regression and the interface journeys) is a development signal, not device evidence. The campaign is UA-F13's
`scripts/run_device_campaign.py`, which reads [device-rows.json](device-rows.json); this page is its human-readable twin
and says the same things. `python3 scripts/check_device_rows.py --experience r02-g10.backwards-aurora` checks the
definition: its shape, the scenario names against the manifest, the devices against the ledger, and that every deferred
{device} task is covered; `release_check.py` runs it as the step `device-rows-r02-g10`. Runs are short (minutes at
most, no soak) and a longer session is bounded by arithmetic from the short run (owner ruling of 2026-11-13), except
the 30-minute round-two stress session that UA-F13 requires, which only the device campaign runs.

## Backwards Aurora as built

Backwards Aurora (`r02-g10.backwards-aurora`) is a puzzle of an aurora drawn as a wave along an upright timeline, some
sections of which run backwards: the player chooses a section by its two ends and reverses it in time, and the level is
won when every checkpoint shows its true height and every bend is within the limit, without tearing a seam past the
breaking limit, within the reversal budget. The panel has the start and end steppers (naming the sample and its
height), Reverse, Undo, Redo, Next level, Reset view, Hint, the tutorial's Dismiss, the failure's Undo and Retry,
Campaign, Daily and Practice, a level stepper, Replay with Step and Stop, and the Sound toggle. On the touch screen a
tap on a sample moves the nearer end of the section, an end can be dragged (never past the other), a sideways swipe
along the band reverses the section on release, a press held 0.5 s on the band shows the timeline freeze preview of
the kernel's own reversal (lifting it sends nothing) and the camera orbits with two fingers. Level 1 is won in 2
reversals, with 3 of 3 stars. A winning play can be replayed. Details:
[backwards-aurora.md](../../architecture/backwards-aurora.md).

## Devices

| Device | Model | Ledger row |
|---|---|---|
| D1 | iPhone 15 | DEV1-R02-G10 |
| D2 | iPad Pro 13-inch (M5) | DEV2-R02-G10 |
| D3 | iPad (A16) on iPadOS 26.5 (not updated) | DEV3-R02-G10 |

Every row runs on D1, D2 and D3, in that order.

## Device scenario set

The campaign runs these 12 scenarios of Backwards Aurora's manifest by id on each device: `launch-first-frame`,
`input-response`, `completion`, `rejection`, `save-restore`, `reset`, `suspend-resume`, `teardown-reentry`,
`cancel-prepare`, `full-playthrough`, `hero` and `fixture-level-1-solved` (a stored win restored on the device). The 80
acceptance rows and the other two fixtures of the manifest (`fixture-budget-out`, `fixture-undo-redo`) stay
simulator-only: they are pure rule outcomes, which the host and the simulator already prove and which a device cannot
change.

## Owner actions

The devices in hand, unlocking them, trusting the computer, the developer-mode and signing steps, charging and
unplugging, the silent switch, the system haptics setting, turning VoiceOver and the text size on and off, tapping
samples, dragging the section's ends, swiping and holding the band and the two-finger orbit, listening and feeling, and
ending the app from the app switcher are done by the owner. Each such step is recorded by the campaign as
`BLOCKED_OWNER_ACTION` with its exact steps when it reaches it, never waited for, and the other rows continue.

## Rows

### BA-D1 — Launch and first frame

- **Devices:** D1, D2, D3.
- **Procedure:** open Backwards Aurora from the catalog with the testing argument, 200 times per device across the
  three host tiers; the campaign records preparation, shader set-up and first present as stage times.
- **Measurements:** `launch`, `first-frame`.
- **Pass:** no shader program is compiled after the experience became interactive; stage times recorded for 200
  samples per device and tier (`docs/performance/budgets.md`, proposal).
- **Gating:** yes. **Covers:** UA-F13 `launch`, `first-frame`.
- **Owner steps:** the device in hand, unlocked, trusted and charged; the campaign installs the automation build
  (signing is the owner's).
- **Status:** pending device campaign.

### BA-D2 — Frame pacing and frame time per tier

- **Devices:** D1, D2, D3.
- **Procedure:** run the `hero` and `full-playthrough` scenarios pinned to tiers 0, 1 and 2 in turn, then with automatic
  levels; the campaign records each frame's interval.
- **Measurements:** `frame-pacing`, `frame-time-per-tier`.
- **Pass:** 60 frames per second with automatic levels (a documented 30 frames per second mode is acceptable on the last
  level), 200 samples per device; frame time per pinned tier recorded.
- **Gating:** yes. **Covers:** UA-F13 `frame-pacing`, T-R02G1003-012, T-R02G1008-012.
- **Owner steps:** the device in hand, unlocked, trusted and charged; the campaign installs the automation build
  (signing is the owner's).
- **Status:** pending device campaign.

### BA-D3 — Memory, thermal state and the round-two stress session

- **Devices:** D1, D2, D3.
- **Procedure:** run the 30-minute round-two stress session of UA-F13 (levels opened, sections chosen and reversed,
  held freeze previews, reversals undone and redone, the camera orbited, levels retried and replayed in a loop) at
  automatic levels; the campaign samples the footprint and the thermal state.
- **Measurements:** `memory`, `thermal`, `stress`.
- **Pass:** memory flat within the declared resource budget over the session (the growth rule of feature 192), 200
  samples per device; thermal state and any tier change recorded.
- **Gating:** yes. **Covers:** UA-F13 `memory`, `thermal`, `stress`, T-R02G1008-012.
- **Owner steps:** the device in hand, unlocked, trusted and charged; the campaign installs the automation build
  (signing is the owner's). The owner keeps the device unplugged for the stress session and tells the campaign the
  starting battery level.
- **Status:** pending device campaign.

### BA-D4 — Touch feel and touch-to-frame latency

- **Devices:** D1, D2, D3.
- **Procedure:** tap samples to move the section's ends and drag an end, swipe sideways along the band to reverse the
  section, hold the band for the timeline freeze preview and orbit the camera with two fingers on each device; the
  campaign records the interval from touch to the first frame showing the change.
- **Measurements:** `touch-to-frame`.
- **Pass:** touch-to-frame latency recorded for 200 samples per device; a tap moves exactly one end of the section and a
  drag never moves an end past the other; a sideways swipe sends exactly one reversal on release; a press held 0.5 s
  shows the kernel's own reversal as the preview and lifting it sends nothing; Reset view restores the authored camera.
- **Gating:** yes. **Covers:** T-R02G1004-012.
- **Owner steps:** the device in hand, unlocked, trusted and charged; the campaign installs the automation build
  (signing is the owner's). The owner taps samples, drags the section's ends, swipes and holds the band and orbits with
  two fingers; the campaign does not synthesise touches on hardware.
- **Status:** pending device campaign.

### BA-D5 — Sound heard and haptics felt

- **Devices:** D1, D2, D3.
- **Procedure:** turn the Sound toggle on and play a level to a win and to a failure with the haptics switch on,
  including one refused reversal; observe the aurora sound and the selection, success, warning and error haptics.
- **Measurements:** `sound-audible`, `haptics-felt`.
- **Pass:** the sound is audible only while it is on, the panel is shown and the scene is active, and follows the
  silent switch; each planned haptic is felt (where the device has no haptic engine, the haptic part is recorded as not
  applicable).
- **Gating:** yes. **Covers:** T-R02G1006-011.
- **Owner steps:** the device in hand, unlocked, trusted and charged; the campaign installs the automation build
  (signing is the owner's). The owner listens and feels, and sets the silent switch and the system haptics setting.
- **Status:** pending device campaign.

### BA-D6 — VoiceOver walk-through (manual, non-gating)

- **Devices:** D1, D2, D3.
- **Procedure:** with VoiceOver on and the largest accessibility text size, set the section's start and end with the
  adjustable steppers, reverse, hear each reversal described with the checkpoints matched and the worst bend, and the
  win; replay it.
- **Measurements:** `voiceover-observation`.
- **Pass:** every control and the summary element are read with their label and value; each reversal, undo, redo,
  refusal and the win are announced; the panel stays readable at the largest accessibility text size; recorded as an
  observation.
- **Gating:** no (non-gating, P-08). **Covers:** T-R02G1006-011.
- **Owner steps:** the device in hand, unlocked, trusted and charged; the campaign installs the automation build
  (signing is the owner's). The owner turns VoiceOver and the text size on and off in Settings and performs the
  walk-through.
- **Status:** pending device campaign.

### BA-D7 — Progress across a real termination

- **Devices:** D1, D2, D3.
- **Procedure:** win level 1, leave the app to the background, end it from the app switcher, reopen Backwards Aurora.
- **Measurements:** `progress-kept`.
- **Pass:** level 1 is solved with its stars, level 2 is open and the replay of level 1 is offered after the reopen; an
  unfinished level restores to the same wave, reversals spent and records.
- **Gating:** yes. **Covers:** T-R02G1007-011.
- **Owner steps:** the device in hand, unlocked, trusted and charged; the campaign installs the automation build
  (signing is the owner's). The owner ends the app from the app switcher.
- **Status:** pending device campaign.

### BA-D8 — Panel journeys in the app

- **Devices:** D1, D2, D3.
- **Procedure:** run the device scenario set by id and the interface journeys of chunk `s3` (`BAPlayUITests` and
  `BAReplayUITests`: win level 1 with the start and end steppers and Reverse, replay, relaunch).
- **Measurements:** `scenarios`, `journeys`.
- **Pass:** every scenario of the device set passes; level 1 is won in 2 reversals with 3 of 3 stars, level 2 is open,
  progress survives the relaunch, the replay ends won.
- **Gating:** yes. **Covers:** T-R02G1009-011.
- **Owner steps:** the device in hand, unlocked, trusted and charged; the campaign installs the automation build
  (signing is the owner's).
- **Status:** pending device campaign.

## The earlier tasks these rows close

- T-R02G1003-012 (feature 393, renderer): frame time per tier on devices — BA-D2.
- T-R02G1004-012 (feature 394, spatial interaction): touch feel and touch-to-frame latency — BA-D4.
- T-R02G1006-011 (feature 396, polish and accessibility): sound heard, haptics felt (BA-D5) and the VoiceOver
  walk-through at the largest text size (BA-D6).
- T-R02G1007-011 (feature 397, persistence): progress kept across a real termination — BA-D7.
- T-R02G1008-012 (feature 398, regression): frame time and memory of the golden levels per tier — BA-D2, BA-D3.
- T-R02G1009-011 (feature 399, in the app): the panel journeys on devices — BA-D8.
