# Research: A18-P02 (feature 132)

- **D1 Numbers-only core (clarification Q1):**
  - **Decision:** the experience core keeps only numbers. The presenter formats the text with the A18-P01 model and an
    injected environment provider.
  - **Rationale:** actions are `[Double]`, and replays must be deterministic.
  - **Alternative:** a core that reads `TimeZone.current`. Rejected, because replays would depend on the device.
- **D2 Ticking:** the overlay's task runs `tick(port:)`, which sends `time.set`, then sleeps until
  `ClockSchedule.nextDeadline`.
  - **Rationale:** no busy loop and no per-frame text work, and the time stays correct while drawing is paused.
  - **Alternative:** sending from `draw`. Rejected, because `draw` has no port, and the time would stop with
    rendering.
- **D3 Theme:** `vc_fbm` with 5 (level-0) or 3 (level-1) octaves, lacunarity 2 and gain 0.5, over
  `uv × 1.5 + time × 0.02 × (cos, sin)` of a slow angle. The result is mapped through four dark palette colours, so
  white text reaches at least 4.5 : 1 against every one (checked with `AccessibleColors.contrastRatio`).
- **D4 Still frames:** time is 0 when motion is off or Reduce Motion is on, so frames are identical. Speed is
  0.25–2 (default 1).
- **D5 Layout:** the time font is 0.22 × the shorter side times the Dynamic Type factor, one line, with a minimum
  scale factor of 0.3 within 90 % of the width; the date uses the title style below it.
- **D6 Verification:** the nine standard scenarios plus five fixtures, because the content-counts audit
  (`verify_experiences.py`, `content_requirement`) requires the planning catalog's count of 5 for A18:
  - `fixture-time-zone-changed`;
  - `fixture-motion-off`;
  - `fixture-twenty-four-hour`;
  - `fixture-seconds-shown`;
  - `fixture-slow-motion`.

  The probe at the canvas centre is `dark`.
- **D7 As built:**
  - The noise is mapped to 0…1 as `clamp(0.5 + 1.5 n)`; the gain gives a frame enough luma spread for the
    non-blank check.
  - `u_octaves` is a float uniform, because the scene binds only float parameters.
  - The foreground kind is proven through `TimeChangeMonitor.applicationNames` (foreground ↦
    `willEnterForegroundNotification`) together with exactly one `time.changed` sent. The value on the wire is not
    observed, because the port's handler is internal to the host.
