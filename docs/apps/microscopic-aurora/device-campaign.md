# Microscopic Aurora — device campaign plan (R02-G19-10, feature 490)

This is the written plan of feature 490 (FR-R02G1910-002 of
[spec.md](../../../specs/490-microscopic-aurora-device-automation-preparation/spec.md)). These rows need real devices.
They run only after `ImplementationLock-100` (CLAUDE.md rule 5), in the order D1 → D2 → D3, and D3 is not updated from
iPadOS 26.5; a campaign that finds D3 on another version is refused, not adapted. Until then every row is "pending
device campaign", and no launch, frame, memory, thermal, latency, sound, haptic or accessibility number is claimed
anywhere. Simulator results never stand in for these rows: the simulator evidence of features 488 and 489 (the
regression and the interface journeys) is a development signal, not device evidence. The campaign is UA-F13's
`scripts/run_device_campaign.py`, which reads [device-rows.json](device-rows.json); this page is its human-readable
twin and says the same things. `python3 scripts/check_device_rows.py --experience r02-g19.microscopic-aurora` checks
the definition: its shape, the scenario names against the manifest, the devices against the ledger, and that every
deferred {device} task is covered; `release_check.py` runs it as the step `device-rows-r02-g19`. Runs are short
(minutes at most, no soak) and a longer session is bounded by arithmetic from the short run (owner ruling of
2026-11-13), except the 30-minute round-two stress session that UA-F13 requires, which only the device campaign runs.

## Microscopic Aurora as built

Microscopic Aurora (`r02-g19.microscopic-aurora`, a free candidate until X-R02-G19) is a puzzle of luminous swimmers in
a round dish under a microscope: the player places up to three magnetic wells on the level's marked sites, each with a
strength and a turning sense, then releases the swarm for one swim, so that the swimmers' glowing trails cover a target
stencil as one connected pattern, without a swimmer leaving the enclosure or the swarm losing its coherence. Every
placement or removal of a well spends one action; the play spends nothing and ends the level won or failed. A play
fails when a swimmer leaves the dish, when the swarm's coherence falls below the requirement, when the stencil's
coverage falls short or when its lit cells form more than one group; a placement or removal that is out of range,
unchanged, on an occupied cell or off a site, or that empties an empty slot, is refused, and so is any action with no
action left. The panel has the well slot, site and strength steppers (− and +) and the sense toggle that choose the
well, Place, Remove, Freeze, Reset view, the tick stepper (Tick − and Tick +, showing a tick of the swim), Play, Undo,
Redo, Next level, the tutorial's Dismiss tutorial, Hint, the failure explanation, Campaign, Daily, Practice, the level
picker with Play level, Replay with Step and Stop, the Sound toggle and a summary element. On the touch screen a tap
on an empty site (while playing) places the chosen well in the first free slot, a drag of a well (from 16 points of
travel, while playing) previews the kernel's swim with the well on the site nearest the finger, or removed when the
finger leaves the dish, and moves or removes it on release, a drag along the scrubber shows the tick nearest the
finger, a tap on the dish field toggles the freeze, a finished play explains in words why nothing happens, two fingers
orbit the camera and a double tap on empty space restores the authored view. Level 1 is won by its certified plan, one
well in slot 1 at row 11, column 18, strength 2, clockwise, then Play, with 3 of 3 stars. A winning play can be
replayed. Details: [microscopic-aurora.md](../../architecture/microscopic-aurora.md) (features 481 … 489).

## Devices

| Device | Model | Ledger row |
|---|---|---|
| D1 | iPhone 15 | DEV1-R02-G19 |
| D2 | iPad Pro 13-inch (M5) | DEV2-R02-G19 |
| D3 | iPad (A16) on iPadOS 26.5 (not updated) | DEV3-R02-G19 |

Every row runs on D1, D2 and D3, in that order.

## Device scenario set

The campaign runs these 12 scenarios of Microscopic Aurora's manifest by id on each device: `launch-first-frame`,
`input-response`, `completion`, `rejection`, `save-restore`, `reset`, `suspend-resume`, `teardown-reentry`,
`cancel-prepare`, `full-playthrough`, `hero` and `fixture-level-1-solved` (a stored win restored on the device). The 80
acceptance rows and the other two fixtures of the manifest (`fixture-run-fails`, `fixture-undo-redo`) stay
simulator-only: they are pure rule outcomes, which the host and the simulator already prove and which a device cannot
change.

