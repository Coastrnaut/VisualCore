# Contract: Living Wallpapers release (A19-P06)

- **Scans:**
  - `scan-sources-release.sh` exits 0: no refused API (clarification Q3) in `Packages/ExperiencesCreative/LivingWallpapers`;
  - `scan-claims-release.sh` exits 0: no refused word (Q2) in the store text and interface Swift, and every test named
    in the claims table exists.
- **Release checks:** `experience-release-a19` and `copy-claims-a19` pass.
- **Recovery:** a failed draw fails the session with the injected message; `history.json` is byte-identical; a new
  session lists both entries.
- **Samples:**
  - snapshot v1 and v2 restore (v1 migrated); newer and damaged are refused;
  - history current loads two entries, while newer and damaged report `newer-version` and `damaged`;
  - every file is byte-identical afterwards.
- **Interface:** `LWHistoryUITests`: export iPhone SE, `history-0` names it, Clear history, no `history-0` and no
  `clear-history` remain; under 60 s.
