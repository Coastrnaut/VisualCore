// ECControls — feature 181 (A25-P02) T-A25-206 (FR-A25-203; clarification Q5; contracts/experience.md "Identifiers").
// The native inline controls of Effects Composer. Every control reads the presenter's mirror, sends through the
// shell's port, has a spoken label naming the effect, its position and the value, and an identifier
// `experience.a25.effects-composer.<name>`:
//
//   - `add-<effect>` (`add-grade`, `add-blur`, …): adds the effect at the end of the chain (`chain.add [effect, count]`);
//   - per node at position i (from 0): `node-<i>` (the row's label), `enable-<i>` (`chain.enable [i, on]`), `up-<i>`
//     and `down-<i>` (`chain.move [i, i ∓ 1]`), `remove-<i>` (`chain.remove [i]`), and for each parameter
//     `value-<i>-<name>-down` and `value-<i>-<name>-up`, which step the value by a tenth of its range, clamped
//     (`chain.set [i, parameter, fraction]`);
//   - `undo` (`edit.undo`) and `redo` (`edit.redo`);
//   - `status`: "Ready" or the message of the last refused action; `diagnostics`: the programs that did not build.
//
// Feature 182 (A25-P03) T-A25-304, T-A25-305, T-A25-307 (clarifications Q1, Q3, Q5; contracts/presets.md):
//   - `compare` ("Show original" / "Show result"): `view.compare [on]`; the status then says "Original";
//   - `presets` (inline, never a menu): the name field `preset-name`, `preset-save` (saves the chain under the typed
//     name), and per preset `preset-row-<n>` (its name; an unreadable file says so with its code), `preset-open-<n>`
//     (readable presets only) and `preset-remove-<n>`, `<n>` the file's number; `preset-message`, the library's last
//     sentence. Without storage the section says that presets are not available;
//   - each node row `node-<i>` offers the named accessibility actions of ``ComposerLabels/actions(for:in:)`` ("Move
//     up", "Move down", "Turn off" or "Turn on", "Raise <name>", "Lower <name>"), applied through the presenter as
//     the matching buttons apply them.
// Feature 183 (A25-P04) T-A25-406 (clarification Q4; contracts/import.md): the picture section, inline:
//   - `import` ("Choose a picture"): the system photo picker (SwiftUI `PhotosPicker`, images only), which runs out of
//     process; the picked item's data (`loadTransferable(type: Data.self)`) goes to the presenter's import. A cancelled
//     pick (no item) and an item without data change nothing; the selection is cleared after each pick, so the same
//     photo can be picked again;
//   - `test-picture` ("Use the test picture"): returns to the built-in test picture.
// The presets section acts through ``ComposerPresetActions`` (the presenter's actions, held weakly).
//
// Every edit is a button, so nothing needs dragging (constitution A25 accessibility). Inline buttons, never a `Menu`, a
// popover or a sheet over the drawing (the A23-P05 lesson). The view stores the port, the mirror and the presenter's
// weakly held actions. Every button is at least 44 points high; the text wraps with Dynamic Type. The spoken labels are
// the pure static functions of ``ComposerLabels`` so that tests can read them.
import EffectsComposerCore
import Foundation
import PhotosUI
import SwiftUI
import VisualCoreExperience
import VisualCoreExperienceHost

/// The spoken labels and value steps of the controls (pure, for the tests).
enum ComposerLabels {
    /// `value` as the controls say it: a whole number without decimals, otherwise at most three decimals without
    /// trailing zeros ("0.5", "1.25").
    static func number(_ value: Double, whole: Bool) -> String {
        if whole || value == value.rounded() { return "\(Int(value.rounded()))" }
        var text = String(format: "%.3f", value)
        while text.hasSuffix("0") { text.removeLast() }
        if text.hasSuffix(".") { text.removeLast() }
        return text
    }

    /// "<title>, effect <position> of <count>", the position counted from 1.
    static func place(_ row: NodeRow, count: Int) -> String {
        row.title + ", effect \(row.index + 1) of \(count)"
    }

    /// The label of the row `node-<i>`: "Color grade, effect 1 of 2, on, exposure 0, contrast 1, saturation 1".
    static func nodeLabel(_ row: NodeRow, count: Int) -> String {
        var parts = [place(row, count: count), row.enabled ? "on" : "off"]
        parts += row.parameters.map { $0.name + " " + number($0.value, whole: $0.spec.whole) }
        return parts.joined(separator: ", ")
    }

    /// The label of `enable-<i>`: "Turn off Color grade, effect 1 of 2, now on" (or "Turn on …, now off").
    static func enableLabel(_ row: NodeRow, count: Int) -> String {
        (row.enabled ? "Turn off " : "Turn on ") + place(row, count: count) + ", now " + (row.enabled ? "on" : "off")
    }

