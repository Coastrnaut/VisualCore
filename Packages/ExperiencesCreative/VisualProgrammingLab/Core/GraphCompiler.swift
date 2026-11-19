// GraphCompiler — feature 168 (A23-P03) T-A23-302 (FR-A23-301, FR-A23-303, FR-A23-304, FR-A23-305; SC-A23-302,
// SC-A23-303, SC-A23-304; clarifications Q1–Q3; data-model.md "Operator", "PassValue", "Pass", "PassSchedule",
// "CompileRefusal", "GraphCompiler"). Turns a checked graph into the bounded schedule of picture passes of a
// 256 × 256 preview:
//   - a graph the checker refuses compiles into no pass: `.invalid` with the checker's status line;
//   - texture nodes reaching the Output, in the checker's order, become passes (Noise, Gradient and Mix one each,
//     Blur two: `blur-h` then `blur-v`, Output one into the framebuffer); Time and Constant become values;
//   - slots are assigned in pass order: an output takes the lowest free slot, a slot is freed after the last pass
//     that reads it, and a schedule needing more than 6 slots is refused before any allocation;
//   - each node has a content key (kind, parameters, and the keys and ports of the nodes feeding its inputs), so an
//     edit marks the node and everything downstream (`changed(from:to:)`). Positions are not part of a key.
// Choices recorded here: a key holds every declared parameter by its value (stored, else default), so a stored
// default and a missing parameter give the same key; parameters are added by their bit pattern (negative zero as
// zero), so a non-finite value never throws. Keys are computed for any graph (a node on a loop takes the marker
// "loop" for the input that closes it); an input fed twice uses its smallest connection in ``GraphEdge`` order.
// Blur's direction is given as the scalar values `directionX` and `directionY`. Pure: no GPU, clock or global state.
import Foundation
import VisualCoreExperience

/// The fragment operator a pass runs.
public enum PassOperator: String, Sendable, CaseIterable {
    /// Layered value noise of `scale`, `octaves` and `speed` at `time`, as grey.
    case noise
    /// A linear ramp from `start` to `end` at `angle` degrees.
    case gradient
    /// The blend of `u_a` and `u_b` by `amount`.
    case mix
    /// The horizontal half of a separable Gaussian blur of `radius` pixels.
    case blurH = "blur-h"
    /// The vertical half of a separable Gaussian blur of `radius` pixels.
    case blurV = "blur-v"
    /// A copy of the final image into the framebuffer.
    case output
}

/// A uniform value of a pass, fixed at compile time or resolved per frame by ``PreviewValues``.
public enum PassValue: Equatable, Sendable {
    /// A fixed float.
    case scalar(Double)
    /// A fixed colour (alpha 1).
    case colour(r: Double, g: Double, b: Double)
    /// The frame time multiplied by `rate` (a Noise fed by a Time node).
    case time(rate: Double)
    /// The frame time (a Noise whose time input is empty).
    case frameTime
}

/// Where a pass draws.
public enum PassTarget: Equatable, Sendable {
    /// Into the slot (a 256 × 256 rgba8 texture) of this index.
    case slot(Int)
    /// Into the framebuffer (the Output pass).
    case framebuffer
}

/// One picture pass of a schedule.
public struct Pass: Equatable, Sendable {
    /// The node the pass draws.
    public let node: NodeID
    /// The operator the pass runs.
    public let `operator`: PassOperator
    /// The sampler inputs: uniform name (`u_a`, `u_b`, `u_image`) → the slot read.
    public let inputs: [String: Int]
    /// The uniform values by name without the `u_` prefix (`scale`, `octaves`, `speed`, `time`, `angle`, `start`,
    /// `end`, `amount`, `radius`, `directionX`, `directionY`).
    public let values: [String: PassValue]
    /// Where the pass draws.
    public let target: PassTarget
    /// The content key of the node (hexadecimal digest).
    public let key: String

    /// A pass of `operator` for `node` reading `inputs`, with `values`, drawing into `target`, keyed `key`.
    public init(node: NodeID, operator: PassOperator, inputs: [String: Int], values: [String: PassValue],
                target: PassTarget, key: String) {
        self.node = node
        self.operator = `operator`
        self.inputs = inputs
        self.values = values
        self.target = target
        self.key = key
    }
}

