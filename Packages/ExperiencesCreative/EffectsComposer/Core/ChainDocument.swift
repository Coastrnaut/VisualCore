// ChainDocument — feature 180 (A25-P01) T-A25-109 (FR-A25-106; SC-A25-105; clarification Q3; data-model.md
// "Chain file"). A chain is stored as the JSON envelope `{"body": {"nodes": [{"effect", "enabled", "id",
// "values"}]}, "kind": "a25.effect-chain", "version": 1}` with sorted keys, at most 65,536 bytes, read through a
// `MigrationChain`. Encoding is deterministic: the same chain gives the same bytes every time.
// Choices recorded here: encoding is total (it never refuses; a value that is not finite is written as the string
// "NaN", "Infinity" or "-Infinity", and negative zero as zero), so every refusal belongs to reading. Reading checks, in
// order: the size (`too-large`); a JSON object of the right kind with a whole-number version (`damaged`); a version
// above the current one (`newer-version`, through the migration chain); a version below 1, a body without `nodes`,
// a node that is not exactly the four keys with their types, or a value that is neither a number nor one of the
// three non-finite strings (`damaged`); more than 8 nodes (`too-many-nodes`); an effect that is not built in
// (`unknown-effect`); then the chain as `EffectChain.validate()` checks it (`out-of-range` of `node.id`,
// `duplicate-node`, `unknown-parameter`, `missing-parameter`, `not-finite`, `out-of-range`). The current-version
// body is decoded from the file's own bytes, so every number is read exactly as written. Pure Foundation.
import Foundation
import VisualCorePersistence

/// Reads and writes chain files (kind `a25.effect-chain`, version 1).
public enum ChainDocument {
    /// The envelope kind of a chain file.
    public static let kind = "a25.effect-chain"
    /// The file version this code writes and reads.
    public static let schemaVersion = 1
    /// The migrations to ``schemaVersion`` (none yet; a newer file is refused through it).
    public static let migrations = MigrationChain(currentVersion: schemaVersion)

    /// The strings that stand for non-finite numbers in a file, so that they are refused as
    /// ``ChainRefusal/notFinite(_:)`` rather than as damage.
    static let positiveInfinityText = "Infinity"
    /// The string of negative infinity.
    static let negativeInfinityText = "-Infinity"
    /// The string of NaN.
    static let nanText = "NaN"

    /// The keys of a stored node.
    static let nodeKeys: Set<String> = ["effect", "enabled", "id", "values"]

    /// The written envelope.
    private struct Envelope: Encodable {
        /// The chain's body.
        var body: Body
        /// Always ``ChainDocument/kind``.
        var kind: String
        /// Always ``ChainDocument/schemaVersion``.
        var version: Int
    }

    /// The written body: the nodes in order.
    private struct Body: Encodable {
        /// The nodes, negative zero written as zero.
        var nodes: [EffectNode]
    }

    /// The read envelope of the current version.
    private struct StoredEnvelope: Decodable {
        /// The stored body.
        var body: StoredBody
    }

    /// The read body of the current version.
    private struct StoredBody: Decodable {
        /// The stored nodes.
        var nodes: [StoredNode]
    }

    /// A stored node before its effect is checked.
    private struct StoredNode: Decodable {
        /// The node identifier.
        var id: Int
        /// The effect's raw text.
        var effect: String
        /// The enabled flag.
        var enabled: Bool
        /// The values by parameter name.
        var values: [String: Double]
    }

    /// The stored file of `chain`: the JSON envelope with sorted keys, the same bytes for the same chain. The chain is
    /// not checked; a chain that ``EffectChain/validate()`` refuses is refused again when the file is read.
    public static func encode(_ chain: EffectChain) -> Data {
        let nodes = chain.nodes.map { node -> EffectNode in
            var normalized = node
            normalized.values = node.values.mapValues { $0 == 0 ? 0 : $0 }
            return normalized
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        encoder.nonConformingFloatEncodingStrategy = .convertToString(
            positiveInfinity: positiveInfinityText, negativeInfinity: negativeInfinityText, nan: nanText)
        // Strings, whole numbers, flags and (with the strategy above) every Double encode, so this cannot fail.
        return (try? encoder.encode(Envelope(body: Body(nodes: nodes), kind: kind, version: schemaVersion))) ?? Data()
    }

    /// Reads a chain file, refusing it with a ``ChainRefusal`` in the order stated in the file header; a refused
    /// file is never partly read.
    public static func decode(_ data: Data) -> Result<EffectChain, ChainRefusal> {
        guard data.count <= ChainLimits.maxFileBytes else { return .failure(.tooLarge) }
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let fileKind = object["kind"] as? String, fileKind == kind,
              let versionNumber = object["version"] as? NSNumber, isFlag(versionNumber) == false,
              let version = object["version"] as? Int else { return .failure(.damaged) }
        guard version <= migrations.currentVersion else { return .failure(.newerVersion) }
        guard version >= 1, let body = object["body"] as? [String: Any] else { return .failure(.damaged) }
        let migrated: [String: Any]
        do {
            migrated = try migrations.migrate(body, from: version)
        } catch MigrationError.newerVersion(_) {
            return .failure(.newerVersion)
        } catch {
            return .failure(.damaged)
        }
        guard Set(migrated.keys) == ["nodes"], let rawNodes = migrated["nodes"] as? [Any] else {
            return .failure(.damaged)
        }
        for rawNode in rawNodes {
            guard let node = rawNode as? [String: Any], Set(node.keys) == nodeKeys,
                  let enabled = node["enabled"] as? NSNumber, isFlag(enabled),
                  let id = node["id"] as? NSNumber, isFlag(id) == false else { return .failure(.damaged) }
        }
        let decoder = JSONDecoder()
        decoder.nonConformingFloatDecodingStrategy = .convertFromString(
            positiveInfinity: positiveInfinityText, negativeInfinity: negativeInfinityText, nan: nanText)
        let bodyData: Data
        if version == migrations.currentVersion {
            bodyData = data
        } else {
            guard let migratedData = try? JSONSerialization.data(withJSONObject: ["body": migrated]) else {
                return .failure(.damaged)
            }
            bodyData = migratedData
        }
        guard let stored = try? decoder.decode(StoredEnvelope.self, from: bodyData) else { return .failure(.damaged) }
        guard stored.body.nodes.count <= ChainLimits.maxNodes else { return .failure(.tooManyNodes) }
        var nodes: [EffectNode] = []
        for node in stored.body.nodes {
            guard let effect = EffectID(rawValue: node.effect) else { return .failure(.unknownEffect(node.effect)) }
            nodes.append(EffectNode(id: node.id, effect: effect, enabled: node.enabled, values: node.values))
        }
        let chain = EffectChain(nodes: nodes)
        do throws(ChainRefusal) {
            try chain.validate()
        } catch {
            return .failure(error)
        }
        return .success(chain)
    }

    /// True when `number` is a JSON `true` or `false` rather than a number.
    static func isFlag(_ number: NSNumber) -> Bool {
        CFGetTypeID(number) == CFBooleanGetTypeID()
    }
}
