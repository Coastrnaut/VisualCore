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
//
// Feature 148 (A20-P04) T-A20-402, T-A20-403, T-A20-405 (FR-A20-401, FR-A20-403, FR-A20-405; clarifications Q1, Q3,
// Q4; gaps G-LIBRARY, G-A11Y). Every control's spoken label and value come from one list (`labels(...)`, also read by
// the tests), for example "Rake" / "Fine rake", "Undo" / "a stroke", "Open Morning" / "Saved garden 1 of 2":
//   - Library: `library-name` (the name field), `library-save` ("Save garden"; a name that a garden already has asks
//     "Replace the garden called <name>?" first), and per saved garden `library-open-<n>`, `library-rename-<n>` (an
//     alert with a name field) and `library-delete-<n>` (asks first); an unreadable file is listed as
//     `library-unreadable-<n>` ("Unreadable garden <name>", its code) with its delete button; `library-message`.
//   - Picture: `still-make` ("Make picture", 1600 by 1200 pixels) and, once written, `still-share` (a `ShareLink`
//     of the PNG file); `still-message`.
//   - Undo, redo, Place and the patterns go through the presenter, which announces them (or their refusal).
//   - At the accessibility text sizes every row stacks in one column and the text wraps (never clipped); the
//     segmented pickers become a column of buttons.
// The library and picture buttons are native controls only: no gesture is added.
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

/// One spoken label of a control: its identifier name, its title and its value (feature 148).
struct GardenControlLabel: Equatable, Sendable {
    /// The identifier name (`experience.a20.digital-zen-garden.<name>`).
    var name: String
    /// The spoken title, for example "Rake".
    var title: String
    /// The spoken value, for example "Fine rake".
    var value: String

    /// "<title>, <value>".
    var text: String { title + ", " + value }
}

extension View {
    /// Applies `label`'s title and value as the accessibility label and value (feature 148).
    func spoken(_ label: GardenControlLabel?) -> some View {
        accessibilityLabel(Text(verbatim: label?.title ?? ""))
            .accessibilityValue(Text(verbatim: label?.value ?? ""))
    }
}

