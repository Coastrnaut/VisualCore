// ScientificReviewTests — feature 107 (A14-P05) T-A14-502 (FR-A14-501, FR-A14-502, FR-A14-504; SC-A14-501–503;
// clarifications Q2, Q3). The model statement is the text of clarification Q3; the review document is deterministic,
// LF, ends with one newline, names every event, the data-sources count with 0 problems, every tour caption and both
// scale labels; every number in a tour caption appears in the data-sources document; the committed
// `docs/apps/solar-system-explorer/scientific-review.md` equals the generated text. Host-free and short.
import Foundation
import SolarSystemExplorerCore
import Testing

@Suite struct ScientificReviewTests {
    @Test func theModelStatementIsClarificationQ3() {
        #expect(ScientificReview.modelStatement == "Positions come from an approximate model: Kepler orbits from the "
                + "planets' mean elements at epoch J2000.0 (E. M. Standish, JPL), held fixed, for dates from 1950 to "
                + "2050. They are not an ephemeris. In the enhanced view, sizes and distances are enlarged and not to "
                + "scale.")
    }

    @Test func theReviewIsDeterministicAndComplete() {
        let text = ScientificReview.markdown()
        #expect(ScientificReview.markdown() == text)
        #expect(text.hasPrefix("# Solar System Explorer — scientific review\n\n"))
        #expect(text.hasSuffix("\n") && !text.hasSuffix("\n\n") && !text.contains("\r"))
        #expect(text.contains("\n" + ScientificReview.modelStatement + "\n"))
        #expect(text.contains(SourceRecord.standishTitle) && text.contains(SourceRecord.standishLink))
        let sections: [String] = ["## The model\n", "## Checks against published events\n", "## Data sources\n",
                                  "## Tour captions\n", "## Scale labels\n"]
        for section in sections { #expect(text.contains(section), "\(section)") }
        #expect(text.contains("| Event | Published | Model | Offset (days) | Tolerance | Source | Result |\n"))
        for result in EventChecks.evaluateBundled() {
            let fixture = result.fixture
            let row = "| \(fixture.name) | \(fixture.publishedDate) | \(ScientificReview.modelDateLabel(result)) | "
                + "\(ScientificReview.offsetText(result)) | ±3 days | \(fixture.source) | pass |"
            #expect(text.contains(row), "\(row)")
        }
        #expect(!text.contains("| fail |"))
        #expect(text.contains("[data-sources.md](data-sources.md)"))
        #expect(ScientificReview.dataSourcesSummary() == "34 values; 0 problems.")
        #expect(text.contains("\n34 values; 0 problems.\n"))
        for tour in Tour.bundled {
            for stop in tour.stops { #expect(text.contains(stop.caption), "\(stop.caption)") }
        }
        for mode in ScaleMode.allCases { #expect(text.contains(mode.label), "\(mode.label)") }
    }

    /// The numbers of `text`: each maximal run of digits, "," and "." that starts with a digit, without a trailing
    /// "," or ".".
    private func numbers(in text: String) -> [String] {
        var found: [String] = []
        var current = ""
        for character in text {
            if character.isASCII && character.isNumber {
                current.append(character)
            } else if (character == "," || character == ".") && !current.isEmpty {
                current.append(character)
            } else {
                if !current.isEmpty { found.append(current) }
                current = ""
            }
        }
        if !current.isEmpty { found.append(current) }
        var trimmed: [String] = []
        for number in found {
            var value = number
            while value.hasSuffix(",") || value.hasSuffix(".") { value.removeLast() }
            if !value.isEmpty { trimmed.append(value) }
        }
        return trimmed
    }

    @Test func everyCaptionNumberIsInTheDataSources() {
        let sources = CitationAudit.markdown(.bundled)
        var checked = 0
        for tour in Tour.bundled {
            for stop in tour.stops {
                let values: [String] = numbers(in: stop.caption)
                #expect(!values.isEmpty, "\(stop.caption)")
                for value in values {
                    checked += 1
                    #expect(sources.contains(value), "\(value) of \"\(stop.caption)\" is in data-sources.md")
                }
            }
        }
        #expect(numbers(in: "Mars: mean radius 3,389.5 km; one orbit takes 686.98 days.") == ["3,389.5", "686.98"])
        #expect(checked >= 17, "the Sun's radius (and B3) and two values for each of the eight planets")
    }

    /// The committed `docs/apps/solar-system-explorer/scientific-review.md` equals the generated document; run the
    /// package tests with `UPDATE_SCIENTIFIC_REVIEW=1` (or `TEST_RUNNER_UPDATE_SCIENTIFIC_REVIEW=1` through
    /// xcodebuild) to rewrite it. Reads the repository through `#filePath`, so it runs from the repository's own
    /// package, not from a scratch copy.
    @Test func theCommittedReviewMatchesTheModel() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let file = root.appendingPathComponent("docs/apps/solar-system-explorer/scientific-review.md")
        let text = ScientificReview.markdown()
        let environment = ProcessInfo.processInfo.environment
        if environment["UPDATE_SCIENTIFIC_REVIEW"] == "1" || environment["TEST_RUNNER_UPDATE_SCIENTIFIC_REVIEW"] == "1" {
            try Data(text.utf8).write(to: file)
        }
        let committed = try String(contentsOf: file, encoding: .utf8)
        #expect(committed == text, "run with UPDATE_SCIENTIFIC_REVIEW=1 and commit the document")
    }
}
