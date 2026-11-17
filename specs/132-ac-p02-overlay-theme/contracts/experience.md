# Contract: Ambient Clock experience (A18-P02)

- **Actions:** each control in data-model.md is accepted inside its ranges and refused outside them. Equal action
  lists give equal digests.
- **Time:**
  - after `time.set(t)`, the presenter's display text equals `ClockFormatter.display(at: t, …)` with the
    environment's locale and zone;
  - `tick` sends the source's instant and returns a deadline strictly later than it, on a minute boundary (or a
    second boundary with seconds on).
- **Time-zone fixture:**
  - with the environment at New York and a fixed instant, the text shows New York time;
  - the provider then switches to Kolkata and `NSSystemTimeZoneDidChange` is posted on the presenter's private
    centre;
  - `time.changed` (timeZone) is sent once, and the text shows Kolkata time for the same instant.
- **Foreground:** posting `UIApplication.willEnterForegroundNotification` on the private centre sends
  `time.changed` (foreground) once.
- **Theme:**
  - white text has a contrast of at least 4.5 : 1 against all four palette colours;
  - frames at `level-0` and `level-1` are not blank;
  - with motion off or Reduce Motion on, two frames at different times are identical; with motion on they differ.
- **Overlay:** the canvas label (`describe`) equals the display's spoken string. No announcement is posted without
  `time.speak`, which is not a control in this phase.
- **Verification:** the nine standard scenarios pass, plus "time zone changed" and "motion off"; the manifest is
  generated and checked.
