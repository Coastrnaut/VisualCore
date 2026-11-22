# Faceted Forge — device campaign plan (R02-G08-10, feature 380)

This is the written plan of feature 380 (FR-R02G0810-002 of
[spec.md](../../../specs/380-faceted-forge-device-automation-preparation/spec.md)). These rows need real devices.
They run only after `ImplementationLock-100` (CLAUDE.md rule 5), in the order D1 → D2 → D3, and D3 is not updated from
iPadOS 26.5; a campaign that finds D3 on another version is refused, not adapted. Until then every row is "pending
device campaign", and no launch, frame, memory, thermal, latency, sound, haptic or accessibility number is claimed
anywhere. Simulator results never stand in for these rows: the simulator evidence of features 378 and 379 (the
regression and the interface journeys) is a development signal, not device evidence. The campaign is UA-F13's
`scripts/run_device_campaign.py`, which reads [device-rows.json](device-rows.json); this page is its human-readable twin
and says the same things. `python3 scripts/check_device_rows.py --experience r02-g08.faceted-forge` checks the
definition: its shape, the scenario names against the manifest, the devices against the ledger, and that every deferred
{device} task is covered; `release_check.py` runs it as the step `device-rows-r02-g07`. Runs are short (minutes at
most, no soak) and a longer session is bounded by arithmetic from the short run (owner ruling of 2026-11-13), except
the 30-minute round-two stress session that UA-F13 requires, which only the device campaign runs.

## Faceted Forge as built

Faceted Forge (`r02-g08.faceted-forge`) is a puzzle of a glowing convex crystal split by cutting planes: the player
chooses a piece, one of 13 directions and an integer depth and cuts, and the level is won when the pieces' shares of
the crystal and their face counts match the target exactly within the cut budget; a piece thinner than the sliver
limit fails the level. The panel has piece, direction and depth pickers, Depth − and Depth +, Cut, Undo, Redo, Next
level and Reset view. On the touch screen a tap chooses a piece, a drag on the ruby plane's rim tilts it, a drag inside
it moves the depth, a tap on it cuts and the camera orbits with two fingers. Level 1 is won in 3 cuts, with 3 of 3
stars. A winning play can be replayed. Details: [faceted-forge.md](../../architecture/faceted-forge.md).

## Devices

| Device | Model | Ledger row |
|---|---|---|
| D1 | iPhone 15 | DEV1-R02-G08 |
| D2 | iPad Pro 13-inch (M5) | DEV2-R02-G08 |
| D3 | iPad (A16) on iPadOS 26.5 (not updated) | DEV3-R02-G08 |

Every row runs on D1, D2 and D3, in that order.

## Device scenario set

The campaign runs these 12 scenarios of Faceted Forge's manifest by id on each device: `launch-first-frame`,
`input-response`, `completion`, `rejection`, `save-restore`, `reset`, `suspend-resume`, `teardown-reentry`,
`cancel-prepare`, `full-playthrough`, `hero` and `fixture-level-1-solved` (a stored win restored on the device). The 80
acceptance rows and the other two fixtures of the manifest (`fixture-budget-out`, `fixture-undo-redo`) stay
simulator-only: they are pure rule outcomes, which the host and the simulator already prove and which a device cannot
change.

## Owner actions

The devices in hand, unlocking them, trusting the computer, the developer-mode and signing steps, charging and
unplugging, the silent switch, the system haptics setting, turning VoiceOver and the text size on and off, tapping
pieces, dragging the cut plane's rim and depth, tapping to cut and the two-finger orbit,
listening and feeling, and ending the app from the app switcher are done by the owner. Each such step is recorded by
the campaign as `BLOCKED_OWNER_ACTION` with its exact steps when it reaches it, never waited for, and the other rows
continue.

## Rows

### FF-D1 — Launch and first frame

- **Devices:** D1, D2, D3.
- **Procedure:** open Faceted Forge from the catalog with the testing argument, 200 times per device across the three
  host tiers; the campaign records preparation, shader set-up and first present as stage times.
- **Measurements:** `launch`, `first-frame`.
- **Pass:** no shader program is compiled after the experience became interactive; stage times recorded for 200
  samples per device and tier (`docs/performance/budgets.md`, proposal).
