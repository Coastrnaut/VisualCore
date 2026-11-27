# Binary Gardens — device campaign plan (R02-G21-10, feature 510)

This is the written plan of feature 510 (FR-R02G2110-002 of
[spec.md](../../../specs/510-binary-gardens-device-automation-preparation/spec.md)). These rows need real devices.
They run only after `ImplementationLock-100` (CLAUDE.md rule 5), in the order D1 → D2 → D3, and D3 is not updated from
iPadOS 26.5; a campaign that finds D3 on another version is refused, not adapted. Until then every row is "pending
device campaign", and no launch, frame, memory, thermal, latency, sound, haptic or accessibility number is claimed
anywhere. Simulator results never stand in for these rows: the simulator evidence of features 508 and 509 (the
regression and the interface journeys) is a development signal, not device evidence. The campaign is UA-F13's
`scripts/run_device_campaign.py`, which reads [device-rows.json](device-rows.json); this page is its human-readable
twin and says the same things. `python3 scripts/check_device_rows.py --experience r02-g21.binary-gardens` checks the
definition: its shape, the scenario names against the manifest, the devices against the ledger, and that every deferred
{device} task is covered; `release_check.py` runs it as the step `device-rows-r02-g21`. Runs are short (minutes at
most, no soak) and a longer session is bounded by arithmetic from the short run (owner ruling of 2026-11-13), except
the 30-minute round-two stress session that UA-F13 requires, which only the device campaign runs.

## Binary Gardens as built

Binary Gardens (`r02-g21.binary-gardens`, a free candidate until X-R02-G21) is a puzzle of twin suns over tiny garden
worlds: the player moves each of the two stars to a nearer or farther distance ring, shifts where along its orbit it
stands, turns its brightness up or down and tilts the orbit plane, then runs the light, so that every garden world keeps
a comfortable stretch of light across a full cycle of 48 ticks without freezing, scorching, wilting or bleaching. Every
ring, phase, luminosity or tilt change spends one action; the run spends nothing and ends the level won or failed. A
run fails when a world stays too dark or too bright for longer than the level's tolerance (frozen, scorched), when its
longest comfortable window is shorter than required (unstable) or when its light summed over the cycle falls below or
above its bloom band (wilted, bleached); a change of a locked control, an unchanged value, a phase off the level's
phase grid, a change that brings the stars too close, and any action with no action left are refused. The panel has
the Star picker, the Ring picker with Ring − and Ring +, the phase target stepper with Phase − and Phase + and Set
phase, the Luminosity picker with Luminosity − and Luminosity +, the Tilt picker with Tilt − and Tilt + (when the level
can tilt), Tick − and Tick + (showing a tick of the cycle), Run, Undo, Redo, Next level, Inspect with the inspected
world's words, Reset view, the tutorial's Dismiss tutorial, Hint, the failure explanation, Campaign, Daily, Practice,
the level picker with Play level, Replay best solution with Step and Stop, the Sound toggle and a summary element. On
the touch screen (feature 504, `BinaryGardensGestureController`) a tap on a world inspects it and a second tap clears
it; a tap on a star selects it and explains it; a tap on a luminosity pip or on the tilt dial (while playing) sets the
nearest pip; a tap or a drag on a gauge row shows the tick under the finger; a drag of a star (from 16 points of
travel, while playing) is a phase drag along its orbit or a ring drag across its rings, previews the kernel's own light
report with the star drawn as a ghost, and sets the change on release; a horizontal drag on a pip row or the tilt dial
previews one step per 32 points and sets it on release; a finished play explains in words why nothing happens; two
fingers orbit the camera and a double tap on empty space restores the authored view. Level 1 is won by its certified
plan, one action — star 2 set to luminosity level 1 of 2 — then Run, with 3 of 3 stars, and the panel then says "Every
world kept its window and bloomed." (`BinaryGardensPresenter.describe`). A winning play can be replayed. Details:
[binary-gardens.md](../../architecture/binary-gardens.md) (features 501 … 509).

