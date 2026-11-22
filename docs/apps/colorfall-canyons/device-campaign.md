# Colorfall Canyons — device campaign plan (R02-G05-10, feature 350)

This is the written plan of feature 350 (FR-R02G0510-002 of
[spec.md](../../../specs/350-colorfall-canyons-device-automation-preparation/spec.md)). These rows need real devices.
They run only after `ImplementationLock-100` (CLAUDE.md rule 5), in the order D1 → D2 → D3, and D3 is not updated from
iPadOS 26.5; a campaign that finds D3 on another version is refused, not adapted. Until then every row is "pending
device campaign", and no launch, frame, memory, thermal, latency, sound, haptic or accessibility number is claimed
anywhere. Simulator results never stand in for these rows: the simulator evidence of features 348 and 349 (the
regression and the interface journeys) is a development signal, not device evidence. The campaign is UA-F13's
`scripts/run_device_campaign.py`, which reads [device-rows.json](device-rows.json); this page is its human-readable twin
and says the same things. `python3 scripts/check_device_rows.py --experience r02-g05.colorfall-canyons` checks the
definition: its shape, the scenario names against the manifest, the devices against the ledger, and that every deferred
{device} task is covered; `release_check.py` runs it as the step `device-rows-r02-g05`. Runs are short (minutes at
most, no soak) and a longer session is bounded by arithmetic from the short run (owner ruling of 2026-11-13), except
the 30-minute round-two stress session that UA-F13 requires, which only the device campaign runs.

## Colorfall Canyons as built

Colorfall Canyons (`r02-g05.colorfall-canyons`, free, a candidate until X-R02-G05) is a puzzle of springs of coloured
light-fluid (cyan, coral, yellow) on a small canyon terrain: the player carves canyon cells one height step lower and
switches the springs' valves, then lets time run, and the fluid runs downhill cell by cell into basins. The level is won
when every target basin holds its required fill and colour mix without contamination or overflow within the tick limit;
carves and valve switches spend the level's action budget, while steps of time cost nothing. The kernel decides every
tick, carve, valve switch and the verdict by exact integer arithmetic with exact conservation of each colour, never by
the renderer. The catalog holds 100 certified levels in five bands of 20, each with a witness file. The scene draws the
terrain blocks, rock slabs, drain pits, pearl-rimmed basins with their target arcs, the spring emitters and an emissive
fluid sheet per cell (each colour also carries a pattern) with GLSL ES 3.00 shaders on the OpenGL ES → ANGLE → Metal
path in three tiers, `level-0`, `level-1` and `level-2` (richest first, positions never move between tiers); a program
that does not compile falls back to the level-2 geometry drawn unlit. A one-finger drag that starts on a carvable cell
rings that cell and sends exactly one carve on release, a tap on a spring sends one valve switch, the camera orbits with
two fingers, and the panel's cell picker and Carve, a valve button per spring, Step 1, Step 10, Run, Undo and Redo send
the same actions. Level 1 is won in 2 actions (Carve twice, then Run) with 3 stars. A winning play can be replayed
action by action. Progress is kept in saved-state snapshot schema 3 (level, mode, progress with the verified winning
trace per level, records, tutorial step, sound choice). An ambient Sound toggle is off by default; announcements and
haptics go through the shared feedback route, and every colour is spoken by name and amount; Reduce Motion holds the
flow bands still and Reduce Flashing slows the fades and caps the glow. Details:
[colorfall-canyons.md](../../architecture/colorfall-canyons.md).

## Devices

| Device | Model | Ledger row |
|---|---|---|
| D1 | iPhone 15 | DEV1-R02-G05 |
| D2 | iPad Pro 13-inch (M5) | DEV2-R02-G05 |
| D3 | iPad (A16) on iPadOS 26.5 (not updated) | DEV3-R02-G05 |

Every row runs on D1, D2 and D3, in that order.

## Device scenario set

