// AnatomyReview — feature 128 (A17-P05) T-A17-502 (FR-A17-503, FR-A17-504; SC-A17-501; clarification Q3;
// data-model "AnatomyReview"; contracts/review.md). The words of the review: the model statement, shown at the top of
// the panel whether or not a part is selected, and a part's review lines, shown after its citations:
//   - the editorial entry (if any): "Text checked against its sources by the lead engineer on <date>.";
//   - then the clinical line: "Reviewed by <reviewer> on <date>." for the part's clinical entry, otherwise
//     "Not reviewed by a clinician.".
// Without a record (none, or the bundled one was refused) the lines are only "Not reviewed by a clinician.", so a
// failed record is never shown as a review.
import Foundation

/// The model statement and the review lines of a part (see the file header).
public enum AnatomyReview {
    /// The statement shown with the model at all times.
    public static let modelStatement = "Schematic model for learning; shapes are simplified."
    /// The clinical line of a part without a clinical entry.
    public static let notReviewedSentence = "Not reviewed by a clinician."

    /// The editorial line for a review on `date`.
    public static func editorialSentence(date: String) -> String {
        "Text checked against its sources by the lead engineer on \(date)."
    }

    /// The clinical line for a review by `reviewer` on `date`.
    public static func clinicalSentence(reviewer: String, date: String) -> String {
        "Reviewed by \(reviewer) on \(date)."
    }

    /// The review lines of the part `partID` in `record`: the editorial line (if any), then the clinical line; with
    /// no record only "Not reviewed by a clinician.".
    public static func lines(partID: String, record: AnatomyReviewRecord?) -> [String] {
        guard let record else { return [notReviewedSentence] }
        let entries = record.entries(for: partID)
        var lines: [String] = []
        if let editorial = entries.first(where: { $0.kind == .editorial }) {
            lines.append(editorialSentence(date: editorial.date))
        }
        if let clinical = entries.first(where: { $0.kind == .clinical }) {
            lines.append(clinicalSentence(reviewer: clinical.reviewer, date: clinical.date))
        } else {
            lines.append(notReviewedSentence)
        }
        return lines
    }
}
