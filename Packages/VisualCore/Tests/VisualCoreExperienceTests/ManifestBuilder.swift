// ManifestBuilder — test helper of feature 187 (T-U01-005): a valid 100-entry launch manifest that a test changes in
// one place. It mirrors data-model section 2 and 3 on purpose, independently of the loader.
import Foundation

struct ManifestBuilder {
    static let family = "Wave mathematics"
    static let launchCodes: [String] = (1...25).map { String(format: "A%02d", $0) }
        + (2...4).flatMap { round in (1...25).map { String(format: "R%02d-G%02d", round, $0) } }

    var root: [String: Any]

    init() {
        let entries: [[String: Any]] = Self.launchCodes.enumerated().map { index, code in Self.entry(code: code, order: index + 1) }
        root = ["schema": 1, "catalog_sha256": String(repeating: "a", count: 64), "experiences": entries]
    }

    static func entry(code: String, order: Int, tier: String? = nil) -> [String: Any] {
        let original = code.hasPrefix("A")
        let premium = code.hasPrefix("R03") || code.hasPrefix("R04") || (!original && Int(code.dropFirst().prefix(2))! >= 5)
        return ["id": code.lowercased() + ".e\(order)", "code": code, "title": "Experience \(order)", "summary": "Summary \(order)",
                "kind": original ? "creative" : "game", "tier": tier ?? (premium ? "premium" : "free"),
                "category": original ? "create" : "puzzle", "family": family, "tags": ["wave-mathematics"], "order": order,
                "palette": [String](), "tile_seed": order, "capabilities": [String](), "quality_tiers": [String](),
                "content": NSNull(), "available": false]
    }

    var entries: [[String: Any]] {
        get { root["experiences"] as! [[String: Any]] }
        set { root["experiences"] = newValue }
    }

    /// The id of entry `index`, as the loader names it in errors.
    func id(_ index: Int) -> String { entries[index]["id"] as! String }

    mutating func set(_ index: Int, _ key: String, _ value: Any) { entries[index][key] = value }
    mutating func remove(_ index: Int, _ key: String) { entries[index].removeValue(forKey: key) }

    var data: Data { try! JSONSerialization.data(withJSONObject: root, options: [.sortedKeys]) }

    static func changing(_ change: (inout ManifestBuilder) -> Void) -> Data {
        var builder = ManifestBuilder()
        change(&builder)
        return builder.data
    }
}
