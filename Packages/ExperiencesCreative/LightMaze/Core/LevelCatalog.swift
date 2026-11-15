// LevelCatalog — feature 096 (A13-P01) T-A13-103 (FR-A13-112–114; clarification Q4; research D4; data-model "Level";
// gap G-BOARD). The twenty bundled Light Maze levels `lm-01` … `lm-20` as Swift data: each with its name, its board
// (size, tiles in board order, the turnable tiles in their starting orientations) and a recorded solution (the
// orientation of every turnable tile, in tile order), by "VisualCore project" under "MIT". Levels 1–5 have one or two
// mirrors, levels 6–15 more mirrors and walls, levels 16–20 add a prism and a second target. Every level is valid, its
// starting state is not solved and its recorded solution lights every target; the tests prove each of these with the
// tracer. The levels were designed for this repository (layouts searched for a single solution with a small
// prototype of the tracer's rules, then named and checked by hand); they are original content.
//
// The JSON codec writes the catalog with sorted keys: `{"levels": […], "schema": 1}`, a level as
// `{"author", "height", "id", "license", "name", "solution": ["slash" | "backslash", …], "tiles": […], "width"}` and
// a tile as `{"column", "direction"?, "kind", "orientation"?, "row"}` (direction only for an emitter, orientation only
// for a mirror or a prism). The validating decoder keeps every valid level and refuses each invalid one with a named
// reason, so one damaged level never hides the rest. Checks per level, in this order (the first failure names the
// reason):
// 1. `missing-license`: the `license` or the `author` is missing or empty.
// 2. `unsupported-license`: the license is not in `LevelCatalog.allowedLicenses` (["MIT"]).
// 3. `invalid-number`: the record is not a JSON object with a non-empty string `id`, a string `name`, integer `width`
//    and `height`, a list `tiles` of objects each with a known string `kind` and integer `column` and `row` (and, when
//    present, a known string `direction` or `orientation`), and a list `solution` of known orientation strings.
//    A document that is not an object with a list `levels` and the integer `schema` 1 is refused as a whole with the
//    id `catalog` and this reason.
// 4. `out-of-range`: the width or the height lies outside 4…12, or there are more than 144 tiles.
// 5. `invalid-board`: the board has another problem (`Board.problem`: a tile outside the board, two tiles in one cell,
//    an emitter without a direction, a mirror or prism without an orientation, not exactly one emitter, no target) or
//    the solution's length differs from the number of turnable tiles.
// 6. `duplicate-id`: an otherwise valid level repeats the id of a level already kept.
import Foundation

/// One level: its id, name, board (in its starting orientations), recorded solution and provenance.
public struct Level: Codable, Equatable, Sendable, Identifiable {
    /// The id, `lm-01` … `lm-20` for the bundled levels.
    public var id: String
    /// The display name ("First light").
    public var name: String
    /// The board with the turnable tiles in their starting orientations.
    public var board: Board
    /// The recorded solution: the orientation of every turnable tile in tile order.
    public var solution: [Orientation]
    /// The author ("VisualCore project").
    public var author: String
    /// The license, one of ``LevelCatalog/allowedLicenses``.
    public var license: String

    /// Creates a level from all of its fields (no validation; `LevelCatalog.check(_:)` validates).
    public init(id: String, name: String, board: Board, solution: [Orientation], author: String, license: String) {
        self.id = id; self.name = name; self.board = board; self.solution = solution
        self.author = author; self.license = license
    }

    /// The starting orientations of the turnable tiles in tile order.
    public var startOrientations: [Orientation] { board.orientations }

    /// The board with the recorded solution applied, or nil when its length differs from the number of turnable tiles.
    public var solvedBoard: Board? { board.applying(solution) }

    /// The number of turnable tiles (mirrors and prisms).
    public var turnableCount: Int { board.turnableIndices.count }

    private enum CodingKeys: String, CodingKey { case author, height, id, license, name, solution, tiles, width }

