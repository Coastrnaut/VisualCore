// LabTestSupport — feature 167 (A23-P02) T-A23-207, T-A23-208 (SC-A23-201–206). Shared helpers of the Visual
// Programming Lab experience tests, after Shader Studio's `StudioTestSupport`: an engine and a shell without a render
// host (prepared and active, so actions are carried out with no frame drawn), a canvas view in which canvas points
// equal view points, simulated touches (taps and drags of one finger, pinches of two), opening the experience in the
// one app's session host, drawing frames and off-screen stills (frame time 0), and the engine digest of a core. Short
// runs only (no sleep, no wall-clock assertion).
import CoreGraphics
import Foundation
import Testing
import UIKit
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreRendering
import VisualCoreScenes
@testable import VisualProgrammingLabExperience
import VisualProgrammingLabCore

/// Building, touching, opening, drawing and reading back Visual Programming Lab.
@MainActor
enum LabTest {
    /// The experience id `a23.visual-programming-lab`.
    static var id: ExperienceID {
        VisualProgrammingLabExperience.id ?? ExperienceID(rawValue: "a23.unknown")!
    }

    /// The view size of the touch tests, points.
    static let viewSize = Vec2(1_024, 768)

    /// A view in which a canvas point equals the view point (zoom 1, the centre at the view's middle).
    static var identityView: CanvasView {
        CanvasView(size: viewSize, centre: CanvasPoint(x: viewSize.x / 2, y: viewSize.y / 2))
    }

    /// The size of the stills: 64 × 48 pixels.
    static let width = 64, height = 48

    /// A prepared, active engine of the core alone.
    static func engine(seed: UInt64 = 1) async throws -> ExperienceEngine<LabCore> {
        var engine = ExperienceEngine<LabCore>(id: id)
        try await engine.prepare(seed: seed)
        try engine.activate()
        return engine
    }

    /// The shell of the factory, prepared and active but without a render host, with ``identityView``.
    static func shell() async throws -> ExperienceShell<LabPresenter> {
        let shell = VisualProgrammingLabExperience.make(id: id)
        try await shell.prepare(seed: 1)
        try shell.activate()
        shell.presenter.view = identityView
        return shell
    }

    /// The core of `shell`.
    static func core(_ shell: ExperienceShell<LabPresenter>) throws -> LabCore {
        try #require(shell.engine.core)
    }

    /// The engine digest of `shell`'s state.
    static func digest(_ shell: ExperienceShell<LabPresenter>) throws -> String {
        try labDigest(core(shell))
    }

    /// The fingerprint of `shell`'s graph.
    static func fingerprint(_ shell: ExperienceShell<LabPresenter>) throws -> String {
        try GraphDocument.fingerprint(of: core(shell).graph).hex
    }

    /// Sends `control` with `values` through `shell`'s presenter and records an issue unless it is accepted.
    @discardableResult
    static func accept(_ shell: ExperienceShell<LabPresenter>, _ control: String, _ values: [Double],
                       sourceLocation: SourceLocation = #_sourceLocation) -> ActionResult {
        let result = shell.presenter.send(control, values, port: shell.port)
        #expect(result == .accepted, "\(control) \(values): \(result.code)", sourceLocation: sourceLocation)
        return result
    }

    // MARK: Touches

    /// Hands one touch event to `shell` (as the session host does while the experience is active).
    static func touch(_ shell: ExperienceShell<LabPresenter>, _ id: Int, _ phase: PointerPhase, _ point: Vec2) {
        shell.handlePointer(PointerEvent(id: id, phase: phase, location: point, timestamp: 0), viewSize: viewSize)
    }

    /// The view point of a canvas point in `shell`'s view.
    static func screen(_ shell: ExperienceShell<LabPresenter>, _ p: CanvasPoint) -> Vec2 {
        shell.presenter.view.screen(fromCanvas: p)
    }

    /// One finger from `from` to `to` in `steps` moves, then lifted at `to`.
    static func drag(_ shell: ExperienceShell<LabPresenter>, from: Vec2, to: Vec2, steps: Int = 4, id: Int = 1) {
        touch(shell, id, .began, from)
        for k in 1...max(steps, 1) {
            touch(shell, id, .moved, from + (to - from) * (Double(k) / Double(max(steps, 1))))
        }
        touch(shell, id, .ended, to)
    }

