# Research: A16-P02 (feature 118)

- **D1 Truth** (clarification 1): CPU model is the truth; GPU mirror in lockstep. *Alternative*: GPU as truth with
  read-back snapshots (rejected: snapshots and replays would depend on GPU rounding).
- **D2 Loading and stepping** (clarification 2): load from CPU on any non-step change; step by the engine's iteration
  delta otherwise.
- **D3 Automaton on RGBA8** (clarification 3): exact states, wrap by index modulo, rule masks as uniforms.
- **D4 Gray-Scott fixture** (clarification 4): 16 × 16, 10 steps, tolerance 0.01 against both half roundings.
- **D5 Isolation** (clarification 5): observed through `FieldPass.runObserver`; `FieldPass` itself refuses
  input-is-output.