    /// Decodes the flat JSON layout of the file header (no validation; use `LevelCatalog.decode(_:)`).
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        board = Board(width: try c.decode(Int.self, forKey: .width), height: try c.decode(Int.self, forKey: .height),
                      tiles: try c.decode([Tile].self, forKey: .tiles))
        solution = try c.decode([Orientation].self, forKey: .solution)
        author = try c.decode(String.self, forKey: .author)
        license = try c.decode(String.self, forKey: .license)
    }

    /// Encodes the flat JSON layout of the file header.
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(author, forKey: .author)
        try c.encode(board.height, forKey: .height)
        try c.encode(id, forKey: .id)
        try c.encode(license, forKey: .license)
        try c.encode(name, forKey: .name)
        try c.encode(solution, forKey: .solution)
        try c.encode(board.tiles, forKey: .tiles)
        try c.encode(board.width, forKey: .width)
    }
}

/// Why a level was refused; the raw values are the reason names used in documents and tests.
public enum LevelRefusalReason: String, Codable, CaseIterable, Error, Sendable {
    /// The level has no license or no author.
    case missingLicense = "missing-license"
    /// The level's license is not an allowed license.
    case unsupportedLicense = "unsupported-license"
    /// A number (or the record layout) is missing, malformed or not an integer.
    case invalidNumber = "invalid-number"
    /// The size lies outside 4…12 or there are more than 144 tiles.
    case outOfRange = "out-of-range"
    /// The id repeats the id of a level already kept.
    case duplicateId = "duplicate-id"
    /// The board breaks a rule, or the solution does not fit its turnable tiles.
    case invalidBoard = "invalid-board"
}

/// One refused level: its id (empty when it had none; `catalog` for an unreadable document) and the reason.
public struct LevelRefusal: Codable, Equatable, Sendable {
    /// The refused level's id, or "" when it had no readable id.
    public var id: String
    /// Why it was refused.
    public var reason: LevelRefusalReason

    /// Creates a refusal record.
    public init(id: String, reason: LevelRefusalReason) { self.id = id; self.reason = reason }
}

/// The level catalog of Light Maze.
public struct LevelCatalog: Codable, Equatable, Sendable {
    /// The catalog schema this code writes and reads.
    public static let schemaVersion = 1
    /// The only licenses a level may carry.
    public static let allowedLicenses = ["MIT"]
    /// The author of every bundled level.
    public static let projectAuthor = "VisualCore project"

    /// The levels in catalog order.
    public var levels: [Level]

    /// Creates a catalog from its levels (no validation; ``decode(_:)`` validates).
    public init(levels: [Level]) { self.levels = levels }

    /// The level with `id`, if any.
    public func level(id: String) -> Level? { levels.first { $0.id == id } }

    /// The level at `index`, if any.
    public func level(at index: Int) -> Level? { levels.indices.contains(index) ? levels[index] : nil }

    /// A bundled level: id `lm-NN` from `number`, the project author and the MIT license.
    private static func level(_ number: Int, _ name: String, _ width: Int, _ height: Int, _ tiles: [Tile],
                              solution: [Orientation]) -> Level {
        let id = number < 10 ? "lm-0\(number)" : "lm-\(number)"
        return Level(id: id, name: name, board: Board(width: width, height: height, tiles: tiles),
                     solution: solution, author: projectAuthor, license: "MIT")
    }

