// CatalogManifest — feature 187 T-U01-006 (FR-U01-003, FR-U01-013, FR-U01-030 to FR-U01-036; data-model sections 2, 3).
// Bounded loading of the runtime catalog: size cap, exact key sets, limits, ranges, one typed error per defect.
import Foundation

/// The validated runtime catalog of the unified app (`Catalog/experiences.json`, schema 1).
///
/// Loading is a pure function of the data: it reads no clock, no language setting, no file and no network, and it
/// either returns a fully validated value or throws exactly one `CatalogError`. A loaded manifest is immutable and
/// may be shared freely.
public struct CatalogManifest: Sendable, Equatable {
    /// The only schema version this build reads.
    public static let supportedSchema = 1
    /// The largest catalog file that is parsed, in bytes.
    public static let maxBytes = 1_048_576
    /// The largest number of entries.
    public static let maxEntries = 400

    /// The schema version of the file (always `supportedSchema`).
    public let schemaVersion: Int
    /// The SHA-256 of the planning catalog the manifest was built from.
    public let catalogSHA256: String
    /// All entries in ascending catalog order.
    public let experiences: [ExperienceDescriptor]

    /// Loads and validates a manifest.
    ///
    /// The checks run in a fixed order, so a file with several defects reports the first: size, JSON object, schema
    /// version, top-level keys, entry count, every entry in turn, duplicates, ascending order, launch allocation.
    public init(data: Data) throws(CatalogError) {
        guard data.count <= Self.maxBytes else { throw .tooLarge(bytes: data.count, limit: Self.maxBytes) }
        let top = try JSONFields.root(of: data, name: "manifest")
        let schema = try top.whole("schema", Int(Int32.min)...Int(Int32.max))
        guard schema == Self.supportedSchema else { throw .unsupportedSchema(found: schema, supported: Self.supportedSchema) }
        try top.requireOnly(["schema", "catalog_sha256", "experiences"])
        let hash = try top.text("catalog_sha256")
        guard JSONFields.isSHA256(hash) else {
            throw .invalidValue(entry: top.entry, field: "catalog_sha256", reason: "64 lower-case hexadecimal digits")
        }
        guard let list = top.object["experiences"] as? [Any] else { throw .wrongType(entry: top.entry, field: "experiences") }
        guard list.count <= Self.maxEntries else { throw .tooManyEntries(count: list.count, limit: Self.maxEntries) }

        var entries: [ExperienceDescriptor] = []
        entries.reserveCapacity(list.count)
        for (index, item) in list.enumerated() {
            entries.append(try Self.descriptor(item, index: index))
        }
        var ids = Set<String>(), codes = Set<String>(), orders = Set<Int>()
        for entry in entries {
            guard ids.insert(entry.id.rawValue).inserted else { throw .duplicate(field: "id", value: entry.id.rawValue) }
            guard codes.insert(entry.code.text).inserted else { throw .duplicate(field: "code", value: entry.code.text) }
            guard orders.insert(entry.order).inserted else { throw .duplicate(field: "order", value: String(entry.order)) }
        }
        for index in entries.indices.dropFirst() where entries[index].order < entries[index - 1].order {
            throw .outOfOrder(entry: entries[index].id.rawValue)
        }
        try Self.checkAllocation(entries)
        schemaVersion = schema
        catalogSHA256 = hash
        experiences = entries
    }

    /// The entry with this id, if the catalog has one.
    public func experience(_ id: ExperienceID) -> ExperienceDescriptor? { experiences.first { $0.id == id } }

    /// The entry with this code, if the catalog has one.
    public func experience(code: ExperienceCode) -> ExperienceDescriptor? { experiences.first { $0.code == code } }

    /// The entries of one launcher category, in catalog order.
    public func experiences(in category: ExperienceCategory) -> [ExperienceDescriptor] { experiences.filter { $0.category == category } }

    /// The entries whose integration gate is pass, in catalog order.
    public var available: [ExperienceDescriptor] { experiences.filter(\.isAvailable) }

    /// The families of one category, each once, in the order of their first entry.
    public func families(in category: ExperienceCategory) -> [String] {
        var seen = Set<String>()
        return experiences(in: category).map(\.family).filter { seen.insert($0).inserted }
    }

    // MARK: - Launch allocation (ADR-0009 D-02; FR-U01-011, FR-U01-012)

    /// Games per round and original experiences: 25 each.
    static let collectionSize = 25
    /// Rounds whose games are free (round 2) and premium at launch (rounds 3 and 4); later rounds are the backlog.
    static let freeRounds = 2...2, premiumLaunchRounds = 3...4, backlogRounds = 5...12

    /// The 100 launch codes in catalog order: A01–A25 and R02-G01–R02-G25 (free), R03-G01–R04-G25 (premium).
    public static let launchCodes: [String] = (1...collectionSize).map { String(format: "A%02d", $0) }
        + (freeRounds.lowerBound...premiumLaunchRounds.upperBound).flatMap { round in
            (1...collectionSize).map { String(format: "R%02d-G%02d", round, $0) }
        }