/// The native controls of Digital Zen Garden (see the file header).
struct GardenControls: View {
    /// The port the controls send through.
    let port: ExperienceActionPort
    /// What the controls show.
    let mirror: GardenMirror
    /// The presenter: the library, the picture and the announced actions (feature 148).
    let presenter: GardenPresenter

    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.experienceStillRenderer) private var stillRenderer
    @State private var name = ""
    @State private var replacing: String?
    @State private var renaming: GardenLibraryEntry?
    @State private var newName = ""
    @State private var deleting: GardenLibraryEntry?

    /// The rake titles, by index of `GardenPalette.rakes`.
    static var rakeTitles: [String] { GardenPalette.rakes.map(\.name) }
    /// The tone titles, by index of `GardenPalette.tones`.
    static var toneTitles: [String] { GardenPalette.tones.map(\.name) }
    /// The tool titles: "Rake" and "Stones" (feature 147).
    static let toolTitles = ["Rake", "Stones"]
    /// The spoken value of the picture controls (feature 148).
    static let stillValue = "PNG, \(GardenStill.width) by \(GardenStill.height) pixels"

    /// The spoken label of the pattern button at `index`: "Rake rows", "Rake a circle", "Rake a wave", "Rake a
    /// spiral".
    static func patternLabel(_ index: Int) -> String {
        ["Rake rows", "Rake a circle", "Rake a wave", "Rake a spiral"][min(max(index, 0), 3)]
    }

    /// The selection buttons: identifier name, title and hint (feature 147).
    static let selectionButtons: [(name: String, title: String)] = [
        ("stone-previous", "Previous"), ("stone-next", "Next"), ("stone-remove", "Remove"),
        ("stone-turn-left", "Turn left"), ("stone-turn-right", "Turn right"), ("stone-nudge-left", "Move left"),
        ("stone-nudge-right", "Move right"), ("stone-nudge-up", "Move up"), ("stone-nudge-down", "Move down"),
    ]

    /// The spoken label of every control shown for `mirror`, the saved gardens `entries` (nil without a library),
    /// the name field's text `name` and whether a written picture is offered (`stillReady`), in display order
    /// (feature 148).
    static func labels(_ mirror: GardenMirror, entries: [GardenLibraryEntry]?, name: String,
                       stillReady: Bool) -> [GardenControlLabel] {
        let rake = rakeTitles[min(max(mirror.rakeStyle, 0), rakeTitles.count - 1)]
        let kind = GardenPalette.stones[min(max(mirror.placeKind, 0), GardenPalette.stones.count - 1)].name
        var labels = [
            GardenControlLabel(name: "rake", title: "Rake", value: rake),
            GardenControlLabel(name: "tone", title: "Sand tone",
                               value: toneTitles[min(max(mirror.tone, 0), toneTitles.count - 1)]),
            GardenControlLabel(name: "undo", title: "Undo", value: mirror.undoValue),
            GardenControlLabel(name: "redo", title: "Redo", value: mirror.redoValue),
        ]
        for (index, pattern) in StrokePatterns.names.enumerated() {
            labels.append(GardenControlLabel(name: "pattern-" + pattern, title: patternLabel(index), value: rake))
        }
        labels.append(GardenControlLabel(name: "tool", title: "Tool",
                                         value: toolTitles[min(max(mirror.toolMode, 0), toolTitles.count - 1)]))
        labels.append(GardenControlLabel(name: "stone-kind", title: "Stone", value: kind))
        labels.append(GardenControlLabel(name: "stone-place", title: "Place stone", value: kind))
        labels.append(GardenControlLabel(name: "selection", title: "Selection", value: mirror.selectionValue))
        for button in selectionButtons {
            labels.append(GardenControlLabel(name: button.name, title: button.title, value: mirror.selectionValue))
        }
        if let entries {
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            labels.append(GardenControlLabel(name: "library-name", title: "Garden name",
                                             value: trimmed.isEmpty ? "empty" : trimmed))
            labels.append(GardenControlLabel(name: "library-save", title: "Save garden",
                                             value: trimmed.isEmpty ? "no name" : trimmed))
            let readable = entries.filter(\.isReadable)
            for (index, entry) in readable.enumerated() {
                let value = "Saved garden \(index + 1) of \(readable.count)"
                let n = String(entry.number)
                labels.append(GardenControlLabel(name: "library-open-" + n, title: "Open " + entry.name, value: value))
                labels.append(GardenControlLabel(name: "library-rename-" + n, title: "Rename " + entry.name,
                                                 value: value))
                labels.append(GardenControlLabel(name: "library-delete-" + n, title: "Delete " + entry.name,
                                                 value: value))
            }
            for entry in entries where !entry.isReadable {
                let n = String(entry.number)
                let code = entry.refusal ?? "damaged"
                labels.append(GardenControlLabel(name: "library-unreadable-" + n,
                                                 title: "Unreadable garden " + entry.name, value: code))
                labels.append(GardenControlLabel(name: "library-delete-" + n, title: "Delete " + entry.name,
                                                 value: "unreadable, " + code))
            }
        }
        labels.append(GardenControlLabel(name: "still-make", title: "Make picture", value: stillValue))
        if stillReady { labels.append(GardenControlLabel(name: "still-share", title: "Share picture", value: stillValue)) }
        return labels
    }

    /// Whether the text is at an accessibility size (the rows then stack in one column).
    private var stacked: Bool { typeSize.isAccessibilitySize }

    /// A row: horizontal, or one column at the accessibility sizes.
    private var row: AnyLayout {
        stacked ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8)) : AnyLayout(HStackLayout(spacing: 8))
    }

    /// The controls.
    var body: some View {
        let entries = presenter.library?.entries
        let stillReady = mirror.stillURL != nil
        let list = Self.labels(mirror, entries: entries, name: name, stillReady: stillReady)
        let spokenLabels = Dictionary(list.map { ($0.name, $0) }, uniquingKeysWith: { first, _ in first })
        return VStack(alignment: .leading, spacing: 8) {
            Text(verbatim: "Digital Zen Garden").font(.headline).accessibilityAddTraits(.isHeader)
            rakePicker(spokenLabels)
            toneMenu(spokenLabels)
            row {
                editButton("Undo", name: "undo", enabled: mirror.canUndo,
                           hint: "Undoes the last stroke, stone change or tone change", spokenLabels) {
                    presenter.undo(port: port)
                }
                editButton("Redo", name: "redo", enabled: mirror.canRedo,
                           hint: "Restores what was undone last", spokenLabels) {
                    presenter.redo(port: port)
                }
            }
            patternButtons(spokenLabels)
            stoneControls(spokenLabels)
            if let message = mirror.message {
                wrapping(message).font(.footnote)
                    .accessibilityIdentifier(port.identifier("message"))
            }
            if let entries { librarySection(entries, spokenLabels) }
            stillSection(spokenLabels)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear { if name.isEmpty, let opened = presenter.openedName { name = opened } }
        .confirmationDialog(Text(verbatim: "Replace the garden called \(replacing ?? "")?"),
                            isPresented: Binding(get: { replacing != nil }, set: { if !$0 { replacing = nil } }),
                            titleVisibility: .visible, presenting: replacing) { target in
            Button(role: .destructive) { presenter.saveGarden(named: target) } label: { Text(verbatim: "Replace") }
                .accessibilityIdentifier(port.identifier("library-replace-confirm"))
        }
        .alert(Text(verbatim: "Rename garden"),
               isPresented: Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } }),
               presenting: renaming) { entry in
            TextField(text: $newName) { Text(verbatim: "Garden name") }
                .accessibilityIdentifier(port.identifier("library-rename-name"))
            Button {
                if case .success(let renamed) = presenter.renameGarden(entry.file, to: newName),
                   name == entry.name { name = renamed.name }
            } label: { Text(verbatim: "Rename") }
                .accessibilityIdentifier(port.identifier("library-rename-confirm"))
            Button(role: .cancel) {} label: { Text(verbatim: "Cancel") }
        }
        .confirmationDialog(Text(verbatim: "Delete the saved garden \(deleting?.name ?? "")?"),
                            isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }),
                            titleVisibility: .visible, presenting: deleting) { entry in
            Button(role: .destructive) { presenter.deleteGarden(entry.file) } label: { Text(verbatim: "Delete") }
                .accessibilityIdentifier(port.identifier("library-delete-confirm"))
        }
    }

    /// `text` wrapping onto as many lines as it needs.
    private func wrapping(_ text: String) -> some View {
        Text(verbatim: text).fixedSize(horizontal: false, vertical: true).multilineTextAlignment(.leading)
    }

    /// A segmented picker of `titles`, or at the accessibility sizes a column of buttons (the selected one marked),
    /// sending `control` when the choice changes.
    @ViewBuilder
    private func choicePicker(_ titles: [String], current: Int, control: String, title: String, name: String,
                              hint: String, _ spokenLabels: [String: GardenControlLabel]) -> some View {
        if stacked {
            VStack(alignment: .leading, spacing: 4) {
                wrapping(title).accessibilityHidden(true)
                ForEach(Array(titles.enumerated()), id: \.offset) { index, choice in
                    Button {
                        guard index != current else { return }
                        port.send(control, [Double(index)])
                    } label: {
                        HStack(spacing: 8) {
                            wrapping(choice)
                            if index == current { Image(systemName: "checkmark").accessibilityHidden(true) }
                        }
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .accessibilityLabel(Text(verbatim: title + ", " + choice))
                    .accessibilityAddTraits(index == current ? .isSelected : [])
                    .accessibilityHint(Text(verbatim: hint))
                    .accessibilityIdentifier(port.identifier(name + "-" + String(index)))
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier(port.identifier(name))
        } else {
            Picker(selection: Binding(get: { current },
                                      set: { next in
                                          guard next != current else { return }
                                          port.send(control, [Double(next)])
                                      })) {
                ForEach(Array(titles.enumerated()), id: \.offset) { index, choice in
                    Text(verbatim: choice).tag(index)
                }
            } label: {
                Text(verbatim: title)
            }
            .pickerStyle(.segmented)
            .frame(minHeight: 44)
            .spoken(spokenLabels[name])
            .accessibilityHint(Text(verbatim: hint))
            .accessibilityIdentifier(port.identifier(name))
        }
    }

    /// The rake picker (sends `rake.style` when the choice changes).
    private func rakePicker(_ spokenLabels: [String: GardenControlLabel]) -> some View {
        let titles = Self.rakeTitles
        return choicePicker(titles, current: min(max(mirror.rakeStyle, 0), titles.count - 1), control: "rake.style",
                            title: "Rake", name: "rake", hint: "Chooses the rake of the next stroke", spokenLabels)
    }

    /// The tone menu (sends `sand.tone` when the choice changes).
    private func toneMenu(_ spokenLabels: [String: GardenControlLabel]) -> some View {
        let titles = Self.toneTitles
        let current = min(max(mirror.tone, 0), titles.count - 1)
        return row {
            wrapping("Sand").accessibilityHidden(true)
            if !stacked { Spacer(minLength: 8) }
            Menu {
                ForEach(Array(titles.enumerated()), id: \.offset) { index, title in
                    Button(title) {
                        guard index != current else { return }
                        port.send("sand.tone", [Double(index)])
                    }
                }
            } label: {
                wrapping(titles[current]).frame(minHeight: 44)
            }
            .spoken(spokenLabels["tone"])
            .accessibilityHint(Text(verbatim: "Chooses the colour of the sand"))
            .accessibilityIdentifier(port.identifier("tone"))
        }
    }

    /// An undo or redo button running `action`, disabled unless `enabled`.
    private func editButton(_ title: String, name: String, enabled: Bool, hint: String,
                            _ spokenLabels: [String: GardenControlLabel],
                            action: @escaping () -> Void) -> some View {
        Button(action: action) {
            wrapping(title).frame(minWidth: 44, minHeight: 44)
        }
        .disabled(!enabled)
        .spoken(spokenLabels[name])
        .accessibilityHint(Text(verbatim: hint))
        .accessibilityIdentifier(port.identifier(name))
    }

    /// The stone controls (feature 147; see the file header).
    private func stoneControls(_ spokenLabels: [String: GardenControlLabel]) -> some View {
        let hasSelection = mirror.selectedStone != nil && mirror.stones.contains { $0.id == mirror.selectedStone }
        return VStack(alignment: .leading, spacing: 6) {
            toolPicker(spokenLabels)
            row {
                kindMenu(spokenLabels)
                if !stacked { Spacer(minLength: 8) }
                Button {
                    presenter.placeStone(kind: mirror.placeKind, port: port)
                } label: {
                    wrapping("Place").frame(minWidth: 44, minHeight: 44)
                }
                .spoken(spokenLabels["stone-place"])
                .accessibilityHint(Text(verbatim: "Places the chosen stone at the centre of the tray"))
                .accessibilityIdentifier(port.identifier("stone-place"))
            }
            wrapping(mirror.selectionValue).font(.footnote)
                .spoken(spokenLabels["selection"])
                .accessibilityIdentifier(port.identifier("selection"))
            row {
                stoneButton("Previous", name: "stone-previous", hint: "Selects the stone below in layer order",
                            values: StoneControlValues.select(direction: -1, stones: mirror.stones,
                                                              selected: mirror.selectedStone), control: "stone.select",
                            spokenLabels)
                stoneButton("Next", name: "stone-next", hint: "Selects the stone above in layer order",
                            values: StoneControlValues.select(direction: 1, stones: mirror.stones,
                                                              selected: mirror.selectedStone), control: "stone.select",
                            spokenLabels)
                stoneButton("Remove", name: "stone-remove", hint: "Removes the selected stone",
                            values: hasSelection ? [] : nil, control: "stone.remove", spokenLabels)
            }
            row {
                stoneButton("Turn left", name: "stone-turn-left", hint: "Turns the selected stone 15 degrees left",
                            values: StoneControlValues.turn(steps: -1, stones: mirror.stones,
                                                            selected: mirror.selectedStone), control: "stone.rotate",
                            spokenLabels)
                stoneButton("Turn right", name: "stone-turn-right", hint: "Turns the selected stone 15 degrees right",
                            values: StoneControlValues.turn(steps: 1, stones: mirror.stones,
                                                            selected: mirror.selectedStone), control: "stone.rotate",
                            spokenLabels)
            }
            row {
                nudgeButton("Left", name: "left", dx: -1, dy: 0, spokenLabels)
                nudgeButton("Right", name: "right", dx: 1, dy: 0, spokenLabels)
                nudgeButton("Up", name: "up", dx: 0, dy: -1, spokenLabels)
                nudgeButton("Down", name: "down", dx: 0, dy: 1, spokenLabels)
            }
        }
    }

    /// The tool picker (sends `tool.mode` when the choice changes).
    private func toolPicker(_ spokenLabels: [String: GardenControlLabel]) -> some View {
        let titles = Self.toolTitles
        return choicePicker(titles, current: min(max(mirror.toolMode, 0), titles.count - 1), control: "tool.mode",
                            title: "Tool", name: "tool",
                            hint: "Chooses whether a touch rakes the sand or moves stones", spokenLabels)
    }

    /// The kind menu of the "Place" control (presentation only).
    private func kindMenu(_ spokenLabels: [String: GardenControlLabel]) -> some View {
        let kinds = GardenPalette.stones
        let current = min(max(mirror.placeKind, 0), kinds.count - 1)
        return Menu {
            ForEach(Array(kinds.enumerated()), id: \.offset) { index, kind in
                Button(kind.name) { mirror.placeKind = index }
            }
        } label: {
            wrapping(kinds[current].name).frame(minHeight: 44)
        }
        .spoken(spokenLabels["stone-kind"])
        .accessibilityHint(Text(verbatim: "Chooses the stone that Place puts on the sand"))
        .accessibilityIdentifier(port.identifier("stone-kind"))
    }

    /// A stone button sending `control` with `values`, disabled when `values` is nil.
    private func stoneButton(_ title: String, name: String, hint: String, values: [Double]?,
                             control: String, _ spokenLabels: [String: GardenControlLabel]) -> some View {
        Button {
            guard let values else { return }
            port.send(control, values)
        } label: {
            wrapping(title).frame(minWidth: 44, minHeight: 44)
        }
        .disabled(values == nil)
        .spoken(spokenLabels[name])
        .accessibilityHint(Text(verbatim: hint))
        .accessibilityIdentifier(port.identifier(name))
    }

    /// A nudge button moving the selected stone by `dx`, `dy` nudge steps.
    private func nudgeButton(_ title: String, name: String, dx: Int, dy: Int,
                             _ spokenLabels: [String: GardenControlLabel]) -> some View {
        stoneButton(title, name: "stone-nudge-" + name, hint: "Moves the selected stone a little " + name,
                    values: StoneControlValues.nudge(dx: dx, dy: dy, stones: mirror.stones,
                                                     selected: mirror.selectedStone),
                    control: "stone.move", spokenLabels)
    }

    /// The four pattern buttons, each raking one stroke with the chosen rake.
    private func patternButtons(_ spokenLabels: [String: GardenControlLabel]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            wrapping("Rake a pattern").font(.subheadline).accessibilityHidden(true)
            row {
                ForEach(Array(StrokePatterns.names.enumerated()), id: \.offset) { index, pattern in
                    Button {
                        presenter.rakePattern(index, port: port)
                    } label: {
                        wrapping(StrokePatterns.titles[index]).frame(minHeight: 44)
                    }
                    .spoken(spokenLabels["pattern-" + pattern])
                    .accessibilityHint(Text(verbatim: "Rakes the pattern into the sand with the chosen rake"))
                    .accessibilityIdentifier(port.identifier("pattern-" + pattern))
                }
            }
        }
    }

    // MARK: Library and picture (feature 148)

    /// The library: the name field, Save, and each saved garden with Open, Rename and Delete.
    private func librarySection(_ entries: [GardenLibraryEntry],
                                _ spokenLabels: [String: GardenControlLabel]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            wrapping("Saved gardens").font(.subheadline).accessibilityAddTraits(.isHeader)
            row {
                TextField(text: $name) { Text(verbatim: "Garden name") }
                    .textFieldStyle(.roundedBorder)
                    .frame(minHeight: 44)
                    .spoken(spokenLabels["library-name"])
                    .accessibilityIdentifier(port.identifier("library-name"))
                Button {
                    if presenter.library?.entry(named: name) != nil, let clean = GardenLibrary.cleanName(name) {
                        replacing = clean
                    } else {
                        presenter.saveGarden(named: name)
                    }
                } label: {
                    wrapping("Save").frame(minWidth: 44, minHeight: 44)
                }
                .spoken(spokenLabels["library-save"])
                .accessibilityHint(Text(verbatim: "Saves the garden under this name"))
                .accessibilityIdentifier(port.identifier("library-save"))
            }
            ForEach(entries) { entry in
                let n = String(entry.number)
                if entry.isReadable {
                    VStack(alignment: .leading, spacing: 4) {
                        wrapping(entry.name).accessibilityHidden(true)
                        row {
                            libraryButton("Open", name: "library-open-" + n, hint: "Opens this garden; the undo "
                                          + "history starts again", spokenLabels) {
                                if case .success(let opened) = presenter.openGarden(entry.file) { name = opened.name }
                            }
                            libraryButton("Rename", name: "library-rename-" + n, hint: "Gives this garden a new name",
                                          spokenLabels) {
                                newName = entry.name
                                renaming = entry
                            }
                            libraryButton("Delete", name: "library-delete-" + n,
                                          hint: "Deletes the saved copy; the open garden stays", spokenLabels) {
                                deleting = entry
                            }
                        }
                    }
                } else {
                    row {
                        wrapping("Unreadable: \(entry.name) (\(entry.refusal ?? "damaged"))").font(.footnote)
                            .spoken(spokenLabels["library-unreadable-" + n])
                            .accessibilityIdentifier(port.identifier("library-unreadable-" + n))
                        libraryButton("Delete", name: "library-delete-" + n, hint: "Deletes the unreadable file",
                                      spokenLabels) {
                            deleting = entry
                        }
                    }
                }
            }
            if let message = mirror.libraryMessage {
                wrapping(message).font(.footnote)
                    .accessibilityIdentifier(port.identifier("library-message"))
            }
        }
    }

    /// A library button running `action`.
    private func libraryButton(_ title: String, name: String, hint: String,
                               _ spokenLabels: [String: GardenControlLabel],
                               action: @escaping () -> Void) -> some View {
        Button(action: action) {
            wrapping(title).frame(minWidth: 44, minHeight: 44)
        }
        .spoken(spokenLabels[name])
        .accessibilityHint(Text(verbatim: hint))
        .accessibilityIdentifier(port.identifier(name))
    }

    /// The picture: "Make picture" and, once written, the share control of the PNG file.
    private func stillSection(_ spokenLabels: [String: GardenControlLabel]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            wrapping("Picture").font(.subheadline).accessibilityAddTraits(.isHeader)
            row {
                Button {
                    presenter.makeStill(renderer: stillRenderer)
                } label: {
                    wrapping("Make picture").frame(minWidth: 44, minHeight: 44)
                }
                .spoken(spokenLabels["still-make"])
                .accessibilityHint(Text(verbatim: "Draws the garden at \(GardenStill.width) by \(GardenStill.height) "
                                        + "pixels"))
                .accessibilityIdentifier(port.identifier("still-make"))
                if let url = mirror.stillURL {
                    ShareLink(item: GardenStillFile(url: url), preview: SharePreview(Text(verbatim: "Zen garden"))) {
                        wrapping("Share picture").frame(minWidth: 44, minHeight: 44)
                    }
                    .spoken(spokenLabels["still-share"])
                    .accessibilityIdentifier(port.identifier("still-share"))
                }
            }
            if let message = mirror.stillMessage {
                wrapping(message).font(.footnote)
                    .accessibilityIdentifier(port.identifier("still-message"))
            }
        }
    }
}
