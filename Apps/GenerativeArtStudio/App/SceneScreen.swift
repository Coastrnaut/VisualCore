// SceneScreen.swift — one family rendering live through the shared VisualCore host (feature 012 T-A01-110; FR-A01-102,
// FR-A01-110, FR-A01-112). The screen owns exactly one RenderHost and destroys it when it goes away.
import GenerativeArtStudioCore
import Observation
import SwiftUI
import VisualCoreRendering
import VisualCoreUI

/// Owns the render host and scene for one opened family.
@MainActor
@Observable
final class SceneModel {
    let family: SceneFamily
    let document: ArtDocument
    let scene: ArtScene
    private(set) var host: RenderHost?
    private(set) var errorMessage: String?
    private var timer: Timer?

    /// Time scale under Reduce Motion (edge case: slower animation; full behavior in Phase 05).
    static let reducedMotionTimeScale = 0.5

    init(family: SceneFamily, reduceMotion: Bool, bundle: ShaderBundle = ArtSceneFactory.shaders,
         makeHost: (RenderScene) throws -> RenderHost = { try RenderHost(scene: $0) }) {
        self.family = family
        document = (try? ArtDocument.from(family.defaultPreset, family: family.id).validated().document)
            ?? ArtDocument(family: family.id, seed: 0, paletteID: family.defaultPaletteID, parameters: [:])
        scene = ArtSceneFactory.makeScene(for: document, bundle: bundle)
        scene.timeScale = reduceMotion ? Self.reducedMotionTimeScale : 1
        do { host = try makeHost(scene) } catch { errorMessage = "Rendering unavailable: \(error)" }
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refreshError() }
        }
    }

    func refreshError() {
        if let message = scene.errorMessage, message != errorMessage { errorMessage = message }
    }

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
