// GardenControls — feature 146 (A20-P02) T-A20-204 (FR-A20-205; clarification Q3). The native controls of Digital Zen
// Garden. Every control reads the presenter's mirror, sends through the action port, and has a spoken label, a hint
// and the identifier `experience.a20.digital-zen-garden.<name>` (`ExperienceActionPort.identifier`):
//
//   - `rake` segmented picker (Fine rake, Wide rake → `rake.style [0 / 1]`);
//   - `tone` menu (the three sand tones → `sand.tone [0…2]`);
//   - `undo` and `redo` buttons (→ `edit.undo []`, `edit.redo []`), each disabled when the history cannot go that way;
//   - four pattern buttons `pattern-rows`, `pattern-circle`, `pattern-wave` and `pattern-spiral`, each raking one
//     stroke of `StrokePatterns` with the chosen rake through `stroke.begin`, `stroke.add` and `stroke.end` — the
//     native alternative of every gesture action;
//   - `message`: the short sentence of a refused stroke (the garden is full), when there is one.
//
// Feature 147 (A20-P03) T-A20-305 (FR-A20-301, FR-A20-303, FR-A20-304; clarification Q3; gaps G-STONES,
// G-SELECTION). The stone controls, the native alternative of every stone gesture:
//   - `tool` segmented picker (Rake, Stones → `tool.mode [0 / 1]`);
//   - `stone-kind` menu (the five stone kinds, presentation only) and `stone-place` ("Place": `stone.place [kind,
//     0.5, 0.5]`, the tray centre; at the stone cap the message "The garden holds 24 stones." is shown);
//   - `selection`: the spoken selection "<kind> selected, <n> of <count>, turned <degrees>°";
//   - `stone-previous` and `stone-next` (`stone.select` with the neighbour's id in depth order, wrapping);
//   - `stone-turn-left` and `stone-turn-right` (`stone.rotate` by −15° and +15°);
//   - `stone-nudge-left`, `-right`, `-up` and `-down` (`stone.move` by 0.02 tray widths, clamped inside the tray);
//   - `stone-remove` (`stone.remove []`).
// The selection controls are disabled without a selected stone; previous and next without stones.
import DigitalZenGardenCore
import Foundation
import SwiftUI
import VisualCoreExperienceHost
import VisualCoreMath

/// The values the stone controls send, computed from the garden's stones and the selection (feature 147).
enum StoneControlValues {
    /// One turn step: 15°, in radians.
    static let turnStep = 15 * Double.pi / 180
    /// One nudge: 0.02 tray widths.
    static let nudgeStep = 0.02

    /// The `stone.select` values of the neighbour of `selected` in depth order (`direction` +1 next, −1 previous);
    /// nil without stones.
    static func select(direction: Int, stones: [Stone], selected: UInt32?) -> [Double]? {
        guard let id = StoneSelection.cycle(from: selected, direction: direction, in: stones) else { return nil }
        return [Double(id)]
    }

    /// The `stone.rotate` values of the selected stone turned by `steps` turn steps (positive clockwise, wrapped into
    /// −π…π); nil without a selection.
    static func turn(steps: Int, stones: [Stone], selected: UInt32?) -> [Double]? {
        guard let stone = stones.first(where: { $0.id == selected }) else { return nil }
        return [GardenPresenter.normalizedAngle(stone.rotation + Double(steps) * turnStep)]
    }

    /// The `stone.move` values of the selected stone nudged by `dx`, `dy` nudge steps (tray widths; y down), clamped
    /// inside the tray; nil without a selection.
    static func nudge(dx: Int, dy: Int, stones: [Stone], selected: UInt32?) -> [Double]? {
        guard let stone = stones.first(where: { $0.id == selected }) else { return nil }
        let x = stone.position.x + Double(dx) * nudgeStep
        let y = stone.position.y + Double(dy) * nudgeStep / GardenPalette.smallTray.yScale
        let clamped = TrayFit.clamped(Vec2(x, y))
        return [clamped.x, clamped.y]
    }

    /// The `stone.place` values of the kind `kind` at the tray centre.
    static func place(kind: Int) -> [Double] {
        [Double(min(max(kind, 0), GardenPalette.stones.count - 1)), 0.5, 0.5]
    }
}

/// The native controls of Digital Zen Garden (see the file header).
struct GardenControls: View {
    /// The port the controls send through.
    let port: ExperienceActionPort
    /// What the controls show.
    let mirror: GardenMirror

    /// The rake titles, by index of `GardenPalette.rakes`.
    static var rakeTitles: [String] { GardenPalette.rakes.map(\.name) }
    /// The tone titles, by index of `GardenPalette.tones`.
    static var toneTitles: [String] { GardenPalette.tones.map(\.name) }

