// PlaygroundView.swift — the fluid canvas screen (feature 019 T-A02-112; FR-A02-106; contracts/app-fields.md).
// The screen owns exactly one RenderHost (VisualCore's audited EGL host) and destroys it when it goes away. The app
// creates no EGL context of its own. The host suspends itself in the background; on resume the frame delta is
// clamped (FramePacing, then TimeStepPolicy), so the fields never take an oversized step.
import FluidArtPlaygroundCore
import SwiftUI
import VisualCoreRendering
import VisualCoreUI

@MainActor
@Observable
final class PlaygroundModel {
    let scene: FluidFieldsScene
    private(set) var host: RenderHost?
    private(set) var failure: String?

    init(configuration: FluidConfiguration = FluidConfiguration()) {
        scene = FluidFieldsScene(configuration: configuration)
        do {
            host = try RenderHost(scene: scene)
        } catch {
            failure = "The graphics view could not start: \(error)"
        }
    }

    /// The spoken canvas value.
    var description: String {
        FluidCanvasDescription.text(configuration: scene.configuration, storage: scene.precision ?? .unorm8,
                                    paused: scene.paused || host?.state != .active)
    }

    func close() {
        host?.destroy()
        host = nil
    }
}

struct PlaygroundView: View {
    @State private var model: PlaygroundModel?

    var body: some View {
        ZStack {
            if let model, let host = model.host {
                RenderSurface(host: host, accessibilityLabel: model.description,
                              accessibilityHint: "Fluid canvas. Dye fades over time; touch interaction comes in a later version.")
                    .ignoresSafeArea(edges: .bottom)
                    .accessibilityIdentifier("fap.canvas")
            } else if let failure = model?.failure {
                Text(failure)
                    .multilineTextAlignment(.center)
                    .padding()
                    .accessibilityIdentifier("fap.canvas.failure")
            } else {
                Color.black.ignoresSafeArea()
            }
        }
        .navigationTitle("Playground")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if model == nil { model = PlaygroundModel() }
        }
        .onDisappear {
            model?.close()
            model = nil
        }
    }
}
