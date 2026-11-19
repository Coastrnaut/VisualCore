// OutputTests — feature 166 (A23-P01) T-A23-107 (SC-A23-104; FR-A23-106; User Story 4; edge cases "an empty graph",
// "a node not connected to the output"; clarification Q4 stage 5). No output, two outputs, a disconnected output and
// an empty required input are refused naming the node and port; an empty optional input passes; a node that does not
// reach the output is ordered but not in `reaching`; the two journey graphs are accepted with the right order.
import Testing
import VisualProgrammingLabCore

@Suite struct OutputTests {
    typealias F = GraphFixtures

    @Test func anEmptyGraphHasNoOutput() {
        #expect(GraphChecker.check(F.empty) == .refused([.noOutput]))
        #expect(GraphChecker.check(F.noOutputNode) == .refused([.noOutput]))
    }

    @Test func twoOutputsAreNamed() {
        #expect(GraphChecker.check(F.twoOutputs) == .refused([.multipleOutputs(F.ids([2, 3]))]))
    }

    @Test func anOutputWithNothingConnectedIsDisconnected() {
        #expect(GraphChecker.check(F.disconnectedOutput) == .refused([.outputDisconnected(NodeID(2))]))
    }

    @Test func aMixWithOneImageInputEmptyNamesThatNodeAndInput() {
        #expect(GraphChecker.check(F.mixMissingB) == .refused([.inputUnconnected(node: NodeID(2), port: "b")]))
        #expect(GraphChecker.check(F.mixMissingA) == .refused([.inputUnconnected(node: NodeID(2), port: "a")]))
    }

    @Test func anEmptyRequiredInputOffThePathIsStillRefused() {
        #expect(GraphChecker.check(F.unreachedEmptyInput)
                == .refused([.inputUnconnected(node: NodeID(3), port: "image")]))
    }

    @Test func emptyOptionalInputsPass() {
        #expect(GraphChecker.check(F.optionalInputsEmpty)
                == .accepted(order: F.ids([1, 2]), reaching: Set(F.ids([1, 2]))))
        #expect(GraphChecker.check(F.journeyMix)   // the mix amount and blur radius are empty
                == .accepted(order: F.ids([1, 2, 3, 4, 5]), reaching: Set(F.ids([1, 2, 3, 4, 5]))))
    }

    @Test func aNodeNotReachingTheOutputIsOrderedButNotMarked() {
        #expect(GraphChecker.check(F.unreachedBranch)
                == .accepted(order: F.ids([1, 2, 3, 4]), reaching: Set(F.ids([1, 2]))))
        guard case .accepted(let order, let reaching) = GraphChecker.check(F.atLimits) else {
            Issue.record("the graph at the limits was refused")
            return
        }
        #expect(order.count == 32)
        #expect(reaching == Set(F.ids([1, 2, 3, 4, 5, 6, 7, 8, 27, 28, 29, 30, 31, 32])))
    }

    @Test func theJourneyGraphsAreAcceptedInOrder() {
        #expect(GraphChecker.check(F.noiseToOutput) == .accepted(order: F.ids([1, 2]), reaching: Set(F.ids([1, 2]))))
        #expect(GraphChecker.check(F.journeyMix)
                == .accepted(order: F.ids([1, 2, 3, 4, 5]), reaching: Set(F.ids([1, 2, 3, 4, 5]))))
        #expect(GraphChecker.check(F.fullLibrary)
                == .accepted(order: F.ids([1, 3, 2, 4, 5, 6, 7]), reaching: Set(F.ids(Array(1...7)))))
    }

    @Test func everyOutputRefusalNamesItsCode() {
        let codes: [(VisualGraph, String)] = [(F.empty, "no-output"), (F.twoOutputs, "multiple-outputs"),
                                              (F.disconnectedOutput, "output-disconnected"),
                                              (F.mixMissingB, "input-unconnected")]
        for (graph, code) in codes {
            guard case .refused(let issues) = GraphChecker.check(graph) else {
                Issue.record("\(code): accepted")
                continue
            }
            #expect(issues.map(\.code) == [code])
        }
    }
}