The campaign runs these 12 scenarios of Colorfall Canyons's manifest by id on each device: `launch-first-frame`,
`input-response`, `completion`, `rejection`, `save-restore`, `reset`, `suspend-resume`, `teardown-reentry`,
`cancel-prepare`, `full-playthrough`, `hero` and `fixture-level-1-solved` (a stored win restored on the device). The 80
acceptance rows (R2-G05-QA-001 … 080) and the other two fixtures of the manifest (`fixture-time-out`,
`fixture-undo-redo`) stay simulator-only: they are pure rule outcomes, which the host and the simulator already prove
and which a device cannot change.

## Owner actions

The devices in hand, unlocking them, trusting the computer, the developer-mode and signing steps, charging and
unplugging, the silent switch, the system haptics setting, turning VoiceOver and the text size on and off, dragging to
carve, tapping the springs and the two-finger orbit, listening and feeling, and ending the app from the app switcher are
done by the owner. Each such step is recorded by the campaign as `BLOCKED_OWNER_ACTION` with its exact steps when it
reaches it, never waited for, and the other rows continue.

## Rows

### CC-D1 — Launch and first frame

- **Devices:** D1, D2, D3.
- **Procedure:** open Colorfall Canyons from the catalog with the testing argument, 200 times per device across the
  three host tiers; the campaign records preparation, shader set-up and first present as stage times.
- **Measurements:** `launch`, `first-frame`.
- **Pass:** no shader program is compiled after the experience became interactive; stage times recorded for 200
  samples per device and tier (`docs/performance/budgets.md`, proposal).
