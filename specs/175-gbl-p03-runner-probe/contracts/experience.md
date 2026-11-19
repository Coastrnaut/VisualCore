# Contract: Graphics Benchmark Lab runner and report (A24-P03)

- **Core:** `TimerProbe`, `TimerSupport`, `DroppedFrameRule`, `RunReport`, `TimingSources`; `BenchmarkRun.report:
  RunReport?`; `RunDocument.schemaVersion = 2`.
- **Experience:** `ReportSource.current(capabilities:tier:conditions:)` builds the report fields from public APIs;
  `BenchPresenter` test seams add `forceTimerUnsupported` and `timer` (read-only); the summary text names the GPU line
  only when GPU times exist.
- **Copy:** no number other than measured percentiles; "GPU time not available on this device" when absent.
