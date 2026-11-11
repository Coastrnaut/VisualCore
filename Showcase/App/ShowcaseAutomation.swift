// ShowcaseAutomation.swift — runs a VisualCoreAutomation mode on the gradient scene when launched with
// VISUALCORE_AUTORUN=<mode>, then exits (feature 010 T-F904; FR-F914). Compiled only under DEBUG || VISUALCORE_AUTOMATION:
// the shipping Release build has no automation code (checked by scripts/check_release_symbols.py). The only trigger
// is the launch environment set by Xcode/simctl/devicectl; there is no URL scheme or remote input.
#if DEBUG || VISUALCORE_AUTOMATION
import SwiftUI
import UIKit
import VisualCoreAutomation
import VisualCoreRendering

enum ShowcaseAutomation {
    /// The requested mode, if this launch is an automation run.
    static let mode = AutomationRunner.requestedMode()
}

/// Full-screen gradient scene that runs the requested mode once it is laid out in a window.
struct AutomationRootView: View {
    let mode: String
    let settings: ShowcaseSettings
    var body: some View {
        AutomationCanvas(mode: mode, settings: settings)
            .ignoresSafeArea()
            .accessibilityLabel("Automation run: \(mode)")
            .accessibilityIdentifier("showcase.automation")
    }
}

private struct AutomationCanvas: UIViewRepresentable {
    let mode: String
    let settings: ShowcaseSettings

    final class Coordinator {
        var host: RenderHost?
        var scene: GradientTextureScene?
        var runner: AutomationRunner?
        var started = false
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> UIView {
        let container = UIView()
        container.backgroundColor = .black
        let scene = GradientTextureScene(settings: settings)
        do {
            let host = try RenderHost(scene: scene)
            host.view.frame = container.bounds
            host.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            container.addSubview(host.view)
            context.coordinator.host = host
            context.coordinator.scene = scene
            context.coordinator.runner = AutomationRunner(host: host, bundleID: Bundle.main.bundleIdentifier ?? "dev.visualcore.Showcase")
        } catch {
            // No renderer: still write an error report so the campaign never waits on a silent app.
            let fallback = try? RenderHost(scene: ClearColorScene(red: 0, green: 0, blue: 0))
            if let fallback {
                AutomationRunner(host: fallback, bundleID: Bundle.main.bundleIdentifier ?? "dev.visualcore.Showcase")
                    .run(mode: "renderer-unavailable")
            } else {
                exit(2)
            }
        }
        return container
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        let coordinator = context.coordinator
        guard !coordinator.started, let runner = coordinator.runner else { return }
        coordinator.started = true
        let scale = uiView.traitCollection.displayScale
        if scale > 0 { coordinator.scene?.scale = Double(scale) }
        // Run after the first layout pass so the surface has its real size.
        DispatchQueue.main.async {
            uiView.layoutIfNeeded()
            runner.run(mode: mode, frames: AutomationRunner.requestedFrames())
        }
    }
}
#endif