- **Gating:** yes. **Covers:** UA-F13 `launch`, `first-frame`.
- **Owner steps:** the device in hand, unlocked, trusted and charged; the campaign installs the automation build
  (signing is the owner's).
- **Status:** pending device campaign.

### CC-D2 — Frame pacing and frame time per tier

- **Devices:** D1, D2, D3.
- **Procedure:** run the `hero` and `full-playthrough` scenarios pinned to tiers 0, 1 and 2 in turn, then with automatic
  levels; the campaign records each frame's interval.
- **Measurements:** `frame-pacing`, `frame-time-per-tier`.
- **Pass:** 60 frames per second with automatic levels (a documented 30 frames per second mode is acceptable on the last
  level), 200 samples per device; frame time per pinned tier recorded.
- **Gating:** yes. **Covers:** UA-F13 `frame-pacing`, T-R02G0503-012, T-R02G0508-012.
- **Owner steps:** the device in hand, unlocked, trusted and charged; the campaign installs the automation build
  (signing is the owner's).
- **Status:** pending device campaign.

### CC-D3 — Memory, thermal state and the round-two stress session

- **Devices:** D1, D2, D3.
- **Procedure:** run the 30-minute round-two stress session of UA-F13 (levels opened, cells carved, valves switched, the
  fluid run, undone and replayed in a loop) at automatic levels; the campaign samples the footprint and the thermal
  state.
- **Measurements:** `memory`, `thermal`, `stress`.
- **Pass:** memory flat within the declared resource budget over the session (the growth rule of feature 192), 200
  samples per device; thermal state and any tier change recorded.
- **Gating:** yes. **Covers:** UA-F13 `memory`, `thermal`, `stress`, T-R02G0508-012.
- **Owner steps:** the device in hand, unlocked, trusted and charged; the campaign installs the automation build
  (signing is the owner's). The owner keeps the device unplugged for the stress session and tells the campaign the
  starting battery level.
- **Status:** pending device campaign.

### CC-D4 — Touch feel and touch-to-frame latency

- **Devices:** D1, D2, D3.
- **Procedure:** drag along the canyon to carve a sluice, tap a spring to switch its valve and orbit the camera with two
  fingers on each device; the campaign records the interval from touch to the first frame showing the change.
- **Measurements:** `touch-to-frame`.
- **Pass:** touch-to-frame latency recorded for 200 samples per device; a drag highlights the cell under the finger and
  exactly one carve is sent on release; a spring tap sends exactly one valve switch.
- **Gating:** yes. **Covers:** T-R02G0504-011.
- **Owner steps:** the device in hand, unlocked, trusted and charged; the campaign installs the automation build
  (signing is the owner's). The owner drags to carve, taps the springs and orbits with two fingers; the campaign does
  not synthesise touches on hardware.
- **Status:** pending device campaign.

### CC-D5 — Sound heard and haptics felt

- **Devices:** D1, D2, D3.
- **Procedure:** turn the Sound toggle on and play a level to a win and to a failure with the haptics switch on,
  including one refused action; observe the ambient loop and the selection, success, warning and error haptics.
- **Measurements:** `sound-audible`, `haptics-felt`.
- **Pass:** the loop is audible only while the sound is on, the panel is shown and the scene is active, and follows the
  silent switch; each planned haptic is felt (where the device has no haptic engine, the haptic part is recorded as not
  applicable).
- **Gating:** yes. **Covers:** T-R02G0506-012.
- **Owner steps:** the device in hand, unlocked, trusted and charged; the campaign installs the automation build
  (signing is the owner's). The owner listens and feels, and sets the silent switch and the system haptics setting.
- **Status:** pending device campaign.

### CC-D6 — VoiceOver walk-through (manual, non-gating)

- **Devices:** D1, D2, D3.
- **Procedure:** with VoiceOver on and the largest accessibility text size, pick a cell with the adjustable cell picker,
  carve it, switch the valves, run the fluid and hear the win; replay it.
- **Measurements:** `voiceover-observation`.
- **Pass:** every control and the summary element are read with their label and value; each pick, carve, valve switch,
  refusal and the win are announced; the panel stays readable at the largest accessibility text size; recorded as an
  observation.
- **Gating:** no (non-gating, P-08). **Covers:** T-R02G0506-012.
- **Owner steps:** the device in hand, unlocked, trusted and charged; the campaign installs the automation build
  (signing is the owner's). The owner turns VoiceOver and the text size on and off in Settings and performs the
  walk-through.
- **Status:** pending device campaign.

### CC-D7 — Progress across a real termination

- **Devices:** D1, D2, D3.
- **Procedure:** win level 1, leave the app to the background, end it from the app switcher, reopen Colorfall Canyons.
- **Measurements:** `progress-kept`.
- **Pass:** level 1 is solved with its stars, level 2 is open and the replay of level 1 is offered after the reopen; an
  unfinished level restores to the same carved cells, valves, fluid and actions.
- **Gating:** yes. **Covers:** T-R02G0507-011.
- **Owner steps:** the device in hand, unlocked, trusted and charged; the campaign installs the automation build
  (signing is the owner's). The owner ends the app from the app switcher.
- **Status:** pending device campaign.

### CC-D8 — Panel journeys in the app

- **Devices:** D1, D2, D3.
- **Procedure:** run the device scenario set by id and the interface journeys of chunk `n3` (`CCPlayUITests` and
  `CCReplayUITests`: win level 1 with the cell picker, Carve, the valve buttons and Run, replay, relaunch).
- **Measurements:** `scenarios`, `journeys`.
- **Pass:** every scenario of the device set passes; level 1 is won with 3 of 3 stars in 2 actions, level 2 is open,
  progress survives the relaunch, the replay ends won.
- **Gating:** yes. **Covers:** T-R02G0509-011.
- **Owner steps:** the device in hand, unlocked, trusted and charged; the campaign installs the automation build
  (signing is the owner's).
- **Status:** pending device campaign.

## The earlier tasks these rows close

- T-R02G0503-012 (feature 343, renderer): frame time per tier on devices — CC-D2.
- T-R02G0504-011 (feature 344, spatial interaction): touch feel and touch-to-frame latency — CC-D4.
- T-R02G0506-012 (feature 346, polish and accessibility): sound heard, haptics felt (CC-D5) and the VoiceOver
  walk-through at the largest text size (CC-D6).
- T-R02G0507-011 (feature 347, persistence): progress kept across a real termination — CC-D7.
- T-R02G0508-012 (feature 348, regression): frame time and memory of the golden levels per tier — CC-D2, CC-D3.
- T-R02G0509-011 (feature 349, in the app): the panel journeys on devices — CC-D8.
