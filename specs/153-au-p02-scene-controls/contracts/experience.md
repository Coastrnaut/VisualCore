# Contract: Aurora experience (A21-P02)

- **Actions:** each of the eight accepted in range and refused outside it or when fractional for an integer control,
  with the state unchanged; snapshot round trip; digest stable; a newer, damaged or refused snapshot is refused on
  restore with the state unchanged.
- **Limit:** every preset drawn at limits 0.2, 0.4 and 0.72, and the start, middle and end of every change between the
  three presets, have no pixel above the limit + 1/255; the reference agrees within the A21-P01 tolerances.
- **Blend:** the change takes 1.5 s of frame time; a new selection mid-change starts from the current blend; immediate
  under Reduce Motion.
- **Chrome:** hidden controls return by a tap and by the "Show controls" action; every control has a spoken label.
- **Rebuild:** after `recreateContext` and a resize the picture equals the one before.
- **Registration:** a21 a candidate, not available; the manifest is valid and its committed file matches.

- **As built (A21-P02):**
  - the knee starts at 5/6 × limit (`SkyShader.kneeRatio`), so the default 0.72 is exactly the A21-P01 knee;
  - only a preset change starts the 1.5 s blend; a control moved during a blend retargets it with its progress kept;
    re-selecting the current preset snaps; opening or restoring shows the state at once;
  - the palette expands to five stops (the sky and four ribbon slots, black beyond the count), which draws the A21-P01
    picture byte for byte; during a blend the larger ribbon count is drawn and a ribbon present on one side only fades;
  - `reset()` returns the limit to 0.6 and keeps the quality tier;
  - restore refusals are `SkyRestoreRefusal` (`damaged`, `scene(SceneRefusal)`, out-of-range `hue` or `limit`); a
    fractional integer value is refused with the rule `a21.not-whole`; the outcome is `preset-<id>`;
  - the tap that shows the controls is presentation only: no gesture action, all eight actions native.
