// ExampleTests — feature 169 (A23-P04) T-A23-406 (FR-A23-404; SC-A23-404, SC-A23-406; clarification Q4; User Story 3).
// The three examples written in code (`clouds`, `soft-gradient`, `mixed-clouds`): each passes the checker, compiles
// within the preview's budget of 6 textures, is a graph the file format writes, has a licence line and a menu item
// `example-<id>` with a spoken label; opened from the starter graph through the presenter (no confirmation is needed:
// nothing was changed) by the same restore path as a saved graph, each becomes the core's graph with no selection, the
// preview compiles it at the next frame and its inset is not flat (the luma of its pixels spans more than 8 of 255).
// Through the one app's session host; short runs only (no sleep, no wall-clock assertion).
import CoreGraphics
import Foundation
import Testing
import VisualCoreExperience
import VisualCoreExperienceHost
@testable import VisualProgrammingLabExperience
import VisualProgrammingLabCore

@MainActor
@Suite(.serialized) struct ExampleTests {
    /// The side of the stills: 192 pixels, so the inset is 64 × 64.
    static let side = 192

    /// The Rec. 709 luma of every pixel of the RGBA8 `pixels`.
    static func lumas(_ pixels: [UInt8]) -> [Double] {
        stride(from: 0, to: pixels.count - 3, by: 4).map { i in
            0.2126 * Double(pixels[i]) + 0.7152 * Double(pixels[i + 1]) + 0.0722 * Double(pixels[i + 2])
        }
    }

    @Test func everyExamplePassesTheCheckerAndCompilesWithinTheBudget() throws {
        #expect(LabExamples.all.map(\.id) == ["clouds", "soft-gradient", "mixed-clouds"])
        #expect(LabExamples.all.map(\.title) == ["Clouds", "Soft gradient", "Mixed clouds"])
        for example in LabExamples.all {
            guard case .accepted = GraphChecker.check(example.graph) else {
                Issue.record("\(example.id): the checker refuses it")
                continue
            }
            guard case .success(let schedule) = GraphCompiler.compile(example.graph) else {
                Issue.record("\(example.id): it does not compile")
                continue
            }
            #expect(schedule.slotCount <= PassSchedule.slotLimit, "\(example.id) within the budget")
            #expect(try GraphDocument.decode(GraphDocument.encode(example.graph)) == example.graph, "\(example.id)")
            #expect(!example.licence.isEmpty && example.licence.contains("repository"))
            #expect(LabExamples.identifierName(example) == "example-" + example.id)
            #expect(LabExamples.spokenLabel(example) == "Open the example " + example.title)
            #expect(LabExamples.example(example.id) == example)
        }
        #expect(LabExamples.example("sunset") == nil)
        #expect(LabExamples.softGradient.graph.edges.contains(GraphEdge(from: NodeID(1), "colour", to: NodeID(2),
                                                                        "start")), "a Constant colour into start")
    }

    @Test(arguments: ["clouds", "soft-gradient", "mixed-clouds"])
    func eachExampleOpensAndDrawsANonFlatInset(id: String) async throws {
        let example = try #require(LabExamples.example(id))
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await LabTest.open(session, size: CGSize(width: 96, height: 96), preview: true)
        let presenter = shell.presenter
        let compiles = presenter.pipeline.compileCount
        #expect(presenter.request(.example(id)), "the starter graph is replaced without asking")
        let core = try LabTest.core(shell)
        #expect(LabLibraryTest.fingerprint(core.graph) == LabLibraryTest.fingerprint(example.graph))
        #expect(core.selection == nil && core.outcome?.code == LabCore.readyCode)
        try LabTest.draw(session)
        #expect(presenter.pipeline.compileCount == compiles + 1)
        #expect(presenter.previewState == .ready, "\(id): \(presenter.previewState)")
        let still = try LabTest.still(session, width: Self.side, height: Self.side, time: 1.25)
        let lumas = Self.lumas(LabTest.inset(still, width: Self.side, height: Self.side))
        let spread = (lumas.max() ?? 0) - (lumas.min() ?? 0)
        #expect(spread > 8, "\(id): the inset is not flat (luma spread \(spread))")
        #expect(session.renderHost?.resources.stats.leaked == 0)
    }
}