    /// The twenty bundled levels `lm-01` … `lm-20` (see the file header).
    public static let bundled = LevelCatalog(levels: [
        level(1, "First light", 5, 5, [
                  .wall(2, 0), .emitter(0, 2, .east), .mirror(2, 2, .backslash), .target(2, 4)],
              solution: [.slash]),
        level(2, "Around the corner", 5, 5, [
                  .mirror(0, 2, .slash), .emitter(4, 2, .west), .mirror(0, 3, .backslash), .target(2, 3),
                  .wall(4, 4)],
              solution: [.backslash, .slash]),
        level(3, "Two turns", 5, 5, [
                  .target(0, 0), .mirror(3, 0, .backslash), .wall(4, 0), .mirror(3, 3, .backslash),
                  .emitter(4, 3, .west), .wall(3, 4)],
              solution: [.slash, .slash]),
        level(4, "Side step", 6, 6, [
                  .wall(1, 0), .target(4, 0), .mirror(4, 2, .backslash), .mirror(5, 2, .backslash), .wall(2, 3),
                  .emitter(5, 4, .south)],
              solution: [.slash, .slash]),
        level(5, "Double back", 6, 6, [
                  .target(5, 0), .wall(0, 1), .mirror(2, 1, .slash), .mirror(5, 1, .slash), .wall(0, 2),
                  .emitter(2, 3, .south), .wall(2, 5)],
              solution: [.backslash, .backslash]),
        level(6, "Three mirrors", 6, 6, [
                  .emitter(4, 0, .north), .mirror(0, 1, .slash), .mirror(4, 1, .slash),
                  .mirror(0, 3, .backslash), .target(2, 3), .wall(5, 4), .wall(0, 5), .wall(5, 5)],
              solution: [.backslash, .backslash, .slash]),
        level(7, "Corridor", 7, 7, [
                  .mirror(1, 0, .slash), .mirror(4, 0, .backslash), .wall(6, 1), .mirror(1, 2, .backslash),
                  .emitter(5, 2, .west), .wall(6, 2), .wall(0, 4), .target(4, 4), .wall(6, 4)],
              solution: [.backslash, .slash, .slash]),
        level(8, "Walled garden", 7, 7, [
                  .emitter(0, 0, .east), .mirror(3, 0, .backslash), .wall(6, 0), .target(1, 1),
                  .mirror(2, 1, .backslash), .wall(4, 2), .wall(0, 4), .mirror(2, 5, .backslash),
                  .mirror(3, 5, .slash), .wall(0, 6)],
              solution: [.slash, .slash, .slash, .backslash]),
        level(9, "Zigzag", 7, 7, [
                  .target(2, 0), .wall(4, 1), .wall(5, 1), .mirror(2, 2, .backslash), .mirror(6, 2, .backslash),
                  .emitter(0, 3, .north), .mirror(0, 5, .backslash), .mirror(6, 5, .slash), .wall(0, 6),
                  .wall(3, 6), .wall(4, 6)],
              solution: [.slash, .slash, .slash, .backslash]),
        level(10, "Switchback", 8, 8, [
                  .target(2, 0), .wall(6, 1), .wall(5, 2), .wall(4, 3), .mirror(0, 4, .slash),
                  .mirror(4, 4, .backslash), .emitter(1, 5, .east), .mirror(4, 5, .slash),
                  .mirror(0, 6, .backslash), .mirror(2, 6, .slash), .wall(1, 7), .wall(4, 7)],
              solution: [.backslash, .slash, .backslash, .slash, .backslash]),
        level(11, "Mirror hall", 8, 8, [
                  .target(3, 0), .mirror(5, 1, .slash), .emitter(6, 1, .west), .wall(1, 2),
                  .mirror(3, 2, .backslash), .mirror(6, 2, .backslash), .wall(0, 3), .wall(2, 3), .wall(0, 6),
                  .wall(1, 6), .wall(4, 7), .mirror(5, 7, .backslash), .mirror(6, 7, .slash)],
              solution: [.backslash, .slash, .slash, .slash, .backslash]),
        level(12, "Long way round", 8, 8, [
                  .wall(7, 0), .mirror(1, 1, .slash), .mirror(3, 1, .backslash), .target(5, 1),
                  .mirror(7, 1, .backslash), .wall(6, 2), .mirror(3, 3, .backslash), .mirror(7, 3, .slash),
                  .wall(7, 4), .mirror(1, 5, .backslash), .emitter(5, 5, .west), .wall(2, 6), .wall(7, 6),
                  .wall(2, 7)],
              solution: [.backslash, .slash, .slash, .slash, .backslash, .slash]),
        level(13, "Labyrinth", 9, 9, [
                  .wall(3, 0), .mirror(5, 0, .slash), .mirror(8, 0, .backslash), .mirror(0, 1, .slash),
                  .mirror(5, 1, .slash), .wall(6, 1), .wall(7, 2), .wall(6, 3), .wall(7, 3),
                  .mirror(0, 5, .backslash), .target(7, 5), .wall(6, 7), .wall(2, 8), .emitter(5, 8, .east),
                  .mirror(8, 8, .slash)],
              solution: [.backslash, .slash, .backslash, .backslash, .slash, .backslash]),
        level(14, "Crossroads", 9, 9, [
                  .wall(1, 0), .wall(4, 0), .mirror(5, 0, .slash), .mirror(8, 0, .backslash),
                  .emitter(1, 1, .north), .mirror(4, 1, .slash), .mirror(8, 1, .slash), .wall(0, 3),
                  .mirror(1, 3, .backslash), .mirror(5, 3, .slash), .wall(8, 3), .mirror(4, 4, .backslash),
                  .target(6, 4), .wall(4, 5), .wall(0, 7), .wall(7, 7), .wall(2, 8)],
              solution: [.backslash, .slash, .backslash, .backslash, .slash, .backslash, .slash]),
        level(15, "Grand tour", 10, 10, [
                  .mirror(4, 0, .slash), .target(9, 0), .wall(7, 1), .emitter(2, 2, .east),
                  .mirror(3, 2, .backslash), .wall(0, 3), .wall(8, 4), .wall(1, 5), .mirror(4, 5, .backslash),
                  .mirror(5, 5, .backslash), .wall(6, 5), .wall(8, 5), .mirror(3, 6, .backslash),
                  .mirror(7, 6, .backslash), .wall(8, 6), .wall(1, 8), .wall(4, 8), .mirror(5, 8, .backslash),
                  .mirror(7, 8, .slash)],
              solution: [.backslash, .slash, .slash, .slash, .slash, .slash, .slash, .backslash]),
        level(16, "Split", 6, 6, [
                  .emitter(1, 0, .east), .prism(2, 0, .backslash), .target(4, 0), .target(1, 3),
                  .mirror(2, 3, .slash), .wall(3, 3), .wall(2, 4)],
              solution: [.slash, .backslash]),
        level(17, "Two lamps", 7, 7, [
                  .target(2, 1), .mirror(6, 1, .backslash), .target(5, 4), .prism(6, 4, .backslash), .wall(3, 5),
                  .wall(4, 5), .wall(5, 5), .emitter(1, 6, .east), .mirror(6, 6, .slash)],
              solution: [.slash, .slash, .backslash]),
        level(18, "Fork in the road", 8, 8, [
                  .mirror(1, 0, .slash), .prism(3, 0, .backslash), .target(4, 0), .wall(5, 2), .wall(6, 2),
                  .mirror(1, 3, .backslash), .mirror(4, 3, .backslash), .wall(5, 3), .target(3, 4),
                  .emitter(4, 6, .south), .wall(2, 7)],
              solution: [.backslash, .slash, .slash, .slash]),
        level(19, "Beam splitter", 9, 9, [
                  .target(3, 0), .wall(8, 1), .wall(2, 2), .wall(4, 2), .emitter(6, 4, .north), .target(0, 5),
                  .mirror(5, 5, .backslash), .mirror(5, 6, .backslash), .prism(6, 6, .slash), .wall(1, 7),
                  .mirror(3, 7, .backslash), .mirror(6, 7, .slash), .wall(4, 8)],
              solution: [.slash, .slash, .backslash, .slash, .backslash]),
        level(20, "Prism maze", 10, 10, [
                  .mirror(1, 0, .slash), .target(5, 0), .wall(5, 1), .wall(7, 1), .mirror(1, 2, .backslash),
                  .mirror(3, 2, .backslash), .target(0, 4), .mirror(6, 4, .backslash), .wall(1, 6),
                  .emitter(0, 7, .east), .prism(3, 7, .slash), .mirror(6, 7, .slash), .wall(7, 7), .wall(8, 7),
                  .wall(7, 8)],
              solution: [.backslash, .slash, .slash, .slash, .backslash, .backslash]),
    ])

