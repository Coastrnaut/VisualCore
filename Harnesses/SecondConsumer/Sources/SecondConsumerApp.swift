// SecondConsumerApp.swift — Lumen Garden app shell (feature 009 T-F806; FR-F801, FR-F805). The garden scene runs inside
// a VisualCore EffectScene (bloom glow) on a RenderHost; touches arrive through RenderHost.pointerHandler.
import Observation
import SwiftUI
import UIKit
import VisualCoreEffects
import VisualCoreEffectsGraph
import VisualCoreRendering

@MainActor
@Observable
final class GardenModel {
    let scene = GardenScene()
    let effect: EffectScene
    let host: RenderHost?
    var diagnostics = ""
    var hint = "Tap to plant a seed."
    private var timer: Timer?
    private var observers: [NSObjectProtocol] = []

    static let glow = EffectGraphDescription(passes: [
        EffectPassDescription(id: "glow", type: "bloom", inputs: ["input": "scene"], output: "o",
                              params: ["threshold": [0.6], "intensity": [1.2], "radius": [8]]),
    ], output: "o")

    init() {
        effect = EffectScene(content: scene, graph: Self.glow)
        host = try? RenderHost(scene: effect)
        let defaults = UserDefaults.standard
        let override: Bool? = defaults.object(forKey: "uitestReduceMotion") == nil ? nil : defaults.bool(forKey: "uitestReduceMotion")
        scene.reduceMotion = override ?? UIAccessibility.isReduceMotionEnabled
        host?.pointerHandler = { [scene] e in scene.handle(e) }
        observers.append(NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.scene.didBecomeActive() }
        })
        timer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in MainActor.assumeIsolated { self?.refresh() } }
        refresh()
    }

    func refresh() {
        guard host != nil else { diagnostics = "Rendering unavailable"; return }
        diagnostics = scene.status
        switch scene.lastInteraction {
        case .planted?: hint = "Seed planted. It blooms in a few seconds."
        case .harvested?: hint = "Harvested! Score \(scene.garden.score)."
        case .notReady?: hint = "Still growing — wait for the bloom."
        case .tooClose?: hint = "Too close to another flower."
        case .full?: hint = "The garden is full — harvest some blooms."
        case nil: hint = "Tap to plant a seed. Drag to blow a breeze."
        }
    }

    func reset() { scene.reset(); refresh() }
}

struct GardenCanvas: UIViewRepresentable {
    let model: GardenModel
    func makeUIView(context: Context) -> UIView { model.host?.view ?? UIView() }
    func updateUIView(_ uiView: UIView, context: Context) {
        let s = uiView.traitCollection.displayScale
        if s > 0 { model.scene.scale = Double(s) }
    }
}

@main
struct SecondConsumerApp: App {
    @State private var model = GardenModel()
    var body: some Scene {
        WindowGroup {
            ZStack(alignment: .top) {
                GardenCanvas(model: model)
                    .ignoresSafeArea()
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Night garden. \(model.scene.garden.plantedCount) flowers, score \(model.scene.garden.score).")
                    .accessibilityHint("Tap to plant a seed or harvest a bloom. Drag to blow a breeze.")
                    .accessibilityAddTraits(.allowsDirectInteraction)
                    .accessibilityIdentifier("garden.canvas")
                VStack(alignment: .leading, spacing: 4) {
                    Text("Lumen Garden").font(.headline).accessibilityIdentifier("garden.title")
                    Text(model.hint).font(.subheadline).accessibilityIdentifier("garden.hint")
                    Text(model.diagnostics).font(.caption2.monospacedDigit())
                        .accessibilityIdentifier("garden.diagnostics").accessibilityLabel(model.diagnostics)
                }
                .padding(10)
                .foregroundStyle(.white)
                .background(.black.opacity(0.45), in: RoundedRectangle(cornerRadius: 10))
                .allowsHitTesting(false)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
            }
            .overlay(alignment: .bottom) {
                Button("Reset garden") { model.reset() }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("garden.reset")
                    .padding()
            }
        }
    }
}