## Owner actions

The devices in hand, unlocking them, trusting the computer, the developer-mode and signing steps, charging and
unplugging, the silent switch, the system haptics setting, turning VoiceOver and the text size on and off, tapping
sites, dragging wells and the scrubber, tapping the field, double-tapping empty space and the two-finger orbit,
listening and feeling, and ending the app from the app switcher are done by the owner. Each such step is recorded by
the campaign as `BLOCKED_OWNER_ACTION` with its exact steps when it reaches it, never waited for, and the other rows
continue.

## Rows

### MA-D1 — Launch and first frame

- **Devices:** D1, D2, D3.
- **Procedure:** open Microscopic Aurora from the catalog with the testing argument, 200 times per device across the
  three host tiers; the campaign records preparation, shader set-up and first present as stage times.
- **Measurements:** `launch`, `first-frame`.
- **Pass:** no shader program is compiled after the experience became interactive; stage times recorded for 200 samples
  per device and tier (docs/performance/budgets.md, proposal).
- **Gating:** yes. **Covers:** UA-F13 `launch`, `first-frame`.
- **Owner steps:** the owner has the device in hand, unlocked, trusted and charged; the automation build is installed by
  the campaign (signing is the owner's).
- **Status:** pending device campaign.

### MA-D2 — Frame pacing and frame time per tier

- **Devices:** D1, D2, D3.
- **Procedure:** run the hero and full-playthrough scenarios pinned to tiers 0, 1 and 2 in turn, then with automatic
  levels; the campaign records each frame's interval.
- **Measurements:** `frame-pacing`, `frame-time-per-tier`.
- **Pass:** 60 frames per second with automatic levels (a documented 30 frames per second mode is acceptable on the last
  level), 200 samples per device; frame time per pinned tier recorded.
- **Gating:** yes. **Covers:** T-R02G1903-012, T-R02G1908-012; UA-F13 `frame-pacing`.
- **Owner steps:** the owner has the device in hand, unlocked, trusted and charged; the automation build is installed by
  the campaign (signing is the owner's).
- **Status:** pending device campaign.

### MA-D3 — Memory, thermal state and the round-two stress session

- **Devices:** D1, D2, D3.
- **Procedure:** run the 30-minute round-two stress session of UA-F13 (levels opened, wells placed on sites by tap and
  with the panel, wells dragged to other sites and off the dish with the swim preview, the swim played, the shown tick
  scrubbed, the field frozen, actions undone and redone, the camera orbited, levels retried and replayed in a loop) at
  automatic levels; the campaign samples the footprint and the thermal state.
- **Measurements:** `memory`, `thermal`, `stress`.
- **Pass:** memory flat within the declared resource budget over the session (the growth rule of feature 192), 200
  samples per device; thermal state and any tier change recorded.
- **Gating:** yes. **Covers:** T-R02G1908-012; UA-F13 `memory`, `thermal`, `stress`.
- **Owner steps:** the owner has the device in hand, unlocked, trusted and charged; the automation build is installed by
  the campaign (signing is the owner's). The owner keeps the device unplugged for the stress session and tells the
  campaign the starting battery level.
- **Status:** pending device campaign.

### MA-D4 — Touch feel and touch-to-frame latency

- **Devices:** D1, D2, D3.
- **Procedure:** tap a site to place the chosen well, drag a well to another site and off the dish to preview the swim
  and move or remove it, drag along the scrubber to show a tick, tap the field to freeze, orbit the camera with two
  fingers and double-tap empty space on each device; the campaign records the interval from touch to the first frame
  showing the change.
- **Measurements:** `touch-to-frame`.
- **Pass:** touch-to-frame latency recorded for 200 samples per device; a tap (travel under 10 points, lifted within 0.5
  s) on a free site sends exactly one well.place; a drag of a well (16 points or more) shows the previewed swim and
  sends exactly one well.place to the new site or one well.remove off the dish on release; a drag along the scrubber
  shows the nearest tick under the finger; a tap on the field toggles the freeze; a gesture on a finished play explains
  why nothing happens; a double tap on empty space (within 0.35 s and 22 points) restores the authored view.
- **Gating:** yes. **Covers:** T-R02G1904-011.
- **Owner steps:** the owner has the device in hand, unlocked, trusted and charged; the automation build is installed by
  the campaign (signing is the owner's). The owner taps sites, drags wells and the scrubber, taps the field, double-taps
  empty space and orbits with two fingers; the campaign does not synthesise touches on hardware.
- **Status:** pending device campaign.

### MA-D5 — Sound heard and haptics felt

- **Devices:** D1, D2, D3.
- **Procedure:** turn the Sound toggle on and play a level to a win and to a failure with the haptics switch on,
  including one refused action (undo with nothing to undo, which the rules refuse); change the selected well's site,
  strength and sense with the panel to hear its auditions; observe the ambient sound and the selection, success, warning
  and error haptics.
- **Measurements:** `sound-audible`, `haptics-felt`.
- **Pass:** the sound is audible only while it is on, the panel is shown and the scene is active, and follows the silent
  switch; each planned haptic is felt (where the device has no haptic engine, the haptic part is recorded as not
  applicable).
- **Gating:** yes. **Covers:** T-R02G1906-011.
- **Owner steps:** the owner has the device in hand, unlocked, trusted and charged; the automation build is installed by
  the campaign (signing is the owner's). The owner listens and feels, and sets the silent switch and the system haptics
  setting.
- **Status:** pending device campaign.

### MA-D6 — VoiceOver walk-through (manual, non-gating)

- **Devices:** D1, D2, D3.
- **Procedure:** with VoiceOver on and the largest accessibility text size, choose a well's site, strength and sense
  with the adjustable controls, place it with Place and play the swim with Play to hear each change and the win; replay
  it.
- **Measurements:** `voiceover-observation`.
- **Pass:** every control and the summary element are read with their label and value; each placement, removal, undo,
  redo, refusal, failure and the win are announced; the panel stays readable at the largest accessibility text size;
  recorded as an observation (non-gating, P-08).
- **Gating:** no (non-gating, P-08). **Covers:** T-R02G1906-011.
- **Owner steps:** the owner has the device in hand, unlocked, trusted and charged; the automation build is installed by
  the campaign (signing is the owner's). The owner turns VoiceOver and the text size on and off in Settings and performs
  the walk-through.
- **Status:** pending device campaign.

### MA-D7 — Progress across a real termination

- **Devices:** D1, D2, D3.
- **Procedure:** win level 1, leave the app to the background, end it from the app switcher, reopen Microscopic Aurora.
- **Measurements:** `progress-kept`.
- **Pass:** level 1 is solved with its stars, level 2 is open and the replay of level 1 is offered after the reopen; an
  unfinished level restores to the same wells, actions left and records.
- **Gating:** yes. **Covers:** T-R02G1907-012.
- **Owner steps:** the owner has the device in hand, unlocked, trusted and charged; the automation build is installed by
  the campaign (signing is the owner's). The owner ends the app from the app switcher.
- **Status:** pending device campaign.

### MA-D8 — Panel journeys in the app

- **Devices:** D1, D2, D3.
- **Procedure:** run the device scenario set by id and the interface journeys of chunk b4 (`MAPlayUITests` and
  `MAReplayUITests`: win level 1 with its well placed and the play, replay, relaunch).
- **Measurements:** `scenarios`, `journeys`.
- **Pass:** every scenario of the device set passes; level 1 is won with its certified plan (one well in slot 1 at row
  11, column 18, strength 2, clockwise, then the play) with 3 of 3 stars, level 2 is open, progress survives the
  relaunch, the replay ends won.
- **Gating:** yes. **Covers:** T-R02G1909-011.
- **Owner steps:** the owner has the device in hand, unlocked, trusted and charged; the automation build is installed by
  the campaign (signing is the owner's).
- **Status:** pending device campaign.
## The earlier tasks these rows close

- T-R02G1903-012 (feature 483, renderer): frame time per tier on devices — MA-D2.
- T-R02G1904-011 (feature 484, gestures): touch feel and touch-to-frame latency — MA-D4.
- T-R02G1906-011 (feature 486, polish and accessibility): sound heard, haptics felt (MA-D5) and the VoiceOver
  walk-through at the largest text size (MA-D6).
- T-R02G1907-012 (feature 487, persistence): progress kept across a real termination — MA-D7.
- T-R02G1908-012 (feature 488, regression): frame time and memory of the golden levels per tier — MA-D2, MA-D3.
- T-R02G1909-011 (feature 489, in the app): the panel journeys on devices — MA-D8.

Features 481, 482 and 485 have no {device} task.
