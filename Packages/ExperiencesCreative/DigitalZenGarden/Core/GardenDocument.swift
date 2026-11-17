// GardenDocument — feature 145 (A20-P01) T-A20-104 (FR-A20-101, FR-A20-102; clarifications Q1, Q2, Q3). The garden
// document: tray, sand tone, stones and rake strokes in normalized tray coordinates, stored as a versioned JSON
// envelope of kind `a20.garden` with typed refusals. Decoding never touches a document the caller holds; a refused
// file leaves the open garden as it was. Pure Foundation and VisualCoreMath; no GPU, network or clock.
import Foundation
import VisualCoreMath

/// Why a garden file was refused. A refused file leaves the open garden unchanged.
public enum DocumentRefusal: Error, Equatable, Sendable {
    /// The file is not valid JSON, has the wrong kind, lacks a field or has a version below 1.
    case damaged
    /// The file was written by a newer version (above ``GardenDocument/schemaVersion``); the value is that version.
    case newerVersion(Int)
    /// The file is larger than ``GardenDocument/maxBytes``; the value is its size in bytes.
    case tooLarge(Int)
    /// The tray id is not in ``GardenPalette/trays``; the value is the id.
    case unknownTray(String)
    /// The sand tone id is not in ``GardenPalette/tones``; the value is the id.
    case unknownTone(String)
    /// A stroke names a rake style that is not in ``GardenPalette/rakes``; the value is the id.
    case unknownRake(String)
    /// A stone names a kind that is not in ``GardenPalette/stones``; the value is the id.
    case unknownStone(String)
    /// A value is non-finite or outside its range, a stone id or depth repeats, or `nextStoneID` is not greater than
    /// every stone id; the value names the field (`points`, `position`, `rotation`, `scale`, `id`, `depth`,
    /// `nextStoneID`).
    case outOfRange(String)
    /// A count is above its cap or a stroke has no points; the value names the field (`stones`, `strokes`,
    /// `points`).
    case overCap(String)

    /// The stable code: `damaged`, `newer-version`, `too-large`, `unknown-tray`, `unknown-tone`, `unknown-rake`,
    /// `unknown-stone`, `out-of-range` or `over-cap`.
    public var code: String {
        switch self {
        case .damaged: return "damaged"
        case .newerVersion: return "newer-version"
        case .tooLarge: return "too-large"
        case .unknownTray: return "unknown-tray"
        case .unknownTone: return "unknown-tone"
        case .unknownRake: return "unknown-rake"
        case .unknownStone: return "unknown-stone"
        case .outOfRange: return "out-of-range"
        case .overCap: return "over-cap"
        }
    }

    /// One plain sentence describing the refusal and naming the offending value.
    public var sentence: String {
        switch self {
        case .damaged:
            return "The garden file is damaged and was not opened."
        case .newerVersion(let version):
            return "The garden file has version \(version), newer than version \(GardenDocument.schemaVersion) "
                + "that this version opens."
        case .tooLarge(let bytes):
            return "The garden file is \(bytes) bytes, above the limit of \(GardenDocument.maxBytes) bytes."
        case .unknownTray(let id):
            return "The garden file names the unknown tray \"\(id)\"."
        case .unknownTone(let id):
            return "The garden file names the unknown sand tone \"\(id)\"."
        case .unknownRake(let id):
            return "The garden file names the unknown rake \"\(id)\"."
        case .unknownStone(let id):
            return "The garden file names the unknown stone \"\(id)\"."
        case .outOfRange(let field):
            return "The garden file has a value out of range for \"\(field)\"."
        case .overCap(let field):
            return "The garden file has too many or too few \"\(field)\"."
        }
    }
}

/// One rake stroke: a rake style and its resampled points in normalized tray coordinates (1…``maxPoints``). A
/// stroke of one point is a dab.
public struct RakeStroke: Codable, Equatable, Sendable {
    /// The most points a stroke holds; a longer stroke ends here and is marked ``capped``.
    public static let maxPoints = 512

    /// The rake style id (one of ``GardenPalette/rakes``).
    public var rake: String
    /// The points, each coordinate finite and in 0…1.
    public var points: [Vec2]
    /// Whether the stroke was cut at ``maxPoints``.
    public var capped: Bool

    /// Creates a stroke.
    public init(rake: String, points: [Vec2], capped: Bool = false) {
        self.rake = rake
        self.points = points
        self.capped = capped
    }
}

/// One stone on the sand. Stones do not change the sand heights in this phase.
public struct Stone: Codable, Equatable, Sendable {
    /// The accepted position range of each coordinate.
    public static let positionRange: ClosedRange<Double> = 0...1
    /// The accepted rotation range, in radians.
    public static let rotationRange: ClosedRange<Double> = -Double.pi...Double.pi
    /// The accepted scale range.
    public static let scaleRange: ClosedRange<Double> = 0.5...2

    /// The id, unique in the garden and below ``GardenDocument/nextStoneID``.
    public var id: UInt32
    /// The stone kind id (one of ``GardenPalette/stones``).
    public var kind: String
    /// The centre in normalized tray coordinates (each in 0…1).
    public var position: Vec2
    /// The rotation in radians (−π…π).
    public var rotation: Double
    /// The scale of the kind's base radii (0.5…2).
    public var scale: Double
    /// The depth order, unique in the garden (higher draws on top).
    public var depth: Int

    /// Creates a stone.
    public init(id: UInt32, kind: String, position: Vec2, rotation: Double, scale: Double, depth: Int) {
        self.id = id
        self.kind = kind
        self.position = position
        self.rotation = rotation
        self.scale = scale
        self.depth = depth
    }
}