    /// The label of `up-<i>` or `down-<i>`: "Move Blur, effect 2 of 3, earlier" (or "later").
    static func moveLabel(_ row: NodeRow, count: Int, up: Bool) -> String {
        "Move " + place(row, count: count) + (up ? ", earlier" : ", later")
    }

    /// The label of `remove-<i>`: "Remove Blur, effect 2 of 3".
    static func removeLabel(_ row: NodeRow, count: Int) -> String {
        "Remove " + place(row, count: count)
    }

    /// The label of `value-<i>-<name>-up` or `-down`: "Raise radius of Blur, effect 2 of 3, now 2" (or "Lower …").
    static func valueLabel(_ row: NodeRow, _ parameter: ParameterRow, count: Int, up: Bool) -> String {
        (up ? "Raise " : "Lower ") + parameter.name + " of " + place(row, count: count) + ", now "
            + number(parameter.value, whole: parameter.spec.whole)
    }

    /// The label of `add-<effect>`: "Add Blur as effect 3".
    static func addLabel(_ effect: EffectID, count: Int) -> String {
        "Add " + EffectLibrary.definition(effect).title + " as effect \(count + 1)"
    }

    /// The fraction `chain.set` takes for one step of `parameter` up or down: the value moved by a tenth of the range,
    /// clamped to it, as a fraction of the range.
    static func stepFraction(_ parameter: ParameterRow, up: Bool) -> Double {
        let range = parameter.spec.range
        let step = (range.upperBound - range.lowerBound) / 10
        let next = min(max(parameter.value + (up ? step : -step), range.lowerBound), range.upperBound)
        return ComposerCore.fraction(of: parameter.spec, value: next)
    }

    /// The label of the `compare` toggle: "Show original" while the result is shown, else "Show result".
    static func compareLabel(_ compare: Bool) -> String {
        compare ? "Show result" : "Show original"
    }

    /// The named accessibility actions of the node at `index` of `chain`, in order: "Move up" (absent for the first),
    /// "Move down" (absent for the last), "Turn off" or "Turn on", then "Raise <name>" and "Lower <name>" for each
    /// parameter in definition order. Empty for an index with no node.
    static func actions(for index: Int, in chain: EffectChain) -> [String] {
        guard chain.nodes.indices.contains(index) else { return [] }
        let node = chain.nodes[index]
        var names: [String] = []
        if index > 0 { names.append("Move up") }
        if index < chain.nodes.count - 1 { names.append("Move down") }
        names.append(node.enabled ? "Turn off" : "Turn on")
        for parameter in node.definition.parameters {
            names.append("Raise " + parameter.name)
            names.append("Lower " + parameter.name)
        }
        return names
    }

    /// The core action the named accessibility action `name` of the node at `index` of `chain` applies: a move by one
    /// place, the enabled flag flipped, or a parameter stepped by a tenth of its range (``stepFraction(_:up:)``); nil
    /// for a name ``actions(for:in:)`` does not list.
    static func command(named name: String, for index: Int,
                        in chain: EffectChain) -> (control: String, values: [Double])? {
        guard actions(for: index, in: chain).contains(name) else { return nil }
        let row = NodeRow(node: chain.nodes[index], index: index)
        switch name {
        case "Move up": return ("chain.move", [Double(index), Double(index - 1)])
        case "Move down": return ("chain.move", [Double(index), Double(index + 1)])
        case "Turn off": return ("chain.enable", [Double(index), 0])
        case "Turn on": return ("chain.enable", [Double(index), 1])
        default:
            for (slot, parameter) in row.parameters.enumerated() {
                if name == "Raise " + parameter.name {
                    return ("chain.set", [Double(index), Double(slot), stepFraction(parameter, up: true)])
                }
                if name == "Lower " + parameter.name {
                    return ("chain.set", [Double(index), Double(slot), stepFraction(parameter, up: false)])
                }
            }
            return nil
        }
    }

    /// The spoken label of `import`: "Choose a picture".
    static let importLabel = "Choose a picture"
    /// The spoken label of `test-picture`: "Use the test picture".
    static let testPictureLabel = "Use the test picture"

    /// The label of `preset-row-<n>`: the preset's name, or "<name>, unreadable (<code>)".
    static func presetLabel(_ entry: LookLibraryEntry) -> String {
        entry.refusal.map { entry.name + ", unreadable (" + $0 + ")" } ?? entry.name
    }
}