    /// The rule is code, not data: a file cannot redefine which experiences are free.
    private static func checkAllocation(_ entries: [ExperienceDescriptor]) throws(CatalogError) {
        for entry in entries {
            let code = entry.code
            guard code.number <= collectionSize else {
                throw .allocation(code: code.text, reason: "a collection has \(collectionSize) experiences")
            }
            let expected: ExperienceTier
            if let round = code.round {
                guard freeRounds.contains(round) || premiumLaunchRounds.contains(round) || backlogRounds.contains(round) else {
                    throw .allocation(code: code.text, reason: "rounds are 02 to 12")
                }
                expected = freeRounds.contains(round) ? .free : .premium
            } else {
                expected = .free
            }
            guard entry.tier == expected else {
                throw .allocation(code: code.text, reason: "this experience is \(expected.rawValue)")
            }
        }
        let present = Set(entries.map(\.code.text))
        if let missing = launchCodes.first(where: { !present.contains($0) }) {
            throw .allocation(code: missing, reason: "a launch experience is missing")
        }
    }

    // MARK: - One entry

    static let entryKeys = ["id", "code", "title", "summary", "kind", "tier", "category", "family", "tags", "order", "palette",
                            "tile_seed", "capabilities", "quality_tiers", "content", "available"]

    private static func descriptor(_ item: Any, index: Int) throws(CatalogError) -> ExperienceDescriptor {
        let position = "#\(index)"
        guard let object = item as? [String: Any] else { throw .wrongType(entry: position, field: "experiences") }
        guard let rawID = object["id"] else { throw .missingField(entry: position, field: "id") }
        guard let idText = rawID as? String else { throw .wrongType(entry: position, field: "id") }
        let id: ExperienceID
        do {
            id = try ExperienceID(idText)
        } catch {
            guard case let .malformed(_, reason) = error else { throw .invalidValue(entry: position, field: "id", reason: "malformed") }
            throw .invalidValue(entry: position, field: "id", reason: reason)
        }
        let fields = JSONFields(entry: idText, object: object)
        try fields.requireOnly(entryKeys)

        guard try fields.text("code") == id.code.text else {
            throw .invalidValue(entry: idText, field: "code", reason: "differs from the code inside the id")
        }
        let title = try fields.text("title", 1...80)
        let summary = try fields.text("summary", 1...300)
        guard let kind = ExperienceKind(rawValue: try fields.text("kind")) else {
            throw .invalidValue(entry: idText, field: "kind", reason: "creative or game")
        }
        guard let tier = ExperienceTier(rawValue: try fields.text("tier")) else {
            throw .invalidValue(entry: idText, field: "tier", reason: "free or premium")
        }
        guard let category = ExperienceCategory(rawValue: try fields.text("category")) else {
            throw .invalidValue(entry: idText, field: "category", reason: "one of the seven launcher categories")
        }
        guard (kind == .game) == (category == .puzzle) else {
            throw .invalidValue(entry: idText, field: "category", reason: "a game is a puzzle and a creative experience is not")
        }
        let family = try fields.text("family", 1...60)
        let tags = try fields.texts("tags", maxCount: 16, length: 1...60)
        guard tags.contains(ExperienceDescriptor.tag(forFamily: family)) else {
            throw .invalidValue(entry: idText, field: "tags", reason: "the family is missing among the tags")
        }
        let order = try fields.whole("order", 1...9_999)
        let palette = try fields.texts("palette", maxCount: 8, length: 7...7)
        guard palette.allSatisfy(JSONFields.isColor) else {
            throw .invalidValue(entry: idText, field: "palette", reason: "a color is written #RRGGBB")
        }
        let tileSeed = try fields.whole("tile_seed", 0...4_294_967_295)
        let capabilities = try fields.texts("capabilities", maxCount: 16, length: 1...40)
        let qualityTiers = try fields.texts("quality_tiers", maxCount: 8, length: 1...40)
        let content = try content(of: fields, kind: kind)
        let available = try fields.flag("available")
        return ExperienceDescriptor(id: id, title: title, summary: summary, kind: kind, tier: tier, category: category, family: family,
                                    tags: tags, order: order, palette: palette, tileSeed: UInt32(tileSeed), capabilities: capabilities,
                                    qualityTiers: qualityTiers, content: content, isAvailable: available)
    }

    private static func content(of fields: JSONFields, kind: ExperienceKind) throws(CatalogError) -> ExperienceContent? {
        guard let raw = fields.object["content"], !(raw is NSNull) else { return nil }
        guard let object = raw as? [String: Any] else { throw .wrongType(entry: fields.entry, field: "content") }
        guard kind == .game else { throw .invalidValue(entry: fields.entry, field: "content", reason: "only a game has content facts") }
        let inner = JSONFields(entry: fields.entry, object: object, reportedField: "content")
        try inner.requireOnly(["levels", "catalog_sha256"])
        let levels = try inner.whole("levels", 0...10_000)
        let hash = try inner.text("catalog_sha256")
        guard JSONFields.isSHA256(hash) else {
            throw .invalidValue(entry: fields.entry, field: "content", reason: "the level catalog hash has 64 lower-case hexadecimal digits")
        }
        return ExperienceContent(levels: levels, catalogSHA256: hash)
    }
}

