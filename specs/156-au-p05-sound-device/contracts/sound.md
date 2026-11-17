# Contract: Aurora sound loop, low-power cadence, interface and campaign (A21-P05)

- **Defaults:** a fresh experience has the sound off; no player is made and nothing plays.
- **Play/stop:**
  - The loop plays when the sound is on, the controls view is on screen and the scene is active, and stops when any
    of them ends.
  - `setVolume(v)` sets the player's volume to `Float(v)` at once.
  - When `play()` returns false (the output failed), the sound choice stays on, the sky is unaffected and there is no
    crash.
- **Independence:**
  - `setup`, `resize`, `draw`, `teardown`, `shedCaches`, a preset change, the still view and reduced flashing never
    call `play` or `stop`.
  - The digest and the manifest are equal with the sound on and off.
- **Cadence:**
  - Under Low Power Mode the cap is 30.
  - Two seconds at 30 and at 60 frames per second end at the same `SkyClock.time` (±1e-6), and the off-screen pixels
    at the shared instants are identical.
  - A step never exceeds the clamped delta (≤ 0.1 s) times the speed.
- **Interface (`c3`):** each test under 60 s.
  - `AUSkyUITests`: the preset, still view, reduced flashing, and hiding and showing the controls.
  - `AUSoundUITests`: the sound off at first; on with a new volume; restored after a relaunch.
- **Campaign:** 8 rows with devices, procedure, pass condition and "pending device campaign"; no number.
