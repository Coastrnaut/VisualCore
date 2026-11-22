# Amethyst Escape — device campaign plan (R02-G07-10, feature 370)

This is the written plan of feature 370 (FR-R02G0710-002 of
[spec.md](../../../specs/370-amethyst-escape-device-automation-preparation/spec.md)). These rows need real devices.
They run only after `ImplementationLock-100` (CLAUDE.md rule 5), in the order D1 → D2 → D3, and D3 is not updated from
iPadOS 26.5; a campaign that finds D3 on another version is refused, not adapted. Until then every row is "pending
device campaign", and no launch, frame, memory, thermal, latency, sound, haptic or accessibility number is claimed
anywhere. Simulator results never stand in for these rows: the simulator evidence of features 368 and 369 (the
regression and the interface journeys) is a development signal, not device evidence. The campaign is UA-F13's
`scripts/run_device_campaign.py`, which reads [device-rows.json](device-rows.json); this page is its human-readable twin
and says the same things. `python3 scripts/check_device_rows.py --experience r02-g07.amethyst-escape` checks the
definition: its shape, the scenario names against the manifest, the devices against the ledger, and that every deferred
{device} task is covered; `release_check.py` runs it as the step `device-rows-r02-g07`. Runs are short (minutes at
most, no soak) and a longer session is bounded by arithmetic from the short run (owner ruling of 2026-11-13), except
the 30-minute round-two stress session that UA-F13 requires, which only the device campaign runs.

## Amethyst Escape as built

Amethyst Escape (`r02-g07.amethyst-escape`) is a puzzle of nested crystal shells: a pearl rests in the innermost shell,
the player turns shells one sector at a time and advances the pearl, which rolls outward through an aperture lined up
under it or else one pocket clockwise along its ring, and the level is won when the pearl leaves the outermost shell
through its exit gap within the move budget. The panel has a shell picker, Turn − and Turn +, Advance, Undo and Redo,
Show all layers and Reset view. On the touch screen a shell turns by a drag on its bezel, a tap on the pearl advances
it, a double tap isolates a shell and the camera orbits with two fingers. Level 1 is won with Turn − on the innermost
shell and Advance twice, in 3 moves, with 3 of 3 stars. A winning play can be replayed. Details:
[amethyst-escape.md](../../architecture/amethyst-escape.md).

## Devices

| Device | Model | Ledger row |
|---|---|---|
| D1 | iPhone 15 | DEV1-R02-G07 |
| D2 | iPad Pro 13-inch (M5) | DEV2-R02-G07 |
| D3 | iPad (A16) on iPadOS 26.5 (not updated) | DEV3-R02-G07 |

Every row runs on D1, D2 and D3, in that order.

## Device scenario set

The campaign runs these 12 scenarios of Amethyst Escape's manifest by id on each device: `launch-first-frame`,
`input-response`, `completion`, `rejection`, `save-restore`, `reset`, `suspend-resume`, `teardown-reentry`,
`cancel-prepare`, `full-playthrough`, `hero` and `fixture-level-1-solved` (a stored win restored on the device). The 80
acceptance rows and the other two fixtures of the manifest (`fixture-budget-out`, `fixture-undo-redo`) stay
simulator-only: they are pure rule outcomes, which the host and the simulator already prove and which a device cannot
change.

## Owner actions

The devices in hand, unlocking them, trusting the computer, the developer-mode and signing steps, charging and
unplugging, the silent switch, the system haptics setting, turning VoiceOver and the text size on and off, dragging
shells by their bezels, tapping to advance the pearl, double-tapping a shell to isolate it and the two-finger orbit,
listening and feeling, and ending the app from the app switcher are done by the owner. Each such step is recorded by
the campaign as `BLOCKED_OWNER_ACTION` with its exact steps when it reaches it, never waited for, and the other rows
continue.

## Rows

### AE-D1 — Launch and first frame

- **Devices:** D1, D2, D3.
- **Procedure:** open Amethyst Escape from the catalog with the testing argument, 200 times per device across the three
  host tiers; the campaign records preparation, shader set-up and first present as stage times.
- **Measurements:** `launch`, `first-frame`.
- **Pass:** no shader program is compiled after the experience became interactive; stage times recorded for 200
  samples per device and tier (`docs/performance/budgets.md`, proposal).
