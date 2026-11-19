// PassPlanTests — feature 181 (A25-P02) T-A25-204 (SC-A25-201; clarification Q1, Q2). The pass compiler on every chain
// shape: empty, single, all-disabled, mixed and full (8) chains give passes holding only the enabled nodes in order;
// no pass reads its output; each slot interval starts at its writer and ends at its single reader; at most two slots
// are alive. The 256 × 256 test image keeps the 64 × 64 pattern and `make()` equals `make(size: 64)`.
import Testing
@testable import EffectsComposerCore

@Suite struct PassPlanTests {
    /// A chain of `count` nodes cycling through the five effects, identifiers 1…count, enabled per `enabled(index)`.
    private func chain(count: Int, enabled: (Int) -> Bool = { _ in true }) -> EffectChain {
        EffectChain(nodes: (0..<count).map {
            EffectNode(id: $0 + 1, effect: EffectID.allCases[$0 % 5], enabled: enabled($0))
        })
    }

    /// Checks the invariants of clarification Q1 on the plan of `chain`.
    private func checkInvariants(_ chain: EffectChain, sourceLocation: SourceLocation = #_sourceLocation) {
        let plan = PassPlan.compile(chain)
        let enabled = chain.nodes.filter(\.enabled)
        #expect(!plan.readsItsOutput(), sourceLocation: sourceLocation)
        for pass in plan.passes { #expect(pass.input != pass.output, sourceLocation: sourceLocation) }
        #expect(plan.passes.first?.input == .source, sourceLocation: sourceLocation)
        #expect(plan.passes.last?.output == .result, sourceLocation: sourceLocation)
        #expect(plan.maxLiveSlots <= 2, sourceLocation: sourceLocation)
        #expect(plan.slotsUsed == min(max(enabled.count - 1, 0), 2), sourceLocation: sourceLocation)
        #expect(plan.lifetimes.count == plan.slotsUsed, sourceLocation: sourceLocation)
        if enabled.isEmpty {
            #expect(plan.passes == [PlanPass(node: nil, input: .source, output: .result)], sourceLocation: sourceLocation)
            return
        }
        #expect(plan.passes.map(\.node) == enabled.map { Optional($0) }, sourceLocation: sourceLocation)
        // Every slot interval: written by its lower bound, read only by its upper bound, nothing else touches it.
        for (slot, intervals) in plan.lifetimes {
            for interval in intervals {
                #expect(plan.passes[interval.lowerBound].output == .slot(slot), sourceLocation: sourceLocation)
                #expect(plan.passes[interval.upperBound].input == .slot(slot), sourceLocation: sourceLocation)
                #expect(interval.upperBound == interval.lowerBound + 1, sourceLocation: sourceLocation)
            }
        }
        let writes = plan.passes.indices.filter { if case .slot = plan.passes[$0].output { true } else { false } }
        let reads = plan.passes.indices.filter { if case .slot = plan.passes[$0].input { true } else { false } }
        let intervals = plan.lifetimes.values.flatMap { $0 }
        #expect(intervals.map(\.lowerBound).sorted() == writes, sourceLocation: sourceLocation)
        #expect(intervals.map(\.upperBound).sorted() == reads, sourceLocation: sourceLocation)
    }

    @Test func emptyChainIsOneCopyPass() {
        let plan = PassPlan.compile(.empty)
        #expect(plan.passes == [PlanPass(node: nil, input: .source, output: .result)])
        #expect(plan.slotsUsed == 0)
        #expect(plan.lifetimes.isEmpty)
        #expect(plan.maxLiveSlots == 0)
        checkInvariants(.empty)
    }

    @Test func singleNodeReadsSourceWritesResult() {
        let one = chain(count: 1)
        let plan = PassPlan.compile(one)
        #expect(plan.passes == [PlanPass(node: one.nodes[0], input: .source, output: .result)])
        #expect(plan.slotsUsed == 0)
        checkInvariants(one)
    }

    @Test func allDisabledChainIsOneCopyPass() {
        let off = chain(count: 5, enabled: { _ in false })
        #expect(PassPlan.compile(off) == PassPlan.compile(.empty))
        checkInvariants(off)
    }

    @Test func mixedChainKeepsOnlyEnabledNodesInOrder() {
        let mixed = chain(count: 6, enabled: { $0 % 3 != 1 })  // nodes 1, 3, 4, 6 enabled
        let plan = PassPlan.compile(mixed)
        #expect(plan.passes.compactMap(\.node?.id) == [1, 3, 4, 6])
        #expect(plan.passes.map(\.input) == [.source, .slot(0), .slot(1), .slot(0)])
        #expect(plan.passes.map(\.output) == [.slot(0), .slot(1), .slot(0), .result])
        #expect(plan.lifetimes == [0: [0...1, 2...3], 1: [1...2]])
        #expect(plan.slotsUsed == 2)
        #expect(plan.maxLiveSlots == 2)
        checkInvariants(mixed)
    }

    @Test func twoNodesUseOneSlot() {
        let two = chain(count: 2)
        let plan = PassPlan.compile(two)
        #expect(plan.passes.map(\.input) == [.source, .slot(0)])
        #expect(plan.passes.map(\.output) == [.slot(0), .result])
        #expect(plan.lifetimes == [0: [0...1]])
        checkInvariants(two)
    }

    @Test func everyChainShapeKeepsTheInvariants() {
        for count in 0...ChainLimits.maxNodes {
            checkInvariants(chain(count: count))
            checkInvariants(chain(count: count, enabled: { $0 % 2 == 0 }))
            checkInvariants(chain(count: count, enabled: { $0 % 2 == 1 }))
        }
        let full = PassPlan.compile(chain(count: ChainLimits.maxNodes))
        #expect(full.passes.count == 8)
        #expect(full.slotsUsed == 2)
        #expect(full.maxLiveSlots == 2)
    }

    @Test func sizedTestImageKeepsThePattern() {
        #expect(TestImage.make(size: 64) == TestImage.make())
        let image = TestImage.make(size: 256)
        #expect(image.width == 256 && image.height == 256)
        // Cells are 32 px. (x, y, red, green, blue)
        let samples: [(Int, Int, UInt8, UInt8, UInt8)] = [
            (0, 0, 0, 0, 255), (255, 255, 255, 255, 255), (31, 0, 31, 0, 255), (32, 0, 32, 0, 0),
            (0, 32, 0, 32, 0), (32, 32, 32, 32, 255), (100, 200, 100, 200, 0), (128, 64, 128, 64, 255),
        ]
        for (x, y, red, green, blue) in samples {
            #expect(image.pixel(x: x, y: y) == SIMD4(red, green, blue, 255), "pixel (\(x), \(y))")
        }
        #expect(TestImage.make(size: 4).width == TestImage.minimumSize)
        #expect(TestImage.make(size: 4_096).width == TestImage.maximumSize)
        #expect(TestImage.size == 64)
    }
}
