// ProjectMReferenceApp.swift — harness UI (feature 008 T-F710; FR-F701): the unmodified ProjectM engine on the
// VisualCore host, inside an EffectScene so Reduce Flashing (VisualCore limiter) can be applied; a picker of the
// upstream test presets and live diagnostics. Tester tool only; no preset library, purchases or audio capture.
import ProjectMBridge
import SwiftUI
import UIKit
import VisualCoreEffects
import VisualCoreEffectsGraph
import VisualCoreRendering

@MainActor
@Observable
final class ReferenceModel {
    let scene: ProjectMScene
    let effect: EffectScene
    let host: RenderHost?
    var diagnostics = ""
    var reduceFlashing = false { didSet { effect.reduceFlashing = reduceFlashing } }
    private var timer: Timer?

    static var presetsDirectory: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().appendingPathComponent("External/projectm-ios/Vendor/projectM/presets/tests")
    }
    static var presets: [String] {
        ((try? FileManager.default.contentsOfDirectory(atPath: presetsDirectory.path)) ?? []).filter { $0.hasSuffix(".milk") }.sorted()
    }

    init() {
        let first = Self.presets.first(where: { $0 == "100-square.milk" }) ?? Self.presets.first ?? "100-square.milk"
        scene = ProjectMScene(presetPath: Self.presetsDirectory.appendingPathComponent(first).path)
        effect = EffectScene(content: scene, graph: EffectGraphDescription(passes: [
            EffectPassDescription(id: "present", type: "copy", inputs: ["input": "scene"], output: "o")], output: "o"))
        host = try? RenderHost(scene: effect)
        timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
        refresh()
    }

    var currentPreset: String { URL(fileURLWithPath: scene.presetPath).lastPathComponent }

    func select(_ name: String) { scene.requestPreset(path: Self.presetsDirectory.appendingPathComponent(name).path) }

    func refresh() {
        guard let host else { diagnostics = "Rendering unavailable"; return }
        let s = host.resources.stats
        let error = scene.lastError.map { "\($0.localizedDescription)" } ?? "none"
        diagnostics = "engine gen=\(scene.engineGeneration.map(String.init) ?? "-") created=\(scene.enginesCreated) frames=\(scene.frames) "
            + "preset=\(currentPreset) state=\(host.state.rawValue) live=\(s.liveTotal) leaked=\(s.leaked) error=\(error)"
    }
}

struct EngineView: UIViewRepresentable {
    let model: ReferenceModel
    func makeUIView(context: Context) -> UIView { model.host?.view ?? UIView() }
    func updateUIView(_ uiView: UIView, context: Context) {}
}

@main
struct ProjectMReferenceApp: App {
    @State private var model = ReferenceModel()
    var body: some Scene {
        WindowGroup {
            ZStack(alignment: .top) {
                EngineView(model: model).ignoresSafeArea()
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("ProjectM visualizer, preset \(model.currentPreset)")
                    .accessibilityIdentifier("reference.canvas")
                VStack(alignment: .leading, spacing: 6) {
                    Text("ProjectM on VisualCore").font(.headline).accessibilityIdentifier("reference.title")
                    Text(model.diagnostics).font(.caption2.monospacedDigit()).accessibilityIdentifier("reference.diagnostics")
                    HStack {
                        Menu("Preset: \(model.currentPreset)") {
                            ForEach(ReferenceModel.presets, id: \.self) { name in Button(name) { model.select(name) } }
                        }
                        .accessibilityIdentifier("reference.presetPicker")
                        Toggle("Reduce Flashing", isOn: Binding(get: { model.reduceFlashing }, set: { model.reduceFlashing = $0 }))
                            .fixedSize()
                            .accessibilityIdentifier("reference.reduceFlashing")
                    }
                }
                .padding(8)
                .foregroundStyle(.white)
                .background(.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 8))
                .padding()
            }
        }
    }
}
