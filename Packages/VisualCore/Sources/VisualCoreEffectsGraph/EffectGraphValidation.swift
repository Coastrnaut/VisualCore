// EffectGraphValidation.swift — rejects unsafe graphs before any GPU work and orders the rest
// (feature 005 T-F403; FR-F402–FR-F404, FR-F406; contract specs/005-effects-graph/contracts/effects-api.md).

public enum EffectGraphError: Error, Equatable, Sendable {
    case unsupportedVersion(Int)
    case tooManyPasses(Int)
    case duplicateID(String)
    case duplicateOutput(String)
    case unknownType(String, pass: String)
    case missingSlot(pass: String, slot: String)
    case missingInput(pass: String, input: String, source: String)
    case invalidScale(pass: String, Double)
    case missingOutput(String)
    case cycle([String])
    case overQuota(bytes: Int, quota: Int)
}

public struct ValidatedGraph: Sendable, Equatable {
    /// Pass ids in execution order.
    public let order: [String]
    public let estimatedBytes: Int
    /// Parameters after defaults and clamping, per pass id.
    public let parameters: [String: [String: [Double]]]
    public let warnings: [String]
}

public enum EffectGraphValidator {
    public static let defaultQuota = 256 << 20

    public static func validate(_ graph: EffectGraphDescription, width: Int, height: Int,
                                quotaBytes: Int = defaultQuota) throws(EffectGraphError) -> ValidatedGraph {
        guard graph.version == EffectGraphDescription.currentVersion else { throw .unsupportedVersion(graph.version) }
        guard graph.passes.count <= PassSchemas.maxPasses else { throw .tooManyPasses(graph.passes.count) }
        var ids = Set<String>(), outputs: [String: String] = [:]
        for p in graph.passes {
            guard ids.insert(p.id).inserted else { throw .duplicateID(p.id) }
            guard outputs[p.output] == nil, p.output != effectSceneSource else { throw .duplicateOutput(p.output) }
            outputs[p.output] = p.id
        }
        var warnings: [String] = []
        var parameters: [String: [String: [Double]]] = [:]
        for p in graph.passes {
            guard let schema = PassSchemas.schema(for: p.type) else { throw .unknownType(p.type, pass: p.id) }
            for slot in schema.inputs where p.inputs[slot] == nil { throw .missingSlot(pass: p.id, slot: slot) }
            for slot in schema.inputs {
                let source = p.inputs[slot]!
                guard source == effectSceneSource || outputs[source] != nil else {
                    throw .missingInput(pass: p.id, input: slot, source: source)
                }
            }
            guard p.scale > 0, p.scale <= 1 else { throw .invalidScale(pass: p.id, p.scale) }
            var resolved: [String: [Double]] = [:]
            for (key, spec) in schema.parameters {
                let given = p.params[key] ?? spec.defaultValue
                resolved[key] = given.map { min(max($0, spec.range.lowerBound), spec.range.upperBound) }
            }
            for key in p.params.keys.sorted() where schema.parameters[key] == nil {
                warnings.append("\(p.id): unknown parameter '\(key)' ignored")
            }
            for slot in p.inputs.keys.sorted() where !schema.inputs.contains(slot) {
                warnings.append("\(p.id): unknown input slot '\(slot)' ignored")
            }
            parameters[p.id] = resolved
        }
        guard outputs[graph.output] != nil else { throw .missingOutput(graph.output) }
        let order = try topologicalOrder(graph.passes, outputs: outputs)
        var bytes = 0
        for p in graph.passes {
            let w = max(1, Int((Double(width) * p.scale).rounded())), h = max(1, Int((Double(height) * p.scale).rounded()))
            let target = w * h * PassSchemas.bytesPerPixel(type: p.type, params: parameters[p.id] ?? [:])
            bytes += target
            if p.type == "feedback" { bytes += target }   // history buffer (FR-F412)
        }
        guard bytes <= quotaBytes else { throw .overQuota(bytes: bytes, quota: quotaBytes) }
        return ValidatedGraph(order: order, estimatedBytes: bytes, parameters: parameters, warnings: warnings)
    }

    /// Kahn's algorithm; ready passes are taken in declaration order (stable, deterministic).
    private static func topologicalOrder(_ passes: [EffectPassDescription], outputs: [String: String]) throws(EffectGraphError) -> [String] {
        var indegree: [String: Int] = [:]
        var dependents: [String: [String]] = [:]
        for p in passes {
            let producers = declaredProducers(p, outputs: outputs)
            indegree[p.id] = producers.count
            for producer in producers { dependents[producer, default: []].append(p.id) }
        }
        let index = Dictionary(uniqueKeysWithValues: passes.enumerated().map { ($1.id, $0) })
        var ready = passes.map(\.id).filter { indegree[$0] == 0 }
        var order: [String] = []
        while !ready.isEmpty {
            ready.sort { index[$0]! < index[$1]! }
            let next = ready.removeFirst()
            order.append(next)
            for d in dependents[next, default: []] {
                indegree[d]! -= 1
                if indegree[d] == 0 { ready.append(d) }
            }
        }
        guard order.count == passes.count else {
            // Unordered passes are on a cycle or downstream of one; name only those on a cycle
            // (a pass that reaches itself through unordered producers) — US1/AC2.
            let ordered = Set(order)
            var producersOf: [String: [String]] = [:]
            for p in passes where !ordered.contains(p.id) {
                producersOf[p.id] = declaredProducers(p, outputs: outputs).filter { !ordered.contains($0) }.sorted()
            }
            func reachesItself(_ start: String) -> Bool {
                var stack = producersOf[start] ?? [], seen = Set<String>()
                while let n = stack.popLast() {
                    if n == start { return true }
                    if seen.insert(n).inserted { stack.append(contentsOf: producersOf[n] ?? []) }
                }
                return false
            }
            throw .cycle(passes.map(\.id).filter { !ordered.contains($0) && reachesItself($0) })
        }
        return order
    }

    /// Producers of a pass's schema-declared input slots; undeclared slots are ignored (FR-F406).
    private static func declaredProducers(_ p: EffectPassDescription, outputs: [String: String]) -> Set<String> {
        let slots = PassSchemas.schema(for: p.type)?.inputs ?? []
        return Set(slots.compactMap { p.inputs[$0] }.compactMap { outputs[$0] })
    }
}
