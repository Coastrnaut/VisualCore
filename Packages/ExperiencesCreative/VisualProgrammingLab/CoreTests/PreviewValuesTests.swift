// PreviewValuesTests — feature 168 (A23-P03) T-A23-302 (FR-A23-301, FR-A23-302; clarification Q1; edge case "Time").
// The floats and colours of every pass of the journey graph at two frame times (only Noise's time moves), the time of
// a Noise fed by Time as time × rate, a Constant's colour at both Gradient ends, and each value case on a synthetic
// pass. Synthetic data only.
import Testing
import VisualProgrammingLabCore

@Suite struct PreviewValuesTests {
    typealias F = GraphFixtures
    typealias C = CompilerFixtures

    @Test func everyJourneyPassAtTwoTimes() {
        guard let passes = C.compiled(F.journeyMix)?.passes, passes.count == 6 else {
            Issue.record("the journey graph did not compile into six passes")
            return
        }
        for time in [0.0, 1.5] {
            let floats = passes.map { PreviewValues.floats(for: $0, time: time) }
            #expect(floats == [["scale": 4, "octaves": 4, "speed": 0.5, "time": time], ["angle": 90],
                               ["amount": 0.5], ["radius": 4, "directionX": 1, "directionY": 0],
                               ["radius": 4, "directionX": 0, "directionY": 1], [:]], "t = \(time)")
        }
        #expect(PreviewValues.colours(for: passes[1])
                == ["start": PassColour(r: 0, g: 0, b: 0), "end": PassColour(r: 1, g: 1, b: 1)])
        for index in [0, 2, 3, 4, 5] { #expect(PreviewValues.colours(for: passes[index]).isEmpty, "\(index)") }
    }

    @Test func noiseFedByTimeRunsAtItsRate() {
        guard let passes = C.compiled(C.timed(constant: 3))?.passes, passes.count == 6 else {
            Issue.record("the full-library graph did not compile into six passes")
            return
        }
        #expect(PreviewValues.floats(for: passes[0], time: 0)["time"] == 0)
        #expect(PreviewValues.floats(for: passes[0], time: 1.5)["time"] == 3)
        #expect(PreviewValues.floats(for: passes[0], time: 1.5)["scale"] == 3)
        let colour = PassColour(r: 0.25, g: 0.5, b: 0.75)
        #expect(PreviewValues.colours(for: passes[1]) == ["start": colour, "end": colour])
        #expect(PreviewValues.floats(for: passes[1], time: 1.5) == ["angle": 90])
    }

    @Test func eachValueCaseResolves() {
        let pass = Pass(node: NodeID(1), operator: .noise, inputs: [:],
                        values: ["a": .scalar(2), "b": .time(rate: 0.5), "c": .frameTime,
                                 "d": .colour(r: 0.1, g: 0.2, b: 0.3)],
                        target: .slot(0), key: "k")
        #expect(PreviewValues.floats(for: pass, time: 4) == ["a": 2, "b": 2, "c": 4])
        #expect(PreviewValues.floats(for: pass, time: 0) == ["a": 2, "b": 0, "c": 0])
        #expect(PreviewValues.colours(for: pass) == ["d": PassColour(r: 0.1, g: 0.2, b: 0.3)])
    }
}
