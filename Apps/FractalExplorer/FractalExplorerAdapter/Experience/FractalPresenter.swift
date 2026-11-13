// FractalPresenter — feature 193 (UA-F07) T-U07-024 (FR-U07-001 to FR-U07-004, FR-U07-010, FR-U07-019; research R1,
// R2). Draws the core of Fractal Explorer with the app's own `FractalScene` (its shader and uniform binding), with the
// viewport derived from the drawable's size and the palette time taken from the core, and turns canvas touches into
// `pan` and `pinch` actions in units of the view's shorter side, as the standalone `ExplorerModel.handle` moves the
// viewport.
//
// Differences from the standalone app's `ExplorerModel` (FR-U07-003):
//   1. The shader time is the core's palette time; the scene's own clock is not advanced.
//   2. There is no CPU fallback picture: a shader failure fails the session's setup, which shows its failure view.
//   3. Capture renders through the session's still renderer and offers the PNG to the share interface; no file is
//      written.
import FractalExplorerAdapterCore
import FractalExplorerCore
import Foundation
import SwiftUI
import UIKit
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreRendering
import VisualCoreScenes

/// The latest core the presenter saw and the canvas size in points, for the controls.
@MainActor
@Observable
final class FractalMirror {
    /// The current state; nil before the first description.
    var core: FractalCore?
    /// The canvas size in points at the last draw.
    var canvasSize = Vec2(390, 390)
}

/// The presenter of Fractal Explorer.
@MainActor
final class FractalPresenter: ExperiencePresenter {
    typealias Core = FractalCore

    let experienceID: ExperienceID
    let mirror = FractalMirror()
    let library: FractalBookmarks
    let reduceMotion: Bool
    private let scene: FractalScene
    private let pointsPerPixel: Double

    // Touch translation (presentation state).
    private var pointers = PointerTracker()
    private var pinch = PinchRecognizer()
    private var lastPoint: [Int: Vec2] = [:]

    init(experienceID: ExperienceID, storage: ExperienceStorage, reduceMotion: Bool, displayScale: Double) {
        self.experienceID = experienceID
        self.reduceMotion = reduceMotion
        library = FractalBookmarks(storage: storage)
        pointsPerPixel = 1 / max(displayScale, 1)
        scene = FractalScene(snapshot: .init(state: FractalState(size: Vec2(390, 390))))
    }

    func setup(_ context: RenderContext) throws {
        try scene.setup(context)
        if let message = scene.errorMessage { throw FractalShaderError(message: message) }
    }

    func resize(_ context: RenderContext) {
        scene.resize(context)
    }

    func draw(_ core: FractalCore, tier: Int, context: RenderContext, frame: FrameInfo) throws {
        let size = Vec2(Double(max(1, context.pixelWidth)) * pointsPerPixel,
                        Double(max(1, context.pixelHeight)) * pointsPerPixel)
        mirror.canvasSize = size
        scene.snapshot = .init(state: core.state(size: size), paletteID: core.paletteID, animate: core.animate)
        scene.bind(pixelWidth: context.pixelWidth)
        scene.inner.fixedTime = core.paletteTime
        try scene.inner.render(context, frame: frame)
    }

    func teardown(_ context: RenderContext) {
        scene.teardown(context)
    }

    func describe(_ core: FractalCore) -> String {
        mirror.core = core
        return core.state(size: mirror.canvasSize).spokenDescription
    }

    /// The view's centre while the region around it lies inside the set: the shader draws points that do not escape
    /// in black, and the CPU's `FractalMath` decides the same points. The region is a 9 × 9 grid over 4 % of the span.
    func probes(_ core: FractalCore) -> [FrameProbe] {
        let state = core.state(size: Vec2(1, 1))
        let half = core.framing.span * 0.02
        for i in -4...4 {
            for j in -4...4 {
                let point = Vec2(core.framing.center.x + Double(i) * half / 4, core.framing.center.y + Double(j) * half / 4)
                if !state.escape(at: point).interior { return [] }
            }
        }
        return [FrameProbe(name: "centre-inside", x: 0.5, y: 0.5, expected: "dark")].compactMap { $0 }
    }

    func makeControls(_ port: ExperienceActionPort) -> AnyView {
        AnyView(FractalControls(port: port, mirror: mirror, library: library, reduceMotion: reduceMotion))
    }

    /// Canvas touches, as `ExplorerModel.handle` moves the viewport: one finger pans by its movement; two fingers pan
    /// by their midpoint's movement and zoom by their distance ratio about the new midpoint. Distances are sent in
    /// units of the view's shorter side, anchors relative to the view's centre.
    func pointer(_ event: PointerEvent, viewSize: Vec2, port: ExperienceActionPort) {
        let side = min(viewSize.x, viewSize.y)
        guard side > 0 else { return }
        let previous = lastPoint
        pointers.handle(event)
        pinch.handle(event, tracker: pointers)
        if event.phase == .moved, pointers.count >= 2 {
            let ids = Array(pointers.order.prefix(2))
            if let a0 = previous[ids[0]], let b0 = previous[ids[1]],
               let a1 = pointers.active[ids[0]], let b1 = pointers.active[ids[1]] {
                let mid0 = (a0 + b0) / 2, mid1 = (a1 + b1) / 2
                let move = (mid1 - mid0) / side
                port.send("pan", [Self.clamp(move.x, 100), Self.clamp(move.y, 100)])
                let d0 = a0.distance(to: b0), d1 = a1.distance(to: b1)
                if d0 > 0, d1 > 0 {
                    let anchor = (mid1 - viewSize / 2) / side
                    port.send("pinch", [min(max(d1 / d0, 0.001), 1_000), Self.clamp(anchor.x, 100),
                                        Self.clamp(anchor.y, 100)])
                }
            }
        } else if event.phase == .moved, pointers.count == 1, let last = previous[event.id] {
            let move = (event.location - last) / side
            port.send("pan", [Self.clamp(move.x, 100), Self.clamp(move.y, 100)])
        }
        switch event.phase {
        case .began, .moved: lastPoint[event.id] = event.location
        case .ended, .cancelled: lastPoint[event.id] = nil
        }
        if pointers.count == 0 { pinch.reset(); lastPoint.removeAll() }
    }

    private static func clamp(_ value: Double, _ limit: Double) -> Double {
        value.isFinite ? min(max(value, -limit), limit) : 0
    }
}

/// The fractal shader did not compile or link on this device.
struct FractalShaderError: Error, CustomStringConvertible {
    let message: String
    var description: String { "The fractal shader failed: \(message)" }
}
