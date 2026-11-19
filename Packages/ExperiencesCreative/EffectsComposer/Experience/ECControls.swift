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
// Every edit is a button, so nothing needs dragging (constitution A25 accessibility). Inline buttons, never a `Menu`, a
// popover or a sheet over the drawing (the A23-P05 lesson). The view stores only references (the port and the mirror),
// never a closure. Every button is at least 44 points high; the text wraps with Dynamic Type. The spoken labels are
// the pure static functions of ``ComposerLabels`` so that tests can read them.
import EffectsComposerCore
import Foundation
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
}

/// The native controls of Effects Composer (see the file header).
struct ECControls: View {
    /// The port of the experience (actions and identifiers).
    let port: ExperienceActionPort
    /// What the controls show.
    let mirror: ComposerMirror

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
            Text(verbatim: mirror.status)
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityLabel(Text(verbatim: "Status, " + mirror.status))
                .accessibilityIdentifier(port.identifier("status"))
            if !mirror.diagnostics.isEmpty {
                Text(verbatim: mirror.diagnostics)
                    .font(.footnote)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityLabel(Text(verbatim: "Program problems, " + mirror.diagnostics))
                    .accessibilityIdentifier(port.identifier("diagnostics"))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
