# Contract: Digital Zen Garden release (A20-P06)

- **Scans:**
  - `scan-sources-release.sh` exits 0: no refused API (clarification Q3) in `Packages/ExperiencesCreative/DigitalZenGarden`;
  - `scan-claims-release.sh` exits 0: no refused word (Q2) in the store text and interface Swift, and every test named
    in the claims table exists.
- **Release checks:** `experience-release-a20` and `copy-claims-a20` pass.
- **Recovery:** a failed draw fails the session with the injected message; `library.json` and both garden files are
  byte-identical; a new session lists both gardens.
- **Samples:**
  - snapshot v1 restores; newer and damaged are refused;
  - a current garden file is listed and opens; newer and damaged are listed as unreadable with `newer-version` and
    `damaged`;
  - a current index lists two gardens; a newer index makes the library read-only; a damaged one is not rewritten by
    reading;
  - every file is byte-identical afterwards.
- **Interface:** `ZGReleaseUITests`: a fresh start shows the three calm switches off; Make picture; the message reads
  "The picture is ready to share: 1600 by 1200 pixels." and `still-share` exists; under 60 s.