/// The compiled, bounded schedule of a graph's preview.
public struct PassSchedule: Equatable, Sendable {
    /// The side of the preview and of every slot, in pixels: 256.
    public static let previewSize = 256
    /// The most slots a schedule may need: 6.
    public static let slotLimit = 6
    /// The bytes of one slot: 256 × 256 × 4 (rgba8).
    public static let bytesPerSlot = 256 * 256 * 4

    /// The passes, in drawing order; the last is the Output pass.
    public let passes: [Pass]
    /// The number of slots in use at once at the peak.
    public let slotCount: Int
    /// The bytes of the slots: ``slotCount`` × ``bytesPerSlot``.
    public var bytes: Int { slotCount * Self.bytesPerSlot }
    /// The content key of every node of the graph.
    public let keys: [NodeID: String]

    /// A schedule of `passes` using `slotCount` slots, with the nodes' `keys`.
    public init(passes: [Pass], slotCount: Int, keys: [NodeID: String]) {
        self.passes = passes
        self.slotCount = slotCount
        self.keys = keys
    }
}

/// Why a graph compiles into no pass.
public enum CompileRefusal: Error, Equatable, Sendable {
    /// The checker refused the graph; the text is its status line (``EditMessages/status(for:in:)``).
    case invalid(String)
    /// The schedule would need this many slots, more than ``PassSchedule/slotLimit``.
    case overBudget(slots: Int)

    /// The sentence shown in the preview: the checker's status, or "This graph needs N textures; the preview
    /// allows 6."
    public var message: String {
        switch self {
        case .invalid(let text): text
        case .overBudget(let slots): "This graph needs \(slots) textures; the preview allows \(PassSchedule.slotLimit)."
        }
    }
}

/// Compiles a ``VisualGraph`` into a ``PassSchedule`` (clarifications Q1–Q3).
public enum GraphCompiler {
    /// The domain of the content keys.
    static let keyDomain = "a23.node-key"

    /// Compiles `graph`: refused by the checker → ``CompileRefusal/invalid(_:)`` with its status; needing more than
    /// ``PassSchedule/slotLimit`` slots → ``CompileRefusal/overBudget(slots:)``; else the schedule.
    public static func compile(_ graph: VisualGraph) -> Result<PassSchedule, CompileRefusal> {
        let result = GraphChecker.check(graph)
        guard case .accepted(let order, let reaching) = result else {
            return .failure(.invalid(EditMessages.status(for: result, in: graph)))
        }
        let keys = keys(of: graph)
        let plans = plan(graph, order: order, reaching: reaching, keys: keys)
        let (targets, slotCount) = assignSlots(plans)
        guard slotCount <= PassSchedule.slotLimit else { return .failure(.overBudget(slots: slotCount)) }
        var passes: [Pass] = []
        for (index, plan) in plans.enumerated() {
            var inputs: [String: Int] = [:]
            for (name, producer) in plan.inputs {
                if case .slot(let slot) = targets[producer] { inputs[name] = slot }
            }
            passes.append(Pass(node: plan.node, operator: plan.operator, inputs: inputs, values: plan.values,
                               target: targets[index], key: plan.key))
        }
        return .success(PassSchedule(passes: passes, slotCount: slotCount, keys: keys))
    }

    /// The content key of every node of `graph` (the first node of a shared identity): a digest of domain
    /// `a23.node-key` over the kind, the declared parameters in name order (stored value, else default) and, for
    /// each input in declaration order, the key and port of the node feeding it, or "none". Positions and
    /// identities are not part of a key, and the order of nodes and connections does not change it.
    public static func keys(of graph: VisualGraph) -> [NodeID: String] {
        var keys: [NodeID: String] = [:]
        var visiting: Set<NodeID> = []
        for node in graph.nodes where keys[node.id] == nil {
            _ = key(of: node.id, in: graph, keys: &keys, visiting: &visiting)
        }
        return keys
    }

