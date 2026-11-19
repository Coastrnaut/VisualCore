# Contract: Graphics Benchmark Lab review (A24-P05)

- **Core:** `RunQualification.qualify(_ run: BenchmarkRun) -> Qualification`; `Repeatability.summarise(opened:
  among:) -> RepeatabilitySummary`; `RunCSV.version = 2`.
- **Experience:** `GBLExplanation.sections` (title, text); `ExplanationView`; `RepeatabilityView`.
- **Identifiers** (prefixed `experience.a24.graphics-benchmark-lab.`): `qualification`, `repeatability`, `explain`,
  `explanation`, `explanation-done`, plus A24-P02 to P04's. As built (T-A24-514): the opened result's button is
  `explain` and the repeatability block's is `repeatability-explain`, so each identifier names one element.
- **Interface:** `GBLRunUITests` in chunk `f3` (serial): a quads run to Finished, save, results, open, explain; a
  background mid-run ending as Interrupted.
