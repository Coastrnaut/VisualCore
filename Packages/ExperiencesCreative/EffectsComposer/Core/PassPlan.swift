// PassPlan — feature 181 (A25-P02) T-A25-203 (clarification Q1; data-model.md "PassPlan"). The pass compiler: the
// enabled nodes of a chain, in order, become passes that ping-pong between two slots. The first pass reads the source,
// pass k reads slot (k − 1) % 2 and writes slot k % 2, and the last writes the result; a single enabled node reads the
// source and writes the result; an empty or all-disabled chain is one copy pass from the source to the result.
// Each slot write lives from its writer to its single reader (the next pass), so at most two slots are alive at a
// time and no pass reads its own output. Choice recorded here: a slot is written more than once in a long chain, so
// `lifetimes` holds every interval of a slot in pass order. Pure Swift; no UI, GPU or clock.

/// Where a pass reads from or writes to.
public enum PassEndpoint: Equatable, Sendable {
    /// The source picture (the test image).
    case source
    /// One of the two intermediate slots, numbered 0 and 1.
    case slot(Int)
    /// The result picture that the preview presents.
    case result
}

/// One pass of a plan: an effect node (or a plain copy) from one endpoint to another.
public struct PlanPass: Equatable, Sendable {
    /// The node whose effect the pass runs, or nil for a copy.
    public let node: EffectNode?
    /// What the pass samples.
    public let input: PassEndpoint
    /// What the pass draws into.
    public let output: PassEndpoint

    /// A pass running `node` (nil for a copy) from `input` to `output`.
    public init(node: EffectNode?, input: PassEndpoint, output: PassEndpoint) {
        self.node = node
        self.input = input
        self.output = output
    }
}

/// The compiled passes of a chain (clarification Q1).
public struct PassPlan: Equatable, Sendable {
    /// The passes in the order they run; never empty.
    public let passes: [PlanPass]
    /// How many distinct slots the plan uses: 0, 1 or 2.
    public let slotsUsed: Int
    /// For each slot used, the intervals it is alive, in pass order: each runs from the index of the pass that writes
    /// the slot to the index of the single pass that reads it.
    public let lifetimes: [Int: [ClosedRange<Int>]]

    /// A plan of `passes`, `slotsUsed` slots and `lifetimes`.
    public init(passes: [PlanPass], slotsUsed: Int, lifetimes: [Int: [ClosedRange<Int>]]) {
        self.passes = passes
        self.slotsUsed = slotsUsed
        self.lifetimes = lifetimes
    }

    /// The plan of `chain`: its enabled nodes in order, ping-ponging between slots 0 and 1; one copy pass from the
    /// source to the result when no node is enabled.
    public static func compile(_ chain: EffectChain) -> PassPlan {
        let enabled = chain.nodes.filter(\.enabled)
        guard !enabled.isEmpty else {
            return PassPlan(passes: [PlanPass(node: nil, input: .source, output: .result)], slotsUsed: 0, lifetimes: [:])
        }
        let last = enabled.count - 1
        var passes: [PlanPass] = []
        var lifetimes: [Int: [ClosedRange<Int>]] = [:]
        for (k, node) in enabled.enumerated() {
            let input: PassEndpoint = k == 0 ? .source : .slot((k - 1) % 2)
            let output: PassEndpoint = k == last ? .result : .slot(k % 2)
            passes.append(PlanPass(node: node, input: input, output: output))
            if k != last { lifetimes[k % 2, default: []].append(k...(k + 1)) }
        }
        return PassPlan(passes: passes, slotsUsed: lifetimes.count, lifetimes: lifetimes)
    }

    /// The largest number of slot intervals alive at any one pass (a slot counts while its writer or reader runs).
    public var maxLiveSlots: Int {
        let intervals = lifetimes.values.flatMap { $0 }
        return passes.indices.map { k in intervals.filter { $0.contains(k) }.count }.max() ?? 0
    }

    /// Whether any pass samples the endpoint it draws into; always false for a compiled plan.
    public func readsItsOutput() -> Bool {
        passes.contains { $0.input == $0.output }
    }
}