    /// The nodes whose key differs between `old` and `new`, with the nodes added and removed.
    public static func changed(from old: VisualGraph, to new: VisualGraph) -> Set<NodeID> {
        let before = keys(of: old)
        let after = keys(of: new)
        var changed: Set<NodeID> = []
        for id in Set(before.keys).union(after.keys) where before[id] != after[id] {
            changed.insert(id)
        }
        return changed
    }

    // MARK: Keys

    /// The key of node `id`, computed once (memoised in `keys`); a node met again while its own key is being
    /// computed (a loop) gives "loop".
    private static func key(of id: NodeID, in graph: VisualGraph, keys: inout [NodeID: String],
                            visiting: inout Set<NodeID>) -> String {
        if let known = keys[id] { return known }
        guard let node = graph.node(id) else { return "missing" }
        guard visiting.insert(id).inserted else { return "loop" }
        var builder = DigestBuilder(domain: keyDomain)
        builder.add(node.kind.rawValue)
        let parameters = node.kind.parameters.sorted { $0.name < $1.name }
        builder.add(count: parameters.count)
        for parameter in parameters {
            builder.add(parameter.name)
            let value = node.value(of: parameter.name) ?? parameter.defaultValue
            builder.add(value == 0 ? UInt64(0) : value.bitPattern)
        }
        builder.add(count: node.kind.inputs.count)
        for input in node.kind.inputs {
            builder.add(input.name)
            if let edge = feeding(id, input.name, in: graph) {
                builder.add(key(of: edge.sourceNode, in: graph, keys: &keys, visiting: &visiting))
                builder.add(edge.sourcePort)
            } else {
                builder.add("none")
            }
        }
        visiting.remove(id)
        let hex = builder.finish().hex
        keys[id] = hex
        return hex
    }

    /// The connection feeding input `port` of node `id` (the smallest in ``GraphEdge`` order), or nil.
    private static func feeding(_ id: NodeID, _ port: String, in graph: VisualGraph) -> GraphEdge? {
        graph.edges.filter { $0.targetNode == id && $0.targetPort == port }.min()
    }

    // MARK: Passes

    /// A pass before its slots are known: its inputs name the index of the pass producing them.
    private struct Plan {
        let node: NodeID
        let `operator`: PassOperator
        let inputs: [(name: String, producer: Int)]
        let values: [String: PassValue]
        let key: String
        let writesSlot: Bool
    }

    /// The plans of the texture nodes of `order` that are in `reaching`, in that order.
    private static func plan(_ graph: VisualGraph, order: [NodeID], reaching: Set<NodeID>,
                             keys: [NodeID: String]) -> [Plan] {
        var plans: [Plan] = []
        var producer: [NodeID: Int] = [:]   // node → index of the plan writing its image
        for id in order where reaching.contains(id) {
            guard let node = graph.node(id) else { continue }
            let key = keys[id] ?? ""
            func source(_ port: String) -> Int? {
                feeding(id, port, in: graph).flatMap { producer[$0.sourceNode] }
            }
            func image(_ port: String, as name: String) -> [(name: String, producer: Int)] {
                source(port).map { [(name, $0)] } ?? []
            }
            switch node.kind {
            case .time, .constant:
                continue
            case .noise:
                plans.append(Plan(node: id, operator: .noise, inputs: [], values: noiseValues(node, graph), key: key,
                                  writesSlot: true))
            case .gradient:
                let values: [String: PassValue] = [
                    "angle": .scalar(node.value(of: "angle") ?? 90),
                    "start": colour(feeding: id, "start", in: graph, otherwise: 0),
                    "end": colour(feeding: id, "end", in: graph, otherwise: 1)]
                plans.append(Plan(node: id, operator: .gradient, inputs: [], values: values, key: key,
                                  writesSlot: true))
            case .mix:
                let values: [String: PassValue] = ["amount": scalar(node, "amount", in: graph)]
                plans.append(Plan(node: id, operator: .mix, inputs: image("a", as: "u_a") + image("b", as: "u_b"),
                                  values: values, key: key, writesSlot: true))
            case .blur:
                let radius = scalar(node, "radius", in: graph)
                plans.append(Plan(node: id, operator: .blurH, inputs: image("image", as: "u_image"),
                                  values: ["radius": radius, "directionX": .scalar(1), "directionY": .scalar(0)],
                                  key: key, writesSlot: true))
                plans.append(Plan(node: id, operator: .blurV, inputs: [("u_image", plans.count - 1)],
                                  values: ["radius": radius, "directionX": .scalar(0), "directionY": .scalar(1)],
                                  key: key, writesSlot: true))
            case .output:
                plans.append(Plan(node: id, operator: .output, inputs: image("image", as: "u_image"), values: [:],
                                  key: key, writesSlot: false))
            }
            producer[id] = plans.count - 1
        }
        return plans
    }

