# Contract: Aurora release (A21-P06)

- **Scans:**
  - `scan-sources-release.sh` exits 0: there is no refused API (clarification Q3) in `Packages/ExperiencesCreative/Aurora`;
  - `scan-claims-release.sh` exits 0: there is no refused word (Q2) in the store text and interface Swift, and every
    test named in the claims table exists.
- **Release checks:** `experience-release-a21` and `copy-claims-a21` pass.
- **Recovery:** a failed draw fails the session with the injected message; `prefs.v1` is byte-identical; a new session
  opens with the saved preset and the sound on.
- **Samples:**
  - snapshot v1 restores; the newer one is refused as `newerSchema` and the damaged one as `corrupt`;
  - the current preferences open with their values;
  - the newer, damaged and out-of-range preferences open the defaults with `newer-version`, `damaged` and
    `out-of-range`;
  - every file is byte-identical afterwards.
- **Interface:** `AUReleaseUITests`: a fresh start names "Polar night" on the canvas, and `sound`, `still` and
  `reduced-flash` read off; under 60 s.
