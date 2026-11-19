// RepeatabilityView — feature 177 (A24-P05) T-A24-505 (FR-A24-502, FR-A24-503, FR-A24-504; clarifications Q1–Q5;
// User Stories 1–3; contracts/review.md "Identifiers"; gap G-DEVICE). How the qualification and the repeatability of
// a run are shown, and the presenter's explanation actions:
//
//   - ``QualificationText``: the class word ("Valid", "Qualified", "Invalid") and the reason sentences of
//     `QualificationReason.sentence`.
//   - ``QualificationView``: the element `qualification`, the class word and one line per reason, spoken as
//     "Qualification, <word>, <sentences>"; shown in the controls after any run ends (finished, stopped or
//     interrupted) and in the opened result.
//   - ``RepeatabilityView``: the block `repeatability` of the opened result: the comparable trials by save order with
//     their frame interval p50 and p95 (two decimals) and GPU p50 when present, the spread lines when present
//     ("Spread of p50: …", "Spread of p95: …", "Spread of GPU p50: …"), "One trial; run it again to compare." with a
//     single comparable trial, the trials that are not comparable with their reason ("Another case or case version",
//     "Another device", "Another OS version", "Another app build", "Another quality tier", "Not valid") and `explain`.
//   - The presenter's ``BenchPresenter/repeatability(of:)`` (the library's readable results, the opened one as
//     `opened`), ``BenchPresenter/showExplanation(from:)`` and ``BenchPresenter/hideExplanation()``.
//
// Values in milliseconds are written by `BenchPresenter.milliseconds(text:)`, so no literal here carries a number
// with a unit. The views store only references and values, never a closure; buttons are at least 44 points high and
// the text wraps with Dynamic Type; nothing is told by colour alone.
import GraphicsBenchmarkLabCore
import SwiftUI
import VisualCoreExperienceHost

/// Where "About these numbers" was opened from.
enum ExplanationSource: String, Equatable, Sendable {
    /// The `explain` button of the opened result.
    case result
    /// The `explain` button of the repeatability block.
    case repeatability
}

/// The words of a qualification (clarifications Q1, Q2).
enum QualificationText {
    /// The class word: "Valid", "Qualified" or "Invalid".
    static func word(_ value: QualificationClass) -> String {
        switch value {
        case .valid: return "Valid"
        case .qualified: return "Qualified"
        case .invalid: return "Invalid"
        }
    }

    /// The reason sentences of `qualification`, in its order.
    static func sentences(_ qualification: Qualification) -> [String] {
        var result: [String] = []
        for reason in qualification.reasons { result.append(reason.sentence) }
        return result
    }

    /// The lines shown: the class word, then one sentence per reason.
    static func lines(_ qualification: Qualification) -> [String] {
        [word(qualification.class)] + sentences(qualification)
    }

    /// The spoken label: "Qualification, <word>", then the sentences, joined by commas.
    static func label(_ qualification: Qualification) -> String {
        (["Qualification"] + lines(qualification)).joined(separator: ", ")
    }
}

/// The qualification of a run: the element `qualification` (see the file header).
struct QualificationView: View {
    /// The port that names the element.
    let port: ExperienceActionPort
    /// The qualification shown.
    let qualification: Qualification

    /// The class word and the reason sentences.
    var body: some View {
        let lines = QualificationText.lines(qualification)
        VStack(alignment: .leading, spacing: 2) {
            ForEach(lines, id: \.self) { line in
                Text(verbatim: line)
                    .font(.footnote)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(verbatim: QualificationText.label(qualification)))
        .accessibilityIdentifier(port.identifier("qualification"))
    }
}

/// The repeatability block of the opened result (see the file header).
struct RepeatabilityView: View {
    /// The port that names the elements.
    let port: ExperienceActionPort
    /// The summary shown.
    let summary: RepeatabilitySummary
    /// The presenter whose ``BenchPresenter/showExplanation(from:)`` the `explain` button calls.
    let presenter: BenchPresenter

    /// The sentence of a trial that is not comparable.
    static func sentence(_ reason: NotComparableReason) -> String {
        switch reason {
        case .differentCase: return "Another case or case version"
        case .differentDevice: return "Another device"
        case .differentOS: return "Another OS version"
        case .differentBuild: return "Another app build"
        case .differentTier: return "Another quality tier"
        case .invalid: return "Not valid"
        }
    }

