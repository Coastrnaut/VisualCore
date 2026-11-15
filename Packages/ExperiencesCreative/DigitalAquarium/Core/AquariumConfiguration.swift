// AquariumConfiguration — feature 072 (A09-P05) T-A09-503 (FR-A09-501, 502; clarification 1; research D1; data-model
// "AquariumConfiguration"). What a person arranges and saves under a name: the starter habitat, the decor pieces with
// their transforms, the lighting level, the chosen decoration kind and the ambient choice — never the fish, the food,
// the step count or the generator. Format 1, coded as JSON with sorted keys (`savedAt` as seconds since the reference
// date, so encoding is deterministic). A saved configuration is rebuilt only through the experience's actions
// (`actions(catalog:)`): `habitat.select [i]`, then `decor.remove [0]` once per starter decor piece of that habitat,
// then for every saved piece i `decor.kind [k]`, `decor.place [x/16, y/9]` and `decor.turn [i, rotation, scale]` (a
// placement appends, so after the removals piece i lands at index i), then `decor.kind`, `lighting.level` and
// `ambient.mode` of the configuration.
import Foundation
import VisualCoreMath

/// A saved aquarium arrangement (format 1): habitat, decor with transforms, lighting, decoration kind and ambient.
public struct AquariumConfiguration: Codable, Equatable, Sendable {
    /// One saved decor piece: a catalog decor kind at a tank position, rotated and scaled.
    public struct Piece: Codable, Equatable, Sendable {
        /// The catalog decor kind id.
        public var kindId: String
        /// The x position in habitat units (0…16).
        public var x: Double
        /// The y position in habitat units (0…9).
        public var y: Double
        /// The rotation in radians (−π…π).
        public var rotation: Double
        /// The scale (0.5…2.0).
        public var scale: Double

        /// Creates a piece from all of its fields; validity is checked by ``AquariumConfiguration/validate(catalog:)``.
        public init(kindId: String, x: Double, y: Double, rotation: Double = 0, scale: Double = 1) {
            self.kindId = kindId; self.x = x; self.y = y; self.rotation = rotation; self.scale = scale
        }

        /// The piece of a habitat decor placement (same kind, position, rotation and scale).
        public init(_ placement: DecorPlacement) {
            self.init(kindId: placement.kindId, x: placement.position.x, y: placement.position.y,
                      rotation: placement.rotation, scale: placement.scale)
        }
    }

    /// The format written by this version; a file with a greater format is newer and never rewritten.
    public static let currentFormat = 1
    /// The most characters of a name after trimming.
    public static let maxNameLength = 40
    /// The name given to a configuration saved with an empty (or all-whitespace) name.
    public static let defaultName = "My aquarium"

    /// The format (1).
    public var format: Int
    /// The identity of the configuration (names need not be unique).
    public var id: UUID
    /// The name: 1…40 characters, without leading or trailing whitespace.
    public var name: String
    /// When the configuration was saved.
    public var savedAt: Date
    /// The index of the starter habitat in the catalog's `habitats`.
    public var habitatIndex: Int
    /// The lighting level (0 dim, 1 soft, 2 bright).
    public var lighting: Int
    /// The decoration kind the next placement uses: an index into the catalog's decor kinds.
    public var decorKind: Int
    /// Whether ambient mode is on.
    public var ambient: Bool
    /// The decor pieces in order; at most ``HabitatDocument/maxDecor``.
    public var decor: [Piece]

    /// Creates a configuration from all of its fields (the name is stored as given;
    /// ``make(document:decorKind:ambient:name:id:savedAt:)`` cleans it); validity is checked by ``validate(catalog:)``.
    public init(format: Int = AquariumConfiguration.currentFormat, id: UUID, name: String, savedAt: Date,
                habitatIndex: Int, lighting: Int, decorKind: Int, ambient: Bool, decor: [Piece]) {
        self.format = format; self.id = id; self.name = name; self.savedAt = savedAt
        self.habitatIndex = habitatIndex; self.lighting = lighting; self.decorKind = decorKind
        self.ambient = ambient; self.decor = decor
    }

    /// `name` trimmed of whitespace and newlines; an empty result becomes ``defaultName``; a longer one is cut to
    /// ``maxNameLength`` characters (and trimmed again, so it never ends in whitespace).
    public static func cleanedName(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return defaultName }
        guard trimmed.count > maxNameLength else { return trimmed }
        return String(trimmed.prefix(maxNameLength)).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// The configuration of `document` (habitat index, lighting and the first ``HabitatDocument/maxDecor`` decor
    /// pieces) with the chosen decoration kind `decorKind` and the ambient choice `ambient`, named
    /// ``cleanedName(_:)`` of `name`, with identity `id`, saved at `savedAt`.
    public static func make(document: HabitatDocument, decorKind: Int, ambient: Bool, name: String, id: UUID,
                            savedAt: Date) -> AquariumConfiguration {
        AquariumConfiguration(id: id, name: cleanedName(name), savedAt: savedAt, habitatIndex: document.habitatIndex,
                              lighting: document.lighting, decorKind: decorKind, ambient: ambient,
                              decor: document.decor.prefix(HabitatDocument.maxDecor).map { Piece($0) })
    }

