// AutomationView.swift — hosts any RenderScene full screen and runs the requested AutomationRunner mode once laid out
// (feature 017 T-A01-603; FR-A01-608; constitution II: shared by every app instead of a per-app canvas). Compiled only
// under DEBUG || VISUALCORE_AUTOMATION; the only trigger is the launch environment (`VISUALCORE_AUTORUN`).
#if DEBUG || VISUALCORE_AUTOMATION
import Foundation
import SwiftUI
import UIKit
import VisualCoreRendering

/// A full-screen RenderHost that runs automation `mode` on the scene `makeScene` returns, after the first layout pass.
/// If no renderer can be created it still writes a `renderer-unavailable` report, so a campaign never waits on a
/// silent app.
public struct AutomationView: UIViewRepresentable {
    let mode: String
    let bundleID: String
    let makeScene: @MainActor () -> RenderScene
    let configure: (@MainActor (RenderScene, CGFloat) -> Void)?
    let outputDirectory: URL?
    let terminate: (Int32) -> Void

    /// `configure` receives the scene and the view's display scale just before the run (for point-sized content).
    /// `outputDirectory` and `terminate` are passed to `AutomationRunner` (defaults: Documents, and exiting the app).
    public init(mode: String, bundleID: String, makeScene: @escaping @MainActor () -> RenderScene,
                configure: (@MainActor (RenderScene, CGFloat) -> Void)? = nil,
                outputDirectory: URL? = nil, terminate: @escaping (Int32) -> Void = { exit($0) }) {
        self.mode = mode
        self.bundleID = bundleID
        self.makeScene = makeScene
        self.configure = configure
        self.outputDirectory = outputDirectory
        self.terminate = terminate
    }

    /// Holds the host, scene and runner for the lifetime of the view.
    public final class Coordinator {
        var host: RenderHost?
        var scene: RenderScene?
        var runner: AutomationRunner?
        var started = false
    }

    /// A fresh coordinator.
    public func makeCoordinator() -> Coordinator { Coordinator() }

    /// Creates the host for the scene (or writes the renderer-unavailable report).
    public func makeUIView(context: Context) -> UIView {
        let container = UIView()
        container.backgroundColor = .black
        container.accessibilityLabel = "Automation run: \(mode)"
        let scene = makeScene()
        do {
            let host = try RenderHost(scene: scene)
            host.view.frame = container.bounds
            host.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            container.addSubview(host.view)
            context.coordinator.host = host
            context.coordinator.scene = scene
            context.coordinator.runner = AutomationRunner(host: host, bundleID: bundleID, outputDirectory: outputDirectory,
                                                          terminate: terminate)
        } catch {
            if let fallback = try? RenderHost(scene: ClearColorScene(red: 0, green: 0, blue: 0)) {
                AutomationRunner(host: fallback, bundleID: bundleID, outputDirectory: outputDirectory, terminate: terminate)
                    .run(mode: "renderer-unavailable")
            } else {
                exit(2)
            }
        }
        return container
    }

    /// Starts the run once, after layout, so the surface has its real size.
    public func updateUIView(_ uiView: UIView, context: Context) {
        let coordinator = context.coordinator
        guard !coordinator.started, let runner = coordinator.runner else { return }
        coordinator.started = true
        if let scene = coordinator.scene { configure?(scene, uiView.traitCollection.displayScale) }
        DispatchQueue.main.async {
            uiView.layoutIfNeeded()
            runner.run(mode: mode, frames: AutomationRunner.requestedFrames())
        }
    }
}
#endif
