// SolarControls — feature 103 (A14-P01) T-A14-103 (FR-A14-121; clarifications Q4, Q5). The native controls of Solar
// System Explorer in one section:
//   Previous body and Next body (`previous-body`, `next-body` → `body.previous` / `body.next`; disabled at the Sun
//     and at Neptune);
//   the Body menu (`body` → `body.select [index]`) listing the nine bodies by name in catalog order;
//   the fact card of the selected body (`fact-1`, `fact-2`, … in display order, each "Mean radius: 6,371 km —
//     Planetary Fact Sheet — Metric": label, value, unit, note and source);
//   the legend "Sizes and spacing not to scale" (`legend`), the status line (`status`: "Earth selected, body 4 of 9")
//     and the answer to a refused action (`message`, shown only when there is one).
// Every control has an accessible label and value (and a hint) and the identifier
// `experience.a14.solar-system-explorer.<name>` from the port; hit areas are at least 44 points high and text wraps.
import SolarSystemExplorerCore
import SwiftUI
import VisualCoreExperience
import VisualCoreExperienceHost

/// The controls of Solar System Explorer.
struct SolarControls: View {
    /// The port the controls send through.
    let port: ExperienceActionPort
    /// What the controls show.
    let mirror: SolarMirror

    /// The names of the bodies in catalog order (the Body menu's entries).
    static var bodyNames: [String] { SolarCore.catalog.bodies.map(\.name) }

    /// `status` with a capital first letter ("Loading" when empty).
    static func sentence(_ status: String) -> String {
        guard let first = status.first else { return "Loading" }
        return first.uppercased() + String(status.dropFirst())
    }

    /// The selected body in words: "Earth, body 4 of 9".
    static func bodyWords(index: Int, count: Int) -> String {
        "\(SolarCore.name(index: index)), body \(index + 1) of \(count)"
    }

    /// The identifier name of fact line `index` (0-based): `fact-1` for the first line.
    static func factName(_ index: Int) -> String { "fact-\(index + 1)" }

    /// The controls, or a progress indicator before the first state.
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
        let words = Self.bodyWords(index: mirror.selection, count: mirror.bodyCount)
        let atFirst = mirror.selection <= 0
        let atLast = mirror.selection >= mirror.bodyCount - 1
        VStack(alignment: .leading, spacing: 8) {
            Text(verbatim: "Solar System Explorer").font(.headline).accessibilityAddTraits(.isHeader)
            HStack(spacing: 8) {
                button("Previous body", name: "previous-body", value: words,
                       hint: atFirst ? "The Sun is the first body" : "Selects the body nearer the Sun",
                       enabled: !atFirst) { send("body.previous") }
                button("Next body", name: "next-body", value: words,
                       hint: atLast ? "Neptune is the last body" : "Selects the body farther from the Sun",
                       enabled: !atLast) { send("body.next") }
            }
            Menu {
                ForEach(Self.bodyNames.indices, id: \.self) { index in
                    Button {
                        send("body.select", [Double(index)])
                    } label: {
                        Text(verbatim: Self.bodyNames[index])
                    }
                }
            } label: {
                Text(verbatim: "Body")
                    .font(.body)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.bordered)
            .accessibilityLabel(Text(verbatim: "Body"))
            .accessibilityValue(Text(verbatim: words))
            .accessibilityHint(Text(verbatim: "Selects any of the nine bodies"))
            .accessibilityIdentifier(port.identifier("body"))
            Text(verbatim: mirror.bodyName).font(.subheadline).accessibilityAddTraits(.isHeader)
            ForEach(mirror.facts.indices, id: \.self) { index in
                Text(verbatim: mirror.facts[index])
                    .font(.footnote)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityLabel(Text(verbatim: "Fact \(index + 1)"))
                    .accessibilityValue(Text(verbatim: mirror.facts[index]))
                    .accessibilityIdentifier(port.identifier(Self.factName(index)))
            }
            Text(verbatim: SolarCore.notToScale)
                .font(.footnote.italic())
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityLabel(Text(verbatim: "Legend"))
                .accessibilityValue(Text(verbatim: SolarCore.notToScale))
                .accessibilityIdentifier(port.identifier("legend"))
            Text(verbatim: Self.sentence(mirror.status))
                .font(.footnote)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityLabel(Text(verbatim: "Status"))
                .accessibilityValue(Text(verbatim: Self.sentence(mirror.status)))
                .accessibilityIdentifier(port.identifier("status"))
            if !mirror.message.isEmpty {
                Text(verbatim: mirror.message)
                    .font(.footnote)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityLabel(Text(verbatim: "Message"))
                    .accessibilityValue(Text(verbatim: mirror.message))
                    .accessibilityIdentifier(port.identifier("message"))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Sends `control` with `values` through the port and shows the answer when it is refused.
    private func send(_ control: String, _ values: [Double] = []) {
        let result = port.send(control, values)
        mirror.message = SolarPresenter.answerWords(control: control, result: result)
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