    /// The configuration's problems, empty when it is valid: the format (exactly 1), the name (1…40 characters,
    /// trimmed), the habitat index and decoration kind (entries of `catalog`), the lighting level (0…2), the decor
    /// count (≤ 12) and every piece (a known kind, a finite position inside the 16 × 9 tank, a finite rotation in
    /// −π…π, a finite scale in 0.5…2.0).
    public func validate(catalog: SpeciesCatalog) -> [String] {
        var problems: [String] = []
        if format != Self.currentFormat { problems.append("format \(format) is not \(Self.currentFormat)") }
        if name.isEmpty || name.count > Self.maxNameLength
            || name != name.trimmingCharacters(in: .whitespacesAndNewlines) {
            problems.append("name is not 1…\(Self.maxNameLength) trimmed characters")
        }
        if !catalog.habitats.indices.contains(habitatIndex) {
            problems.append("habitat index \(habitatIndex) is not in the catalog")
        }
        if !HabitatDocument.lightingRange.contains(lighting) {
            problems.append("lighting \(lighting) is outside 0…2")
        }
        if !catalog.decor.indices.contains(decorKind) {
            problems.append("decoration kind \(decorKind) is not in the catalog")
        }
        if decor.count > HabitatDocument.maxDecor {
            problems.append("\(decor.count) decor items exceed \(HabitatDocument.maxDecor)")
        }
        for (i, piece) in decor.enumerated() {
            if catalog.decor(id: piece.kindId) == nil {
                problems.append("decor \(i) kind \(piece.kindId) is not in the catalog")
            }
            if !piece.x.isFinite || !piece.y.isFinite || piece.x < 0 || piece.x > SwimBounds.tankWidth
                || piece.y < 0 || piece.y > SwimBounds.tankHeight {
                problems.append("decor \(i) is outside the tank")
            }
            if !piece.rotation.isFinite || !DecorSpot.rotationRange.contains(piece.rotation) {
                problems.append("decor \(i) rotation is outside −π…π")
            }
            if !piece.scale.isFinite || !DecorSpot.scaleRange.contains(piece.scale) {
                problems.append("decor \(i) scale is outside 0.5…2.0")
            }
        }
        return problems
    }

    /// The actions that rebuild this configuration on any aquarium, in order: `habitat.select [habitatIndex]`;
    /// `decor.remove [0]` once per starter decor piece of that habitat (at most 12); for every piece i `decor.kind
    /// [kind index]`, `decor.place [x/16, y/9]` and `decor.turn [i, rotation, scale]`; then `decor.kind [decorKind]`,
    /// `lighting.level [lighting]` and `ambient.mode [1 or 0]`. Meant for a configuration that passed
    /// ``validate(catalog:)``: an unknown habitat removes nothing and an unknown kind is sent as index 0.
    public func actions(catalog: SpeciesCatalog) -> [(control: String, values: [Double])] {
        var list: [(control: String, values: [Double])] = [("habitat.select", [Double(habitatIndex)])]
        let starter = catalog.habitats.indices.contains(habitatIndex)
            ? min(catalog.habitats[habitatIndex].decor.count, HabitatDocument.maxDecor) : 0
        for _ in 0..<starter { list.append(("decor.remove", [0])) }
        for (i, piece) in decor.enumerated() {
            let kind = catalog.decor.firstIndex { $0.id == piece.kindId } ?? 0
            list.append(("decor.kind", [Double(kind)]))
            list.append(("decor.place", [piece.x / SwimBounds.tankWidth, piece.y / SwimBounds.tankHeight]))
            list.append(("decor.turn", [Double(i), piece.rotation, piece.scale]))
        }
        list.append(("decor.kind", [Double(decorKind)]))
        list.append(("lighting.level", [Double(lighting)]))
        list.append(("ambient.mode", [ambient ? 1 : 0]))
        return list
    }

    // MARK: File coding

    /// Why a configuration file could not be decoded.
    public enum FileError: Error, Equatable, Sendable {
        /// The file was written by a newer version (its format).
        case newer(Int)
        /// The file is not a configuration.
        case malformed
    }

    /// The configuration as JSON with sorted keys (`savedAt` as seconds since the reference date).
    public func fileData() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(self)
    }

    /// The format of a configuration file, read first so a newer file is recognised even when its other fields
    /// changed.
    private struct FormatProbe: Decodable { var format: Int }

    /// Decodes a configuration file: a format greater than ``currentFormat`` is `.newer`; anything that is not a
    /// configuration is `.malformed`. Validation (``validate(catalog:)``) and the id check against the file name are
    /// the caller's.
    public static func decode(_ data: Data) throws(FileError) -> AquariumConfiguration {
        let decoder = JSONDecoder()
        guard let probe = try? decoder.decode(FormatProbe.self, from: data) else { throw .malformed }
        if probe.format > currentFormat { throw .newer(probe.format) }
        guard let configuration = try? decoder.decode(AquariumConfiguration.self, from: data) else {
            throw .malformed
        }
        return configuration
    }
}