    /// One finger down and up at `point`.
    static func tap(_ shell: ExperienceShell<LabPresenter>, _ point: Vec2, id: Int = 1) {
        touch(shell, id, .began, point)
        touch(shell, id, .ended, point)
    }

    /// Two fingers about `centre`, `from` points apart, spread to `to` points apart along x, then lifted.
    static func pinch(_ shell: ExperienceShell<LabPresenter>, centre: Vec2, from: Double, to: Double) {
        touch(shell, 1, .began, centre - Vec2(from / 2, 0))
        touch(shell, 2, .began, centre + Vec2(from / 2, 0))
        touch(shell, 1, .moved, centre - Vec2(to / 2, 0))
        touch(shell, 2, .moved, centre + Vec2(to / 2, 0))
        touch(shell, 1, .ended, centre - Vec2(to / 2, 0))
        touch(shell, 2, .ended, centre + Vec2(to / 2, 0))
    }

    /// A drag from output `output` of `source` to input `input` of `target`, at their port points.
    static func wire(_ shell: ExperienceShell<LabPresenter>, from source: Int, output: Int, to target: Int,
                     input: Int) throws {
        let graph = try core(shell).graph
        let a = try #require(graph.node(NodeID(source)))
        let b = try #require(graph.node(NodeID(target)))
        drag(shell, from: screen(shell, CanvasLayout.outputPoint(of: a, index: output)),
             to: screen(shell, CanvasLayout.inputPoint(of: b, index: input)))
    }

    // MARK: Session host

    /// Opens Visual Programming Lab in `session` through the factory, lays the view out at `size` points, sets the
    /// presenter's view to `size` with the canvas origin at its middle and draws one frame. A session without a
    /// quality pin is pinned to level 0.
    static func open(_ session: ExperienceSession,
                     size: CGSize = CGSize(width: 64, height: 48)) async throws -> ExperienceShell<LabPresenter> {
        let id = self.id
        var made: ExperienceShell<LabPresenter>?
        if session.qualityPin == nil { session.qualityPin = 0 }
        let request = ExperienceOpenRequest(id: id, seed: 1, snapshot: nil, refusedSnapshotFails: false) {
            let shell = VisualProgrammingLabExperience.make(id: id)
            made = shell
            return shell
        }
        let opened = await session.open(request)
        #expect(opened == .running)
        let view = try #require(session.renderHost?.view)
        view.frame = CGRect(origin: .zero, size: size)
        view.layoutIfNeeded()
        let shell = try #require(made)
        shell.presenter.view = CanvasView(size: Vec2(Double(size.width), Double(size.height)),
                                          centre: CanvasPoint(x: 5, y: 7))
        try draw(session)
        return shell
    }

    /// Draws `count` frames of `session`.
    static func draw(_ session: ExperienceSession, frames count: Int = 1) throws {
        let host = try #require(session.renderHost)
        var drawn = 0
        for _ in 0..<count where host.renderOneFrame(present: false) { drawn += 1 }
        #expect(drawn == count)
    }

    /// An off-screen still of `session` at `width` × `height` (frame time 0), RGBA8 rows top-down.
    static func still(_ session: ExperienceSession, width: Int = width, height: Int = height) throws -> [UInt8] {
        let host = try #require(session.renderHost)
        return try host.renderOffscreen(width: width, height: height, time: 0).rgba
    }

    /// Whether every pixel of the RGBA8 `pixels` has a Rec. 709 luma below 40 of 255 (the class `dark`).
    static func allDark(_ pixels: [UInt8]) -> Bool {
        stride(from: 0, to: pixels.count - 3, by: 4).allSatisfy { i in
            0.2126 * Double(pixels[i]) + 0.7152 * Double(pixels[i + 1]) + 0.0722 * Double(pixels[i + 2]) < 40
        }
    }
}

/// The digest of `core` as the engine computes it (the experience id as domain).
func labDigest(_ core: LabCore) throws -> String {
    var builder = DigestBuilder(domain: LabCore.experienceID)
    try core.writeDigest(into: &builder)
    return builder.finish().hex
}

/// `core` after `control` with `values` applied directly, with the result.
func labApplied(_ core: LabCore, _ control: String, _ values: [Double]) -> (LabCore, ActionResult) {
    var next = core
    let result = next.apply(ExperienceAction(control: control, values: values, step: 0))
    return (next, result)
}
