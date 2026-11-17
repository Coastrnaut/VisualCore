# Data Model: A20-P05 (feature 149)

- **Calm settings:** `calm.sound`, `calm.drift`, `calm.haptics` ∈ {0, 1}, default 0; core state outside the digest;
  stored as the experience value `calm.v1` (JSON `{sound, drift, haptics}`), ignored when damaged. A garden reset keeps
  the switches (a preference, like the quality tier); a snapshot restore starts them off, and the presenter re-sends
  the kept `calm.v1` switches at the next draw.
- **Drift:** grain offset += 0.01 tray widths per second of frame time when `calm.drift` is on and Reduce Motion is
  off; otherwise 0, with the still frame reused. With the drift on, the mean luminance of
  consecutive frames changes by less than `SandScene.maxFrameLuminanceStep` (0.02 of full scale; nothing flashes).
- **Sounds:** `stroke`, `place`, `remove`: procedural one-shot tones (0.12–0.25 s, 180–420 Hz, gain ≤ 0.2).
- **Campaign row:** id ZG-D1…D8, measurement, devices, procedure, threshold, status "pending device campaign".