    /// The spoken label of the pattern button at `index`: "Rake rows", "Rake a circle", "Rake a wave", "Rake a
    /// spiral".
    static func patternLabel(_ index: Int) -> String {
        ["Rake rows", "Rake a circle", "Rake a wave", "Rake a spiral"][min(max(index, 0), 3)]
    }

    /// The controls.
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(verbatim: "Digital Zen Garden").font(.headline).accessibilityAddTraits(.isHeader)
            rakePicker
            toneMenu
            HStack(spacing: 12) {
                editButton("Undo", name: "undo", control: "edit.undo", enabled: mirror.canUndo,
                           hint: "Removes the last stroke or tone change")
                editButton("Redo", name: "redo", control: "edit.redo", enabled: mirror.canRedo,
                           hint: "Restores what was undone last")
            }
            patternButtons
            stoneControls
            if let message = mirror.message {
                Text(verbatim: message).font(.footnote)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier(port.identifier("message"))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// The rake picker (sends `rake.style` when the choice changes).
    private var rakePicker: some View {
        let titles = Self.rakeTitles
        let current = min(max(mirror.rakeStyle, 0), titles.count - 1)
        return Picker(selection: Binding(get: { current },
                                         set: { next in
                                             guard next != current else { return }
                                             port.send("rake.style", [Double(next)])
                                         })) {
            ForEach(Array(titles.enumerated()), id: \.offset) { index, title in
                Text(verbatim: title).tag(index)
            }
        } label: {
            Text(verbatim: "Rake")
        }
        .pickerStyle(.segmented)
        .frame(minHeight: 44)
        .accessibilityLabel(Text(verbatim: "Rake, " + titles[current]))
        .accessibilityHint(Text(verbatim: "Chooses the rake of the next stroke"))
        .accessibilityIdentifier(port.identifier("rake"))
    }

    /// The tone menu (sends `sand.tone` when the choice changes).
    private var toneMenu: some View {
        let titles = Self.toneTitles
        let current = min(max(mirror.tone, 0), titles.count - 1)
        return HStack {
            Text(verbatim: "Sand").accessibilityHidden(true)
            Spacer(minLength: 8)
            Menu {
                ForEach(Array(titles.enumerated()), id: \.offset) { index, title in
                    Button(title) {
                        guard index != current else { return }
                        port.send("sand.tone", [Double(index)])
                    }
                }
            } label: {
                Text(verbatim: titles[current]).frame(minHeight: 44)
            }
            .accessibilityLabel(Text(verbatim: "Sand tone, " + titles[current]))
            .accessibilityHint(Text(verbatim: "Chooses the colour of the sand"))
            .accessibilityIdentifier(port.identifier("tone"))
        }
    }

    /// An undo or redo button sending `control`, disabled unless `enabled`.
    private func editButton(_ title: String, name: String, control: String, enabled: Bool,
                            hint: String) -> some View {
        Button {
            port.send(control)
        } label: {
            Text(verbatim: title).frame(minWidth: 44, minHeight: 44)
        }
        .disabled(!enabled)
        .accessibilityLabel(Text(verbatim: title))
        .accessibilityHint(Text(verbatim: hint))
        .accessibilityIdentifier(port.identifier(name))
    }

    /// The tool titles: "Rake" and "Stones" (feature 147).
    static let toolTitles = ["Rake", "Stones"]

    /// The stone controls (feature 147; see the file header).
    private var stoneControls: some View {
        let hasSelection = mirror.selectedStone != nil && mirror.stones.contains { $0.id == mirror.selectedStone }
        return VStack(alignment: .leading, spacing: 6) {
            toolPicker
            HStack(spacing: 8) {
                kindMenu
                Spacer(minLength: 8)
                Button {
                    let result = port.send("stone.place", StoneControlValues.place(kind: mirror.placeKind))
                    if result.code == "action.rule." + GardenRule.stoneCap { mirror.stoneCapShown = true }
                } label: {
                    Text(verbatim: "Place").frame(minWidth: 44, minHeight: 44)
                }
                .accessibilityLabel(Text(verbatim: "Place stone"))
                .accessibilityHint(Text(verbatim: "Places the chosen stone at the centre of the tray"))
                .accessibilityIdentifier(port.identifier("stone-place"))
            }
            Text(verbatim: mirror.selectionValue).font(.footnote)
                .accessibilityLabel(Text(verbatim: "Selection"))
                .accessibilityValue(Text(verbatim: mirror.selectionValue))
                .accessibilityIdentifier(port.identifier("selection"))
            HStack(spacing: 8) {
                stoneButton("Previous", name: "stone-previous", hint: "Selects the stone below in layer order",
                            values: StoneControlValues.select(direction: -1, stones: mirror.stones,
                                                              selected: mirror.selectedStone), control: "stone.select")
                stoneButton("Next", name: "stone-next", hint: "Selects the stone above in layer order",
                            values: StoneControlValues.select(direction: 1, stones: mirror.stones,
                                                              selected: mirror.selectedStone), control: "stone.select")
                stoneButton("Remove", name: "stone-remove", hint: "Removes the selected stone",
                            values: hasSelection ? [] : nil, control: "stone.remove")
            }
            HStack(spacing: 8) {
                stoneButton("Turn left", name: "stone-turn-left", hint: "Turns the selected stone 15 degrees left",
                            values: StoneControlValues.turn(steps: -1, stones: mirror.stones,
                                                            selected: mirror.selectedStone), control: "stone.rotate")
                stoneButton("Turn right", name: "stone-turn-right", hint: "Turns the selected stone 15 degrees right",
                            values: StoneControlValues.turn(steps: 1, stones: mirror.stones,
                                                            selected: mirror.selectedStone), control: "stone.rotate")
            }
            HStack(spacing: 8) {
                nudgeButton("Left", name: "left", dx: -1, dy: 0)
                nudgeButton("Right", name: "right", dx: 1, dy: 0)
                nudgeButton("Up", name: "up", dx: 0, dy: -1)
                nudgeButton("Down", name: "down", dx: 0, dy: 1)
            }
        }
    }

    /// The tool picker (sends `tool.mode` when the choice changes).
    private var toolPicker: some View {
        let titles = Self.toolTitles
        let current = min(max(mirror.toolMode, 0), titles.count - 1)
        return Picker(selection: Binding(get: { current },
                                         set: { next in
                                             guard next != current else { return }
                                             port.send("tool.mode", [Double(next)])
                                         })) {
            ForEach(Array(titles.enumerated()), id: \.offset) { index, title in
                Text(verbatim: title).tag(index)
            }
        } label: {
            Text(verbatim: "Tool")
        }
        .pickerStyle(.segmented)
        .frame(minHeight: 44)
        .accessibilityLabel(Text(verbatim: "Tool, " + titles[current]))
        .accessibilityHint(Text(verbatim: "Chooses whether a touch rakes the sand or moves stones"))
        .accessibilityIdentifier(port.identifier("tool"))
    }

    /// The kind menu of the "Place" control (presentation only).
    private var kindMenu: some View {
        let kinds = GardenPalette.stones
        let current = min(max(mirror.placeKind, 0), kinds.count - 1)
        return Menu {
            ForEach(Array(kinds.enumerated()), id: \.offset) { index, kind in
                Button(kind.name) { mirror.placeKind = index }
            }
        } label: {
            Text(verbatim: kinds[current].name).frame(minHeight: 44)
        }
        .accessibilityLabel(Text(verbatim: "Stone, " + kinds[current].name))
        .accessibilityHint(Text(verbatim: "Chooses the stone that Place puts on the sand"))
        .accessibilityIdentifier(port.identifier("stone-kind"))
    }

    /// A stone button sending `control` with `values`, disabled when `values` is nil.
    private func stoneButton(_ title: String, name: String, hint: String, values: [Double]?,
                             control: String, spoken: String? = nil) -> some View {
        Button {
            guard let values else { return }
            port.send(control, values)
        } label: {
            Text(verbatim: title).frame(minWidth: 44, minHeight: 44)
        }
        .disabled(values == nil)
        .accessibilityLabel(Text(verbatim: spoken ?? title))
        .accessibilityHint(Text(verbatim: hint))
        .accessibilityIdentifier(port.identifier(name))
    }

    /// A nudge button moving the selected stone by `dx`, `dy` nudge steps.
    private func nudgeButton(_ title: String, name: String, dx: Int, dy: Int) -> some View {
        stoneButton(title, name: "stone-nudge-" + name, hint: "Moves the selected stone a little " + name,
                    values: StoneControlValues.nudge(dx: dx, dy: dy, stones: mirror.stones,
                                                     selected: mirror.selectedStone),
                    control: "stone.move", spoken: "Move " + name)
    }

    /// The four pattern buttons, each raking one stroke with the chosen rake.
    private var patternButtons: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(verbatim: "Rake a pattern").font(.subheadline).accessibilityHidden(true)
            HStack(spacing: 8) {
                ForEach(Array(StrokePatterns.names.enumerated()), id: \.offset) { index, name in
                    Button {
                        StrokePatterns.send(StrokePatterns.points(index: index), rake: mirror.rakeStyle, port: port)
                    } label: {
                        Text(verbatim: StrokePatterns.titles[index]).frame(minHeight: 44)
                    }
                    .accessibilityLabel(Text(verbatim: Self.patternLabel(index)))
                    .accessibilityHint(Text(verbatim: "Rakes the pattern into the sand with the chosen rake"))
                    .accessibilityIdentifier(port.identifier("pattern-" + name))
                }
            }
        }
    }
}
