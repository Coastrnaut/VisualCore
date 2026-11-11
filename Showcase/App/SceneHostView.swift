// SceneHostView.swift — hosts one scene's render view with the accessible canvas, status, diagnostics overlay and
// error view (feature 007 T-F604; FR-F602, FR-F607–FR-F609).
import SwiftUI
import UIKit
import VisualCoreRendering

struct RenderCanvas: UIViewRepresentable {
    let sceneHost: SceneHost
    func makeUIView(context: Context) -> UIView {
        let container = UIView()
        container.backgroundColor = .black
        if let view = sceneHost.host?.view {
            view.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(view)
            NSLayoutConstraint.activate([
                view.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                view.trailingAnchor.constraint(equalTo: container.trailingAnchor),
                view.topAnchor.constraint(equalTo: container.topAnchor),
                view.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            ])
        }
        return container
    }
    func updateUIView(_ uiView: UIView, context: Context) {
        let s = uiView.traitCollection.displayScale
        if s > 0 { sceneHost.scene.scale = Double(s) }
    }
}

struct SceneHostView: View {
    let descriptor: SceneDescriptor
    let settings: ShowcaseSettings
    @State private var sceneHost: SceneHost?
    @State private var showDiagnostics = true

    var body: some View {
        ZStack(alignment: .top) {
            if let sceneHost {
                RenderCanvas(sceneHost: sceneHost)
                    .ignoresSafeArea(edges: .bottom)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(descriptor.accessibilityDescription)
                    .accessibilityHint(descriptor.interactionHint)
                    .accessibilityAddTraits(.allowsDirectInteraction)
                    .accessibilityIdentifier("showcase.canvas")
                VStack(alignment: .leading, spacing: 6) {
                    Text(sceneHost.status.isEmpty ? " " : sceneHost.status)
                        .font(.footnote.monospacedDigit())
                        .accessibilityIdentifier("showcase.status")
                        .accessibilityLabel(sceneHost.status)
                    if sceneHost.scene.effectsEnabled != nil {
                        Toggle("Post-processing", isOn: Binding(
                            get: { sceneHost.scene.effectsEnabled ?? false },
                            set: { sceneHost.scene.effectsEnabled = $0; sceneHost.sample() }))
                            .accessibilityIdentifier("showcase.effectToggle")
                            .fixedSize()
                    }
                    if showDiagnostics {
                        DiagnosticsOverlay(snapshot: sceneHost.snapshot) { sceneHost.simulateContextLoss() }
                    }
                    if let message = sceneHost.snapshot.error, sceneHost.scene.errorMessage != nil {
                        Text(message).font(.callout).foregroundStyle(.red).accessibilityIdentifier("showcase.error")
                        Button("Retry") { sceneHost.scene.retry() }.accessibilityIdentifier("showcase.retry")
                    }
                }
                .padding(8)
                .foregroundStyle(.white)
                .background(.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 8))
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ProgressView()
            }
        }
        .navigationTitle(descriptor.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            Button(showDiagnostics ? "Hide diagnostics" : "Show diagnostics") { showDiagnostics.toggle() }
                .accessibilityIdentifier("showcase.diagnosticsToggle")
        }
        .onAppear { if sceneHost == nil { sceneHost = SceneHost(scene: descriptor.make(settings)) } }
        .onDisappear { sceneHost?.close(); sceneHost = nil }
    }
}
