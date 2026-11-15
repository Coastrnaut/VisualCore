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
//
// Feature 084 (A11-P03) T-A11-303 (FR-A11-303, FR-A11-311; SC-A11-301, SC-A11-304; clarifications 2, 4) adds an
// "Edit" group, the native alternative to every canvas gesture:
//   Previous body and Next body (`select-previous`, `select-next` → `edit.select [id]`, walking the bodies in drawing
//   order and wrapping; the first or the last body when nothing is selected);
//   Pin / Unpin (`pin` → `edit.pin [selected]`; disabled without a selection or for a static body);
//   Delete (`delete` → `edit.delete [selected]`);
//   Add at centre (`add-centre` → `edit.add [5, 4, kind]`; disabled at 48 bodies);
//   the shape picker (`shape`: Circle or Box, presentation state the canvas tap uses too);
//   Hold / Let go (`hold` → `edit.grab [selected, its centre]`, or `edit.release` while a body is held);
//   four direction buttons (`nudge-up`, `nudge-down`, `nudge-left`, `nudge-right`): while a body is held they move the
//   hold's target 0.5 m (`edit.move`, clamped into the stage) — the native alternative to dragging — otherwise they
//   nudge the selected body by 1 m/s (`edit.nudge [±1, 0]`, `[0, ±1]`);
//   two toggles (`velocity-arrows` → `overlay.velocity [0/1]`, `force-arrows` → `overlay.forces [0/1]`);
// an editing line (`editing`: pinned bodies, the selection, a grab, the overlays) and the state panel (`panel`): the
// note "Educational approximation", the kinetic, potential, spring and total energy in joules, the momentum in
// kg·m/s and the selected body's speed in m/s, each with two decimals (`panel-kinetic`, `panel-potential`,
// `panel-spring`, `panel-total`, `panel-momentum`, `panel-speed`), and the note that contact and drag forces are not
// drawn (`arrow-note`). Every control has a VoiceOver label and value.
import SwiftUI
import PhysicsPlaygroundCore
import VisualCoreExperienceHost
import VisualCoreMath

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

    /// The stage point "Add at centre" adds at, in metres.
    static let addPoint = Vec2(5, 4)
    /// How far a direction button moves a held body's target, in metres.
    static let holdStep = 0.5
    /// The shape picker's titles: "Circle", "Box".
    static let shapeTitles = ["Circle", "Box"]

    /// The body the previous (`forward` false) or next (`forward` true) selection control selects among `ids` (in
    /// drawing order) from `selected`: the neighbour, wrapping at the ends; the first (next) or the last (previous)
    /// body when nothing or a missing body is selected; nil without bodies.
    static func neighbour(of selected: Int?, in ids: [Int], forward: Bool) -> Int? {
        guard !ids.isEmpty else { return nil }
        guard let selected, let index = ids.firstIndex(of: selected) else { return forward ? ids.first : ids.last }
        let next = (index + (forward ? 1 : -1) + ids.count) % ids.count
        return ids[next]
    }

    /// The hold's target `target` moved by (`dx`, `dy`) × ``holdStep`` metres and clamped into the stage.
    static func movedTarget(_ target: Vec2, dx: Double, dy: Double) -> Vec2 {
        let stage = WorldSettings.defaultStage
        return Vec2(min(max(target.x + dx * holdStep, 0), stage.x), min(max(target.y + dy * holdStep, 0), stage.y))
    }

    /// The selection in words for the controls' values: "No body selected" or "Body 7 selected".
    static func selectionValue(_ id: Int?) -> String {
        id.map { "Body \($0) selected" } ?? "No body selected"
    }

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
            editGroup(canAdd: canDrop)
            Text(verbatim: Self.sentence(mirror.status))
                .font(.footnote)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier(port.identifier("status"))
            Text(verbatim: Self.sentence(mirror.forces))
                .font(.footnote)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier(port.identifier("forces"))
            Text(verbatim: Self.sentence(mirror.editing))
                .font(.footnote)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier(port.identifier("editing"))
            statePanel
            Text(verbatim: Self.note)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier(port.identifier("note"))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// The edit group (feature 084): selection, pin, delete, add, shape, hold, directions and overlay toggles.
    @ViewBuilder private func editGroup(canAdd: Bool) -> some View {
        let selected = mirror.selectedId
        let selection = Self.selectionValue(selected)
        let holding = mirror.grabbedId != nil
        let canMoveSelected = selected != nil && !mirror.selectedStatic && !mirror.selectedPinned
        Text(verbatim: "Edit").font(.subheadline).accessibilityAddTraits(.isHeader)
        HStack(spacing: 8) {
            button("Previous body", name: "select-previous", value: selection,
                   hint: "Selects the previous body", enabled: !mirror.bodyIds.isEmpty) {
                if let id = Self.neighbour(of: selected, in: mirror.bodyIds, forward: false) {
                    _ = port.send("edit.select", [Double(id)])
                }
            }
            button("Next body", name: "select-next", value: selection,
                   hint: "Selects the next body", enabled: !mirror.bodyIds.isEmpty) {
                if let id = Self.neighbour(of: selected, in: mirror.bodyIds, forward: true) {
                    _ = port.send("edit.select", [Double(id)])
                }
            }
        }
        HStack(spacing: 8) {
            button(mirror.selectedPinned ? "Unpin" : "Pin", name: "pin",
                   value: mirror.selectedPinned ? "Pinned" : selection,
                   hint: mirror.selectedStatic ? "A static body cannot be pinned"
                       : "Fixes the selected body in place, or releases it",
                   enabled: selected != nil && !mirror.selectedStatic) {
                if let selected { _ = port.send("edit.pin", [Double(selected)]) }
            }
            button("Delete", name: "delete", value: selection,
                   hint: "Removes the selected body and its springs", enabled: selected != nil) {
                if let selected { _ = port.send("edit.delete", [Double(selected)]) }
            }
        }
        HStack(spacing: 8) {
            button("Add at centre", name: "add-centre", value: Self.shapeTitles[mirror.shapeKind == 1 ? 1 : 0],
                   hint: canAdd ? "Adds the chosen shape at the centre of the stage" : "The stage is full",
                   enabled: canAdd) {
                _ = port.send("edit.add", [Self.addPoint.x, Self.addPoint.y, Double(mirror.shapeKind)])
            }
            button(holding ? "Let go" : "Hold", name: "hold",
                   value: holding ? "Holding body \(mirror.grabbedId ?? 0)" : selection,
                   hint: holding ? "Lets the held body go with its own velocity"
                       : "Holds the selected body at its centre; the direction buttons then move it",
                   enabled: holding || canMoveSelected) {
                if holding {
                    _ = port.send("edit.release")
                } else if let selected, let center = mirror.selectedCenter {
                    let point = Self.movedTarget(center, dx: 0, dy: 0)
                    _ = port.send("edit.grab", [Double(selected), point.x, point.y])
                }
            }
        }
        Picker(selection: Binding(get: { mirror.shapeKind }, set: { mirror.shapeKind = $0 })) {
            ForEach(Self.shapeTitles.indices, id: \.self) { index in
                Text(verbatim: Self.shapeTitles[index]).tag(index)
            }
        } label: {
            Text(verbatim: "Shape")
        }
        .pickerStyle(.segmented)
        .frame(minHeight: 44)
        .accessibilityLabel(Text(verbatim: "Shape to add"))
        .accessibilityValue(Text(verbatim: Self.shapeTitles[mirror.shapeKind == 1 ? 1 : 0]))
        .accessibilityIdentifier(port.identifier("shape"))
        HStack(spacing: 8) {
            ForEach(Self.directions.indices, id: \.self) { index in
                let direction = Self.directions[index]
                button(direction.title, name: direction.name,
                       value: holding ? "Holding body \(mirror.grabbedId ?? 0)" : selection,
                       hint: holding ? "Moves the held body \(direction.words) by half a metre"
                           : "Pushes the selected body \(direction.words) at 1 metre per second",
                       enabled: holding || canMoveSelected) {
                    if holding, let target = mirror.grabTarget {
                        let point = Self.movedTarget(target, dx: direction.dx, dy: direction.dy)
                        _ = port.send("edit.move", [point.x, point.y])
                    } else {
                        _ = port.send("edit.nudge", [direction.dx, direction.dy])
                    }
                }
            }
        }
        toggle("Velocity arrows", name: "velocity-arrows", control: "overlay.velocity", isOn: mirror.showVelocity)
        toggle("Force arrows", name: "force-arrows", control: "overlay.forces", isOn: mirror.showForces)
    }

    /// The four direction buttons: (title, identifier name, direction in words, dx, dy).
    static let directions: [(title: String, name: String, words: String, dx: Double, dy: Double)] = [
        ("Up", "nudge-up", "up", 0, 1), ("Down", "nudge-down", "down", 0, -1),
        ("Left", "nudge-left", "left", -1, 0), ("Right", "nudge-right", "right", 1, 0),
    ]

    /// A toggle `title` with the identifier `name` that sends `control [1/0]` when it changes.
    private func toggle(_ title: String, name: String, control: String, isOn: Bool) -> some View {
        Toggle(isOn: Binding(get: { isOn }, set: { on in
            if on != isOn { _ = port.send(control, [on ? 1 : 0]) }
        })) {
            Text(verbatim: title)
        }
        .frame(minHeight: 44)
        .accessibilityLabel(Text(verbatim: title))
        .accessibilityValue(Text(verbatim: isOn ? "On" : "Off"))
        .accessibilityIdentifier(port.identifier(name))
    }

    /// The state panel (feature 084): the note, the six measured rows and what the arrows leave out.
    private var statePanel: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(verbatim: PlaygroundPanel.note)
                .font(.footnote.weight(.semibold))
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier(port.identifier("panel"))
            let rows = mirror.panel.rows
            ForEach(rows.indices, id: \.self) { index in
                let row = rows[index]
                HStack {
                    Text(verbatim: row.label)
                    Spacer(minLength: 8)
                    Text(verbatim: row.value).monospacedDigit()
                }
                .font(.footnote)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(verbatim: row.label))
                .accessibilityValue(Text(verbatim: row.value))
                .accessibilityIdentifier(port.identifier(row.name))
            }
            Text(verbatim: PlaygroundPanel.arrowNote)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier(port.identifier("arrow-note"))
        }
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
