// SceneHost.swift — owns one RenderHost per open scene, forwards touches, samples diagnostics at 4 Hz and
// simulates context loss (feature 007 T-F604; FR-F602, FR-F607, FR-F608; contract showcase-contract.md).
import Foundation
import Observation
import QuartzCore
import UIKit
import VisualCoreRendering
import VisualCoreScenes

/// Diagnostics shown in the overlay; `label` is read by the smoke test (`showcase.diagnostics`).
struct DiagnosticsSnapshot: Equatable {
    var frames = 0
    var fps = 0.0
    var state = "uninitialized"
    var generation = 0
    var liveResources = 0
    var liveBytes = 0
    var peakBytes = 0
    var warnings = 0
    var leaked = 0
    var error: String?

    var label: String {
        "frames=\(frames) fps=\(String(format: "%.0f", fps)) state=\(state) gen=\(generation) live=\(liveResources) "
            + "bytes=\(liveBytes) peak=\(peakBytes) warnings=\(warnings) leaked=\(leaked) error=\(error ?? "none")"
    }
}

@MainActor
@Observable
final class SceneHost {
    let scene: ShowcaseRenderScene
    private(set) var host: RenderHost?
    private(set) var snapshot = DiagnosticsSnapshot()
    private(set) var status = ""
    private var timer: Timer?
    private var lastSample: (frames: Int, time: CFTimeInterval)?

    /// Set when no render host could be created (edge case "rendering unavailable"); shown by SceneHostView.
    private(set) var unavailableMessage: String?

    /// `makeHost` is injectable so tests can simulate a device without a usable renderer.
    init(scene: ShowcaseRenderScene, makeHost: (ShowcaseRenderScene) throws -> RenderHost = { try RenderHost(scene: $0) }) {
        self.scene = scene
        do {
            let host = try makeHost(scene)
            host.pointerHandler = { [weak scene] e in scene?.handle(e) }
            self.host = host
        } catch {
            unavailableMessage = "Rendering unavailable: \(error)"
            snapshot.error = unavailableMessage
        }
        timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.sample() }
        }
        sample()
    }

    /// Takes a diagnostics sample (also called by the 4 Hz timer).
    func sample(now: CFTimeInterval = CACurrentMediaTime()) {
        status = scene.status
        guard let host else { return }
        let stats = host.resources.stats
        let frames = host.presentedFrameCount
        var fps = snapshot.fps
        if let last = lastSample, now > last.time { fps = Double(frames - last.frames) / (now - last.time) }
        lastSample = (frames, now)
        snapshot = DiagnosticsSnapshot(frames: frames, fps: max(0, fps), state: host.state.rawValue, generation: host.generation,
                                       liveResources: stats.liveTotal, liveBytes: stats.totalBytes, peakBytes: stats.peakBytes,
                                       warnings: stats.warnings.count, leaked: stats.leaked,
                                       error: scene.errorMessage ?? host.lastError.map { "\($0)" })
    }

    /// FR-F607: drops and recreates the GL context; the scene rebuilds its resources.
    func simulateContextLoss() {
        host?.recreateContext()
        sample()
    }

    /// FR-F608: releases the scene's GPU objects and the context.
    func close() {
        timer?.invalidate()
        timer = nil
        host?.pointerHandler = nil
        host?.destroy()
        sample()
    }
}
