# Research: A21-P05 (feature 156)

- **D1 Loop owner (clarification Q1):** the presenter owns the loop through a small `SkySound` policy. Alternative: a
  VisualCore lifecycle hook for presenters (rejected: a VisualCore change for one user; the controls view's life and
  the scene phase already mark "Aurora on screen in the active app").
- **D2 Seam:** `AmbientLoopPlayer`'s output seam is internal to VisualCoreAudio, so the experience defines its own
  protocol `SkyLoopPlaying`. The real player conforms by an empty extension. Alternative: making the seam public
  (rejected: a VisualCore API change).
- **D3 Lazy player:** the player is made at the first `play`, so a start with the sound off never touches
  `AVAudioSession`.
- **D4 Cadence (Q2):** the host's `FramePacing` cap and clamped delta, proved by tests. Alternative: an
  experience-level frame skip (rejected: duplicates the host and would step the clock unevenly).
- **D5 Interface (Q3):** serial chunk `c3`, two classes, after A20's `b3`. The relaunch omits `-vcResetData`, so the
  stored preferences survive.
- **D6 Campaign (Q4):** eight rows in A20's format; short runs extrapolated by arithmetic; no number claimed.