/// A garden (schema 1): the tray, the sand tone, the stones and the strokes in order.
public struct GardenDocument: Codable, Equatable, Sendable {
    /// The envelope kind of a garden file.
    public static let kind = "a20.garden"
    /// The schema version this code writes and reads.
    public static let schemaVersion = 1
    /// The largest garden file accepted, in bytes.
    public static let maxBytes = 262_144
    /// The most stones a garden holds.
    public static let maxStones = 24
    /// The most strokes a garden holds.
    public static let maxStrokes = 400

    /// The tray id (one of ``GardenPalette/trays``).
    public var tray: String
    /// The sand tone id (one of ``GardenPalette/tones``).
    public var tone: String
    /// The stones (at most ``maxStones``).
    public var stones: [Stone]
    /// The strokes in the order they were raked (at most ``maxStrokes``).
    public var strokes: [RakeStroke]
    /// The id the next placed stone receives; greater than every stone id.
    public var nextStoneID: UInt32

    /// Creates a document.
    public init(tray: String, tone: String, stones: [Stone], strokes: [RakeStroke], nextStoneID: UInt32) {
        self.tray = tray
        self.tone = tone
        self.stones = stones
        self.strokes = strokes
        self.nextStoneID = nextStoneID
    }

    /// The empty garden: `small-tray`, `pale`, no stones, no strokes, next stone id 1.
    public static let empty = GardenDocument(tray: GardenPalette.smallTray.id, tone: GardenPalette.defaultToneID,
                                             stones: [], strokes: [], nextStoneID: 1)

    private struct Envelope: Codable {
        var kind: String
        var version: Int
        var body: GardenDocument?
    }

    private struct Header: Decodable {
        var kind: String
        var version: Int
    }

    /// The garden file: the JSON envelope `{"body", "kind", "version"}` with sorted keys and unescaped slashes.
    /// Throws when a number is not finite.
    public func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(Envelope(kind: Self.kind, version: Self.schemaVersion, body: self))
    }

    /// Reads a garden file. Checks, in order: the size (``DocumentRefusal/tooLarge(_:)``), the envelope and its kind
    /// (``DocumentRefusal/damaged``), the version (``DocumentRefusal/newerVersion(_:)``), the body
    /// (``DocumentRefusal/damaged``), then every value (``validate()``). Nothing the caller holds is changed.
    public static func decode(_ data: Data) -> Result<GardenDocument, DocumentRefusal> {
        guard data.count <= maxBytes else { return .failure(.tooLarge(data.count)) }
        let decoder = JSONDecoder()
        guard let header = try? decoder.decode(Header.self, from: data), header.kind == kind,
              header.version >= 1 else { return .failure(.damaged) }
        guard header.version <= schemaVersion else { return .failure(.newerVersion(header.version)) }
        guard let envelope = try? decoder.decode(Envelope.self, from: data),
              let document = envelope.body else { return .failure(.damaged) }
        if let refusal = document.validate() { return .failure(refusal) }
        return .success(document)
    }

    /// The first refusal of the document's values, or nil when it is valid. Checks, in order: the tray, the tone,
    /// the stone and stroke counts, each stroke (rake, point count, points), each stone (kind, position, rotation,
    /// scale), unique stone ids and depths, then `nextStoneID`.
    public func validate() -> DocumentRefusal? {
        guard GardenPalette.tray(id: tray) != nil else { return .unknownTray(tray) }
        guard GardenPalette.tone(id: tone) != nil else { return .unknownTone(tone) }
        guard stones.count <= Self.maxStones else { return .overCap("stones") }
        guard strokes.count <= Self.maxStrokes else { return .overCap("strokes") }
        for stroke in strokes {
            if let refusal = Self.refusal(of: stroke) { return refusal }
        }
        var ids = Set<UInt32>()
        var depths = Set<Int>()
        for stone in stones {
            if let refusal = Self.refusal(of: stone) { return refusal }
            guard ids.insert(stone.id).inserted else { return .outOfRange("id") }
            guard depths.insert(stone.depth).inserted else { return .outOfRange("depth") }
            guard stone.id < nextStoneID else { return .outOfRange("nextStoneID") }
        }
        guard nextStoneID >= 1 else { return .outOfRange("nextStoneID") }
        return nil
    }

    private static func refusal(of stroke: RakeStroke) -> DocumentRefusal? {
        guard GardenPalette.rake(id: stroke.rake) != nil else { return .unknownRake(stroke.rake) }
        guard !stroke.points.isEmpty, stroke.points.count <= RakeStroke.maxPoints else { return .overCap("points") }
        for point in stroke.points where !inUnit(point) { return .outOfRange("points") }
        return nil
    }

    private static func refusal(of stone: Stone) -> DocumentRefusal? {
        guard GardenPalette.stone(id: stone.kind) != nil else { return .unknownStone(stone.kind) }
        guard inUnit(stone.position) else { return .outOfRange("position") }
        guard stone.rotation.isFinite, Stone.rotationRange.contains(stone.rotation) else {
            return .outOfRange("rotation")
        }
        guard stone.scale.isFinite, Stone.scaleRange.contains(stone.scale) else { return .outOfRange("scale") }
        return nil
    }

    private static func inUnit(_ point: Vec2) -> Bool {
        point.x.isFinite && point.y.isFinite && Stone.positionRange.contains(point.x)
            && Stone.positionRange.contains(point.y)
    }
}