    // MARK: - Validation

    /// The license problem of a level with `author` and `license`, or nil when both are present and allowed.
    public static func licenseError(author: String, license: String) -> LevelRefusalReason? {
        let author = author.trimmingCharacters(in: .whitespacesAndNewlines)
        let license = license.trimmingCharacters(in: .whitespacesAndNewlines)
        if author.isEmpty || license.isEmpty { return .missingLicense }
        return allowedLicenses.contains(license) ? nil : .unsupportedLicense
    }

    /// The first problem of `level` (license, layout, ranges, then board rules), or nil when valid.
    public static func check(_ level: Level) -> LevelRefusalReason? {
        if let error = licenseError(author: level.author, license: level.license) { return error }
        guard !level.id.isEmpty else { return .invalidNumber }
        switch level.board.problem {
        case .some(.sizeOutOfRange), .some(.tooManyTiles): return .outOfRange
        case .some: return .invalidBoard
        case .none: break
        }
        guard level.solution.count == level.turnableCount else { return .invalidBoard }
        return nil
    }

    // MARK: - JSON

    /// The catalog as JSON with sorted keys (deterministic bytes for equal catalogs).
    public func encoded() -> Data {
        struct Document: Encodable { var levels: [Level]; var schema: Int }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return (try? encoder.encode(Document(levels: levels, schema: Self.schemaVersion))) ?? Data()
    }

