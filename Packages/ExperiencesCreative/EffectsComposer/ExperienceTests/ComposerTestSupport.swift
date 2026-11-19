// ComposerTestSupport — feature 181 (A25-P02) T-A25-207, T-A25-208 (SC-A25-202 – SC-A25-205). Shared helpers of the
// Effects Composer experience tests, after Graphics Benchmark Lab's `BenchSessionSupport`: an engine of the core alone,
// opening the experience in the one app's session host (with the presenter configured before its first `setup`),
// drawing frames, the engine digest of a core, an action applied to a core directly and the CPU reference of a chain
// on the 256 × 256 test image. Short runs only: no sleep, no wall-clock assertion.
import CoreGraphics
import EffectsComposerCore
import Foundation
import Testing
import UIKit
import VisualCoreExperience
import VisualCoreExperienceHost
@testable import EffectsComposerExperience

/// Building, opening and driving Effects Composer in tests.
@MainActor
enum ComposerTest {
    /// The experience id `a25.effects-composer`.
    static var id: ExperienceID {
        EffectsComposerExperience.id ?? ExperienceID(rawValue: "a25.unknown")!
    }

    /// The test image the preview draws.
    static let image = TestImage.make(size: PreviewRenderer.previewSide)

    /// A prepared, active engine of the core alone.
    static func engine(seed: UInt64 = 1) async throws -> ExperienceEngine<ComposerCore> {
        var engine = ExperienceEngine<ComposerCore>(id: id)
        try await engine.prepare(seed: seed)
        try engine.activate()
        return engine
    }

    /// Opens Effects Composer in `session` through the factory, with `configure` run on the presenter before its first
    /// `setup` (the result is captured unless `configure` turns it off), lays the view out at `size` points, pins the
    /// quality to level 0 and draws one frame.
    static func open(_ session: ExperienceSession, size: CGSize = CGSize(width: 64, height: 48),
                     configure: @escaping (ComposerPresenter) -> Void = { _ in }) async throws
        -> ExperienceShell<ComposerPresenter> {
        let id = self.id
        var made: ExperienceShell<ComposerPresenter>?
        if session.qualityPin == nil { session.qualityPin = 0 }
        let request = ExperienceOpenRequest(id: id, seed: 1, snapshot: nil, refusedSnapshotFails: false) {
            let shell = EffectsComposerExperience.make(id: id)
            shell.presenter.captureResult = true
            configure(shell.presenter)
            made = shell
            return shell
        }
        let opened = await session.open(request)
        #expect(opened == .running)
        let shell = try #require(made)
        let view = try #require(session.renderHost?.view)
        view.frame = CGRect(origin: .zero, size: size)
        view.layoutIfNeeded()
        try draw(session)
        return shell
    }

    /// Draws one frame of `session`.
    static func draw(_ session: ExperienceSession, sourceLocation: SourceLocation = #_sourceLocation) throws {
        let host = try #require(session.renderHost, sourceLocation: sourceLocation)
        let drawn = host.renderOneFrame(present: false)
        #expect(drawn, "a frame", sourceLocation: sourceLocation)
    }

    /// Sends `control` with `values` through `shell`'s port and records an issue unless it is accepted.
    @discardableResult
    static func accept(_ shell: ExperienceShell<ComposerPresenter>, _ control: String, _ values: [Double] = [],
                       sourceLocation: SourceLocation = #_sourceLocation) -> ActionResult {
        let result = shell.port.send(control, values)
        #expect(result == .accepted, "\(control) \(values): \(result.code)", sourceLocation: sourceLocation)
        return result
    }

    /// The core of `shell`.
    static func core(_ shell: ExperienceShell<ComposerPresenter>) throws -> ComposerCore {
        try #require(shell.engine.core)
    }

    /// The digest of `core` as the engine computes it (the experience id as domain).
    nonisolated static func digest(_ core: ComposerCore) throws -> String {
        var builder = DigestBuilder(domain: ComposerCore.experienceID)
        try core.writeDigest(into: &builder)
        return builder.finish().hex
    }

    /// `core` after `control` with `values` applied directly, with the result.
    nonisolated static func applied(_ core: ComposerCore, _ control: String,
                                    _ values: [Double] = []) -> (ComposerCore, ActionResult) {
        var next = core
        let result = next.apply(ExperienceAction(control: control, values: values, step: 0))
        return (next, result)
    }

    /// The CPU reference of `chain` on the test image.
    static func reference(_ chain: EffectChain) -> RGBAImage {
        EffectReference.apply(chain, to: image)
    }

    /// The largest channel difference between the preview's last result and the CPU reference of `chain`.
    static func difference(_ shell: ExperienceShell<ComposerPresenter>, _ chain: EffectChain,
                           sourceLocation: SourceLocation = #_sourceLocation) throws -> Int {
        let result = try #require(shell.presenter.lastResult, sourceLocation: sourceLocation)
        return result.maxChannelDifference(reference(chain))
    }

    /// The tolerance of a chain: 4/255 when an enabled distort is in it, else 2/255.
    static func tolerance(_ chain: EffectChain) -> Int {
        chain.nodes.contains { $0.enabled && $0.effect == .distort } ? 4 : 2
    }

    /// A program text that does not build: `effect`'s program with an undeclared name in its body.
    static func broken(_ effect: EffectID) -> String {
        EffectPrograms.source(for: effect).replacingOccurrences(of: "void main() {",
                                                                  with: "void main() {\n    undeclaredName = 1.0;")
    }
}
