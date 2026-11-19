# Contract: A23-P05 tests

- **Interface identifiers used** (all from A23-P02 to P04, prefixed `experience.a23.visual-programming-lab.`):
  `add-node`, `node-list`, `input-<id>-<index>`, `status`, `feedback`, `library`, `library-name`, `library-save`,
  `library-row-<file>`, `library-open-<file>`, `library-done`.
- **Launch:** `-vcResetData`, `-vcSkipWelcome`, `-vcCandidates`, `-openExperience a23.visual-programming-lab`
  (relaunch without `-vcResetData`).
- **Chunk:** `e3` = `VPLCanvasUITests`, `VPLRecoveryUITests`, serial.
- **As built (A23-P05):** the Add node menu, the Examples menu and the list form's pickers are inline expanding button
  lists: `add-node` opens `add-node-<kind>`, `examples` opens `example-<id>`, and `input-<id>-<index>` opens
  `input-<id>-<index>-option-<tag>` (tags `none` and `<id>-<output>`), because XCTest never saw the app idle while a
  system menu was open over a canvas presenting 30 frames a second (each tap waited 60 s). The stress test compares
  each cycle with the first cycle showing the same example (49 with 1, 50 with 2), as data-model.md records.
