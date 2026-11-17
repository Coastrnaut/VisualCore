# Research: A19-P05 (feature 142)

- **D1 Campaign plan as the gap's deliverable:** device facts (the size limit, the colour profile after Photos, heat,
  memory) cannot come from a simulator, so G-DEVICE closes with a plan whose rows wait for the campaign. This is
  Ambient Clock's A18-P05 pattern.
- **D2 Test limit argument (Q2):**
  - **Decision:** `-lwExportLimit <n>`, compiled only under automation.
  - **Rationale:** it makes the notice path testable in the interface without changing shipping behaviour.
  - **Alternative:** a simulator with a lower limit. None exists.
- **D3 Text collection (Q1, Q5):** XCUITest's static texts and button labels of the experience screen and of the help
  sheet, joined and scanned case-insensitively. It checks the words as the person sees them.