    /// Decodes a catalog from `data`, keeping every valid level and naming every refused one (see the file header for
    /// the checks and their order). An unreadable document gives an empty catalog and one `catalog` refusal.
    public static func decode(_ data: Data) -> (catalog: LevelCatalog, refused: [LevelRefusal]) {
        let unreadable = (LevelCatalog(levels: []), [LevelRefusal(id: "catalog", reason: .invalidNumber)])
        guard let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let list = root["levels"] as? [Any], integer(root["schema"]) == schemaVersion else { return unreadable }
        var kept: [Level] = []
        var refused: [LevelRefusal] = []
        for element in list {
            let object = (element as? [String: Any]) ?? [:]
            switch parse(object) {
            case .success(let level) where kept.contains(where: { $0.id == level.id }):
                refused.append(LevelRefusal(id: level.id, reason: .duplicateId))
            case .success(let level): kept.append(level)
            case .failure(let reason): refused.append(LevelRefusal(id: (object["id"] as? String) ?? "", reason: reason))
            }
        }
        return (LevelCatalog(levels: kept), refused)
    }

    /// An integral JSON number as an `Int`, or nil (booleans, strings, fractions and non-finite values are not).
    private static func integer(_ value: Any?) -> Int? {
        guard let number = value as? NSNumber, CFGetTypeID(number) != CFBooleanGetTypeID() else { return nil }
        let double = number.doubleValue
        guard double.isFinite, double == double.rounded(), abs(double) < 1e9 else { return nil }
        return Int(double)
    }

    /// One JSON tile object, or nil when its layout is malformed.
    private static func tile(_ value: Any) -> Tile? {
        guard let object = value as? [String: Any], let kindName = object["kind"] as? String,
              let kind = TileKind(rawValue: kindName), let column = integer(object["column"]),
              let row = integer(object["row"]) else { return nil }
        var direction: Direction?
        if let raw = object["direction"] {
            guard let name = raw as? String, let parsed = Direction(rawValue: name) else { return nil }
            direction = parsed
        }
        var orientation: Orientation?
        if let raw = object["orientation"] {
            guard let name = raw as? String, let parsed = Orientation(rawValue: name) else { return nil }
            orientation = parsed
        }
        return Tile(kind: kind, cell: Cell(column, row), direction: direction, orientation: orientation)
    }

    /// One JSON object to a checked level, or the first reason it is refused.
    private static func parse(_ object: [String: Any]) -> Result<Level, LevelRefusalReason> {
        if let error = licenseError(author: (object["author"] as? String) ?? "",
                                    license: (object["license"] as? String) ?? "") { return .failure(error) }
        guard let id = object["id"] as? String, !id.isEmpty, let name = object["name"] as? String,
              let width = integer(object["width"]), let height = integer(object["height"]),
              let tileList = object["tiles"] as? [Any], let solutionList = object["solution"] as? [Any]
        else { return .failure(.invalidNumber) }
        let tiles = tileList.compactMap(tile)
        let solution = solutionList.compactMap { ($0 as? String).flatMap(Orientation.init(rawValue:)) }
        guard tiles.count == tileList.count, solution.count == solutionList.count else {
            return .failure(.invalidNumber)
        }
        let level = Level(id: id, name: name, board: Board(width: width, height: height, tiles: tiles),
                          solution: solution, author: (object["author"] as? String) ?? "",
                          license: (object["license"] as? String) ?? "")
        if let error = check(level) { return .failure(error) }
        return .success(level)
    }
}
