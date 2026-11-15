// SpawnPattern — feature 076 (A10-P02) T-A10-202 (FR-A10-202, FR-A10-222; clarification 2; data-model
// "SpawnPattern"). The data-defined pattern table of the wave director. Every pattern carries an id, a display name,
// the rule that turns it into spawns, the steps between wall rows (wall only; 0 otherwise), a short description of its
// spawns, and an author and license record (the table is listed in the content license document with role
// `pattern`). The rules (applied by `WaveDirector`, spawns from wave step 30):
// - `rain`: one object per spawn gap in a seeded lane, hazard 70 % (spike-ball or bar, item seeded) / orb 30 %.
// - `wall`: a row every 120 steps: spike-balls of radius 0.5 in four lanes sharing one fall speed; the free lane is
//   seeded and never the previous row's free lane.
// - `zigzag`: a spike-ball per spawn gap walking the lanes 0 → 4 → 0 (cursor 0…7).
// - `orb-trail`: a glow-orb per spawn gap in one seeded lane, and bars in both neighbouring lanes every second gap.
import Foundation

/// How a spawn pattern turns into spawns.
public enum PatternRule: String, Codable, CaseIterable, Sendable {
    /// One seeded object per spawn gap in a seeded lane.
    case rain
    /// A row of hazards with exactly one free lane.
    case wall
    /// Hazards walking across the lanes and back.
    case zigzag
    /// A lane of orbs guarded by bars in the neighbouring lanes.
    case orbTrail = "orb-trail"
}

/// One entry of the pattern table.
public struct SpawnPattern: Codable, Equatable, Sendable, Identifiable {
    /// Kebab-case identifier, unique in the table (equal to the rule's raw value for the bundled table).
    public var id: String
    /// Descriptive display name ("Wall").
    public var name: String
    /// The rule that produces the spawns.
    public var rule: PatternRule
    /// Steps between wall rows (120 for `wall`); 0 for the patterns that spawn once per spawn gap.
    public var rowEvery: Int
    /// A one-line description of the spawns (offset, lane, kind, content).
    public var spawns: String
    /// The author ("VisualCore project").
    public var author: String
    /// The license, one of ``ArcadeCatalog/allowedLicenses``.
    public var license: String

    /// Creates a pattern from all of its fields (no validation).
    public init(id: String, name: String, rule: PatternRule, rowEvery: Int = 0, spawns: String, author: String,
                license: String) {
        self.id = id; self.name = name; self.rule = rule; self.rowEvery = rowEvery; self.spawns = spawns
        self.author = author; self.license = license
    }
}

/// The bundled pattern table.
public enum PatternTable {
    /// The pattern every run's first wave uses.
    public static let firstPatternId = "rain"

    /// The four bundled patterns in table order: rain, wall, zigzag, orb-trail; each by "VisualCore project" under
    /// "MIT".
    public static let bundled: [SpawnPattern] = {
        let author = ArcadeCatalog.projectAuthor, license = "MIT"
        return [
            SpawnPattern(id: "rain", name: "Rain", rule: .rain,
                         spawns: "every spawn gap from step 30: one seeded lane; hazard 70 % (spike-ball or bar), "
                             + "orb 30 % (glow-orb)", author: author, license: license),
            SpawnPattern(id: "wall", name: "Wall", rule: .wall, rowEvery: 120,
                         spawns: "every 120 steps from step 30: spike-balls of radius 0.5 in four lanes, one seeded "
                             + "free lane never the previous one, one shared fall speed", author: author,
                         license: license),
            SpawnPattern(id: "zigzag", name: "Zigzag", rule: .zigzag,
                         spawns: "every spawn gap from step 30: a spike-ball in lanes 0, 1, 2, 3, 4, 3, 2, 1, …",
                         author: author, license: license),
            SpawnPattern(id: "orb-trail", name: "Orb trail", rule: .orbTrail,
                         spawns: "every spawn gap from step 30: a glow-orb in one seeded lane; every second gap "
                             + "bars in both neighbouring lanes", author: author, license: license),
        ]
    }()

    /// The bundled pattern with `id`, if any.
    public static func pattern(id: String) -> SpawnPattern? { bundled.first { $0.id == id } }

    /// The bundled pattern ids in table order.
    public static var ids: [String] { bundled.map(\.id) }
}