/// Reads the fields of one JSON object and names the entry and the field in every error.
struct JSONFields {
    /// The name of the object in errors.
    let entry: String
    let object: [String: Any]
    /// When set, every error of this reader names this field instead of the inner key (for nested objects).
    var reportedField: String?

    init(entry: String, object: [String: Any], reportedField: String? = nil) {
        self.entry = entry
        self.object = object
        self.reportedField = reportedField
    }

    /// Parses data that must be a JSON object. The caller has checked the size.
    static func root(of data: Data, name: String) throws(CatalogError) -> JSONFields {
        let parsed: Any
        do {
            parsed = try JSONSerialization.jsonObject(with: data)
        } catch {
            throw .unreadable(reason: "not valid JSON")
        }
        guard let object = parsed as? [String: Any] else { throw .unreadable(reason: "the top level is not an object") }
        return JSONFields(entry: name, object: object)
    }

    private func name(_ key: String) -> String { reportedField ?? key }

    /// Refuses a key outside `keys` (first in sorted order), then the first key of `keys` that is absent.
    func requireOnly(_ keys: [String]) throws(CatalogError) {
        if let extra = object.keys.sorted().first(where: { !keys.contains($0) }) {
            throw .unknownField(entry: entry, field: name(extra))
        }
        if let missing = keys.first(where: { object[$0] == nil }) {
            throw .missingField(entry: entry, field: name(missing))
        }
    }

    func text(_ key: String, _ length: ClosedRange<Int>? = nil) throws(CatalogError) -> String {
        guard let value = object[key] else { throw .missingField(entry: entry, field: name(key)) }
        guard let text = value as? String else { throw .wrongType(entry: entry, field: name(key)) }
        if let length, !length.contains(text.count) {
            throw .invalidValue(entry: entry, field: name(key), reason: "\(length.lowerBound) to \(length.upperBound) characters")
        }
        return text
    }

    func texts(_ key: String, maxCount: Int, length: ClosedRange<Int>) throws(CatalogError) -> [String] {
        guard let value = object[key] else { throw .missingField(entry: entry, field: name(key)) }
        guard let list = value as? [Any] else { throw .wrongType(entry: entry, field: name(key)) }
        guard list.count <= maxCount else { throw .invalidValue(entry: entry, field: name(key), reason: "at most \(maxCount) items") }
        var out: [String] = []
        for item in list {
            guard let text = item as? String else { throw .wrongType(entry: entry, field: name(key)) }
            guard length.contains(text.count) else {
                throw .invalidValue(entry: entry, field: name(key), reason: "each item has \(length.lowerBound) to \(length.upperBound) characters")
            }
            out.append(text)
        }
        return out
    }

    /// A JSON number that is finite, whole and inside `range`. A Boolean is not a number.
    func whole(_ key: String, _ range: ClosedRange<Int>) throws(CatalogError) -> Int {
        guard let value = object[key] else { throw .missingField(entry: entry, field: name(key)) }
        guard let number = value as? NSNumber, CFGetTypeID(number) != CFBooleanGetTypeID() else {
            throw .wrongType(entry: entry, field: name(key))
        }
        let double = number.doubleValue
        guard double.isFinite else { throw .invalidNumber(entry: entry, field: name(key), reason: "not finite") }
        guard double == double.rounded(), let whole = Int(exactly: double) else {
            throw .invalidNumber(entry: entry, field: name(key), reason: "not a whole number")
        }
        guard range.contains(whole) else {
            throw .invalidNumber(entry: entry, field: name(key), reason: "outside \(range.lowerBound) to \(range.upperBound)")
        }
        return whole
    }

    /// A JSON Boolean. The numbers 0 and 1 are not Booleans.
    func flag(_ key: String) throws(CatalogError) -> Bool {
        guard let value = object[key] else { throw .missingField(entry: entry, field: name(key)) }
        guard let number = value as? NSNumber, CFGetTypeID(number) == CFBooleanGetTypeID() else {
            throw .wrongType(entry: entry, field: name(key))
        }
        return number.boolValue
    }

    static func isSHA256(_ text: String) -> Bool {
        text.utf8.count == 64 && text.utf8.allSatisfy { (48...57).contains($0) || (97...102).contains($0) }
    }

    static func isColor(_ text: String) -> Bool {
        let bytes = Array(text.utf8)
        return bytes.count == 7 && bytes[0] == UInt8(ascii: "#")
            && bytes.dropFirst().allSatisfy { (48...57).contains($0) || (65...70).contains($0) || (97...102).contains($0) }
    }
}
