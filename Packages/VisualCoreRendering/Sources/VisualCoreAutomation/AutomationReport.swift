// AutomationReport.swift — the JSON written by AutomationRunner (feature 010 T-F903; data model
// specs/010-stabilization-release/data-model.md). Compiled only under DEBUG || VISUALCORE_AUTOMATION.
#if DEBUG || VISUALCORE_AUTOMATION
import Foundation

/// Frame-time statistics in milliseconds.
public struct FrameTimeStats: Codable, Equatable, Sendable {
    /// Fastest frame.
    public var min: Double
    /// Median frame.
    public var median: Double
    /// 95th-percentile frame (nearest rank).
    public var p95: Double
    /// Slowest frame.
    public var max: Double

    /// Statistics of `samples` (milliseconds); nil when empty.
    public init?(samples: [Double]) {
        guard !samples.isEmpty else { return nil }
        let s = samples.sorted()
        min = s[0]
        max = s[s.count - 1]
        median = s.count % 2 == 1 ? s[s.count / 2] : (s[s.count / 2 - 1] + s[s.count / 2]) / 2
        p95 = s[Swift.min(s.count - 1, Int((0.95 * Double(s.count)).rounded(.up)) - 1)]
    }
}

/// One automation run's result (schema 1), written as JSON to the app's Documents directory.
public struct AutomationReport: Codable, Equatable, Sendable {
    /// Report format version.
    public var schema = 1
    /// Mode that ran (`smoke`, `launch`, `lifecycle`, or the unknown name requested).
    public var mode: String
    /// Bundle identifier of the app that produced the report.
    public var bundleID: String
    /// Hardware model identifier (e.g. `iPhone15,4`), or the simulated model on a simulator.
    public var deviceModel: String
    /// Operating-system version string.
    public var osVersion: String
    /// UTC start time, ISO 8601.
    public var startedAt: String
    /// Frames rendered during the run.
    public var frames = 0
    /// Per-frame render time statistics (`smoke`, `lifecycle`).
    public var frameTimeMs: FrameTimeStats?
    /// Milliseconds from runner creation to the first presented frame (`launch`).
    public var timeToFirstFrameMs: Double?
    /// Suspend/resume and context-loss cycles completed (`lifecycle`).
    public var cycles: Int?
    /// GPU resources the host reported as leaked at the end (`lifecycle`).
    public var leaked: Int?
    /// `pass`, `fail` or `error`.
    public var result: String
    /// Human-readable detail for `fail`/`error`.
    public var message: String?
}
#endif
