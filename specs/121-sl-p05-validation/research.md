# Research: A16-P05 (feature 121)

- **D1 Report from a test** (Q5): like the scenario manifest, a test regenerates the report and checks the committed
  one, so it cannot drift. *Alternative:* a Python script (rejected: the measurements need the GPU session).
- **D2 Tolerances** (Q1): 0 for the automaton, 0.01 for the float families; the in-shader half rounding of A16-P03
  (D7) makes the measured value 0.0.
- **D3 Limits on CPU and GPU** (Q2): 600 iterations at each limit, finite everywhere; beyond the limit refused.
- **D4 Bounds** (Q3): per-frame GPU steps ≤ 128; the presenter's targets ≤ 256 KiB; the registry within its budget.
- **D5 Timing reported, not asserted** (Q4): a simulator figure; the device campaign measures devices.
- **D6 Size change** (Q5): the field targets are grid-sized, so a canvas resize reloads them and a context recreation
  remakes them; both are checked against the CPU field.
