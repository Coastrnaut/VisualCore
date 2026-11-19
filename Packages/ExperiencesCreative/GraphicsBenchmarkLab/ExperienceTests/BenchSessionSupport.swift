// BenchSessionSupport — feature 174 (A24-P02) T-A24-208, T-A24-209 (SC-A24-202, SC-A24-203, SC-A24-204). Shared
// helpers of the Graphics Benchmark Lab experience tests that play the experience (the workload helpers are in
// BenchTestSupport.swift): an engine and a shell without a render host, opening the experience in the one app's
// session host, drawing frames at synthetic frame times through the presenter's `feedTime`, the engine digest of a
// core and an action applied to a core directly. Short runs only: no sleep, no wall-clock assertion, never a plan run
// in real time.
import CoreGraphics
import Foundation
import Testing
import UIKit
import VisualCoreExperience
import VisualCoreExperienceHost
@testable import GraphicsBenchmarkLabExperience
import GraphicsBenchmarkLabCore

/// Building, opening and driving Graphics Benchmark Lab in tests.
@MainActor
enum BenchTest {
    /// The experience id `a24.graphics-benchmark-lab`.
    static var id: ExperienceID {
        GraphicsBenchmarkLabExperience.id ?? ExperienceID(rawValue: "a24.unknown")!
    }

    /// A prepared, active engine of the core alone.
    static func engine(seed: UInt64 = 1) async throws -> ExperienceEngine<BenchCore> {
        var engine = ExperienceEngine<BenchCore>(id: id)
        try await engine.prepare(seed: seed)
        try engine.activate()
        return engine
    }

    /// The shell of the factory, prepared and active but without a render host.
    static func shell() async throws -> ExperienceShell<BenchPresenter> {
        let shell = GraphicsBenchmarkLabExperience.make(id: id)
        try await shell.prepare(seed: 1)
        try shell.activate()
        return shell
    }

    /// The core of `shell`.
    static func core(_ shell: ExperienceShell<BenchPresenter>) throws -> BenchCore {
        try #require(shell.engine.core)
    }

    /// Sends `control` with `values` through `shell`'s port and records an issue unless it is accepted.
    @discardableResult
    static func accept(_ shell: ExperienceShell<BenchPresenter>, _ control: String, _ values: [Double] = [],
                       sourceLocation: SourceLocation = #_sourceLocation) -> ActionResult {
        let result = shell.port.send(control, values)
        #expect(result == .accepted, "\(control) \(values): \(result.code)", sourceLocation: sourceLocation)
        return result
    }

    /// Opens Graphics Benchmark Lab in `session` through the factory, lays the view out at `size` points, pins the
    /// quality to level 0 when unpinned and draws one frame at the synthetic time `time` (seconds).
    static func open(_ session: ExperienceSession, size: CGSize = CGSize(width: 64, height: 48),
                     time: Double = 0) async throws -> ExperienceShell<BenchPresenter> {
        let id = self.id
        var made: ExperienceShell<BenchPresenter>?
        if session.qualityPin == nil { session.qualityPin = 0 }
        let request = ExperienceOpenRequest(id: id, seed: 1, snapshot: nil, refusedSnapshotFails: false) {
            let shell = GraphicsBenchmarkLabExperience.make(id: id)
            made = shell
            return shell
        }
        let opened = await session.open(request)
        #expect(opened == .running)
        let shell = try #require(made)
        let view = try #require(session.renderHost?.view)
        view.frame = CGRect(origin: .zero, size: size)
        view.layoutIfNeeded()
        try draw(session, shell, at: time)
        return shell
    }

    /// Draws one frame of `session` with `shell`'s presenter fed the frame time `time` (seconds).
    static func draw(_ session: ExperienceSession, _ shell: ExperienceShell<BenchPresenter>, at time: Double,
                     sourceLocation: SourceLocation = #_sourceLocation) throws {
        let host = try #require(session.renderHost, sourceLocation: sourceLocation)
        shell.presenter.feedTime = time
        let drawn = host.renderOneFrame(present: false)
        #expect(drawn, "a frame at \(time) s", sourceLocation: sourceLocation)
    }

    /// Draws one frame of `session` with `shell`'s presenter fed the frame time `time` (seconds) and presents it, as
    /// the display link does (feature 175 T-A24-310): the presentation submits the frame's GL work, so its GPU timer
    /// result becomes available a few frames later; a burst of frames drawn without presenting may leave the work
    /// unsubmitted and time nothing.
    static func drawPresented(_ session: ExperienceSession, _ shell: ExperienceShell<BenchPresenter>, at time: Double,
                              sourceLocation: SourceLocation = #_sourceLocation) throws {
        let host = try #require(session.renderHost, sourceLocation: sourceLocation)
        shell.presenter.feedTime = time
        let drawn = host.renderOneFrame(present: true)
        #expect(drawn, "a presented frame at \(time) s", sourceLocation: sourceLocation)
    }

    /// Draws one frame at each of `times` (seconds).
    static func draw(_ session: ExperienceSession, _ shell: ExperienceShell<BenchPresenter>,
                     times: [Double]) throws {
        for time in times { try draw(session, shell, at: time) }
    }

    /// `count` frame times from `start`, `step` seconds apart.
    static func times(from start: Double, step: Double, count: Int) -> [Double] {
        var times: [Double] = []
        for k in 0..<max(0, count) { times.append(start + Double(k) * step) }
        return times
    }

    /// The digest of `core` as the engine computes it (the experience id as domain).
    static func digest(_ core: BenchCore) throws -> String {
        var builder = DigestBuilder(domain: BenchCore.experienceID)
        try core.writeDigest(into: &builder)
        return builder.finish().hex
    }

    /// `core` after `control` with `values` applied directly, with the result.
    static func applied(_ core: BenchCore, _ control: String, _ values: [Double] = []) -> (BenchCore, ActionResult) {
        var next = core
        let result = next.apply(ExperienceAction(control: control, values: values, step: 0))
        return (next, result)
    }
}
