// ParticleControls — feature 193 (UA-F07) T-U07-027 (FR-U07-002, FR-U07-022; rule E-12). The native controls of
// Particle Universe inside the one app: playback, emitters with their family, size, lifetime and colours, the placed
// force with its kind, position and strength, trails and blend, and a new seed. Every change is an action through the
// port; every control has a VoiceOver label, a hit area of at least 44 by 44 points and text that wraps at the
// largest sizes.
import ParticleUniverseCore
import SwiftUI
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreParameters
import VisualCoreSimulation

/// The controls of Particle Universe.
struct ParticleControls: View {
    let port: ExperienceActionPort
    let mirror: ParticleMirror
    let reduceMotion: Bool

    @State private var motionApplied = false

    var body: some View {
        Group {
            if let core = mirror.core {
                content(core)
            } else {
                ProgressView().accessibilityLabel(Text(verbatim: "Loading"))
            }
        }
        .task {
            // Under Reduce Motion the scene starts paused, as the standalone app does (adapter difference 4). The
            // controls can appear before the experience is active, when the action is refused, so it is retried for
            // at most 5 s.
            guard reduceMotion, !motionApplied else { return }
            for _ in 0..<50 {
                if mirror.core?.playing == false { motionApplied = true; return }
                if mirror.core?.playing == true, port.send("pause").isAccepted { motionApplied = true; return }
                try? await Task.sleep(for: .milliseconds(100))
            }
        }
    }

