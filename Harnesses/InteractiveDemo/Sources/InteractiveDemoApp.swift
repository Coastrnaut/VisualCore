// InteractiveDemoApp.swift — SwiftUI shell for the InteractiveDemo harness (feature 006 T-F519; FR-F510).
// Diagnostics are exposed to UI tests via accessibility identifiers; controls have VoiceOver labels and
// use Dynamic Type text styles. Launch argument `-uitestReduceMotion YES|NO` overrides Reduce Motion.
import SwiftUI
import UIKit
import VisualCoreRendering
import VisualCoreScenes

@main
struct InteractiveDemoApp: App {
    @State private var model = DemoModel()
    var body: some Scene {
        WindowGroup { ContentView(model: model) }
    }
}

/// Owns the render host and the demo scene for the app's lifetime.
@MainActor
final class DemoController {
    let scene: DemoScene
    let host: RenderHost?
    private var observers: [NSObjectProtocol] = []

    init(model: DemoModel) {
        scene = DemoScene(model: model)
        do {
            let host = try RenderHost(scene: scene)
            self.host = host
            host.pointerHandler = { [scene] e in scene.handle(e) }
        } catch {
            host = nil
            model.errorText = "Rendering unavailable: \(error)"
        }
        applyReduceMotion()
        let center = NotificationCenter.default
        observers.append(center.addObserver(forName: UIAccessibility.reduceMotionStatusDidChangeNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.applyReduceMotion() }
        })
        observers.append(center.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.scene.didBecomeActive() }
        })
    }

    private func applyReduceMotion() {
        let override = UserDefaults.standard.object(forKey: "uitestReduceMotion") as? Bool
        scene.reduceMotion = override ?? UIAccessibility.isReduceMotionEnabled
    }
}

struct RenderSurface: UIViewRepresentable {
    let controller: DemoController
    func makeUIView(context: Context) -> UIView {
        let container = UIView()
        container.backgroundColor = .black
        if let view = controller.host?.view {
            view.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(view)
            NSLayoutConstraint.activate([
                view.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                view.trailingAnchor.constraint(equalTo: container.trailingAnchor),
                view.topAnchor.constraint(equalTo: container.topAnchor),
                view.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            ])
            controller.scene.scale = Double(view.traitCollection.displayScale > 0 ? view.traitCollection.displayScale : 2)
        }
        return container
    }
    func updateUIView(_ uiView: UIView, context: Context) {
        let s = uiView.traitCollection.displayScale
        if s > 0 { controller.scene.scale = Double(s) }
    }
}

struct ContentView: View {
    let model: DemoModel
    @State private var controller: DemoController

    init(model: DemoModel) {
        self.model = model
        _controller = State(initialValue: DemoController(model: model))
    }

    var body: some View {
        ZStack(alignment: .top) {
            RenderSurface(controller: controller)
                .ignoresSafeArea()
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Interactive canvas")
                .accessibilityHint("Drag to spawn particles. Pinch to zoom.")
                .accessibilityAddTraits(.allowsDirectInteraction)
                .accessibilityIdentifier("demo.canvas")
            VStack(alignment: .leading, spacing: 4) {
                Text(model.diagnostics)
                    .font(.footnote.monospacedDigit())
                    .accessibilityIdentifier("demo.diagnostics")
                    .accessibilityLabel(model.diagnostics)
                Text(model.stepsLabel)
                    .font(.caption2.monospacedDigit())
                    .accessibilityIdentifier("demo.steps")
                    .accessibilityLabel(model.stepsLabel)
                if let error = model.errorText { Text(error).font(.callout).foregroundStyle(.red) }
                if model.reduceMotion { Text("Reduce Motion: animations shortened").font(.caption) }
            }
            .padding(8)
            .background(.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 8))
            .foregroundStyle(.white)
            .allowsHitTesting(false)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
        .overlay(alignment: .bottom) {
            HStack(spacing: 16) {
                Button(model.running ? "Pause" : "Resume") { controller.scene.setRunning(!model.running) }
                    .accessibilityLabel(model.running ? "Pause simulation" : "Resume simulation")
                    .accessibilityIdentifier("demo.toggle")
                Button("Reset") { controller.scene.reset() }
                    .accessibilityLabel("Reset particles and camera")
                    .accessibilityIdentifier("demo.reset")
            }
            .font(.body)
            .buttonStyle(.borderedProminent)
            .padding()
        }
    }
}
