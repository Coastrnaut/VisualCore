# Contract: release tooling and automation (Phase 9)

Synced with the shipped tools (convergence T-F923).

```text
python3 scripts/check_public_api.py [--update]          # exit 0 ok, 1 undocumented/changed (names listed)
python3 scripts/check_licenses.py                       # exit 0 all dependencies inventoried, 1 unknown license / missing text
python3 scripts/check_documented_api.py --sources <consumer dir>   # exit 1 when a consumer uses an undocumented VisualCore name
python3 scripts/release_check.py [--list] [--only STEP…] [--skip STEP…] [--json PATH] [--log-dir DIR]
        # runs every step in order, one log file per step + summary.json (schema 1: result, passed, total,
        # steps[name, status pass|fail|timeout|error, exit_code, seconds, log, command]); exit 0 only if all pass
python3 scripts/run_automation_sim.py --app <simulator .app> --runtime 27.2|26.5 --mode smoke|launch|lifecycle|<other>
        [--frames N] --out <dir> [--timeout S] [--dry-run]
        # first available iPhone on the runtime (never a hard-coded name); exit 0 pass, 1 fail/error, 3 timeout
python3 scripts/simulator_baselines.py --app <measurement .app> [--runtimes 27.2 26.5] [--smoke-runs 3]
        [--frames 300] [--launches 10]          # → docs/performance/baselines-simulator.json
python3 scripts/check_release_symbols.py --app <Release .app> [--expect-present]
        # Release: 0 automation symbols and 0 VISUALCORE_AUTORUN strings; --expect-present proves detection on a measurement build
swift run -c release --package-path Packages/VisualCore VisualCoreBaselines [--json]   # → docs/performance/baselines-host.json
```

Measurement build: Release + `SWIFT_ACTIVE_COMPILATION_CONDITIONS=VISUALCORE_AUTOMATION` (command-line setting, so it
reaches package targets too).

```swift
// VisualCoreAutomation — the whole module compiles only under DEBUG || VISUALCORE_AUTOMATION
@MainActor public final class AutomationRunner {
  public nonisolated static let environmentKey = "VISUALCORE_AUTORUN"
  public nonisolated static let framesKey = "VISUALCORE_AUTORUN_FRAMES"          // 1…10,000, default 120
  public nonisolated static let knownModes = ["smoke", "launch", "lifecycle"]
  public private(set) var lastReportURL: URL?
  public init(host: RenderHost, bundleID: String, outputDirectory: URL? = nil /* Documents */,
              terminate: @escaping (Int32) -> Void = { exit($0) })
  public nonisolated static func requestedMode(environment: [String: String] = ProcessInfo.processInfo.environment) -> String?
  public nonisolated static func requestedFrames(environment: [String: String] = ProcessInfo.processInfo.environment) -> Int
  @discardableResult public func run(mode: String, frames: Int = 120) -> AutomationReport
      // writes <outputDirectory>/visualcore-automation-<mode>-<UTC>.json, then terminate(0 pass | 1 fail | 2 error/unknown)
}
public struct AutomationReport: Codable, Equatable, Sendable { … see data-model … }
public struct FrameTimeStats: Codable, Equatable, Sendable { min, median, p95 (nearest rank), max }
```

Modes: `smoke` times N frames; `launch` measures runner creation → first presented frame (stops at the first frame,
≤ 600 attempts); `lifecycle` runs max(5, N/10) pause/resume cycles with a context recreation every third cycle and
reports leaks.

Release builds: `nm -U` of the Showcase Release binary and its frameworks contains no `AutomationRunner`,
`AutomationReport`, `VisualCoreAutomation`, `ShowcaseAutomation` or `AutomationRootView` symbols and no
`VISUALCORE_AUTORUN` string; the trigger is the launch environment only (no URL scheme, no remote input).
