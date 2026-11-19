# Contract: Visual Programming Lab release (A23-P06)

- **Privacy page:**
  - stored data and its removal;
  - "nothing is sent";
  - "no permission is asked";
  - the licences.
- **Source scan:** 0 refused uses in `Packages/ExperiencesCreative/VisualProgrammingLab`.
- **Claims scan:** 0 refused words in the store text and the interface Swift; "no code to type" is present; every
  named test exists.
- **Release checklist:** every row has a status and evidence; device rows name VPL-D1 … VPL-D6.
- **Release steps:** `experience-release-a23` and `copy-claims-a23` pass; the release build passes unsigned.
- **Recovery:** a failed draw ends the session with a message; storage is byte-identical; a new session lists and
  opens the graphs.
- **Samples:** as in data-model.md.
- **Interface (`e3`, `VPLReleaseUITests`):**
  - the status is "Ready";
  - `node-row-1` and `node-row-2` are present and `node-row-3` is absent;
  - there is no `feedback`;
  - there is no `library-row-graph-1`.
