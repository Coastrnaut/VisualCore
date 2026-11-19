// GBLControls — feature 174 (A24-P02) T-A24-207 (FR-A24-205; clarification Q4; contracts/experience.md
// "Accessibility identifiers"). The native controls of Graphics Benchmark Lab. Every control reads the presenter's
// mirror, sends through the shell's port, has a spoken label and an identifier
// `experience.a24.graphics-benchmark-lab.<name>`:
//
//   - `case-quads`, `case-alu`, `case-particles`: an inline list of the three built-in cases, one button each
//     (`case.select [index]`); the selected one is marked with a check and the selected trait;
//   - `run-start` ("Start run", `run.start`) and `run-stop` ("Stop run", `run.stop`);
//   - `status`: the status word ("Ready", "Warm-up", "Measuring", "Cool-down", "Finished", "Stopped",
//     "Interrupted");
//   - `summary`: after a finished run, the summary block (interval percentiles, frame counts, flag sentences).
//
// Inline buttons, never a `Menu`, a menu-style `Picker`, a popover or a sheet over the drawing (the A23-P05 lesson: while
// a menu is up over a canvas that presents new frames, the system never reports the app idle). The view stores only
// references (the port and the mirror), never a closure: a controls view that stores closures never compares equal and
// is rebuilt every frame. Every button is at least 44 points high; the text wraps with Dynamic Type.
import GraphicsBenchmarkLabCore
import SwiftUI
import VisualCoreExperienceHost

/// The native controls of Graphics Benchmark Lab (see the file header).
struct GBLControls: View {
    /// The port of the experience (actions and identifiers).
    let port: ExperienceActionPort
    /// What the controls show.
    let mirror: BenchMirror

    /// The identifier name of the button of the case at `index`: `case-<id>`, for example `case-alu`.
    static func caseName(_ index: Int) -> String {
        "case-" + (BenchCore.cases.indices.contains(index) ? BenchCore.cases[index].id : "unknown")
    }

    /// The controls.
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(verbatim: "Graphics Benchmark Lab").font(.headline).accessibilityAddTraits(.isHeader)
            VStack(alignment: .leading, spacing: 4) {
                ForEach(BenchCore.cases.indices, id: \.self) { index in
                    caseButton(index)
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel(Text(verbatim: "Cases"))
            HStack(spacing: 12) {
                Button {
                    _ = port.send("run.start")
                } label: {
                    Text(verbatim: "Start run").frame(minHeight: 44)
                }
                .disabled(mirror.running)
                .accessibilityLabel(Text(verbatim: "Start run"))
                .accessibilityHint(Text(verbatim: "Runs the selected case: warm-up, measurement, then cool-down"))
                .accessibilityIdentifier(port.identifier("run-start"))
                Button {
                    _ = port.send("run.stop")
                } label: {
                    Text(verbatim: "Stop run").frame(minHeight: 44)
                }
                .disabled(!mirror.running)
                .accessibilityLabel(Text(verbatim: "Stop run"))
                .accessibilityHint(Text(verbatim: "Ends the run now; a stopped run has no summary"))
                .accessibilityIdentifier(port.identifier("run-stop"))
            }
            Text(verbatim: mirror.status)
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityLabel(Text(verbatim: "Status, " + mirror.status))
                .accessibilityIdentifier(port.identifier("status"))
            if !mirror.summaryLines.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(mirror.summaryLines, id: \.self) { line in
                        Text(verbatim: line)
                            .font(.footnote)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(Text(verbatim: "Summary, " + mirror.summaryLines.joined(separator: ", ")))
                .accessibilityIdentifier(port.identifier("summary"))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// The button of the case at `index`, marked when it is the selected case.
    private func caseButton(_ index: Int) -> some View {
        let title = BenchPresenter.title(ofCase: index)
        let selected = mirror.selectedCase == index
        return Button {
            _ = port.send("case.select", [Double(index)])
        } label: {
            HStack(spacing: 8) {
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .accessibilityHidden(true)
                Text(verbatim: title)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(minHeight: 44)
        }
        .accessibilityLabel(Text(verbatim: title))
        .accessibilityValue(Text(verbatim: selected ? "Selected" : ""))
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityHint(Text(verbatim: "Chooses this case; a run in progress stops"))
        .accessibilityIdentifier(port.identifier(Self.caseName(index)))
    }
}