/// The native controls of Effects Composer (see the file header).
struct ECControls: View {
    /// The port of the experience (actions and identifiers).
    let port: ExperienceActionPort
    /// What the controls show.
    let mirror: ComposerMirror
    /// The presenter's library and accessibility actions.
    let presets: ComposerPresetActions
    /// The name typed into `preset-name`.
    @State private var presetName = ""
    /// The item picked in `import`; nil when nothing is picked (or after it was handed over).
    @State private var pickedItem: PhotosPickerItem?

    /// Sends `control` with `values` and shows "Ready" or the refusal's message in the status line.
    @MainActor
    static func send(_ port: ExperienceActionPort, _ mirror: ComposerMirror, _ control: String,
                     _ values: [Double] = []) {
        let message = ComposerPresenter.message(for: port.send(control, values).code)
        if mirror.status != message { mirror.status = message }
    }

    /// The controls.
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(verbatim: "Effects Composer").font(.headline).accessibilityAddTraits(.isHeader)
            addButtons
            ForEach(mirror.rows, id: \.id) { row in
                nodeRow(row)
            }
            HStack(spacing: 12) {
                button("Undo", label: "Undo the last edit", name: "undo", enabled: mirror.canUndo) {
                    Self.send(port, mirror, "edit.undo")
                }
                button("Redo", label: "Redo the last undone edit", name: "redo", enabled: mirror.canRedo) {
                    Self.send(port, mirror, "edit.redo")
                }
            }
            button(ComposerLabels.compareLabel(mirror.compare), label: ComposerLabels.compareLabel(mirror.compare),
                   name: "compare", enabled: true) {
                Self.send(port, mirror, "view.compare", [mirror.compare ? 0 : 1])
            }
            Text(verbatim: mirror.shownStatus)
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityLabel(Text(verbatim: "Status, " + mirror.shownStatus))
                .accessibilityIdentifier(port.identifier("status"))
            if !mirror.diagnostics.isEmpty {
                Text(verbatim: mirror.diagnostics)
                    .font(.footnote)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityLabel(Text(verbatim: "Program problems, " + mirror.diagnostics))
                    .accessibilityIdentifier(port.identifier("diagnostics"))
            }
            pictureSection
            presetsSection
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onChange(of: pickedItem) { _, item in
            guard let item else { return }
            pickedItem = nil
            Self.load(item, into: presets.importPicture)
        }
    }

    /// Loads the data of the picked `item` and hands it to `importPicture`; an item without data does nothing.
    @MainActor
    static func load(_ item: PhotosPickerItem, into importPicture: @escaping @MainActor (Data) -> Void) {
        Task { @MainActor in
            guard let data = try? await item.loadTransferable(type: Data.self) else { return }
            importPicture(data)
        }
    }

    /// The inline picture controls: `import` (the photo picker) and `test-picture`.
    private var pictureSection: some View {
        HStack(spacing: 12) {
            PhotosPicker(selection: $pickedItem, matching: .images) {
                Text(verbatim: ComposerLabels.importLabel)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(minWidth: 44, minHeight: 44)
            }
            .accessibilityLabel(Text(verbatim: ComposerLabels.importLabel))
            .accessibilityIdentifier(port.identifier("import"))
            button("Test picture", label: ComposerLabels.testPictureLabel, name: "test-picture", enabled: true) {
                presets.useTestPicture()
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text(verbatim: "Picture"))
    }

    /// The inline presets: the name field, the save button, one row per preset and the library's message.
    private var presetsSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(verbatim: "Presets").font(.subheadline).accessibilityAddTraits(.isHeader)
            if mirror.hasLibrary {
                HStack(spacing: 12) {
                    TextField("Preset name", text: $presetName)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .frame(minHeight: 44)
                        .accessibilityLabel(Text(verbatim: "Preset name"))
                        .accessibilityIdentifier(port.identifier("preset-name"))
                    button("Save", label: "Save the chain as a preset", name: "preset-save",
                           enabled: !mirror.presetsReadOnly) {
                        if case .success = presets.save(presetName) { presetName = "" }
                    }
                }
                ForEach(mirror.presets) { entry in
                    presetRow(entry)
                }
            } else {
                Text(verbatim: "Presets are not available here.").font(.footnote)
            }
            if let message = mirror.libraryMessage {
                Text(verbatim: message)
                    .font(.footnote)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityLabel(Text(verbatim: "Presets, " + message))
                    .accessibilityIdentifier(port.identifier("preset-message"))
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(port.identifier("presets"))
    }

    /// The row of one preset: its name, `preset-open-<n>` (readable only) and `preset-remove-<n>`.
    private func presetRow(_ entry: LookLibraryEntry) -> some View {
        let n = entry.number
        return HStack(spacing: 12) {
            Text(verbatim: ComposerLabels.presetLabel(entry))
                .font(.footnote)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier(port.identifier("preset-row-\(n)"))
            if entry.isReadable {
                button("Open", label: "Open the preset " + entry.name, name: "preset-open-\(n)", enabled: true) {
                    _ = presets.open(entry.file)
                }
            }
            button("Remove", label: "Remove the preset " + entry.name, name: "preset-remove-\(n)",
                   enabled: !mirror.presetsReadOnly) {
                _ = presets.remove(entry.file)
            }
        }
    }

    /// One `add-<effect>` button per effect.
    private var addButtons: some View {
        let count = mirror.rows.count
        return VStack(alignment: .leading, spacing: 4) {
            ForEach(ComposerCore.effects, id: \.self) { effect in
                button("Add " + EffectLibrary.definition(effect).title,
                       label: ComposerLabels.addLabel(effect, count: count), name: "add-" + effect.rawValue,
                       enabled: count < ChainLimits.maxNodes) {
                    Self.send(port, mirror, "chain.add",
                              [Double(ComposerCore.effects.firstIndex(of: effect) ?? 0), Double(count)])
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text(verbatim: "Add an effect"))
    }

    /// The row of the node `row`: its label, its buttons and its parameters.
    private func nodeRow(_ row: NodeRow) -> some View {
        let count = mirror.rows.count
        let i = row.index
        return VStack(alignment: .leading, spacing: 4) {
            Text(verbatim: "\(i + 1). " + row.title + (row.enabled ? "" : " (off)"))
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityLabel(Text(verbatim: ComposerLabels.nodeLabel(row, count: count)))
                .accessibilityIdentifier(port.identifier("node-\(i)"))
                .accessibilityActions {
                    ForEach(ComposerLabels.actions(for: i, in: mirror.chain), id: \.self) { name in
                        Button(name) { presets.perform(name, i) }
                    }
                }
            HStack(spacing: 12) {
                button(row.enabled ? "Turn off" : "Turn on", label: ComposerLabels.enableLabel(row, count: count),
                       name: "enable-\(i)", enabled: true) {
                    Self.send(port, mirror, "chain.enable", [Double(i), row.enabled ? 0 : 1])
                }
                button("Up", label: ComposerLabels.moveLabel(row, count: count, up: true), name: "up-\(i)",
                       enabled: i > 0) {
                    Self.send(port, mirror, "chain.move", [Double(i), Double(i - 1)])
                }
                button("Down", label: ComposerLabels.moveLabel(row, count: count, up: false), name: "down-\(i)",
                       enabled: i < count - 1) {
                    Self.send(port, mirror, "chain.move", [Double(i), Double(i + 1)])
                }
                button("Remove", label: ComposerLabels.removeLabel(row, count: count), name: "remove-\(i)",
                       enabled: true) {
                    Self.send(port, mirror, "chain.remove", [Double(i)])
                }
            }
            ForEach(Array(row.parameters.enumerated()), id: \.offset) { index, parameter in
                parameterRow(row, parameter, index: index, count: count)
            }
        }
    }

    /// The value line and the `-down` and `-up` steps of one parameter.
    private func parameterRow(_ row: NodeRow, _ parameter: ParameterRow, index: Int, count: Int) -> some View {
        let i = row.index
        let base = "value-\(i)-\(parameter.name)"
        return HStack(spacing: 12) {
            Text(verbatim: parameter.name + " " + ComposerLabels.number(parameter.value, whole: parameter.spec.whole))
                .font(.footnote)
                .accessibilityHidden(true)
            button("−", label: ComposerLabels.valueLabel(row, parameter, count: count, up: false), name: base + "-down",
                   enabled: parameter.value > parameter.spec.range.lowerBound) {
                Self.send(port, mirror, "chain.set",
                          [Double(i), Double(index), ComposerLabels.stepFraction(parameter, up: false)])
            }
            button("+", label: ComposerLabels.valueLabel(row, parameter, count: count, up: true), name: base + "-up",
                   enabled: parameter.value < parameter.spec.range.upperBound) {
                Self.send(port, mirror, "chain.set",
                          [Double(i), Double(index), ComposerLabels.stepFraction(parameter, up: true)])
            }
        }
    }

    /// A button showing `title`, spoken as `label`, identified as `name`, at least 44 points high.
    private func button(_ title: String, label: String, name: String, enabled: Bool,
                        action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(verbatim: title)
                .fixedSize(horizontal: false, vertical: true)
                .frame(minWidth: 44, minHeight: 44)
        }
        .disabled(!enabled)
        .accessibilityLabel(Text(verbatim: label))
        .accessibilityIdentifier(port.identifier(name))
    }
}