- **Gating:** yes. **Covers:** UA-F13 `launch`, `first-frame`.
- **Owner steps:** the device in hand, unlocked, trusted and charged; the campaign installs the automation build
  (signing is the owner's).
- **Status:** pending device campaign.

### FF-D2 — Frame pacing and frame time per tier

- **Devices:** D1, D2, D3.
- **Procedure:** run the `hero` and `full-playthrough` scenarios pinned to tiers 0, 1 and 2 in turn, then with automatic
  levels; the campaign records each frame's interval.
- **Measurements:** `frame-pacing`, `frame-time-per-tier`.
- **Pass:** 60 frames per second with automatic levels (a documented 30 frames per second mode is acceptable on the last
  level), 200 samples per device; frame time per pinned tier recorded.
- **Gating:** yes. **Covers:** UA-F13 `frame-pacing`, T-R02G0803-012, T-R02G0808-012.
- **Owner steps:** the device in hand, unlocked, trusted and charged; the campaign installs the automation build
  (signing is the owner's).
- **Status:** pending device campaign.

### FF-D3 — Memory, thermal state and the round-two stress session

- **Devices:** D1, D2, D3.
- **Procedure:** run the 30-minute round-two stress session of UA-F13 (levels opened, pieces cut, cuts undone and
  redone, the camera orbited, levels retried and replayed in a loop) at automatic levels; the campaign samples the
  footprint and the thermal state.
- **Measurements:** `memory`, `thermal`, `stress`.
- **Pass:** memory flat within the declared resource budget over the session (the growth rule of feature 192), 200
  samples per device; thermal state and any tier change recorded.
- **Gating:** yes. **Covers:** UA-F13 `memory`, `thermal`, `stress`, T-R02G0808-012.
- **Owner steps:** the device in hand, unlocked, trusted and charged; the campaign installs the automation build
  (signing is the owner's). The owner keeps the device unplugged for the stress session and tells the campaign the
  starting battery level.
- **Status:** pending device campaign.

### FF-D4 — Touch feel and touch-to-frame latency

- **Devices:** D1, D2, D3.
- **Procedure:** tap a piece to choose it, drag the ruby plane's rim to tilt it, drag inside it to change the depth,
  tap it to cut and orbit the camera with two fingers on each device; the campaign records the interval from touch to
  the first frame showing the change.
- **Measurements:** `touch-to-frame`.
- **Pass:** touch-to-frame latency recorded for 200 samples per device; a tap chooses exactly one piece; a rim drag
  settles on one of the 13 directions and a depth drag on a whole depth; a tap on the plane sends exactly one cut;
  Reset view restores the authored camera.
- **Gating:** yes. **Covers:** T-R02G0804-011.
- **Owner steps:** the device in hand, unlocked, trusted and charged; the campaign installs the automation build
  (signing is the owner's). The owner taps pieces, drags the plane's rim and depth, taps to cut and orbits with two
  fingers; the campaign does not synthesise touches on hardware.
- **Status:** pending device campaign.

### FF-D5 — Sound heard and haptics felt

- **Devices:** D1, D2, D3.
- **Procedure:** turn the Sound toggle on and play a level to a win and to a failure with the haptics switch on,
  including one refused action; observe the ambient loop and the selection, success, warning and error haptics.
- **Measurements:** `sound-audible`, `haptics-felt`.
- **Pass:** the loop is audible only while the sound is on, the panel is shown and the scene is active, and follows the
  silent switch; each planned haptic is felt (where the device has no haptic engine, the haptic part is recorded as not
  applicable).
- **Gating:** yes. **Covers:** T-R02G0806-011.
- **Owner steps:** the device in hand, unlocked, trusted and charged; the campaign installs the automation build
  (signing is the owner's). The owner listens and feels, and sets the silent switch and the system haptics setting.
- **Status:** pending device campaign.

### FF-D6 — VoiceOver walk-through (manual, non-gating)

- **Devices:** D1, D2, D3.
- **Procedure:** with VoiceOver on and the largest accessibility text size, choose the piece, direction and
  depth with the adjustable pickers, cut, hear the pieces described and the win; replay it.
- **Measurements:** `voiceover-observation`.
- **Pass:** every control and the summary element are read with their label and value; each cut, undo, redo,
  refusal and the win are announced; the panel stays readable at the largest accessibility text size; recorded as an
  observation.
- **Gating:** no (non-gating, P-08). **Covers:** T-R02G0806-011.
- **Owner steps:** the device in hand, unlocked, trusted and charged; the campaign installs the automation build
  (signing is the owner's). The owner turns VoiceOver and the text size on and off in Settings and performs the
  walk-through.
- **Status:** pending device campaign.

### FF-D7 — Progress across a real termination

- **Devices:** D1, D2, D3.
- **Procedure:** win level 1, leave the app to the background, end it from the app switcher, reopen Faceted Forge.
- **Measurements:** `progress-kept`.
- **Pass:** level 1 is solved with its stars, level 2 is open and the replay of level 1 is offered after the reopen; an
  unfinished level restores to the same pieces, cuts and records.
- **Gating:** yes. **Covers:** T-R02G0807-011.
- **Owner steps:** the device in hand, unlocked, trusted and charged; the campaign installs the automation build
  (signing is the owner's). The owner ends the app from the app switcher.
- **Status:** pending device campaign.

### FF-D8 — Panel journeys in the app

- **Devices:** D1, D2, D3.
- **Procedure:** run the device scenario set by id and the interface journeys of chunk `q3` (`FFPlayUITests` and
  `FFReplayUITests`: win level 1 with the piece, direction and depth pickers and Cut, replay, relaunch).
- **Measurements:** `scenarios`, `journeys`.
- **Pass:** every scenario of the device set passes; level 1 is won in 3 cuts with 3 of 3 stars, level 2 is open,
  progress survives the relaunch, the replay ends won.
- **Gating:** yes. **Covers:** T-R02G0809-011.
- **Owner steps:** the device in hand, unlocked, trusted and charged; the campaign installs the automation build
  (signing is the owner's).
- **Status:** pending device campaign.

## The earlier tasks these rows close

- T-R02G0803-012 (feature 373, renderer): frame time per tier on devices — FF-D2.
- T-R02G0804-011 (feature 374, spatial interaction): touch feel and touch-to-frame latency — FF-D4.
- T-R02G0806-011 (feature 376, polish and accessibility): sound heard, haptics felt (FF-D5) and the VoiceOver
  walk-through at the largest text size (FF-D6).
- T-R02G0807-011 (feature 377, persistence): progress kept across a real termination — FF-D7.
- T-R02G0808-012 (feature 378, regression): frame time and memory of the golden levels per tier — FF-D2, FF-D3.
- T-R02G0809-011 (feature 379, in the app): the panel journeys on devices — FF-D8.