## Devices

| Device | Model | Ledger row |
|---|---|---|
| D1 | iPhone 15 | DEV1-R02-G21 |
| D2 | iPad Pro 13-inch (M5) | DEV2-R02-G21 |
| D3 | iPad (A16) on iPadOS 26.5 (not updated) | DEV3-R02-G21 |

Every row runs on D1, D2 and D3, in that order.

## Device scenario set

The campaign runs these 12 scenarios of Binary Gardens' manifest by id on each device: `launch-first-frame`,
`input-response`, `completion`, `rejection`, `save-restore`, `reset`, `suspend-resume`, `teardown-reentry`,
`cancel-prepare`, `full-playthrough`, `hero` and `fixture-level-1-solved` (a stored win restored on the device). The 80
acceptance rows and the other two fixtures of the manifest (`fixture-run-fails`, `fixture-undo-redo`) stay
simulator-only: they are pure rule outcomes, which the host and the simulator already prove and which a device cannot
change.

## Owner actions

The devices in hand, unlocking them, trusting the computer, the developer-mode and signing steps, charging and
unplugging, the silent switch, the system haptics setting, turning VoiceOver and the text size on and off, tapping
worlds, stars, luminosity pips, the tilt dial and gauge rows, dragging stars, pip rows, the dial and gauge rows,
double-tapping empty space and the two-finger orbit, listening and feeling, and ending the app from the app switcher
are done by the owner. Each such step is recorded by the campaign as `BLOCKED_OWNER_ACTION` with its exact steps when
it reaches it, never waited for, and the other rows continue.

## Rows

### BG-D1 — Launch and first frame

- **Devices:** D1, D2, D3.
- **Procedure:** open Binary Gardens from the catalog with the testing argument, 200 times per device across the three
  host tiers; the campaign records preparation, shader set-up and first present as stage times.
- **Measurements:** `launch`, `first-frame`.
- **Pass:** no shader program is compiled after the experience became interactive; stage times recorded for 200 samples
  per device and tier (docs/performance/budgets.md, proposal).