    /// The line of a comparable trial: "Trial <order>: p50 <x>, p95 <y>" and ", GPU p50 <z>" when it has one.
    static func trialLine(_ trial: Trial) -> String {
        var text = "Trial \(trial.order): p50 " + BenchPresenter.milliseconds(text: trial.intervalP50) + ", p95 "
            + BenchPresenter.milliseconds(text: trial.intervalP95)
        if let gpu = trial.gpuP50 { text += ", GPU p50 " + BenchPresenter.milliseconds(text: gpu) }
        return text
    }

    /// The line of a trial that is not comparable: "Trial <order>: not comparable, <reason>".
    static func notComparableLine(_ trial: NotComparableTrial) -> String {
        "Trial \(trial.order): not comparable, " + sentence(trial.reason)
    }

    /// The block's lines: the count of comparable trials, each trial, the spreads (or the one-trial sentence), then
    /// the trials that are not comparable.
    static func lines(_ summary: RepeatabilitySummary) -> [String] {
        var lines: [String] = []
        let count = summary.comparable.count
        if count == 0 {
            lines.append("No comparable trial.")
        } else if count == 1 {
            lines.append("One comparable trial.")
        } else {
            lines.append("\(count) comparable trials.")
        }
        for trial in summary.comparable { lines.append(trialLine(trial)) }
        if count == 1 { lines.append(oneTrial) }
        if let spread = summary.spreadP50Ms { lines.append("Spread of p50: " + BenchPresenter.milliseconds(text: spread)) }
        if let spread = summary.spreadP95Ms { lines.append("Spread of p95: " + BenchPresenter.milliseconds(text: spread)) }
        if let spread = summary.spreadGPUP50Ms {
            lines.append("Spread of GPU p50: " + BenchPresenter.milliseconds(text: spread))
        }
        for trial in summary.notComparable { lines.append(notComparableLine(trial)) }
        return lines
    }

    /// The sentence shown with a single comparable trial.
    static let oneTrial = "One trial; run it again to compare."

    /// The block.
    var body: some View {
        let lines = Self.lines(summary)
        VStack(alignment: .leading, spacing: 4) {
            Text(verbatim: "Repeatability")
                .font(.subheadline)
                .accessibilityAddTraits(.isHeader)
            VStack(alignment: .leading, spacing: 2) {
                ForEach(lines, id: \.self) { line in
                    Text(verbatim: line)
                        .font(.footnote)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(Text(verbatim: "Repeatability, " + lines.joined(separator: ", ")))
            Button {
                presenter.showExplanation(from: .repeatability)
            } label: {
                Text(verbatim: "About these numbers").frame(minHeight: 44)
            }
            .accessibilityLabel(Text(verbatim: "About these numbers"))
            .accessibilityHint(Text(verbatim: "Explains how trials are compared and why they differ"))
            .accessibilityIdentifier(port.identifier("explain"))
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(port.identifier("repeatability"))
    }
}

/// The presenter's repeatability and explanation actions (T-A24-505; contracts/review.md).
extension BenchPresenter {
    /// The repeatability of `opened` among the library's readable results (clarification Q3); `opened` alone without a
    /// library.
    func repeatability(of opened: OpenedResult) -> RepeatabilitySummary {
        var among: [OrderedRun] = []
        if let library {
            let entries = library.entries
            for entry in entries where entry.isReadable && entry.file != opened.entry.file {
                if case .success(let other) = library.open(file: entry.file) {
                    among.append(OrderedRun(order: other.entry.order, run: other.run))
                }
            }
        }
        return Repeatability.summarise(opened: OrderedRun(order: opened.entry.order, run: opened.run), among: among)
    }

    /// Shows "About these numbers" in the opened result, opened from `source`; nothing without an opened result.
    func showExplanation(from source: ExplanationSource) {
        guard mirror.openedResult != nil else { return }
        if mirror.explanationSource != source { mirror.explanationSource = source }
    }

    /// Hides "About these numbers".
    func hideExplanation() {
        if mirror.explanationSource != nil { mirror.explanationSource = nil }
    }
}
