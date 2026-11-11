// SandboxView.swift — family picker, live and dropped counts, play/pause/step/new seed (feature 033 A04-P01 T-A04-106;
// FR-A04-106). Feature 034 (A04-P02): the GPU stage (VisualCore RenderHost + ParticleLayerScene) with the CPU Canvas
// preview as fallback, one placed force with tap/drag and control alternatives, and the effective particle limit
// (contracts/app-ui.md). The app makes no GL or EGL call.
import ParticleUniverseCore
import SwiftUI
import VisualCoreSimulation
import VisualCoreUI

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
        // Dragging the force to the right must not navigate back; the back button and edge swipe still work.
        .contentSwipeBackDisabled()
        .onAppear { if model == nil { model = SceneModel(reduceMotion: reduceMotion) } }
        .onDisappear {
            model?.tearDown()
            model = nil
        }
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
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// Segmented at regular sizes; a menu at accessibility sizes, where four segments would clip their titles.
    @ViewBuilder private var familyPicker: some View {
        let picker = Picker("Emitter family", selection: Binding(get: { model.family }, set: { model.select($0) })) {
            ForEach(EmitterFamily.allCases, id: \.self) { Text($0.title).tag($0) }
        }
        if dynamicTypeSize.isAccessibilitySize {
            picker.pickerStyle(.menu)
        } else {
            picker.pickerStyle(.segmented)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                familyPicker
                    .accessibilityIdentifier("pu.sandbox.family")
                Text(model.family.spokenDescription)
                    .font(.callout)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("pu.sandbox.description")
                // Per-frame state (particles, counts, effective limit) is read only inside small leaf views, so the
                // pickers and buttons are not rebuilt on every frame (a rebuild each frame swallowed segment taps).
                StageView(model: model)
                    .aspectRatio(1, contentMode: .fit)
                    .frame(maxWidth: 640)
                    .frame(maxWidth: .infinity)
                StatusView(model: model)
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 12) { playbackControls }
                    VStack(alignment: .leading, spacing: 12) { playbackControls }
                }
                ForceControls(model: model)
            }
            .padding()
        }
    }

    @ViewBuilder private var playbackControls: some View {
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

/// The square stage: the GPU surface (or the CPU preview) with a touch layer that places and drags the force.
private struct StageView: View {
    let model: SceneModel

    var body: some View {
        GeometryReader { geo in
            ZStack {
                if model.rendererMode == .gpu, let host = model.stage?.host {
                    RenderSurface(host: host, accessibilityLabel: model.canvasDescription)
                } else {
                    ParticlePreview(model: model)
                }
                Color.clear
                    .contentShape(Rectangle())
                    .highPriorityGesture(DragGesture(minimumDistance: 0).onChanged { value in
                        model.touch(at: value.location, in: geo.size)
                    })
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(model.canvasDescription)
        .accessibilityHint("Tap to place the force and drag to move it. The Center and move buttons do the same without a gesture.")
        .accessibilityAddTraits(.isImage)
        .accessibilityIdentifier("pu.sandbox.canvas")
    }
}

/// Live and dropped counts, the effective limit and the renderer.
private struct StatusView: View {
    let model: SceneModel

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(model.liveText)
                .font(.body.monospacedDigit())
                .accessibilityIdentifier("pu.sandbox.live")
            Text(model.droppedText)
                .font(.body.monospacedDigit())
                .accessibilityIdentifier("pu.sandbox.dropped")
            Text(model.effectiveText)
                .font(.body.monospacedDigit())
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("pu.sandbox.effective")
            Text(model.rendererText)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("pu.sandbox.renderer")
        }
    }
}

/// The force kind, its text, Center, four nudges and the strength slider (every gesture has a control).
private struct ForceControls: View {
    let model: SceneModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("Force", selection: Binding(get: { model.selectedKind }, set: { model.selectKind($0) })) {
                Text("None").tag(PlacedForceKind?.none)
                ForEach(PlacedForceKind.allCases, id: \.self) { Text($0.title).tag(PlacedForceKind?.some($0)) }
            }
            .pickerStyle(.menu)
            .accessibilityIdentifier("pu.sandbox.forceKind")
            Text(model.forceText)
                .font(.body.monospacedDigit())
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("pu.sandbox.force")
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) { moveButtons }
                VStack(alignment: .leading, spacing: 8) { moveButtons }
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("Strength \(model.strengthText)")
                    .accessibilityHidden(true)
                Slider(value: Binding(get: { model.strength }, set: { model.setStrength($0) }), in: PlacedForce.strengthRange) {
                    Text("Strength")
                }
                .accessibilityValue(model.strengthText)
                .accessibilityIdentifier("pu.sandbox.strength")
            }
        }
    }

    @ViewBuilder private var moveButtons: some View {
        Button { model.center() } label: {
            Label("Center", systemImage: "scope").frame(minHeight: 44)
        }
        .buttonStyle(.bordered)
        .accessibilityIdentifier("pu.sandbox.center")
        nudge("Move left", "arrow.left", "pu.sandbox.nudgeLeft", -50, 0)
        nudge("Move right", "arrow.right", "pu.sandbox.nudgeRight", 50, 0)
        nudge("Move up", "arrow.up", "pu.sandbox.nudgeUp", 0, 50)
        nudge("Move down", "arrow.down", "pu.sandbox.nudgeDown", 0, -50)
    }

    private func nudge(_ title: String, _ image: String, _ id: String, _ dx: Double, _ dy: Double) -> some View {
        Button { model.nudge(dx, dy) } label: {
            Label(title, systemImage: image).labelStyle(.iconOnly).frame(minWidth: 44, minHeight: 44)
        }
        .buttonStyle(.bordered)
        .disabled(model.placedForce == nil)
        .accessibilityLabel(title)
        .accessibilityIdentifier(id)
    }
}

/// CPU fallback: draws a copy of the particles, the world square −500…500 fitted into the view, y up, and advances
/// the model with each display frame's date while playing.
private struct ParticlePreview: View {
    let model: SceneModel

    var body: some View {
        let particles = model.particles
        TimelineView(.animation(minimumInterval: nil, paused: !model.isPlaying)) { timeline in
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
            .onChange(of: timeline.date) { _, date in model.frame(at: date) }
        }
    }
}