- **Gating:** yes. **Covers:** UA-F13 `launch`, `first-frame`.
- **Owner steps:** the owner has the device in hand, unlocked, trusted and charged; the automation build is installed by
  the campaign (signing is the owner's).
- **Status:** pending device campaign.

### BG-D2 — Frame pacing and frame time per tier

- **Devices:** D1, D2, D3.
- **Procedure:** run the hero and full-playthrough scenarios and the golden levels pinned to tiers 0, 1 and 2 in turn,
  then with automatic levels; the campaign records each frame's interval.
- **Measurements:** `frame-pacing`, `frame-time-per-tier`.
- **Pass:** 60 frames per second with automatic levels (a documented 30 frames per second mode is acceptable on the last
  level), 200 samples per device; frame time per pinned tier and per golden level recorded.
- **Gating:** yes. **Covers:** T-R02G2103-012, T-R02G2108-012; UA-F13 `frame-pacing`.
- **Owner steps:** the owner has the device in hand, unlocked, trusted and charged; the automation build is installed by
  the campaign (signing is the owner's).
- **Status:** pending device campaign.

### BG-D3 — Memory, thermal state and the round-two stress session

- **Devices:** D1, D2, D3.
- **Procedure:** run the 30-minute round-two stress session of UA-F13 (levels opened, stars dragged across their rings
  and along their orbits with the light preview, luminosity pips and the tilt dial tapped and dragged, stars, rings,
  phases, luminosities and the tilt set with the panel, worlds inspected, gauge rows scrubbed, the light run, actions
  undone and redone, the camera orbited, levels retried and replayed in a loop) at automatic levels; the campaign
  samples the footprint and the thermal state, with the golden levels' memory per tier.
- **Measurements:** `memory`, `thermal`, `stress`.
- **Pass:** memory flat within the declared resource budget over the session (the growth rule of feature 192), 200
  samples per device; memory per tier, thermal state and any tier change recorded.
- **Gating:** yes. **Covers:** T-R02G2108-012; UA-F13 `memory`, `thermal`, `stress`.
- **Owner steps:** the owner has the device in hand, unlocked, trusted and charged; the automation build is installed by
  the campaign (signing is the owner's). The owner keeps the device unplugged for the stress session and tells the
  campaign the starting battery level.
- **Status:** pending device campaign.

### BG-D4 — Touch feel and touch-to-frame latency

- **Devices:** D1, D2, D3.
- **Procedure:** tap a world to inspect it and again to clear it, tap a star to select it, tap a luminosity pip and the
  tilt dial to set them, tap and drag along a gauge row to show a tick, drag a star across its rings and along its
  orbit to preview and set the change, drag along a luminosity pip row and the tilt dial to preview and set the value,
  double-tap empty space to reset the view and orbit the camera with two fingers on each device; the campaign records
  the interval from touch to the first frame showing the change.
- **Measurements:** `touch-to-frame`.
- **Pass:** touch-to-frame latency recorded for 200 samples per device; a tap (travel under 10 points, lifted within 0.5
  s) on a world sends inspectWorld for it, or clears it when it is already inspected; a tap on a star selects it and
  explains it; a tap on a luminosity pip or the tilt dial while playing sends exactly one star.luminosity or orbit.tilt
  for the nearest pip when it differs, and a locked brightness or a single level is explained; a tap or drag on a gauge
  row shows the tick under the finger (clock.show, never an undo step); a star drag (16 points or more) is a phase drag
  along the orbit tangent or else a ring drag, shows the kernel's own report for the change with the star drawn as a
  ghost and sends exactly one star.ring or star.phase on release, and nothing when the target is unchanged; a drag on a
  pip row or the dial previews one step per 32 points and sends exactly one star.luminosity or orbit.tilt on release
  when it differs; a gesture on a finished play explains why nothing happens; a double tap on empty space (within 0.35
  s and 22 points) restores the authored view; two fingers orbit within yaw plus or minus 60 degrees and pitch -20 to
  +35 degrees.
- **Gating:** yes. **Covers:** T-R02G2104-011.
- **Owner steps:** the owner has the device in hand, unlocked, trusted and charged; the automation build is installed by
  the campaign (signing is the owner's). The owner taps worlds, stars, pips, the tilt dial and gauge rows, drags stars,
  pips, the dial and gauge rows, double-taps empty space and orbits with two fingers; the campaign does not synthesise
  touches on hardware.
- **Status:** pending device campaign.

### BG-D5 — Sound heard and haptics felt

- **Devices:** D1, D2, D3.
- **Procedure:** turn the Sound toggle on and play a level to a win and to a failure with the haptics switch on,
  including one refused action (an unchanged ring, phase, brightness or tilt, which the rules refuse); choose each star
  with the panel to hear its audition; observe the ambient sound and the selection, success, warning and error
  haptics, with the announcements of feature 506 ("Star n moved to ring r (its radius in units).", "Every world kept
  its light and bloomed. Level won spending a actions, k of 3 stars.", the failure explanation, and the refusal "That
  ring, phase, brightness or tilt change cannot be made (locked, unchanged, off the phase grid or too close to the
  other star), or there is nothing to undo or redo.").
- **Measurements:** `sound-audible`, `haptics-felt`.
- **Pass:** the sound is audible only while it is on, the panel is shown and the scene is active, and follows the silent
  switch; each planned haptic is felt (where the device has no haptic engine, the haptic part is recorded as not
  applicable).
- **Gating:** yes. **Covers:** T-R02G2106-011.
- **Owner steps:** the owner has the device in hand, unlocked, trusted and charged; the automation build is installed by
  the campaign (signing is the owner's). The owner listens and feels, and sets the silent switch and the system haptics
  setting.
- **Status:** pending device campaign.

### BG-D6 — VoiceOver walk-through (manual, non-gating)

- **Devices:** D1, D2, D3.
- **Procedure:** with VoiceOver on and the largest accessibility text size, choose a star with the adjustable Star
  control, adjust its ring, phase and luminosity and the tilt with the adjustable controls, show a tick, inspect a world
  and run the light with Run to hear each change and the win; replay it.
- **Measurements:** `voiceover-observation`.
- **Pass:** every control and the summary element are read with their label and value (", locked" for a locked
  control); each ring move ("Star n moved to ring r (its radius in units)."), phase shift ("Star n shifted to phase
  p."), luminosity change ("Star n's luminosity set to L."), tilt change ("Tilt set to t of T steps."), undo
  ("Undone."), redo ("Redone."), refusal, failure and the win ("Every world kept its light and bloomed.") are
  announced; the panel stays readable at the largest accessibility text size; recorded as an observation (non-gating,
  P-08).
- **Gating:** no (non-gating, P-08). **Covers:** T-R02G2106-011.
- **Owner steps:** the owner has the device in hand, unlocked, trusted and charged; the automation build is installed by
  the campaign (signing is the owner's). The owner turns VoiceOver and the text size on and off in Settings and performs
  the walk-through.
- **Status:** pending device campaign.

### BG-D7 — Progress across a real termination

- **Devices:** D1, D2, D3.
- **Procedure:** win level 1, leave the app to the background, end it from the app switcher, reopen Binary Gardens.
- **Measurements:** `progress-kept`.
- **Pass:** level 1 is solved with its stars, level 2 is open and the replay of level 1 is offered after the reopen; an
  unfinished level restores to the same rings, phases, luminosities, tilt, actions left and records, and the Sound
  choice is kept.
- **Gating:** yes. **Covers:** T-R02G2107-012.
- **Owner steps:** the owner has the device in hand, unlocked, trusted and charged; the automation build is installed by
  the campaign (signing is the owner's). The owner ends the app from the app switcher.
- **Status:** pending device campaign.

### BG-D8 — Panel journeys in the app

- **Devices:** D1, D2, D3.
- **Procedure:** run the device scenario set by id and the interface journeys of chunk d4 (`BGPlayUITests` and
  `BGReplayUITests`: win level 1 with star 2's luminosity lowered and the run, reading the panel's win text, replay,
  relaunch).
- **Measurements:** `scenarios`, `journeys`.
- **Pass:** every scenario of the device set passes; level 1 is won with its certified plan (star 2 set to luminosity
  level 1 of 2, then the run) and the panel reads "Every world kept its window and bloomed."
  (`BinaryGardensPresenter.describe`) with "Best: 3 of 3 stars", level 2 is open, progress survives the relaunch, the
  replay ends won.
- **Gating:** yes. **Covers:** T-R02G2109-011.
- **Owner steps:** the owner has the device in hand, unlocked, trusted and charged; the automation build is installed by
  the campaign (signing is the owner's).
- **Status:** pending device campaign.

## The earlier tasks these rows close

- T-R02G2103-012 (feature 503, renderer): frame time per tier on devices — BG-D2.
- T-R02G2104-011 (feature 504, gestures): touch feel and touch-to-frame latency — BG-D4.
- T-R02G2106-011 (feature 506, polish and accessibility): sound heard, haptics felt (BG-D5) and the VoiceOver
  walk-through at the largest text size (BG-D6).
- T-R02G2107-012 (feature 507, persistence): progress kept across a real termination — BG-D7.
- T-R02G2108-012 (feature 508, regression): frame time and memory of the golden levels per tier — BG-D2, BG-D3.
- T-R02G2109-011 (feature 509, in the app): the panel journeys on devices — BG-D8.

Features 501, 502 and 505 have no {device} task.
