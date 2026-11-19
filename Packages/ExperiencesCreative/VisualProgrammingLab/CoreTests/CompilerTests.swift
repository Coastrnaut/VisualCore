// CompilerTests — feature 168 (A23-P03) T-A23-302 (FR-A23-301, FR-A23-303; SC-A23-302; clarification Q1; edge cases
// "a node not reaching the Output", "scalar and colour nodes"). The starter graph compiles into a noise pass and the
// output pass with one slot; the journey graph into noise, gradient, mix, blur-h, blur-v and output in the checker's
// order with the right slot inputs; Time and Constant become values (time × rate, clamped connected scalars, a
// Constant's colour, black and white defaults, the frame time); a node not reaching the Output makes no pass; every
// invalid fixture compiles into no pass with the checker's status. Also holds the compiler fixtures the slot, key and
// value tests share. Synthetic data only.
import Testing
import VisualProgrammingLabCore

/// Graphs and helpers shared by the compiler, slot, key and value tests.
enum CompilerFixtures {
    typealias F = GraphFixtures

    /// The schedule of `graph`, or nil when it is refused.
    static func compiled(_ graph: VisualGraph) -> PassSchedule? {
        try? GraphCompiler.compile(graph).get()
    }

    /// `graph` with the stored parameters of node `id` replaced by `parameters`.
    static func setting(_ graph: VisualGraph, _ id: Int, _ parameters: [String: Double]) -> VisualGraph {
        var copy = graph
        copy.nodes = copy.nodes.map { node in
            var node = node
            if node.id == NodeID(id) { node.parameters = parameters }
            return node
        }
        return copy
    }

    /// The full-library graph with Time(1) at rate 2 and Constant(3) of value `value` and colour (0.25, 0.5, 0.75).
    static func timed(constant value: Double) -> VisualGraph {
        let graph = setting(F.fullLibrary, 1, ["rate": 2])
        return setting(graph, 3, ["value": value, "red": 0.25, "green": 0.5, "blue": 0.75])
    }

    /// Noise(1) → Blur(2) → Blur(3) → Output(4): five passes writing slots.
    static var chainOfFive: VisualGraph {
        VisualGraph(nodes: [F.node(1, .noise), F.node(2, .blur), F.node(3, .blur), F.node(4, .output)],
                    edges: [F.edge(1, "image", 2, "image"), F.edge(2, "image", 3, "image"),
                            F.edge(3, "image", 4, "image")])
    }

    /// `noises` Noise nodes (1…n) folded by a chain of Mix nodes (n + 1 … 2n − 1) into Output(2n). Every noise is
    /// drawn before the first mix, so the peak is n + 1 slots.
    static func fan(_ noises: Int) -> VisualGraph {
        var nodes = (1...noises).map { F.node($0, .noise) }
        var edges: [GraphEdge] = []
        for step in 1..<noises {
            let mix = noises + step
            nodes.append(F.node(mix, .mix))
            edges.append(F.edge(step == 1 ? 1 : mix - 1, "image", mix, "a"))
            edges.append(F.edge(step + 1, "image", mix, "b"))
        }
        nodes.append(F.node(2 * noises, .output))
        edges.append(F.edge(2 * noises - 1, "image", 2 * noises, "image"))
        return VisualGraph(nodes: nodes, edges: edges)
    }
}

@Suite struct CompilerTests {
    typealias F = GraphFixtures
    typealias C = CompilerFixtures

