# Contract: A23-P05 tests

- **Interface identifiers used** (all from A23-P02 to P04, prefixed `experience.a23.visual-programming-lab.`):
  `add-node`, `node-list`, `input-<id>-<index>`, `status`, `feedback`, `library`, `library-name`, `library-save`,
  `library-row-<file>`, `library-open-<file>`, `library-done`.
- **Launch:** `-vcResetData`, `-vcSkipWelcome`, `-vcCandidates`, `-openExperience a23.visual-programming-lab`
  (relaunch without `-vcResetData`).
- **Chunk:** `e3` = `VPLCanvasUITests`, `VPLRecoveryUITests`, serial.
