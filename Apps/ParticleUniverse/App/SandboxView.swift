// SandboxView.swift — family picker, live and dropped counts, play/pause/step/new seed and a CPU preview
// (feature 033 A04-P01 T-A04-106; FR-A04-106; contract "App UI contract"). The preview is a SwiftUI Canvas: no GPU or
// EGL in this phase (the GPU loop is Phase 02).
import ParticleUniverseCore
import SwiftUI
import VisualCoreSimulation

struct SandboxView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var model: SceneModel?

    var body: some View {
        Group {
            if let model { SandboxContent(model: model) } else { Color.clear }
        }
        .navigationTitle("Sandbox")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { if model == nil { model = SceneModel(reduceMotion: reduceMotion) } }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .background: model?.enterBackground()
            case .active: model?.enterForeground()
            default: break
            }
        }
    }
}

private struct SandboxContent: View {
    let model: SceneModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Picker("Emitter family", selection: Binding(get: { model.family }, set: { model.select($0) })) {
                    ForEach(EmitterFamily.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("pu.sandbox.family")
                Text(model.family.spokenDescription)
                    .font(.callout)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("pu.sandbox.description")
                ParticlePreview(particles: model.particles, playing: model.isPlaying) { model.frame(at: $0) }
                    .aspectRatio(1, contentMode: .fit)
                    .frame(maxWidth: 640)
                    .frame(maxWidth: .infinity)
                    .accessibilityElement()
                    .accessibilityLabel(model.canvasDescription)
                    .accessibilityAddTraits(.isImage)
                    .accessibilityIdentifier("pu.sandbox.canvas")
                Text(model.liveText)
                    .font(.body.monospacedDigit())
                    .accessibilityIdentifier("pu.sandbox.live")
                Text(model.droppedText)
                    .font(.body.monospacedDigit())
                    .accessibilityIdentifier("pu.sandbox.dropped")
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 12) { controls }
                    VStack(alignment: .leading, spacing: 12) { controls }
                }
            }
            .padding()
        }
    }

    @ViewBuilder private var controls: some View {
        Button { model.setPlaying(!model.isPlaying) } label: {
            Label(model.isPlaying ? "Pause" : "Play", systemImage: model.isPlaying ? "pause.fill" : "play.fill")
                .frame(minHeight: 44)
        }
        .buttonStyle(.borderedProminent)
        .accessibilityIdentifier("pu.sandbox.play")
        Button { model.step() } label: {
            Label("Step", systemImage: "forward.frame").frame(minHeight: 44)
        }
        .buttonStyle(.bordered)
        .disabled(model.isPlaying)
        .accessibilityIdentifier("pu.sandbox.step")
        Button { model.reseed() } label: {
            Label("New seed", systemImage: "dice").frame(minHeight: 44)
        }
        .buttonStyle(.bordered)
        .accessibilityIdentifier("pu.sandbox.reseed")
    }
}

/// Draws a copy of the particles: the world square −500…500 fitted into the view, y up. Calls `onFrame` with each
/// display frame's date while playing.
private struct ParticlePreview: View {
    let particles: [ParticleInstance]
    let playing: Bool
    let onFrame: (Date) -> Void

    var body: some View {
        TimelineView(.animation(minimumInterval: nil, paused: !playing)) { timeline in
            Canvas { context, size in
                context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.black))
                let scale = min(size.width, size.height) / 1_000
                let cx = size.width / 2, cy = size.height / 2
                for p in particles {
                    let d = max(p.size * scale, 1)
                    let x = cx + p.position.x * scale, y = cy - p.position.y * scale
                    let color = Color(.sRGB, red: p.color.x, green: p.color.y, blue: p.color.z, opacity: p.color.w)
                    context.fill(Path(ellipseIn: CGRect(x: x - d / 2, y: y - d / 2, width: d, height: d)), with: .color(color))
                }
            }
            .onChange(of: timeline.date) { _, date in onFrame(date) }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
