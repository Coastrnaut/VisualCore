// LabTestSupport — feature 167 (A23-P02) T-A23-207, T-A23-208 (SC-A23-201–206). Shared helpers of the Visual
// Programming Lab experience tests, after Shader Studio's `StudioTestSupport`: an engine and a shell without a render
// host (prepared and active, so actions are carried out with no frame drawn), a canvas view in which canvas points
// equal view points, simulated touches (taps and drags of one finger, pinches of two), opening the experience in the
// one app's session host, drawing frames and off-screen stills (frame time 0), and the engine digest of a core. Short
// runs only (no sleep, no wall-clock assertion).
//
// Feature 168 (A23-P03) T-A23-305–307 (SC-A23-301–306): `open` hides the preview unless asked (`preview: true`) or the
// runner's default view is kept, so the A23-P02 grid tests see the grid alone; stills take a frame time; graphs are
// built node by node (`GraphBuild`) and drawn through the presenter's `graphOverride`; the inset (the bottom-left
// square of a third of the shorter side) is read back with references at each pixel's centre in its 0…1
// coordinates.
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
    /// presenter's view to `size` with the canvas origin at its middle (unless `keepDefaultView`, as the verification
    /// runner leaves it) and draws one frame. A session without a
    /// quality pin is pinned to level 0.
    /// The preview is shown when `preview` is true, or when it is nil and `keepDefaultView` is set (the runner's
    /// opening); otherwise it is hidden before the first frame (the grid tests of A23-P02).
    static func open(_ session: ExperienceSession, size: CGSize = CGSize(width: 64, height: 48),
                     keepDefaultView: Bool = false, preview: Bool? = nil,
                     graph: VisualGraph? = nil) async throws -> ExperienceShell<LabPresenter> {
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
        let shell = try #require(made)
        shell.presenter.previewVisible = preview ?? keepDefaultView
        shell.presenter.graphOverride = graph
        let view = try #require(session.renderHost?.view)
        view.frame = CGRect(origin: .zero, size: size)
        view.layoutIfNeeded()
        if !keepDefaultView {
            shell.presenter.view = CanvasView(size: Vec2(Double(size.width), Double(size.height)),
                                              centre: CanvasPoint(x: 5, y: 7))
        }
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

    /// An off-screen still of `session` at `width` × `height` (frame time `time`, 0 by default), RGBA8 rows
    /// top-down.
    static func still(_ session: ExperienceSession, width: Int = width, height: Int = height,
                      time: Double = 0) throws -> [UInt8] {
        let host = try #require(session.renderHost)
        return try host.renderOffscreen(width: width, height: height, time: time).rgba
    }

    // MARK: Preview (A23-P03)

    /// The inset of a `width` × `height` still: its side in pixels (a third of the shorter side).
    static func insetSide(width: Int, height: Int) -> Int {
        PreviewPipeline.insetSide(width: width, height: height)
    }

    /// The RGB of inset pixel (`x`, `y`) of the top-down RGBA8 `still` (`x` from the left, `y` from the bottom, as
    /// the inset's 0…1 coordinates run).
    static func insetPixel(_ still: [UInt8], width: Int, height: Int, x: Int, y: Int) -> SIMD3<Double> {
        let row = height - 1 - y
        let i = (row * width + x) * 4
        guard i >= 0, i + 2 < still.count else { return SIMD3(-1_000, -1_000, -1_000) }
        return SIMD3(Double(still[i]), Double(still[i + 1]), Double(still[i + 2]))
    }

    /// The largest channel difference, in 0…255, between the inset of `still` and `reference` (0…1 RGB at each
    /// pixel's centre `u`, `v` in 0…1), over the inset pixels where `include` holds.
    static func insetError(_ still: [UInt8], width: Int, height: Int,
                           include: (Double, Double) -> Bool = { _, _ in true },
                           reference: (Double, Double) -> SIMD3<Double>) -> Double {
        let side = insetSide(width: width, height: height)
        var worst = 0.0
        for y in 0..<side {
            for x in 0..<side {
                let u = (Double(x) + 0.5) / Double(side), v = (Double(y) + 0.5) / Double(side)
                guard include(u, v) else { continue }
                let got = insetPixel(still, width: width, height: height, x: x, y: y)
                let want = reference(u, v) * 255
                for c in 0..<3 { worst = max(worst, abs(got[c] - want[c])) }
            }
        }
        return worst
    }

    /// The inset of `still`, RGBA8 rows bottom-up (as a render target reads back).
    static func inset(_ still: [UInt8], width: Int, height: Int) -> [UInt8] {
        let side = insetSide(width: width, height: height)
        var pixels: [UInt8] = []
        pixels.reserveCapacity(side * side * 4)
        for y in 0..<side {
            let row = height - 1 - y
            pixels.append(contentsOf: still[(row * width * 4)..<((row * width + side) * 4)])
        }
        return pixels
    }

    /// The live bytes of render targets (the `.framebuffer` kind) in `session`'s registry.
    static func targetBytes(_ session: ExperienceSession) throws -> Int {
        try #require(session.renderHost).resources.stats.liveBytes[.framebuffer, default: 0]
    }
}

/// Builds a graph node by node for the preview tests: identities in call order from 1, positions 200 points apart.
struct GraphBuild {
    /// The graph so far.
    private(set) var graph = VisualGraph()

    /// Adds a node of `kind` with `parameters` and returns its identity.
    @discardableResult
    mutating func add(_ kind: NodeKind, _ parameters: [String: Double] = [:]) -> NodeID {
        let id = NodeID(graph.nodes.count + 1)
        let position = CanvasPoint(x: Double(graph.nodes.count % 6) * 200, y: Double(graph.nodes.count / 6) * 200)
        graph.nodes.append(GraphNode(id: id, kind: kind, parameters: parameters, position: position))
        return id
    }

    /// Connects output `output` of `source` to input `input` of `target`.
    mutating func wire(_ source: NodeID, _ output: String = "image", to target: NodeID, _ input: String = "image") {
        graph.edges.append(GraphEdge(from: source, output, to: target, input))
    }

    /// A graph of `kind` (with `parameters`) into an Output.
    static func single(_ kind: NodeKind, _ parameters: [String: Double] = [:]) -> VisualGraph {
        var build = GraphBuild()
        let node = build.add(kind, parameters)
        let output = build.add(.output)
        build.wire(node, to: output)
        return build.graph
    }

    /// `noises` Noise nodes folded by a chain of Mix nodes into an Output: the Noise passes run first (smallest
    /// identities), so `noises` slots are held at once and the first Mix needs one more (`noises + 1` slots).
    static func fan(_ noises: Int) -> VisualGraph {
        var build = GraphBuild()
        let sources = (0..<noises).map { k in build.add(.noise, ["scale": Double(2 + k)]) }
        var last = sources[0]
        for source in sources.dropFirst() {
            let mix = build.add(.mix)
            build.wire(last, to: mix, "a")
            build.wire(source, to: mix, "b")
            last = mix
        }
        let output = build.add(.output)
        build.wire(last, to: output)
        return build.graph
    }
}

extension LabTest {
    /// Opens Visual Programming Lab with the preview shown, drawing `graph` (the core's graph when nil), on a
    /// square surface of `side` points, and draws one frame.
    static func openPreview(_ session: ExperienceSession, graph: VisualGraph? = nil,
                            side: CGFloat = 96) async throws -> ExperienceShell<LabPresenter> {
        try await open(session, size: CGSize(width: side, height: side), preview: true, graph: graph)
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
