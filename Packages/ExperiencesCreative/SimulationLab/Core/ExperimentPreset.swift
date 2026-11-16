// ExperimentPreset — feature 120 (A16-P04) T-A16-402 (FR-A16-430, SC-A16-403; clarification Q4; data-model
// "ExperimentPreset (schema 1)"; contracts/ui.md). A named, attributed experiment: schema 1, name (1…60 characters
// after trimming), a valid 64 × 64 `SimulationSpec`, palette id `standard`, annotation (≤ 200 characters), source and
// license (`original` or `public-domain`). Written as JSON with sorted keys.
//
// `decode(_:)` refuses, in this order: `damaged` (not JSON, or no whole-number `schema` ≥ 1), `newer-version` (a schema
// above 1), `damaged` (a missing or malformed key, or an unreadable spec), `invalid` (a spec that `SimulationSpec`
// refuses for any other reason, or a preset whose `problem()` is not nil).
// The six family presets are bundled: Life, HighLife, Seeds, Spots, Mazes and Pulse.
import Foundation

/// A named, attributed simulation experiment (schema 1).
public struct ExperimentPreset: Codable, Equatable, Sendable {
    /// The preset schema this code reads and writes.
    public static let schemaVersion = 1
    /// The allowed licenses.
    public static let licenses: Set<String> = ["original", "public-domain"]
    /// The longest name, in characters after trimming.
    public static let maxNameLength = 60
    /// The longest annotation, in characters.
    public static let maxAnnotationLength = 200
    /// The only palette id of this phase.
    public static let standardPalette = "standard"

    /// The schema (1).
    public var schema: Int
    /// The name shown in the library.
    public var name: String
    /// The simulation spec.
    public var spec: SimulationSpec
    /// The palette id (`standard`).
    public var palette: String
    /// A short note about what to look for.
    public var annotation: String
    /// Where the parameters come from.
    public var source: String
    /// The license of the parameters (`original` or `public-domain`).
    public var license: String

    /// Creates a schema-1 preset (no validation; see `problem()`).
    public init(name: String, spec: SimulationSpec, palette: String = ExperimentPreset.standardPalette,
                annotation: String, source: String, license: String) {
        schema = Self.schemaVersion
        self.name = name
        self.spec = spec
        self.palette = palette
        self.annotation = annotation
        self.source = source
        self.license = license
    }

    /// Why the preset cannot be used, as a sentence; nil when it is valid.
    public func problem() -> String? {
        guard schema == Self.schemaVersion else {
            return "The experiment uses schema \(schema); only schema 1 is understood."
        }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "The experiment needs a name." }
        guard trimmed.count <= Self.maxNameLength else {
            return "The experiment name must be at most \(Self.maxNameLength) characters."
        }
        guard annotation.count <= Self.maxAnnotationLength else {
            return "The annotation must be at most \(Self.maxAnnotationLength) characters."
        }
        guard Self.licenses.contains(license) else {
            return "The license must be original or public-domain."
        }
        guard !source.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return "The experiment needs a source."
        }
        guard palette == Self.standardPalette else { return "The palette \"\(palette)\" is not known." }
        if let refusal = spec.refusal() { return refusal.sentence }
        guard spec.gridSize == SimulationSpec.standardGridSize else {
            return "The experiment grid must be \(SimulationSpec.standardGridSize) cells per side."
        }
        return nil
    }

    /// The preset as JSON with sorted keys.
    public func encoded() -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return (try? encoder.encode(self)) ?? Data()
    }

    /// Why a preset file was refused.
    public enum PresetRefusal: String, Error, Sendable {
        /// Not JSON, or a missing or malformed key.
        case damaged
        /// A schema newer than this code understands.
        case newerVersion = "newer-version"
        /// Readable, but the spec is refused or `problem()` is not nil.
        case invalid
    }

    /// The schema envelope read before the whole preset.
    private struct Envelope: Decodable {
        /// The schema.
        let schema: Int
    }

    /// The valid preset in `data`, or the reason it is refused (see the file header for the order of the checks).
    public static func decode(_ data: Data) -> Result<ExperimentPreset, PresetRefusal> {
        guard let envelope = try? JSONDecoder().decode(Envelope.self, from: data), envelope.schema >= 1 else {
            return .failure(.damaged)
        }
        guard envelope.schema <= schemaVersion else { return .failure(.newerVersion) }
        let preset: ExperimentPreset
        do {
            preset = try JSONDecoder().decode(ExperimentPreset.self, from: data)
        } catch let refusal as SimulationRefusal {
            return .failure(refusal.reason == .damaged ? .damaged : .invalid)
        } catch {
            return .failure(.damaged)
        }
        guard preset.problem() == nil else { return .failure(.invalid) }
        return .success(preset)
    }

    /// The six bundled family presets: Life, HighLife, Seeds, Spots, Mazes and Pulse (seed 1, grid 64).
    public static let bundled: [ExperimentPreset] = [
        ExperimentPreset(name: "Life", spec: .standard(.automaton, preset: 0, seed: 1),
                         annotation: "Birth on 3, survival on 2 or 3: gliders, blinkers and still lifes emerge.",
                         source: "Conway 1970 (Game of Life)", license: "public-domain"),
        ExperimentPreset(name: "HighLife", spec: .standard(.automaton, preset: 1, seed: 1),
                         annotation: "Life with an extra birth on 6; look for the self-copying replicator.",
                         source: "Thompson 1994 (HighLife)", license: "public-domain"),
        ExperimentPreset(name: "Seeds", spec: .standard(.automaton, preset: 2, seed: 1),
                         annotation: "Birth on 2, no survival: every cell lives one generation and the field explodes.",
                         source: "Silverman (Seeds)", license: "public-domain"),
        ExperimentPreset(name: "Spots", spec: .standard(.reactionDiffusion, preset: 0, seed: 1),
                         annotation: "Gray-Scott with feed 0.035 and kill 0.065: patches settle into separate spots.",
                         source: "Pearson 1993 (Gray-Scott classification)", license: "public-domain"),
        ExperimentPreset(name: "Mazes", spec: .standard(.reactionDiffusion, preset: 1, seed: 1),
                         annotation: "Gray-Scott with feed 0.029 and kill 0.057: stripes grow into a maze.",
                         source: "Pearson 1993 (Gray-Scott classification)", license: "public-domain"),
        ExperimentPreset(name: "Pulse", spec: .standard(.wave, preset: 0, seed: 1),
                         annotation: "A single pulse spreads as a ring and reflects from the fixed edges.",
                         source: "VisualCore (original)", license: "original"),
    ]
}
