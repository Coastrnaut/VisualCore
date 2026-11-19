// ExplanationView — feature 177 (A24-P05) T-A24-505 (FR-A24-504; clarification "What does 'About these numbers'
// say, and where is it?"; User Story 3; contracts/review.md "Identifiers"). "About these numbers" (``GBLExplanation``)
// inline in the opened result, opened by `explain` from the opened result or from the repeatability block (never a
// sheet, a menu or a popover over the drawing: the A23-P05 lesson):
//
//   - the container `explanation` keeps its children separate (`accessibilityElement(children: .contain)`), so
//     VoiceOver reads each heading on its own;
//   - the explanation's heading and every section title are `Text` with the header trait; every section text is a
//     separate `Text` in the body style, wrapping with Dynamic Type; nothing is told by colour alone;
//   - `explanation-done` ("Done") closes it.
//
// The view stores only references (the port and the presenter), never a closure. The button is at least 44 points
// high.
import SwiftUI
import VisualCoreExperienceHost

/// "About these numbers", inline in the opened result (see the file header).
struct ExplanationView: View {
    /// The port that names the elements.
    let port: ExperienceActionPort
    /// The presenter whose ``BenchPresenter/hideExplanation()`` the Done button calls.
    let presenter: BenchPresenter

    /// The explanation.
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(verbatim: GBLExplanation.title)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            ForEach(GBLExplanation.sections) { section in
                Text(verbatim: section.title)
                    .font(.footnote.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                Text(verbatim: section.text)
                    .font(.footnote)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Button {
                presenter.hideExplanation()
            } label: {
                Text(verbatim: "Done").frame(minHeight: 44)
            }
            .accessibilityLabel(Text(verbatim: "Done with About these numbers"))
            .accessibilityIdentifier(port.identifier("explanation-done"))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text(verbatim: GBLExplanation.title))
        .accessibilityIdentifier(port.identifier("explanation"))
    }
}
