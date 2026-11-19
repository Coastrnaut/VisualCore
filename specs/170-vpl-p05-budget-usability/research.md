# Research: A23-P05 (feature 170)

- **D1 Levels (clarification Q1):** comparing the level after a warm-up cycle with the level after the last is the
  Shader Studio method (A22-P05): the first cycle legitimately builds programs and slots; growth after it is a leak.
- **D2 Pass counts (Q2):** `runCount` counts real `FieldPass.run` calls, so it proves the schedule drawn, not only the
  schedule computed.
- **D3 States (Q3):** the five preview states cover every branch of `PreviewPipeline`.
- **D4 Interface tests (Q4):** the list form is the accessible and small-screen path (manual risk 2), so it is the one
  proved on the phone; dragging is proved by the package's touch tests.
- **D5 Device plan (Q5):** the Shader Studio and Aurora plans' form; rows pending until ImplementationLock-100.
