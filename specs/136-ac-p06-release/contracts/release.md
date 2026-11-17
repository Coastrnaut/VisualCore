# Contract: Ambient Clock release (A18-P06)

- **Scans:**
  - `scan-sources-release.sh` exits 0: no refused API in `Packages/ExperiencesCreative/AmbientClock`, no `brightness =`
    write, and `isIdleTimerDisabled` exactly in `Experience/KeepAwake.swift`;
  - `scan-claims-release.sh` exits 0: no refused word in the store text and interface Swift, and every test named in
    the claims table exists.
- **Release checks:** `experience-release-a18` and `copy-claims-a18` pass.
- **Recovery:** a failed draw fails the session; `favourites.json` is byte-identical; a new session lists both
  favourites.
- **Samples:**
  - snapshot v1, v2 and v3 restore (v1 and v2 migrated); newer and damaged are refused;
  - favourites current loads, while newer and damaged report their problem;
  - every file is byte-identical afterwards.
- **Interface:** `ACThemeUITests`: Wave Field, then save "Evening", then switch, then apply, and Wave Field is shown.