    @ViewBuilder private func content(_ core: ParticleCore) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            section("Playback") {
                HStack {
                    button(core.playing ? "Pause" : "Play", identifier: "play") { port.send(core.playing ? "pause" : "play") }
                    button("Step", identifier: "step", hint: core.playing ? "Pause first to step" : "Advances one step") {
                        port.send("step")
                    }
                    .disabled(core.playing)
                    button("New seed", identifier: "reseed", hint: "Restarts the scene with the next seed") {
                        port.send("reseed")
                    }
                }
                Text(verbatim: "Live particles: \(core.simulation.liveCount) of \(core.simulation.scene.particleLimit)")
                    .font(.footnote).accessibilityIdentifier(port.identifier("live"))
            }
            section("Emitters") {
                Text(verbatim: "Emitters: \(core.simulation.visibleEmitters.count) of \(ParticleScene.maxEmitters)")
                    .font(.footnote).accessibilityIdentifier(port.identifier("emitters"))
                ForEach(Array(core.simulation.visibleEmitters.indices), id: \.self) { index in
                    choice("Emitter \(index + 1)", selected: core.selectedEmitter == index,
                           identifier: "emitter.\(index)") { port.send("emitter.select", [Double(index)]) }
                }
                HStack {
                    button("Add emitter", identifier: "emitter.add") { port.send("emitter.add") }
                        .disabled(!core.simulation.canAddEmitter)
                    button("Remove emitter", identifier: "emitter.remove") { port.send("emitter.remove") }
                        .disabled(core.simulation.visibleEmitters.count < 2)
                }
            }
            section("Family") {
                ForEach(Array(EmitterFamily.allCases.enumerated()), id: \.offset) { index, family in
                    choice(family.title, selected: core.selectedEntry.family == family, identifier: "family." + family.rawValue,
                           hint: family.spokenDescription) {
                        if core.selectedEntry.family != family { port.send("family", [Double(index)]) }
                    }
                }
            }
            section("Particles") {
                let size = core.selectedEntry.size ?? core.selectedEntry.family.emitter().startSize
                slider("Size", identifier: "size", value: size, range: SceneEmitter.sizeRange,
                       text: "\(Int(size.rounded())) points")
                let range = core.selectedEntry.family.emitter().lifetime
                let lifetime = core.selectedEntry.lifetime ?? (range.lowerBound + range.upperBound) / 2
                slider("Lifetime", identifier: "lifetime", value: lifetime, range: SceneEmitter.lifetimeRange,
                       text: String(format: "%.1f seconds", lifetime))
                ForEach(Array(ParticleCore.gradientIDs.enumerated()), id: \.offset) { index, id in
                    choice(id.flatMap { Palette.builtIn($0)?.name } ?? "Family colors",
                           selected: core.selectedEntry.gradient == id, identifier: "gradient." + (id ?? "family")) {
                        port.send("gradient", [Double(index)])
                    }
                }
            }
            section("Force") {
                choice("None", selected: core.selectedKind == nil, identifier: "force.none") { port.send("force.kind", [0]) }
                ForEach(Array(PlacedForceKind.allCases.enumerated()), id: \.offset) { index, kind in
                    choice(kind.title, selected: core.selectedKind == kind, identifier: "force." + kind.rawValue) {
                        port.send("force.kind", [Double(index + 1)])
                    }
                }
                Text(verbatim: core.placedForce.map { "Force: \($0.kind.title) at \(Int($0.position.x.rounded())), \(Int($0.position.y.rounded()))" }
                     ?? "Force: none — tap the canvas to place it")
                    .font(.footnote).accessibilityIdentifier(port.identifier("force"))
                HStack {
                    button("Center", identifier: "force.center") { port.send("force.center") }
                    button("Left", identifier: "force.left") { port.send("force.nudge", [-50, 0]) }
                        .disabled(core.placedForce == nil)
                    button("Right", identifier: "force.right") { port.send("force.nudge", [50, 0]) }
                        .disabled(core.placedForce == nil)
                }
                slider("Strength", identifier: "strength", value: core.strength, range: PlacedForce.strengthRange,
                       text: String(format: "×%.1f", core.strength))
            }
            section("Look") {
                Toggle(isOn: Binding(get: { core.trailsOn }, set: { port.send("trails", [$0 ? 1 : 0]) })) {
                    Text(verbatim: "Trails")
                }
                .frame(minHeight: 44)
                .accessibilityIdentifier(port.identifier("trails"))
                if core.trailsOn {
                    slider("Trail strength", identifier: "trailStrength", value: core.trailStrength, range: 0...1,
                           text: "\(Int((core.trailStrength * 100).rounded())) percent")
                }
                Toggle(isOn: Binding(get: { core.additive }, set: { port.send("blend", [$0 ? 1 : 0]) })) {
                    Text(verbatim: "Glowing blend")
                }
                .frame(minHeight: 44)
                .accessibilityIdentifier(port.identifier("blend"))
            }
        }
    }

    // MARK: Building blocks

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(verbatim: title).font(.headline).accessibilityAddTraits(.isHeader)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func slider(_ title: String, identifier: String, value: Double, range: ClosedRange<Double>,
                        text: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(verbatim: title).font(.body)
                Spacer()
                Text(verbatim: text).font(.subheadline.monospacedDigit())
            }
            Slider(value: Binding(get: { value }, set: { port.send(identifier, [$0]) }), in: range)
                .frame(minHeight: 44)
                .accessibilityLabel(Text(verbatim: title))
                .accessibilityValue(Text(verbatim: text))
                .accessibilityIdentifier(port.identifier(identifier))
        }
    }

    private func choice(_ title: String, selected: Bool, identifier: String, hint: String? = nil,
                        action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(verbatim: title).font(.body).multilineTextAlignment(.leading)
                Spacer()
                if selected { Image(systemName: "checkmark").accessibilityHidden(true) }
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .contentShape(Rectangle())
        }
        .accessibilityLabel(Text(verbatim: title))
        .accessibilityHint(Text(verbatim: hint ?? ""))
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier(port.identifier(identifier))
    }

    private func button(_ title: String, identifier: String, hint: String? = nil,
                        action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(verbatim: title).font(.body).frame(minWidth: 44, minHeight: 44)
        }
        .buttonStyle(.bordered)
        .accessibilityLabel(Text(verbatim: title))
        .accessibilityHint(Text(verbatim: hint ?? ""))
        .accessibilityIdentifier(port.identifier(identifier))
    }
}
