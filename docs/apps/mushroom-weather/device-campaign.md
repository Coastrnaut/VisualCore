# Mushroom Weather — device campaign plan (R02-G20-10, feature 500)

This is the written plan of feature 500 (FR-R02G2010-002 of
[spec.md](../../../specs/500-mushroom-weather-device-automation-preparation/spec.md)). These rows need real devices.
They run only after `ImplementationLock-100` (CLAUDE.md rule 5), in the order D1 → D2 → D3, and D3 is not updated from
iPadOS 26.5; a campaign that finds D3 on another version is refused, not adapted. Until then every row is "pending
device campaign", and no launch, frame, memory, thermal, latency, sound, haptic or accessibility number is claimed
anywhere. Simulator results never stand in for these rows: the simulator evidence of features 498 and 499 (the
regression and the interface journeys) is a development signal, not device evidence. The campaign is UA-F13's
`scripts/run_device_campaign.py`, which reads [device-rows.json](device-rows.json); this page is its human-readable
twin and says the same things. `python3 scripts/check_device_rows.py --experience r02-g20.mushroom-weather` checks the
definition: its shape, the scenario names against the manifest, the devices against the ledger, and that every deferred
{device} task is covered; `release_check.py` runs it as the step `device-rows-r02-g20`. Runs are short (minutes at
most, no soak) and a longer session is bounded by arithmetic from the short run (owner ruling of 2026-11-13), except
the 30-minute round-two stress session that UA-F13 requires, which only the device campaign runs.

## Mushroom Weather as built

Mushroom Weather (`r02-g20.mushroom-weather`, a free candidate until X-R02-G20) is a puzzle of a midnight miniature
forest floor: the player places spore pods on the level's marked sites, opens or closes canopy vents and shifts the
moonlight, then lets the weather run, so that every mushroom colony holds its preferred humidity band for the last
required cycles, without a sensitive colony drying out or any cell turning to mold. Every placement, move or removal of
a pod, every vent change and every moonlight change spends one action; the run spends nothing and ends the level won or
failed. A run fails when a sensitive colony falls below its survival floor (dried), when a cell rises above the mold
bound (mold) or when a colony does not stay in its band to the end (unstable); a placement off a site, on a colony or
another pod, an unchanged action, the removal of an empty slot and any action with no action left are refused. The
panel has the pod slot and site steppers (− and +) that choose the pod and its site, Place, Remove, a toggle per vent
(Vent 1 … 6), the moonlight steppers with Set moonlight, Reset view, the cycle stepper (Cycle − and Cycle +, showing a
cycle of the run), Run, Undo, Redo, Next level, the tutorial's Dismiss tutorial, Hint, the failure explanation,
Campaign, Daily, Practice, the level picker with Play level, Replay with Step and Stop, the Sound toggle and a summary
element. On the touch screen a tap on an empty site (while playing) places a pod in the first free slot, or says that
every slot is used; a tap on a vent sends its other state; a drag of a pod (from 16 points of travel, while playing)
previews the weather from the kernel's own run with the pod on the site nearest the finger within 24 points, or removed
when the finger leaves the floor, and moves or removes it on release; a vertical drag on the moon previews the
moonlight one level per 40 points (0 … 3) and sets it on release; a drag along the scrubber shows the cycle nearest the
finger; a finished play explains in words why nothing happens; two fingers orbit the camera and a double tap off the
floor restores the authored view. Level 1 is won by its certified plan, one pod in slot 1 on the site at row 2, column
5, then vent 1 closed, then Run, with 3 of 3 stars. A winning play can be replayed. Details:
[mushroom-weather.md](../../architecture/mushroom-weather.md) (features 491 … 499).

## Devices

| Device | Model | Ledger row |
|---|---|---|
| D1 | iPhone 15 | DEV1-R02-G20 |
| D2 | iPad Pro 13-inch (M5) | DEV2-R02-G20 |
| D3 | iPad (A16) on iPadOS 26.5 (not updated) | DEV3-R02-G20 |

Every row runs on D1, D2 and D3, in that order.

## Device scenario set

The campaign runs these 12 scenarios of Mushroom Weather's manifest by id on each device: `launch-first-frame`,
`input-response`, `completion`, `rejection`, `save-restore`, `reset`, `suspend-resume`, `teardown-reentry`,
`cancel-prepare`, `full-playthrough`, `hero` and `fixture-level-1-solved` (a stored win restored on the device). The 80
acceptance rows and the other two fixtures of the manifest (`fixture-run-fails`, `fixture-undo-redo`) stay
simulator-only: they are pure rule outcomes, which the host and the simulator already prove and which a device cannot
change.

