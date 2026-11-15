// PlaygroundControls — feature 082 (A11-P01) T-A11-104 (FR-A11-121, FR-A11-113; clarification 5). The native controls
// of Physics Playground in one section:
//   Drop circle and Drop box (`drop-circle`, `drop-box` → `world.drop [0]` / `[1]`; disabled at 48 bodies);
//   Pause / Run (`pause` → `world.pause [1/0]`);
//   Step (`step` → `world.step`; enabled only while paused, one tick of 1/120 s);
//   the time-scale picker (`time-scale` → `world.timeScale [0…3]`: ¼×, ½×, 1×, 2×);
//   Reset (`reset` → `world.reset`: the starting scene, normal speed, running);
//   the status line (`status`: bodies, running or paused, time scale) and the note (`note`) that the results are
//   educational approximations.
// Every control has an accessible label and value (or hint) and the identifier
// `experience.a11.physics-playground.<name>` from the port; hit areas are at least 44 points high and text wraps.
import SwiftUI
import PhysicsPlaygroundCore
import VisualCoreExperienceHost

/// The controls of Physics Playground.
struct PlaygroundControls: View {
    let port: ExperienceActionPort
    let mirror: PlaygroundMirror

    /// The note shown under the controls.
    static let note = "The simulation is an educational approximation, not a precise physical measurement."

    /// `status` with a capital first letter ("Loading" when empty).
    static func sentence(_ status: String) -> String {
        guard let first = status.first else { return "Loading" }
        return first.uppercased() + String(status.dropFirst())
    }

    /// Whether another body can be dropped.
    static func canDrop(bodyCount: Int) -> Bool { bodyCount < PhysicsWorld.maxBodies }

    var body: some View {
        Group {
            if mirror.ready {
                content
            } else {
                ProgressView().accessibilityLabel(Text(verbatim: "Loading"))
            }
        }
    }

    @ViewBuilder private var content: some View {
        let canDrop = Self.canDrop(bodyCount: mirror.bodyCount)
        let bodies = PlaygroundPresenter.bodyWords(mirror.bodyCount)
        VStack(alignment: .leading, spacing: 8) {
            Text(verbatim: "Physics Playground").font(.headline).accessibilityAddTraits(.isHeader)
            HStack(spacing: 8) {
                button("Drop circle", name: "drop-circle", value: bodies,
                       hint: canDrop ? "Drops a circle of a random material from the top" : "The stage is full",
                       enabled: canDrop) { _ = port.send("world.drop", [0]) }
                button("Drop box", name: "drop-box", value: bodies,
                       hint: canDrop ? "Drops a box of a random material from the top" : "The stage is full",
                       enabled: canDrop) { _ = port.send("world.drop", [1]) }
            }
            HStack(spacing: 8) {
                button(mirror.paused ? "Run" : "Pause", name: "pause", value: mirror.paused ? "Paused" : "Running",
                       hint: mirror.paused ? "Lets the world run again" : "Holds the world still",
                       enabled: true) { _ = port.send("world.pause", [mirror.paused ? 0 : 1]) }
                button("Step", name: "step", value: mirror.paused ? "Paused" : "Running",
                       hint: mirror.paused ? "Advances the world by one tick" : "Available while paused",
                       enabled: mirror.paused) { _ = port.send("world.step") }
            }
            Picker(selection: Binding(get: { mirror.timeScaleIndex },
                                      set: { index in
                                          if index != mirror.timeScaleIndex {
                                              _ = port.send("world.timeScale", [Double(index)])
                                          }
                                      })) {
                ForEach(0..<PhysicsWorld.timeScales.count, id: \.self) { index in
                    Text(verbatim: PlaygroundPresenter.timeScaleText(index))
                        .accessibilityLabel(Text(verbatim: PlaygroundPresenter.timeScaleWords(index)))
                        .tag(index)
                }
            } label: {
                Text(verbatim: "Time scale")
            }
            .pickerStyle(.segmented)
            .frame(minHeight: 44)
            .accessibilityLabel(Text(verbatim: "Time scale"))
            .accessibilityValue(Text(verbatim: PlaygroundPresenter.timeScaleWords(mirror.timeScaleIndex)))
            .accessibilityIdentifier(port.identifier("time-scale"))
            button("Reset", name: "reset", value: bodies,
                   hint: "Returns to the starting scene at normal speed", enabled: true) {
                _ = port.send("world.reset")
            }
            Text(verbatim: Self.sentence(mirror.status))
                .font(.footnote)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier(port.identifier("status"))
            Text(verbatim: Self.note)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier(port.identifier("note"))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// A bordered button `title` with the identifier `name`, the accessible value `value` and the hint `hint`.
    private func button(_ title: String, name: String, value: String, hint: String, enabled: Bool,
                        action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(verbatim: title)
                .font(.body)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.bordered)
        .disabled(!enabled)
        .accessibilityLabel(Text(verbatim: title))
        .accessibilityValue(Text(verbatim: value))
        .accessibilityHint(Text(verbatim: hint))
        .accessibilityIdentifier(port.identifier(name))
    }
}
