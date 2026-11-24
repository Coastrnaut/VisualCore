# Acoustic Constellator — device campaign plan (R02-G13-10, feature 430)

This is the written plan of feature 430 (FR-R02G1310-002 of
[spec.md](../../../specs/430-acoustic-constellator-device-automation-preparation/spec.md)). These rows need real
devices. They run only after `ImplementationLock-100` (CLAUDE.md rule 5), in the order D1 → D2 → D3, and D3 is not
updated from iPadOS 26.5; a campaign that finds D3 on another version is refused, not adapted. Until then every row is
"pending device campaign", and no launch, frame, memory, thermal, latency, sound, haptic or accessibility number is
claimed anywhere. Simulator results never stand in for these rows: the simulator evidence of features 428 and 429 (the
regression and the interface journeys) is a development signal, not device evidence. The campaign is UA-F13's
`scripts/run_device_campaign.py`, which reads [device-rows.json](device-rows.json); this page is its human-readable twin
and says the same things. `python3 scripts/check_device_rows.py --experience r02-g13.acoustic-constellator` checks the
definition: its shape, the scenario names against the manifest, the devices against the ledger, and that every deferred
{device} task is covered; `release_check.py` runs it as the step `device-rows-r02-g13`. Runs are short (minutes at
most, no soak) and a longer session is bounded by arithmetic from the short run (owner ruling of 2026-11-13), except the
30-minute round-two stress session that UA-F13 requires, which only the device campaign runs.

## Acoustic Constellator as built

Acoustic Constellator (`r02-g13.acoustic-constellator`, a free candidate until X-R02-G13) is a puzzle of drifting
musical stars, each pulsing at its own natural rate: linking two stars couples them and pulls their phases together, and
a link stretched too far by the drift snaps; the player links the pairs of a target celestial symbol (and any helping
links the limits allow) and nudges stars' starting phases within the action budget, then listens, and the level is won
when every link of the symbol exists and the stars cohere above the level's threshold for the hold interval within the
listening window. The panel has the star and partner steppers (naming the chosen star and its partner), Link, Unlink,
the nudge steppers (minus and plus), Listen, Undo, Redo, Next level, Reset view, Hint, the tutorial's Dismiss, the
failure's Undo and Retry, Campaign, Daily, Practice, the level picker with Play level, Replay best solution with Step
and Stop, the Sound toggle and a summary element. On the touch screen a tap on a star while playing nudges it one step
forward and chooses it, a tap on a link chooses its two stars and describes it without spending an action, a drag of 16
points or more from a star draws a filament to the finger and, released on another star, links an unlinked pair (or
unlinks a pair the player linked), a tap on the coherence or hold gauge listens, two fingers orbit the camera and a
double tap on empty space restores the authored view. Level 1 is won by linking star 0 with star 1, then listening,
with 3 of 3 stars. A winning play can be replayed. Details:
[acoustic-constellator.md](../../architecture/acoustic-constellator.md) (features 421 … 429).

## Devices

| Device | Model | Ledger row |
|---|---|---|
| D1 | iPhone 15 | DEV1-R02-G13 |
| D2 | iPad Pro 13-inch (M5) | DEV2-R02-G13 |
| D3 | iPad (A16) on iPadOS 26.5 (not updated) | DEV3-R02-G13 |

Every row runs on D1, D2 and D3, in that order.

## Device scenario set

The campaign runs these 12 scenarios of Acoustic Constellator's manifest by id on each device: `launch-first-frame`,
`input-response`, `completion`, `rejection`, `save-restore`, `reset`, `suspend-resume`, `teardown-reentry`,
`cancel-prepare`, `full-playthrough`, `hero` and `fixture-level-1-solved` (a stored win restored on the device). The 80
acceptance rows and the other two fixtures of the manifest (`fixture-budget-out`, `fixture-undo-redo`) stay
simulator-only: they are pure rule outcomes, which the host and the simulator already prove and which a device cannot
change.

## Owner actions

