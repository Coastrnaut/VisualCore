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
//
// Feature 083 (A11-P02) T-A11-204 (FR-A11-221; clarification 4) adds three segmented pickers, each sending its level
// through the port only when it changes:
//   Gravity (`gravity` → `world.gravity [0…2]`: Off, Moon, Earth);
//   Drag (`drag` → `world.drag [0…2]`: None, Low, High);
//   Spring stiffness (`stiffness` → `world.stiffness [0…3]`: Soft, Medium, Stiff, Very stiff);
// with VoiceOver labels and values naming the level and its number ("Earth, 9.81 metres per second squared"), and a
// forces line (`forces`: springs, stiffness, gravity and drag) under the status line.
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
            levelPicker("Gravity", name: "gravity", control: "world.gravity",
                        titles: PlaygroundPresenter.gravityTitles, selected: mirror.gravityLevel,
                        value: PlaygroundPresenter.gravityValue)
            levelPicker("Drag", name: "drag", control: "world.drag", titles: PlaygroundPresenter.dragTitles,
                        selected: mirror.dragLevel, value: PlaygroundPresenter.dragValue)
            levelPicker("Spring stiffness", name: "stiffness", control: "world.stiffness",
                        titles: PlaygroundPresenter.stiffnessTitles, selected: mirror.stiffnessLevel,
                        value: PlaygroundPresenter.stiffnessValue)
            button("Reset", name: "reset", value: bodies,
                   hint: "Returns to the starting scene at normal speed with the default forces", enabled: true) {
                _ = port.send("world.reset")
            }
            Text(verbatim: Self.sentence(mirror.status))
                .font(.footnote)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier(port.identifier("status"))
            Text(verbatim: Self.sentence(mirror.forces))
                .font(.footnote)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier(port.identifier("forces"))
            Text(verbatim: Self.note)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier(port.identifier("note"))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// A segmented picker `title` with the identifier `name` over the levels `titles`, showing `selected` and sending
    /// `control` with the chosen level when it changes; its accessible value is `value(selected)` and each segment's
    /// label is `value` of its level; a visible caption names it above.
    private func levelPicker(_ title: String, name: String, control: String, titles: [String], selected: Int,
                             value: @escaping (Int) -> String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            // The visible caption; VoiceOver reads the picker's own label instead.
            Text(verbatim: title).font(.footnote).accessibilityHidden(true)
            picker(title, name: name, control: control, titles: titles, selected: selected, value: value)
        }
    }

    /// The segmented picker of ``levelPicker(_:name:control:titles:selected:value:)``.
    private func picker(_ title: String, name: String, control: String, titles: [String], selected: Int,
                        value: @escaping (Int) -> String) -> some View {
        Picker(selection: Binding(get: { selected },
                                  set: { level in
                                      if level != selected { _ = port.send(control, [Double(level)]) }
                                  })) {
            ForEach(titles.indices, id: \.self) { level in
                Text(verbatim: titles[level])
                    .accessibilityLabel(Text(verbatim: value(level)))
                    .tag(level)
            }
        } label: {
            Text(verbatim: title)
        }
        .pickerStyle(.segmented)
        .frame(minHeight: 44)
        .accessibilityLabel(Text(verbatim: title))
        .accessibilityValue(Text(verbatim: value(selected)))
        .accessibilityIdentifier(port.identifier(name))
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