- **Gating:** yes. **Covers:** UA-F13 `launch`, `first-frame`.
- **Owner steps:** the device in hand, unlocked, trusted and charged; the campaign installs the automation build
  (signing is the owner's).
- **Status:** pending device campaign.

### AE-D2 — Frame pacing and frame time per tier

- **Devices:** D1, D2, D3.
- **Procedure:** run the `hero` and `full-playthrough` scenarios pinned to tiers 0, 1 and 2 in turn, then with automatic
  levels; the campaign records each frame's interval.
- **Measurements:** `frame-pacing`, `frame-time-per-tier`.
- **Pass:** 60 frames per second with automatic levels (a documented 30 frames per second mode is acceptable on the last
  level), 200 samples per device; frame time per pinned tier recorded.
- **Gating:** yes. **Covers:** UA-F13 `frame-pacing`, T-R02G0703-012, T-R02G0708-012.
- **Owner steps:** the device in hand, unlocked, trusted and charged; the campaign installs the automation build
  (signing is the owner's).
- **Status:** pending device campaign.

### AE-D3 — Memory, thermal state and the round-two stress session

- **Devices:** D1, D2, D3.
- **Procedure:** run the 30-minute round-two stress session of UA-F13 (levels opened, shells turned, the pearl advanced,
  layers isolated, moves undone, levels retried and replayed in a loop) at automatic levels; the campaign samples the
  footprint and the thermal state.
- **Measurements:** `memory`, `thermal`, `stress`.
- **Pass:** memory flat within the declared resource budget over the session (the growth rule of feature 192), 200
  samples per device; thermal state and any tier change recorded.
- **Gating:** yes. **Covers:** UA-F13 `memory`, `thermal`, `stress`, T-R02G0708-012.
- **Owner steps:** the device in hand, unlocked, trusted and charged; the campaign installs the automation build
  (signing is the owner's). The owner keeps the device unplugged for the stress session and tells the campaign the
  starting battery level.
- **Status:** pending device campaign.

### AE-D4 — Touch feel and touch-to-frame latency

- **Devices:** D1, D2, D3.
- **Procedure:** drag a shell by its bezel to a new angle, tap to advance the pearl, double-tap a shell to isolate it
  and orbit the camera with two fingers on each device; the campaign records the interval from touch to the first frame
  showing the change.
- **Measurements:** `touch-to-frame`.
- **Pass:** touch-to-frame latency recorded for 200 samples per device; a bezel drag turns the shell by whole sectors
  and exactly one turn per sector is sent on release; a tap sends exactly one advance; a double tap isolates one shell
  and Show all layers restores them.
- **Gating:** yes. **Covers:** T-R02G0704-012.
- **Owner steps:** the device in hand, unlocked, trusted and charged; the campaign installs the automation build
  (signing is the owner's). The owner drags shells by their bezels, taps to advance the pearl, double-taps a shell to
  isolate it and orbits with two fingers; the campaign does not synthesise touches on hardware.
- **Status:** pending device campaign.

### AE-D5 — Sound heard and haptics felt

- **Devices:** D1, D2, D3.
- **Procedure:** turn the Sound toggle on and play a level to a win and to a failure with the haptics switch on,
  including one refused action; observe the ambient loop and the selection, success, warning and error haptics.
- **Measurements:** `sound-audible`, `haptics-felt`.
- **Pass:** the loop is audible only while the sound is on, the panel is shown and the scene is active, and follows the
  silent switch; each planned haptic is felt (where the device has no haptic engine, the haptic part is recorded as not
  applicable).
- **Gating:** yes. **Covers:** T-R02G0706-011.
- **Owner steps:** the device in hand, unlocked, trusted and charged; the campaign installs the automation build
  (signing is the owner's). The owner listens and feels, and sets the silent switch and the system haptics setting.
- **Status:** pending device campaign.

### AE-D6 — VoiceOver walk-through (manual, non-gating)

- **Devices:** D1, D2, D3.
- **Procedure:** with VoiceOver on and the largest accessibility text size, pick a shell with the adjustable shell
  picker, turn it, advance the pearl and hear the escape; replay it.
- **Measurements:** `voiceover-observation`.
- **Pass:** every control and the summary element are read with their label and value; each shell pick, turn, advance,
  refusal and the escape are announced; the panel stays readable at the largest accessibility text size; recorded as an
  observation.
- **Gating:** no (non-gating, P-08). **Covers:** T-R02G0706-011.
- **Owner steps:** the device in hand, unlocked, trusted and charged; the campaign installs the automation build
  (signing is the owner's). The owner turns VoiceOver and the text size on and off in Settings and performs the
  walk-through.
- **Status:** pending device campaign.

### AE-D7 — Progress across a real termination

- **Devices:** D1, D2, D3.
- **Procedure:** win level 1, leave the app to the background, end it from the app switcher, reopen Amethyst Escape.
- **Measurements:** `progress-kept`.
- **Pass:** level 1 is solved with its stars, level 2 is open and the replay of level 1 is offered after the reopen; an
  unfinished level restores to the same shell angles, pearl pocket, moves and actions.
- **Gating:** yes. **Covers:** T-R02G0707-011.
- **Owner steps:** the device in hand, unlocked, trusted and charged; the campaign installs the automation build
  (signing is the owner's). The owner ends the app from the app switcher.
- **Status:** pending device campaign.

### AE-D8 — Panel journeys in the app

- **Devices:** D1, D2, D3.
- **Procedure:** run the device scenario set by id and the interface journeys of chunk `p3` (`AEPlayUITests` and
  `AEReplayUITests`: win level 1 with the shell picker, Turn − and Advance, replay, relaunch).
- **Measurements:** `scenarios`, `journeys`.
- **Pass:** every scenario of the device set passes; level 1 is escaped in 3 moves with 3 of 3 stars, level 2 is open,
  progress survives the relaunch, the replay ends won.
- **Gating:** yes. **Covers:** T-R02G0709-011.
- **Owner steps:** the device in hand, unlocked, trusted and charged; the campaign installs the automation build
  (signing is the owner's).
- **Status:** pending device campaign.

## The earlier tasks these rows close

- T-R02G0703-012 (feature 363, renderer): frame time per tier on devices — AE-D2.
- T-R02G0704-012 (feature 364, spatial interaction): touch feel and touch-to-frame latency — AE-D4.
- T-R02G0706-011 (feature 366, polish and accessibility): sound heard, haptics felt (AE-D5) and the VoiceOver
  walk-through at the largest text size (AE-D6).
- T-R02G0707-011 (feature 367, persistence): progress kept across a real termination — AE-D7.
- T-R02G0708-012 (feature 368, regression): frame time and memory of the golden levels per tier — AE-D2, AE-D3.
- T-R02G0709-011 (feature 369, in the app): the panel journeys on devices — AE-D8.
