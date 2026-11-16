# Research: A16-P06 (feature 122)

- **D1 Privacy facts:**
  - The experience stores preset files `preset-<uuid>.json` in its own `ExperienceStorage` folder, the session state
    in the app's saved state, and the latest capture PNG in `tmp/a16-captures`, emptied when the experience opens.
  - It sends nothing and asks for no permission. The share sheet sends a picture only where the person chooses.
  - Deleting a saved experiment removes its file; deleting the app removes everything.
- **D2 Claims** (Q2): the A15 approach with Simulation Lab's words. "Exact" is allowed, for the automaton's states.
- **D3 Source scan** (Q3): the A15 list.
- **D4 Interface** (Q4): a serial chunk, like `w2`. The presenter draws every frame on the main thread, as Molecular
  Explorer's does.
- **D5 Device campaign:** SL-D1 frame pacing at ×4, SL-D2 thermal over a short run, SL-D3 VoiceOver reading the
  description and the legend, SL-D4 Dynamic Type at the largest size, SL-D5 float-target support on the oldest device
  (and the refusal where it is missing), SL-D6 share sheet to Files. All are pending-campaign-ii.
- **D6 No schema examples:** the state and preset schemas are at 1, so no older stored form exists.