    @Test func theStarterGraphCompilesIntoNoiseAndOutputWithOneSlot() {
        guard let schedule = C.compiled(F.noiseToOutput) else {
            Issue.record("the starter graph was refused")
            return
        }
        #expect(schedule.passes.map(\.operator) == [.noise, .output])
        #expect(schedule.passes.map(\.node) == F.ids([1, 2]))
        #expect(schedule.slotCount == 1)
        #expect(schedule.passes.map(\.target) == [.slot(0), .framebuffer])
        #expect(schedule.passes.map(\.inputs) == [[:], ["u_image": 0]])
        #expect(schedule.passes.first?.values
                == ["scale": .scalar(4), "octaves": .scalar(4), "speed": .scalar(0.5), "time": .frameTime])
    }

    @Test func theJourneyGraphCompilesInTheCheckersOrderWithItsSlotInputs() {
        guard let schedule = C.compiled(F.journeyMix) else {
            Issue.record("the journey graph was refused")
            return
        }
        #expect(schedule.passes.map(\.operator) == [.noise, .gradient, .mix, .blurH, .blurV, .output])
        #expect(schedule.passes.map(\.node) == F.ids([1, 2, 3, 4, 4, 5]))
        #expect(schedule.passes.map(\.inputs)
                == [[:], [:], ["u_a": 0, "u_b": 1], ["u_image": 2], ["u_image": 0], ["u_image": 1]])
        #expect(schedule.passes.map(\.target) == [.slot(0), .slot(1), .slot(2), .slot(0), .slot(1), .framebuffer])
        #expect(schedule.slotCount == 3)
        #expect(PassOperator.allCases.map(\.rawValue) == ["noise", "gradient", "mix", "blur-h", "blur-v", "output"])
    }

    @Test func blurIsTwoPassesWithItsDirections() {
        guard let schedule = C.compiled(F.journeyMix), schedule.passes.count == 6 else {
            Issue.record("the journey graph did not compile into six passes")
            return
        }
        #expect(schedule.passes[3].values == ["radius": .scalar(4), "directionX": .scalar(1), "directionY": .scalar(0)])
        #expect(schedule.passes[4].values == ["radius": .scalar(4), "directionX": .scalar(0), "directionY": .scalar(1)])
        #expect(schedule.passes[2].values == ["amount": .scalar(0.5)])
        #expect(schedule.passes[1].values
                == ["angle": .scalar(90), "start": .colour(r: 0, g: 0, b: 0), "end": .colour(r: 1, g: 1, b: 1)])
        #expect(schedule.passes[5].values.isEmpty)
    }

    @Test func timeAndConstantBecomeValuesNotPasses() {
        guard let schedule = C.compiled(C.timed(constant: 3)), schedule.passes.count == 6 else {
            Issue.record("the full-library graph did not compile into six passes")
            return
        }
        #expect(schedule.passes.map(\.node) == F.ids([2, 4, 5, 6, 6, 7]))   // Time 1 and Constant 3 make no pass
        #expect(schedule.passes[0].values
                == ["scale": .scalar(3), "octaves": .scalar(4), "speed": .scalar(0.5), "time": .time(rate: 2)])
        let colour = PassValue.colour(r: 0.25, g: 0.5, b: 0.75)
        #expect(schedule.passes[1].values == ["angle": .scalar(90), "start": colour, "end": colour])
        #expect(schedule.passes[2].values == ["amount": .scalar(1)])            // 3 clamped to 0…1
        #expect(schedule.passes[3].values["radius"] == .scalar(3))
        #expect(schedule.passes[4].values["radius"] == .scalar(3))
    }

    @Test func connectedScalarsAreClampedToTheInputsRange() {
        guard let low = C.compiled(C.timed(constant: -8)), let high = C.compiled(C.timed(constant: 8)),
              low.passes.count == 6, high.passes.count == 6 else {
            Issue.record("the full-library graph did not compile")
            return
        }
        #expect(low.passes[0].values["scale"] == .scalar(0.5))
        #expect(low.passes[2].values["amount"] == .scalar(0))
        #expect(low.passes[3].values["radius"] == .scalar(0))
        #expect(high.passes[0].values["scale"] == .scalar(8))
        #expect(high.passes[2].values["amount"] == .scalar(1))
        #expect(high.passes[3].values["radius"] == .scalar(8))
    }

    @Test func storedParametersReachThePassesAndMissingOnesTakeTheirDefaults() {
        let graph = C.setting(F.noiseToOutput, 1, ["octaves": 2])
        #expect(C.compiled(graph)?.passes.first?.values
                == ["scale": .scalar(4), "octaves": .scalar(2), "speed": .scalar(0.5), "time": .frameTime])
        let gradient = C.setting(F.optionalInputsEmpty, 1, ["angle": 45])
        #expect(C.compiled(gradient)?.passes.first?.values
                == ["angle": .scalar(45), "start": .colour(r: 0, g: 0, b: 0), "end": .colour(r: 1, g: 1, b: 1)])
    }

    @Test func aNodeNotReachingTheOutputMakesNoPass() {
        let schedule = C.compiled(F.unreachedBranch)
        #expect(schedule?.passes.map(\.node) == F.ids([1, 2]))
        #expect(schedule?.slotCount == 1)
    }

    @Test func everyInvalidFixtureCompilesIntoNoPassWithTheCheckersStatus() {
        var fixtures: [(name: String, graph: VisualGraph, status: String)] = [
            ("empty", F.empty, "No output"), ("no-output-node", F.noOutputNode, "No output"),
            ("disconnected-output", F.disconnectedOutput, "Output not connected"),
            ("mix-missing-b", F.mixMissingB, "Mix 2: input b is empty"),
            ("mix-missing-a", F.mixMissingA, "Mix 2: input a is empty"),
            ("unreached-empty-input", F.unreachedEmptyInput, "Blur 3: input image is empty"),
            ("two-outputs", F.twoOutputs, "More than one output")]
        for (name, graph) in F.cycles { fixtures.append((name, graph, "The graph has a loop")) }
        for fixture in fixtures {
            let result = GraphCompiler.compile(fixture.graph)
            #expect(result == .failure(.invalid(fixture.status)), "\(fixture.name)")
            #expect(fixture.status == EditMessages.status(for: GraphChecker.check(fixture.graph), in: fixture.graph),
                    "\(fixture.name)")
            if case .failure(let refusal) = result { #expect(refusal.message == fixture.status, "\(fixture.name)") }
        }
    }

    @Test func everyFixtureTheCheckerRefusesIsInvalidAndEveryAcceptedOneIsNot() {
        for (name, graph) in F.all {
            let refused: Bool
            if case .refused = GraphChecker.check(graph) { refused = true } else { refused = false }
            let invalid: Bool
            if case .failure(.invalid) = GraphCompiler.compile(graph) { invalid = true } else { invalid = false }
            #expect(refused == invalid, "\(name)")
        }
    }

    @Test func theRefusalSentences() {
        #expect(CompileRefusal.overBudget(slots: 7).message == "This graph needs 7 textures; the preview allows 6.")
        #expect(CompileRefusal.invalid("Output not connected").message == "Output not connected")
    }
}
