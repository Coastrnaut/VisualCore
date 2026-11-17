# Contract: themes, presets and favourites (A18-P03)

- **Contrast:** `ThemeCatalog.contrastProblems()` is empty, and each of the 48 palette colours gives white text at
  least 4.5 : 1.
- **Render:** each theme at each level draws a non-blank frame whose centre probe is `dark`.
- **Preset:**
  - the round trip is exact;
  - damaged, newer, oversized and each out-of-range field are refused with their reason.
- **Favourites:**
  - save, reopen and apply restore the same preset;
  - the 13th is refused as `over-cap`, and a duplicate as `duplicate-name`;
  - an empty name becomes "Favourite N";
  - a damaged library file gives an empty list and a problem, without a crash.
- **Snapshot:** a schema-1 example migrates to theme 0 and palette 0; the schema-2 example round-trips.
- **Crossfade use:** a theme change under Reduce Motion shows the new theme on the next frame; otherwise the frame at
  0.6 s is a mix of the two.
- **Manifest:** the nine standard scenarios plus the five A18-P02 fixtures, `fixture-theme-waves` and
  `fixture-theme-shapes-palette`.
