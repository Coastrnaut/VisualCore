// SceneScreen.swift — one family rendering live through the shared VisualCore host (feature 012 T-A01-110; FR-A01-102,
// FR-A01-110, FR-A01-112; controls and clock: feature 013). The screen owns exactly one RenderHost and destroys it when
// it goes away.
import GenerativeArtStudioCore
import Observation
import SwiftUI
import VisualCoreParameters
import VisualCoreRendering
import VisualCoreSimulation
import VisualCoreUI

/// Owns the render host, the clocked scene and the composition being edited for one opened family.
@MainActor
@Observable
final class SceneModel {
    let family: SceneFamily
    /// The composition being edited; every change is applied to the live scene by the next frame.
    var editor: CompositionEditor { didSet { ArtSceneFactory.apply(editor.composition, to: scene) } }
    /// The composition currently shown.
    var document: ArtDocument { editor.composition }
    let scene: ArtScene
    let clocked: ClockedArtScene
    private(set) var host: RenderHost?
    private(set) var errorMessage: String?
    /// Mirrors the clock for the UI (refreshed by the controls and the 0.25 s timer).
    private(set) var time: Double = 0
    private(set) var isPlaying = true
    private var timer: Timer?

    /// Playback-rate factor under Reduce Motion (edge case; applied through `SceneClock.reducedMotion`).
    static let reducedMotionTimeScale = SceneClock.reducedMotionFactor

    init(family: SceneFamily, reduceMotion: Bool, bundle: ShaderBundle = ArtSceneFactory.shaders,
         editor initial: CompositionEditor? = nil,
         makeHost: (RenderScene) throws -> RenderHost = { try RenderHost(scene: $0) }) {
        self.family = family
        let start = initial ?? CompositionEditor(family: family)
        editor = start
        scene = ArtSceneFactory.makeScene(for: start.composition, bundle: bundle)
        var clock = SceneClock()
        clock.reducedMotion = reduceMotion
        clocked = ClockedArtScene(inner: scene, clock: clock)
        scene.timeScale = reduceMotion ? Self.reducedMotionTimeScale : 1
        do { host = try makeHost(clocked) } catch { errorMessage = "Rendering unavailable: \(error)" }
        timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
    }

    /// Pulls the scene error and clock state into observable properties.
    func refresh() {
        if let message = scene.errorMessage, message != errorMessage { errorMessage = message }
        if time != clocked.clock.time { time = clocked.clock.time }
        if isPlaying != clocked.clock.isPlaying { isPlaying = clocked.clock.isPlaying }
    }

    func refreshError() { refresh() }

    func togglePlay() { clocked.clock.toggle(); refresh() }
    func scrub(to t: Double) { clocked.clock.scrub(to: t); refresh() }

    func close() {
        timer?.invalidate()
        timer = nil
        host?.destroy()
    }
}

struct SceneScreen: View {
    let family: SceneFamily
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.displayScale) private var displayScale
    @State private var model: SceneModel?

    var body: some View {
        ZStack(alignment: .bottom) {
            if let model, let host = model.host {
                RenderSurface(host: host, accessibilityLabel: family.accessibilityDescription,
                              accessibilityHint: "\(family.title), preset \(family.defaultPreset.title).")
                    .ignoresSafeArea(edges: .bottom)
                    .accessibilityIdentifier("gas.scene.canvas")
            } else {
                Color.black.ignoresSafeArea()
            }
            if let message = model?.errorMessage {
                Text(message)
                    .font(.footnote.monospaced())
                    .padding(12)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
                    .padding()
                    .accessibilityLabel("Shader error: \(message)")
                    .accessibilityIdentifier("gas.scene.error")
            }
        }
        .navigationTitle(family.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(family.title).font(.headline).accessibilityIdentifier("gas.scene.title")
            }
        }
        .onAppear {
            if model == nil {
                let m = SceneModel(family: family, reduceMotion: reduceMotion)
                m.scene.displayScale = Double(displayScale)
                model = m
            }
        }
        .onDisappear {
            model?.close()
            model = nil
        }
    }
}