## Owner actions

The devices in hand, unlocking them, trusting the computer, the developer-mode and signing steps, charging and
unplugging, the silent switch, the system haptics setting, turning VoiceOver and the text size on and off, tapping
sites and vents, dragging pods, the moon and the scrubber, double-tapping off the floor and the two-finger orbit,
listening and feeling, and ending the app from the app switcher are done by the owner. Each such step is recorded by
the campaign as `BLOCKED_OWNER_ACTION` with its exact steps when it reaches it, never waited for, and the other rows
continue.

## Rows

### MW-D1 — Launch and first frame

- **Devices:** D1, D2, D3.
- **Procedure:** open Mushroom Weather from the catalog with the testing argument, 200 times per device across the
  three host tiers; the campaign records preparation, shader set-up and first present as stage times.
- **Measurements:** `launch`, `first-frame`.
- **Pass:** no shader program is compiled after the experience became interactive; stage times recorded for 200 samples
  per device and tier (docs/performance/budgets.md, proposal).
- **Gating:** yes. **Covers:** UA-F13 `launch`, `first-frame`.
- **Owner steps:** the owner has the device in hand, unlocked, trusted and charged; the automation build is installed by
  the campaign (signing is the owner's).
- **Status:** pending device campaign.

### MW-D2 — Frame pacing and frame time per tier

- **Devices:** D1, D2, D3.
- **Procedure:** run the hero and full-playthrough scenarios pinned to tiers 0, 1 and 2 in turn, then with automatic
  levels; the campaign records each frame's interval.
- **Measurements:** `frame-pacing`, `frame-time-per-tier`.
- **Pass:** 60 frames per second with automatic levels (a documented 30 frames per second mode is acceptable on the last
  level), 200 samples per device; frame time per pinned tier recorded.
- **Gating:** yes. **Covers:** T-R02G2003-012, T-R02G2008-012; UA-F13 `frame-pacing`.
- **Owner steps:** the owner has the device in hand, unlocked, trusted and charged; the automation build is installed by
  the campaign (signing is the owner's).
- **Status:** pending device campaign.

### MW-D3 — Memory, thermal state and the round-two stress session

- **Devices:** D1, D2, D3.
- **Procedure:** run the 30-minute round-two stress session of UA-F13 (levels opened, pods placed on sites by tap and
  with the panel, pods dragged to other sites and off the floor with the weather preview, vents toggled, the moon
  dragged and the moonlight set, the weather run, the shown cycle scrubbed, actions undone and redone, the camera
  orbited, levels retried and replayed in a loop) at automatic levels; the campaign samples the footprint and the
  thermal state.
- **Measurements:** `memory`, `thermal`, `stress`.
- **Pass:** memory flat within the declared resource budget over the session (the growth rule of feature 192), 200
  samples per device; thermal state and any tier change recorded.
- **Gating:** yes. **Covers:** T-R02G2008-012; UA-F13 `memory`, `thermal`, `stress`.
- **Owner steps:** the owner has the device in hand, unlocked, trusted and charged; the automation build is installed by
  the campaign (signing is the owner's). The owner keeps the device unplugged for the stress session and tells the
  campaign the starting battery level.
- **Status:** pending device campaign.

### MW-D4 — Touch feel and touch-to-frame latency

- **Devices:** D1, D2, D3.
- **Procedure:** tap an empty site to place a pod, drag a pod to another site and off the floor to preview the weather
  and move or remove it, tap a vent to toggle it, drag the moon up and down to preview and set the moonlight, drag along
  the cycle scrubber to show a cycle, orbit the camera with two fingers and double-tap off the floor on each device; the
  campaign records the interval from touch to the first frame showing the change.
- **Measurements:** `touch-to-frame`.
- **Pass:** touch-to-frame latency recorded for 200 samples per device; a tap (travel under 10 points, lifted within 0.5
  s) on an empty site sends exactly one pod.place to the first free slot, or says that every slot is used; a tap on a
  vent sends exactly one vent.set with its other state; a drag of a pod (16 points or more) shows the previewed weather
  from the kernel's own run with the pod drawn as a ghost and sends exactly one pod.place to the nearest site within 24
  points or one pod.remove off the floor on release, and nothing when the target is unchanged; a vertical drag on the
  moon previews the moonlight one level per 40 points (clamped 0 to 3) and sends exactly one moon.set on release when it
  differs; a drag along the scrubber shows the nearest cycle under the finger; a gesture on a finished play explains why
  nothing happens; a double tap off the floor (within 0.35 s and 22 points) restores the authored view.
- **Gating:** yes. **Covers:** T-R02G2004-011.
- **Owner steps:** the owner has the device in hand, unlocked, trusted and charged; the automation build is installed by
  the campaign (signing is the owner's). The owner taps sites and vents, drags pods, the moon and the scrubber,
  double-taps off the floor and orbits with two fingers; the campaign does not synthesise touches on hardware.
- **Status:** pending device campaign.

### MW-D5 — Sound heard and haptics felt

- **Devices:** D1, D2, D3.
- **Procedure:** turn the Sound toggle on and play a level to a win and to a failure with the haptics switch on,
  including one refused action (Remove on an empty slot, which the rules refuse); change the selected slot and site with
  the panel to hear the site auditions; observe the ambient sound and the selection, success, warning and error
  haptics.
- **Measurements:** `sound-audible`, `haptics-felt`.
- **Pass:** the sound is audible only while it is on, the panel is shown and the scene is active, and follows the silent
  switch; each planned haptic is felt (where the device has no haptic engine, the haptic part is recorded as not
  applicable).
- **Gating:** yes. **Covers:** T-R02G2006-011.
- **Owner steps:** the owner has the device in hand, unlocked, trusted and charged; the automation build is installed by
  the campaign (signing is the owner's). The owner listens and feels, and sets the silent switch and the system haptics
  setting.
- **Status:** pending device campaign.

### MW-D6 — VoiceOver walk-through (manual, non-gating)

- **Devices:** D1, D2, D3.
- **Procedure:** with VoiceOver on and the largest accessibility text size, choose a slot and a site with the adjustable
  controls, place the pod with Place, toggle a vent, choose and set the moonlight and run the weather with Run to hear
  each change and the win; replay it.
- **Measurements:** `voiceover-observation`.
- **Pass:** every control and the summary element are read with their label and value; each placement, move, removal,
  vent change, moonlight change, undo, redo, refusal, failure and the win are announced; the panel stays readable at the
  largest accessibility text size; recorded as an observation (non-gating, P-08).
- **Gating:** no (non-gating, P-08). **Covers:** T-R02G2006-011.
- **Owner steps:** the owner has the device in hand, unlocked, trusted and charged; the automation build is installed by
  the campaign (signing is the owner's). The owner turns VoiceOver and the text size on and off in Settings and performs
  the walk-through.
- **Status:** pending device campaign.

### MW-D7 — Progress across a real termination

- **Devices:** D1, D2, D3.
- **Procedure:** win level 1, leave the app to the background, end it from the app switcher, reopen Mushroom Weather.
- **Measurements:** `progress-kept`.
- **Pass:** level 1 is solved with its stars, level 2 is open and the replay of level 1 is offered after the reopen; an
  unfinished level restores to the same pods, vents, moonlight, actions left and records.
- **Gating:** yes. **Covers:** T-R02G2007-012.
- **Owner steps:** the owner has the device in hand, unlocked, trusted and charged; the automation build is installed by
  the campaign (signing is the owner's). The owner ends the app from the app switcher.
- **Status:** pending device campaign.

### MW-D8 — Panel journeys in the app

- **Devices:** D1, D2, D3.
- **Procedure:** run the device scenario set by id and the interface journeys of chunk c4 (`MWPlayUITests` and
  `MWReplayUITests`: win level 1 with its pod placed, its vent closed and the run, replay, relaunch).
- **Measurements:** `scenarios`, `journeys`.
- **Pass:** every scenario of the device set passes; level 1 is won with its certified plan (one pod in slot 1 on the
  site at row 2, column 5, vent 1 closed, then the run) with 3 of 3 stars, level 2 is open, progress survives the
  relaunch, the replay ends won.
- **Gating:** yes. **Covers:** T-R02G2009-011.
- **Owner steps:** the owner has the device in hand, unlocked, trusted and charged; the automation build is installed by
  the campaign (signing is the owner's).
- **Status:** pending device campaign.

## The earlier tasks these rows close

- T-R02G2003-012 (feature 493, renderer): frame time per tier on devices — MW-D2.
- T-R02G2004-011 (feature 494, gestures): touch feel and touch-to-frame latency — MW-D4.
- T-R02G2006-011 (feature 496, polish and accessibility): sound heard, haptics felt (MW-D5) and the VoiceOver
  walk-through at the largest text size (MW-D6).
- T-R02G2007-012 (feature 497, persistence): progress kept across a real termination — MW-D7.
- T-R02G2008-012 (feature 498, regression): frame time and memory of the golden levels per tier — MW-D2, MW-D3.
- T-R02G2009-011 (feature 499, in the app): the panel journeys on devices — MW-D8.

Features 491, 492 and 495 have no {device} task.
