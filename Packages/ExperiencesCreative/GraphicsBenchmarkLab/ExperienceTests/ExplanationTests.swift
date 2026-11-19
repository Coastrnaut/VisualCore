// ExplanationTests — feature 177 (A24-P05) T-A24-506 (FR-A24-504; SC-A24-503; clarification "What does 'About these
// numbers' say, and where is it?"; User Story 3). "About these numbers":
//   - exactly the five sections of the clarification, in order, each with a heading and a text;
//   - every limit of User Story 3 is named: frame interval, CPU, GPU, thermal, Low Power Mode, display refresh,
//     background, case version, simulator, rank; and "a gap of over a second";
//   - the words carry no number with a unit and none of the denylist's frame or refresh phrases (the full scan is
//     `scripts/check_copy_claims.py` over the source);
//   - it is reachable from an opened result and from its repeatability block (the presenter's
//     ``BenchMirror/explanationSource``), never without an opened result, and closing the result hides it.
// Headings: the view marks the explanation's title and every section title with the header trait; the model gives each
// section a distinct title, which is what the view marks. Synthetic runs only: no clock, no sleep, no host.
import Foundation
import Testing
@testable import GraphicsBenchmarkLabExperience
import GraphicsBenchmarkLabCore

@Suite(.serialized) struct ExplanationTests {
    @Test func theExplanationHasTheFiveSectionsInOrder() {
        let titles = GBLExplanation.titles
        #expect(titles == ["What is measured", "Valid, qualified, invalid", "Why numbers differ", "Simulator numbers",
                           "What the lab does not do"])
        let unique = Set(titles)
        #expect(unique.count == titles.count, "each heading is distinct")
        for section in GBLExplanation.sections {
            let text = section.text
            #expect(!text.isEmpty, "\(section.title) has a text")
        }
        let title = GBLExplanation.title
        #expect(title == "About these numbers")
    }

    @Test func everyLimitOfUserStoryThreeIsNamed() {
        let text = GBLExplanation.fullText.lowercased()
        let limits = ["frame interval", "cpu", "gpu", "thermal", "low power mode", "display refresh", "background",
                      "case version", "simulator", "rank", "a gap of over a second"]
        for limit in limits {
            let present = text.contains(limit)
            #expect(present, "the explanation names \(limit)")
        }
    }

    @Test func theWordsCarryNoMeasuredClaim() throws {
        let text = GBLExplanation.fullText
        let lowered = text.lowercased()
        for phrase in ["frame rate", "framerate", "refresh rate", "fps", "smooth", "fast", "best", "battery"] {
            let present = lowered.contains(phrase)
            #expect(!present, "no \(phrase)")
        }
        let pattern = try NSRegularExpression(
            pattern: "\\b\\d+(\\.\\d+)?\\s*(fps|frames per second|ms|milliseconds|%|percent|hours?|hz|hertz)(?![A-Za-z])",
            options: [.caseInsensitive])
        let range = NSRange(text.startIndex..., in: text)
        let matches = pattern.numberOfMatches(in: text, range: range)
        #expect(matches == 0, "no number with a unit")
    }

    @MainActor
    @Test func theExplanationIsReachableFromAResultAndFromItsRepeatability() throws {
        let place = try BenchStoragePlace("explanation")
        defer { place.remove() }
        let exporter = ResultTest.exporter("explanation")
        defer { exporter.clear() }
        let presenter = BenchPresenter(storage: place.storage, exporter: exporter)
        presenter.showExplanation(from: .result)
        let without = presenter.mirror.explanationSource
        #expect(without == nil, "nothing to explain without an opened result")
        let library = try #require(presenter.library)
        _ = ResultTest.value(library.save(try QualificationFixture.ordinaryRun()))
        presenter.showResults()
        _ = try #require(ResultTest.value(presenter.openResult(file: "result-1.json")))
        let block = presenter.mirror.repeatability
        #expect(block != nil, "the opened result has its repeatability block")

        presenter.showExplanation(from: .result)
        let fromResult = presenter.mirror.explanationSource
        #expect(fromResult == .result)
        presenter.hideExplanation()
        let hidden = presenter.mirror.explanationSource
        #expect(hidden == nil)

        presenter.showExplanation(from: .repeatability)
        let fromBlock = presenter.mirror.explanationSource
        #expect(fromBlock == .repeatability)
        presenter.closeResult()
        let closed = presenter.mirror.explanationSource
        #expect(closed == nil, "closing the result hides the explanation")
    }
}
