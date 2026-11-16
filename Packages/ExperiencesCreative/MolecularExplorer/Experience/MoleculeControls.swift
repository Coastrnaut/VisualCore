// MoleculeControls — feature 110 (A15-P01) T-A15-106 (FR-A15-131; clarification Q5). The native controls of Molecular
// Explorer in one section:
//   Previous molecule and Next molecule (`previous-molecule`, `next-molecule` → `molecule.previous` /
//     `molecule.next`; disabled at water and at caffeine, with a hint saying so);
//   the Molecule menu (`molecule` → `molecule.select [index]`) listing the five titles in library order;
//   the name and formula line (`name`: "Caffeine — C8H10N4O2"), the counts line (`counts`: "24 atoms, 25 bonds"), the
//     source line (`source`: "PubChem Compound CID 2519, 3D conformer — public domain"), the status line (`status`:
//     "Caffeine selected, molecule 5 of 5") and the answer to a refused action (`message`, shown only when there is
//     one).
// Every control and line has an accessible label and value (controls a hint too) and the identifier
// `experience.a15.molecular-explorer.<name>` from the port; hit areas are at least 44 points high and text wraps.
//
// The view holds references only — the port, the mirror and the presenter — and no closure: the host rebuilds the
// controls on every port revision, and SwiftUI keeps an open Molecule menu only when the rebuilt view compares equal
// (a stored closure never does; feature 108 T-A14-609, docs/automatedtesting.md). Actions go through the presenter.
import MolecularExplorerCore
import SwiftUI
import VisualCoreExperience
import VisualCoreExperienceHost

/// The controls of Molecular Explorer.
struct MoleculeControls: View {
    /// The port the controls send through.
    let port: ExperienceActionPort
    /// What the controls show.
    let mirror: MoleculeMirror
    /// The presenter every action goes through (it shows the answer to a refused action in the mirror). A reference,
    /// not a closure, so that the view compares equal from one host update to the next.
    let presenter: MoleculePresenter

    /// The titles of the molecules in library order (the Molecule menu's entries).
    static var moleculeTitles: [String] { MoleculeCore.library.map(\.title) }

    /// `status` with a capital first letter ("Loading" when empty).
    static func sentence(_ status: String) -> String {
        guard let first = status.first else { return "Loading" }
        return first.uppercased() + String(status.dropFirst())
    }

    /// The selected molecule in words: "Caffeine, molecule 5 of 5".
    static func moleculeWords(index: Int, count: Int) -> String {
        "\(MoleculeCore.title(index: index)), molecule \(index + 1) of \(count)"
    }

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

    /// The buttons, the menu and the lines.
    @ViewBuilder private var content: some View {
        let words = Self.moleculeWords(index: mirror.selection, count: mirror.moleculeCount)
        let atFirst = mirror.selection <= 0
        let atLast = mirror.selection >= mirror.moleculeCount - 1
        VStack(alignment: .leading, spacing: 8) {
            Text(verbatim: "Molecular Explorer").font(.headline).accessibilityAddTraits(.isHeader)
            HStack(spacing: 8) {
                button("Previous molecule", name: "previous-molecule", value: words,
                       hint: atFirst ? "Water is the first molecule" : "Selects the previous molecule",
                       enabled: !atFirst) { send("molecule.previous") }
                button("Next molecule", name: "next-molecule", value: words,
                       hint: atLast ? "Caffeine is the last molecule" : "Selects the next molecule",
                       enabled: !atLast) { send("molecule.next") }
            }
            Menu {
                ForEach(Self.moleculeTitles.indices, id: \.self) { index in
                    Button {
                        send("molecule.select", [Double(index)])
                    } label: {
                        Text(verbatim: Self.moleculeTitles[index])
                    }
                }
            } label: {
                Text(verbatim: "Molecule")
                    .font(.body)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.bordered)
            .accessibilityLabel(Text(verbatim: "Molecule"))
            .accessibilityValue(Text(verbatim: words))
            .accessibilityHint(Text(verbatim: "Selects any of the five molecules"))
            .accessibilityIdentifier(port.identifier("molecule"))
            line(mirror.nameLine, label: "Name and formula", name: "name", font: .subheadline)
            line(mirror.countsLine, label: "Counts", name: "counts", font: .footnote)
            line(mirror.sourceLine, label: "Source", name: "source", font: .footnote)
            line(Self.sentence(mirror.status), label: "Status", name: "status", font: .footnote)
            if !mirror.message.isEmpty {
                line(mirror.message, label: "Message", name: "message", font: .footnote)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Sends `control` with `values` through the presenter, which shows the answer when it is refused.
    private func send(_ control: String, _ values: [Double] = []) {
        presenter.send(control, values, through: port)
    }

    /// A wrapping text line `text` with the accessible label `label`, the value `text` and the identifier `name`.
    private func line(_ text: String, label: String, name: String, font: Font) -> some View {
        Text(verbatim: text)
            .font(font)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityLabel(Text(verbatim: label))
            .accessibilityValue(Text(verbatim: text))
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
