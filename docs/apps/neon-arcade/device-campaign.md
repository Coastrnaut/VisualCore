# Neon Arcade — device campaign plan

**Status: nothing measured on a device.** Every result below is pending. Feature 079 (A10-P05, FR-A10-520, task
T-A10-504); carried out in the {device} task T-A10-506. Neon Arcade (`a10.neon-arcade`) is measured as a row of the one
VisualCore app's device campaign (Auto-Creator.md section 23), not as a separate app. Simulator results — the
simulation, wave, collision, budget, effects, score and render tests — are development signals only and never device
evidence.

## When and in which order

1. Not before the gate `ImplementationLock-100` is recorded: `python3 scripts/migration_ledger.py guard-device` must
   exit 0. No install, launch or test of the app on a physical device happens earlier.
2. The owner has provisioned signing, paired, trusted and unlocked the devices and answers every system prompt that
   needs a person (owner steps; otherwise the row is `BLOCKED_OWNER_ACTION`). The agent never taps a trust prompt.
3. Order: **D1** (iPhone 15, the reference phone), then **D2** (iPad Pro 13-inch M5, the reference tablet), then
   **D3** (iPad A16). **D3 stays on iPadOS 26.5 and is never updated**; if it reports another version, its campaign
   is blocked and the owner is told. Device names are those of `docs/release/support-matrix.md`.
4. Every measurement uses short runs; only the thermal row lasts ten minutes, as the plan of the one app's campaign
   asks. Longer behaviour is bounded by arithmetic from the short runs. Hardware identifiers go only to untracked
   private files.

## Measurements

The quality levels are configured caps, not measurements (clarification 1): level 2 → glow 1.6 × the radius, glow
opacity at most 0.35 including the pulse, at most 256 live particles; level 1 → 1.4 ×, 0.30, 128; level 0 → 1.2 ×,
0.25 with no pulse, 48. Low Power Mode selects level 0; reduced flashing removes the pulse at every level. The game
itself (its fixed step, collisions, waves and score) is the same at every level.

| Measurement | Devices | Procedure | Pass criterion | Status |
|---|---|---|---|---|
| Frame pacing per quality level | D1 (reference phone), D2 (reference tablet); D3 as a third row | Neon Dodge in wave 1 and in wave 3 or later, with bursts from hits and pickups; pin the host's quality level to 0, 1 and 2 and record CPU and GPU time per frame over a short run; first run and warm runs separate. Source: `PerformanceRecord.pacing`, `qualityLevel`, `qualityPinned` | At the level the governor settles on, CPU and GPU time each stay within the display's refresh interval except isolated spikes; every lower level is at least as fast as the level above; the run's digest is the same at every level | pending device campaign (waits for `ImplementationLock-100`) |
| Thermal state over a 10-minute session | D1, D2, D3 | Ten minutes of play (restarting after each game over), not charging; record `PerformanceRecord.thermal`, `lowPower`, the quality level and the frame intervals each minute | The thermal state never reaches critical; when it rises the level steps down instead of frames being dropped | pending device campaign (waits for `ImplementationLock-100`) |
| Glow readability in bright light | D1, D2, D3 | Outdoors or under a bright lamp at full and at automatic screen brightness; at levels 0, 1 and 2, with the app's reduced-flashing setting off and on; a run with hazards, orbs and bursts on screen | Every hazard, orb and the player are told apart from the field and from each other at a glance; no glow or particle hides a collision shape (the contrast ratios of clarification 2 hold on screen as they do in the render tests) | pending device campaign (waits for `ImplementationLock-100`) |
| Audio routes | D1, D2, D3 | Sound on: play with the speaker, then connect and disconnect wired or Bluetooth headphones mid-run; turn the silent switch (or the silent mode control) on and off; take a call or start a timer alarm mid-run (interruption) and return; sound off: repeat once | Effects follow the current route without a crash or stuck voice; the silent switch silences the effects (ambient category); after an interruption the effects resume on the next cue and the run is paused, never advanced; with sound off nothing plays | pending device campaign (waits for `ImplementationLock-100`) |
| VoiceOver pass | D1, D2, D3 | VoiceOver on: title screen, start, a run with hits, pickups and a wave change, pause, game over with a new high score, the experience's controls (sound, haptics, steering sensitivity) | Every screen and control is spoken with its label; announcements at most one per second, only for hits, waves and game over; every action can be done with VoiceOver | pending device campaign (waits for `ImplementationLock-100`) |
| High-score survival after force-quit | D1, D2, D3 | Finish three runs with different scores; force-quit the app from the app switcher; relaunch and open Neon Arcade; then force-quit during the save of a fourth game over and relaunch | The table lists the same scores in the same order after relaunch; an interrupted save leaves the last complete table; only `high-scores.json` and the experience's state file are in its folder (owner-held container copy) | pending device campaign (waits for `ImplementationLock-100`) |

Each row is recorded pass, fail or `BLOCKED_OWNER_ACTION`; skipped is never success. No measured value of Neon Arcade
is claimed anywhere until its row passes.
