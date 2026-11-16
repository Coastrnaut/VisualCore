# Data model: A16-P05 (feature 121)

| Entity | Fields | Rules |
|---|---|---|
| Validation report (`docs/apps/simulation-lab/validation-report.md`) | runtime; per family: frames, max \|GPU − CPU\|, tolerance; fixtures (float16, toward zero); limits: iterations, non-finite cells, refusal sentences; max GPU steps in a frame; presenter target bytes, registry bytes and budget; iterations per second (simulator figure) | deterministic lines compared with the committed file; timing lines excluded |
| `SimulationPresenter.ownedTargetBytes` | Int | display target + automaton, Gray-Scott and wave pairs |
| `SimulationPresenter.maxGPUStepsInFrame` | Int | the largest per-frame GPU step delta since setup |
