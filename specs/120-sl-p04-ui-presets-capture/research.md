# Research: A16-P04 (feature 120)

- **D1 Paint as an action** (Q1): painting is `sim.paint`, recorded and digested, so replays and saved states include
  it. *Alternative:* mutate the field from the presenter (rejected: it breaks determinism and the runner).
- **D2 Histogram app-local** (Q2): 16 bins over the display range, gated to every 15 frames while running. *Alternative:* a
  VisualCoreSimulation `FieldGrid` histogram (rejected for now: one consumer; recorded in the contract for reassessment
  when a second appears).
- **D3 Motion caps in the presenter** (Q3): the device settings stay out of the deterministic core, as the float
  probe did in A16-P03.
- **D4 Preset files in ExperienceStorage** (Q4, corrected at plan): `NamedLibrary` writes to Application Support outside
  the experience's handle; Fractal Explorer's bookmarks already use one file per entry in `ExperienceStorage`, and its
  64-file quota covers the cap of 24.
- **D5 Capture through the host's still renderer** (Q5): it renders on the host's own context (no second context), then
  `StillImageEncoder` and one file in a `TemporaryFolder`, shared by a ShareLink with no Photos access.