    /// The values of a Noise pass: scale (fed by a Constant, clamped), octaves, speed and time.
    private static func noiseValues(_ node: GraphNode, _ graph: VisualGraph) -> [String: PassValue] {
        var time = PassValue.frameTime
        if let edge = feeding(node.id, "time", in: graph), let source = graph.node(edge.sourceNode),
           source.kind == .time {
            time = .time(rate: source.value(of: "rate") ?? 1)
        }
        return ["scale": scalar(node, "scale", in: graph), "octaves": .scalar(node.value(of: "octaves") ?? 4),
                "speed": .scalar(node.value(of: "speed") ?? 0.5), "time": time]
    }

    /// The scalar input `name` of `node`: a connected Constant's `value` clamped to the parameter of the same name's
    /// range, else that parameter's value.
    private static func scalar(_ node: GraphNode, _ name: String, in graph: VisualGraph) -> PassValue {
        let parameter = node.kind.parameter(name)
        if let edge = feeding(node.id, name, in: graph), let source = graph.node(edge.sourceNode),
           source.kind == .constant, let value = source.value(of: "value") {
            guard let range = parameter?.range else { return .scalar(value) }
            return .scalar(min(max(value, range.lowerBound), range.upperBound))
        }
        return .scalar(node.value(of: name) ?? parameter?.defaultValue ?? 0)
    }

    /// The colour input `port` of node `id`: a connected Constant's red, green and blue, else grey `otherwise`
    /// (black 0 for start, white 1 for end).
    private static func colour(feeding id: NodeID, _ port: String, in graph: VisualGraph,
                               otherwise grey: Double) -> PassValue {
        if let edge = feeding(id, port, in: graph), let source = graph.node(edge.sourceNode),
           source.kind == .constant {
            return .colour(r: source.value(of: "red") ?? 1, g: source.value(of: "green") ?? 1,
                           b: source.value(of: "blue") ?? 1)
        }
        return .colour(r: grey, g: grey, b: grey)
    }

    // MARK: Slots

    /// The target of every plan and the peak number of slots in use: each writing plan takes the lowest slot free
    /// before it runs (a slot it reads is still taken), and a slot is freed after the last plan that reads it.
    private static func assignSlots(_ plans: [Plan]) -> (targets: [PassTarget], slotCount: Int) {
        var lastRead: [Int: Int] = [:]   // producer index → index of its last reader
        for (index, plan) in plans.enumerated() {
            for input in plan.inputs { lastRead[input.producer] = max(lastRead[input.producer] ?? index, index) }
        }
        var targets: [PassTarget] = []
        var taken: Set<Int> = []
        var slotOf: [Int: Int] = [:]   // producer index → its slot
        var peak = 0
        for (index, plan) in plans.enumerated() {
            if plan.writesSlot {
                var slot = 0
                while taken.contains(slot) { slot += 1 }
                taken.insert(slot)
                slotOf[index] = slot
                targets.append(.slot(slot))
                peak = max(peak, taken.count)
            } else {
                targets.append(.framebuffer)
            }
            for (producer, reader) in lastRead where reader == index {
                if let slot = slotOf[producer] { taken.remove(slot) }
            }
            if plan.writesSlot && lastRead[index] == nil, let slot = slotOf[index] { taken.remove(slot) }
        }
        return (targets, peak)
    }
}
