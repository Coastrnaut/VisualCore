// AutomationRunner.swift — unattended measurement modes for the device campaign (feature 010 T-F903; FR-F914; contract
// specs/010-stabilization-release/contracts/release-contract.md; modeled on the reference projectM-iOS runner, CLAUDE.md §9).
// Compiled only under DEBUG || VISUALCORE_AUTOMATION. Triggered solely by the launch environment
// (VISUALCORE_AUTORUN=<mode>); there is no URL scheme or remote trigger. Each mode writes one JSON report and exits.
#if DEBUG || VISUALCORE_AUTOMATION
import Foundation
import QuartzCore
import VisualCoreRendering

/// Runs one automation mode against a RenderHost, writes an `AutomationReport` and terminates the app.
@MainActor
public final class AutomationRunner {
    /// Environment variable naming the mode.
    public static let environmentKey = "VISUALCORE_AUTORUN"
    /// Environment variable with the frame count (default 120, clamped 1…10,000).
    public static let framesKey = "VISUALCORE_AUTORUN_FRAMES"
    /// Supported modes.
    public static let knownModes = ["smoke", "launch", "lifecycle"]

    private let host: RenderHost
    private let bundleID: String
    private let outputDirectory: URL
    private let terminate: (Int32) -> Void
    private let created = CACurrentMediaTime()
    /// File written by the last run.
    public private(set) var lastReportURL: URL?

    /// - Parameters:
    ///   - outputDirectory: where reports go (default: the app's Documents directory).
    ///   - terminate: ends the process after the report is written (tests pass a recorder instead of `exit`).
    public init(host: RenderHost, bundleID: String, outputDirectory: URL? = nil, terminate: @escaping (Int32) -> Void = { exit($0) }) {
        self.host = host
        self.bundleID = bundleID
        self.outputDirectory = outputDirectory ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        self.terminate = terminate
    }

    /// The mode requested by the launch environment, if any.
    public static func requestedMode(environment: [String: String] = ProcessInfo.processInfo.environment) -> String? {
        environment[environmentKey].flatMap { $0.isEmpty ? nil : $0 }
    }

    /// The frame count requested by the launch environment (default 120, clamped 1…10,000).
    public static func requestedFrames(environment: [String: String] = ProcessInfo.processInfo.environment) -> Int {
        min(max(environment[framesKey].flatMap(Int.init) ?? 120, 1), 10_000)
    }

    /// Runs `mode`, writes the report, then terminates with 0 (pass), 1 (fail) or 2 (error/unknown mode).
    @discardableResult
    public func run(mode: String, frames: Int = 120) -> AutomationReport {
        var report = AutomationReport(mode: mode, bundleID: bundleID, deviceModel: Self.deviceModel(), osVersion: Self.osVersion(),
                                      startedAt: ISO8601DateFormatter().string(from: Date()), result: "pass")
        switch mode {
        case "smoke": smoke(&report, frames: frames)
        case "launch": launch(&report)
        case "lifecycle": lifecycle(&report, frames: frames)
        default:
            report.result = "error"
            report.message = "unknown mode '\(mode)'; known: \(Self.knownModes.joined(separator: ", "))"
        }
        write(report)
        terminate(report.result == "pass" ? 0 : (report.result == "fail" ? 1 : 2))
        return report
    }

    private func timedFrame() -> Double? {
        let start = CACurrentMediaTime()
        guard host.renderOneFrame(present: true) else { return nil }
        return (CACurrentMediaTime() - start) * 1000
    }

    private func smoke(_ report: inout AutomationReport, frames: Int) {
        var samples: [Double] = []
        for _ in 0..<max(1, frames) { if let t = timedFrame() { samples.append(t) } }
        report.frames = samples.count
        report.frameTimeMs = FrameTimeStats(samples: samples)
        if samples.count < frames { report.result = "fail"; report.message = "\(frames - samples.count) frames failed to render" }
    }

    private func launch(_ report: inout AutomationReport) {
        for _ in 0..<600 where timedFrame() == nil {}
        report.frames = host.presentedFrameCount
        if host.presentedFrameCount > 0 {
            report.timeToFirstFrameMs = (CACurrentMediaTime() - created) * 1000
        } else {
            report.result = "fail"; report.message = "no frame presented"
        }
    }

    private func lifecycle(_ report: inout AutomationReport, frames: Int) {
        let cycles = max(5, frames / 10)
        var samples: [Double] = []
        var failures = 0
        for i in 0..<cycles {
            host.pause(); host.resume()
            if i % 3 == 2 { host.recreateContext() }
            if let t = timedFrame() { samples.append(t) } else { failures += 1 }
        }
        report.cycles = cycles
        report.frames = samples.count
        report.frameTimeMs = FrameTimeStats(samples: samples)
        report.leaked = host.resources.stats.leaked
        if failures > 0 || report.leaked != 0 {
            report.result = "fail"
            report.message = "frames failed: \(failures), leaked: \(report.leaked ?? -1)"
        }
    }

    private func write(_ report: AutomationReport) {
        let stamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "")
        let url = outputDirectory.appendingPathComponent("visualcore-automation-\(report.mode)-\(stamp).json")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try? FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
        if let data = try? encoder.encode(report) { try? data.write(to: url) }
        lastReportURL = url
    }

    static func deviceModel() -> String {
        if let simulated = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] { return simulated }
        var info = utsname()
        uname(&info)
        return withUnsafeBytes(of: &info.machine) { raw in
            String(decoding: raw.prefix { $0 != 0 }, as: UTF8.self)
        }
    }

    static func osVersion() -> String {
        let v = ProcessInfo.processInfo.operatingSystemVersion
        return "\(v.majorVersion).\(v.minorVersion).\(v.patchVersion)"
    }
}
#endif