The devices in hand, unlocking them, trusting the computer, the developer-mode and signing steps, charging and
unplugging, the silent switch, the system haptics setting, turning VoiceOver and the text size on and off, tapping and
dragging stars, tapping the gauges and the two-finger orbit, listening and feeling, and ending the app from the app
switcher are done by the owner. Each such step is recorded by the campaign as `BLOCKED_OWNER_ACTION` with its exact
steps when it reaches it, never waited for, and the other rows continue.

## Rows

### ACN-D1 — Launch and first frame

- **Devices:** D1, D2, D3.
- **Procedure:** open Acoustic Constellator from the catalog with the testing argument, 200 times per device across the
  three host tiers; the campaign records preparation, shader set-up and first present as stage times.
- **Measurements:** `launch`, `first-frame`.
- **Pass:** no shader program is compiled after the experience became interactive; stage times recorded for 200 samples
  per device and tier (docs/performance/budgets.md, proposal).
- **Gating:** yes. **Covers:** UA-F13 `launch`, `first-frame`.
- **Owner steps:** the owner has the device in hand, unlocked, trusted and charged; the automation build is installed by
  the campaign (signing is the owner's).
- **Status:** pending device campaign.

### ACN-D2 — Frame pacing and frame time per tier

- **Devices:** D1, D2, D3.
- **Procedure:** run the hero and full-playthrough scenarios pinned to tiers 0, 1 and 2 in turn, then with automatic
  levels; the campaign records each frame's interval.
- **Measurements:** `frame-pacing`, `frame-time-per-tier`.
- **Pass:** 60 frames per second with automatic levels (a documented 30 frames per second mode is acceptable on the last
  level), 200 samples per device; frame time per pinned tier recorded.
- **Gating:** yes. **Covers:** T-R02G1303-012, T-R02G1308-012; UA-F13 `frame-pacing`.
- **Owner steps:** the owner has the device in hand, unlocked, trusted and charged; the automation build is installed by
  the campaign (signing is the owner's).
- **Status:** pending device campaign.

### ACN-D3 — Memory, thermal state and the round-two stress session

- **Devices:** D1, D2, D3.
- **Procedure:** run the 30-minute round-two stress session of UA-F13 (levels opened, stars linked and unlinked with
  drags and the panel, stars nudged, the constellation listened to, actions undone and redone, the camera orbited,
  levels retried and replayed in a loop) at automatic levels; the campaign samples the footprint and the thermal state.
- **Measurements:** `memory`, `thermal`, `stress`.
- **Pass:** memory flat within the declared resource budget over the session (the growth rule of feature 192), 200
  samples per device; thermal state and any tier change recorded.
- **Gating:** yes. **Covers:** T-R02G1308-012; UA-F13 `memory`, `thermal`, `stress`.
- **Owner steps:** the owner has the device in hand, unlocked, trusted and charged; the automation build is installed by
  the campaign (signing is the owner's). The owner keeps the device unplugged for the stress session and tells the
  campaign the starting battery level.
- **Status:** pending device campaign.

### ACN-D4 — Touch feel and touch-to-frame latency

- **Devices:** D1, D2, D3.
- **Procedure:** tap a star to nudge it, drag from one star to another to link them (and back over a player link to
  unlink it), tap the coherence or hold gauge to listen, orbit the camera with two fingers and double-tap empty space on
  each device; the campaign records the interval from touch to the first frame showing the change.
- **Measurements:** `touch-to-frame`.
- **Pass:** touch-to-frame latency recorded for 200 samples per device; a tap under 10 points and 0.5 s on a star while
  playing nudges it once and chooses it; a drag of 16 points or more from a star previews the filament and, released
  within 22 points of another star, links the pair exactly once (or unlinks a pair the player linked); a tap on a gauge
  while playing sends exactly one listen; a double tap on empty space restores the authored camera.
- **Gating:** yes. **Covers:** T-R02G1304-011.
- **Owner steps:** the owner has the device in hand, unlocked, trusted and charged; the automation build is installed by
  the campaign (signing is the owner's). The owner taps and drags stars, taps the gauges and orbits with two fingers;
  the campaign does not synthesise touches on hardware.
- **Status:** pending device campaign.

### ACN-D5 — Sound heard and haptics felt

- **Devices:** D1, D2, D3.
- **Procedure:** turn the Sound toggle on and play a level to a win and to a failure with the haptics switch on,
  including one refused action (a link the rules refuse, such as one beyond a star's degree limit); inspect a link to
  hear its audition; observe the constellation's ambient sound and the selection, success, warning and error haptics.
- **Measurements:** `sound-audible`, `haptics-felt`.
- **Pass:** the sound is audible only while it is on, the panel is shown and the scene is active, and follows the silent
  switch; each planned haptic is felt (where the device has no haptic engine, the haptic part is recorded as not
  applicable).
- **Gating:** yes. **Covers:** T-R02G1306-011.
- **Owner steps:** the owner has the device in hand, unlocked, trusted and charged; the automation build is installed by
  the campaign (signing is the owner's). The owner listens and feels, and sets the silent switch and the system haptics
  setting.
- **Status:** pending device campaign.

### ACN-D6 — VoiceOver walk-through (manual, non-gating)

- **Devices:** D1, D2, D3.
- **Procedure:** with VoiceOver on and the largest accessibility text size, choose a star and a partner with the
  adjustable star and partner steppers, link them and hear the pair described, listen and hear the win; replay it.
- **Measurements:** `voiceover-observation`.
- **Pass:** every control and the summary element are read with their label and value; each link, unlink, nudge,
  listen, undo, redo, refusal, failure and the win are announced; the panel stays readable at the largest accessibility
  text size; recorded as an observation (non-gating, P-08).
- **Gating:** no (non-gating, P-08). **Covers:** T-R02G1306-011.
- **Owner steps:** the owner has the device in hand, unlocked, trusted and charged; the automation build is installed by
  the campaign (signing is the owner's). The owner turns VoiceOver and the text size on and off in Settings and performs
  the walk-through.
- **Status:** pending device campaign.

### ACN-D7 — Progress across a real termination

- **Devices:** D1, D2, D3.
- **Procedure:** win level 1, leave the app to the background, end it from the app switcher, reopen Acoustic
  Constellator.
- **Measurements:** `progress-kept`.
- **Pass:** level 1 is solved with its stars, level 2 is open and the replay of level 1 is offered after the reopen; an
  unfinished level restores to the same links, actions left and records.
- **Gating:** yes. **Covers:** T-R02G1307-011.
- **Owner steps:** the owner has the device in hand, unlocked, trusted and charged; the automation build is installed by
  the campaign (signing is the owner's). The owner ends the app from the app switcher.
- **Status:** pending device campaign.

### ACN-D8 — Panel journeys in the app

- **Devices:** D1, D2, D3.
- **Procedure:** run the device scenario set by id and the interface journeys of chunk v3 (win level 1 with the star
  and partner steppers, Link and Listen, replay, relaunch).
- **Measurements:** `scenarios`, `journeys`.
- **Pass:** every scenario of the device set passes; level 1 is won with its one certified link (star 0 with star 1) and
  the listen with 3 of 3 stars, level 2 is open, progress survives the relaunch, the replay ends won.
- **Gating:** yes. **Covers:** T-R02G1309-011.
- **Owner steps:** the owner has the device in hand, unlocked, trusted and charged; the automation build is installed by
  the campaign (signing is the owner's).
- **Status:** pending device campaign.

## The earlier tasks these rows close

- T-R02G1303-012 (feature 423, renderer): frame time per tier on devices — ACN-D2.
- T-R02G1304-011 (feature 424, spatial interaction): touch feel and touch-to-frame latency — ACN-D4.
- T-R02G1306-011 (feature 426, polish and accessibility): sound heard, haptics felt (ACN-D5) and the VoiceOver
  walk-through at the largest text size (ACN-D6).
- T-R02G1307-011 (feature 427, persistence): progress kept across a real termination — ACN-D7.
- T-R02G1308-012 (feature 428, regression): frame time and memory of the golden levels per tier — ACN-D2, ACN-D3.
- T-R02G1309-011 (feature 429, in the app): the panel journeys on devices — ACN-D8.

Features 421, 422 and 425 have no {device} task.
