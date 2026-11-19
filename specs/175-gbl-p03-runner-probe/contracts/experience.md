# Contract: Graphics Benchmark Lab runner and report (A24-P03)

- **Core:** `TimerProbe`, `TimerSupport`, `DroppedFrameRule`, `RunReport`, `TimingSources`; `BenchmarkRun.report:
  RunReport?`; `RunDocument.schemaVersion = 2`.
- **Experience:** `ReportSource.report(case:capabilities:tier:start:end:gpuMeasured:)` builds the report from public
  APIs (`deviceModel()`, `osVersion()`, `appVersion()`, `appBuild()`, `thermalName(_:)`);
  `BenchPresenter` test seams add `forceTimerUnsupported` and `timer` (read-only); the summary text names the GPU line
  only when GPU times exist.
- **Copy:** no number other than measured percentiles; "GPU time not available on this device" when absent.
- **As built:** the timer is keyed by the presenter's drawn-frame counter and mapped to the recorded sample's index;
  GPU and report tests present each frame (`renderOneFrame(present: true)`), because unpresented frames drawn in a
  burst were not timed reliably on the simulator.
