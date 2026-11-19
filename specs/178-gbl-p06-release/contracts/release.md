# Contract: Graphics Benchmark Lab release (A24-P06)

- **Privacy page:**
  - stored data and its removal, the export files and their removal;
  - "nothing is sent automatically"; an export leaves only through the share sheet the person opens;
  - "no permission is asked"; device facts from public sources only;
  - the licences.
- **Source scan:** 0 refused uses in `Packages/ExperiencesCreative/GraphicsBenchmarkLab`; `ShareLink` only in
  `Experience/ResultsView.swift`.
- **Claims scan:** 0 refused words in the store text and the interface Swift; "does not rank devices" is present;
  every named test exists.
- **Release checklist:** every row has a status and evidence; device rows name GBL-D1 … GBL-D6.
- **Release steps:** `experience-release-a24` and `copy-claims-a24` pass; the release build passes unsigned.
- **Recovery:** a failed draw ends the session with a message; storage is byte-identical; a new session lists and
  opens the results.
- **Samples:** as in data-model.md.
- **Interface (`f3`, `GBLReleaseUITests`):**
  - the status is "Ready";
  - `case-quads` is selected;
  - there is no `qualification`;
  - after `results`, "No saved results." is shown and there is no `result-row-1`.
