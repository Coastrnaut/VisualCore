// SlotTests — feature 168 (A23-P03) T-A23-302 (FR-A23-304; SC-A23-303; clarification Q2; User Story 3). Slots are
// assigned in pass order (lowest free slot, freed after the last read): a chain of five slot-writing passes needs 2
// slots; a graph needing exactly 6 slots compiles and one needing 7 is refused with "This graph needs 7 textures; the
// preview allows 6."; bytes are slots × 256 × 256 × 4; no pass writes a slot it reads, and every slot read holds the
// picture of a node feeding the reader. Synthetic data only.
import Testing
import VisualProgrammingLabCore

@Suite struct SlotTests {
    typealias F = GraphFixtures
    typealias C = CompilerFixtures

    @Test func theBudgetConstants() {
        #expect(PassSchedule.previewSize == 256)
        #expect(PassSchedule.slotLimit == 6)
        #expect(PassSchedule.bytesPerSlot == 262_144)
    }

    @Test func aChainOfFivePassesUsesTwoSlots() {
        guard let schedule = C.compiled(C.chainOfFive) else {
            Issue.record("the chain was refused")
            return
        }
        #expect(schedule.passes.map(\.operator) == [.noise, .blurH, .blurV, .blurH, .blurV, .output])
        #expect(schedule.passes.map(\.target) == [.slot(0), .slot(1), .slot(0), .slot(1), .slot(0), .framebuffer])
        #expect(schedule.slotCount == 2)
        #expect(schedule.bytes == 2 * 262_144)
    }

    @Test func aGraphNeedingExactlySixSlotsCompiles() {
        let schedule = C.compiled(C.fan(5))
        #expect(schedule?.slotCount == 6)
        #expect(schedule?.bytes == 1_572_864)
        #expect(schedule?.passes.count == 10)
    }

    @Test func aGraphNeedingSevenSlotsIsRefusedWithTheSentence() {
        let result = GraphCompiler.compile(C.fan(6))
        #expect(result == .failure(.overBudget(slots: 7)))
        if case .failure(let refusal) = result {
            #expect(refusal.message == "This graph needs 7 textures; the preview allows 6.")
        }
        // The graph at the node and connection limits draws six noises before its first mix.
        #expect(GraphCompiler.compile(F.atLimits) == .failure(.overBudget(slots: 7)))
    }

    @Test func bytesAreSlotsTimesSlotBytes() {
        for (name, graph) in F.acyclic + [("chain", C.chainOfFive), ("fan-5", C.fan(5))] {
            guard let schedule = C.compiled(graph) else { continue }
            #expect(schedule.bytes == schedule.slotCount * PassSchedule.bytesPerSlot, "\(name)")
            #expect((1...PassSchedule.slotLimit).contains(schedule.slotCount), "\(name)")
        }
    }

    @Test func everySlotReadHoldsThePictureOfAFeedingNode() {
        let graphs = [("journey", F.journeyMix), ("full-library", F.fullLibrary), ("chain", C.chainOfFive),
                      ("fan-5", C.fan(5)), ("descending", F.descendingIDs)]
        for (name, graph) in graphs {
            guard let schedule = C.compiled(graph) else {
                Issue.record("\(name): refused")
                continue
            }
            var writer: [Int: (node: NodeID, operator: PassOperator)] = [:]
            for pass in schedule.passes {
                for (sampler, slot) in pass.inputs {
                    #expect(pass.target != .slot(slot), "\(name): \(pass.node) writes the slot it reads")
                    guard let source = writer[slot] else {
                        Issue.record("\(name): \(pass.node) \(sampler) reads an unwritten slot")
                        continue
                    }
                    let feeds = graph.edges.contains { $0.sourceNode == source.node && $0.targetNode == pass.node }
                    let ownHalf = source.node == pass.node && source.operator == .blurH && pass.operator == .blurV
                    #expect(feeds || ownHalf, "\(name): \(pass.node) \(sampler) reads \(source.node)")
                }
                if case .slot(let slot) = pass.target { writer[slot] = (pass.node, pass.operator) }
            }
        }
    }
}
