// ShellModel — feature 190 T-U04-004 (FR-U04-011, FR-U04-020 to FR-U04-024, FR-U04-033, FR-U04-041, FR-U04-052,
// FR-U04-060, FR-U04-061; data-model sections 1 to 4 and 6). The pure model of the app shell: routes, preferences,
// the launcher's state, the startup decision and the reset plan. Nothing here reads a clock, a file, a language
// setting or a network; the app renders these values and stores the preferences.
import Foundation

// MARK: - Routes

/// A place of the app shell. Its text form is what the preferences store: `catalog`, `settings`, `about` or
/// `experience:<id>`.
public enum ShellRoute: Sendable, Equatable, Hashable, Codable {
    /// The launcher with the catalog.
    case catalog
    /// One experience, by its id.
    case experience(ExperienceID)
    /// The settings.
    case settings
    /// The about page.
    case about

    private static let experiencePrefix = "experience:"

    /// Parses the text form; `nil` for any other text, including an experience route with a malformed id.
    public init?(text: String) {
        switch text {
        case "catalog": self = .catalog
        case "settings": self = .settings
        case "about": self = .about
        default:
            guard text.hasPrefix(Self.experiencePrefix),
                  let id = ExperienceID(rawValue: String(text.dropFirst(Self.experiencePrefix.count))) else { return nil }
            self = .experience(id)
        }
    }

    /// The text form: `catalog`, `settings`, `about` or `experience:<id>`.
    public var text: String {
        switch self {
        case .catalog: "catalog"
        case .experience(let id): Self.experiencePrefix + id.rawValue
        case .settings: "settings"
        case .about: "about"
        }
    }

    /// Decodes a route from its text; any other text is a decoding error.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let text = try container.decode(String.self)
        guard let route = ShellRoute(text: text) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "malformed shell route")
        }
        self = route
    }

    /// Encodes the route as its text.
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(text)
    }
}

// MARK: - Preferences

/// A choice for an accessibility setting of the shell: follow the system, or force it on or off.
public enum AccessibilityChoice: String, Sendable, Codable, CaseIterable {
    /// Follow the system setting.
    case system
    /// Always on.
    case on
    /// Always off.
    case off
}

/// The preferences of the app shell (schema 1), stored as JSON under `storageKey`.
///
/// Reading never fails: damaged, oversized or newer data gives the defaults and a note for the diagnostics.
public struct ShellPreferences: Sendable, Equatable, Codable {
    /// The schema version this build writes and the highest it reads.
    public static let schema = 1
    /// The largest stored value that is parsed, in bytes (64 KiB); larger data is treated as unreadable.
    public static let maxBytes = 65_536
    /// The largest number of characters of the stored search text.
    public static let maxSearchLength = 100
    /// The key the app stores the preferences under.
    public static let storageKey = "vc.shell.preferences"
    /// The key the app stores the copy of an unreadable session state under (feature 191).
    public static let unreadableCopyKey = "vc.shell.preferences.unreadable"
    /// The earlier schema versions for which a migration to the current schema exists. It must hold every
    /// version from 1 below `schema`; empty while the schema is 1.
    public static var migratedVersions: [Int] { [] }
    /// The note of `decode` for data that is damaged, oversized or of an unknown shape.
    public static let noteUnreadable = "preferences.unreadable"
    /// The note of `decode` for data written by a newer schema.
    public static let noteNewer = "preferences.newer"
    /// The quality overrides the shell accepts; `nil` means automatic.
    public static let qualityRange = 0...7

    /// Whether the welcome was seen. Default false.
    public var welcomeSeen: Bool = false
    /// The route the app returns to. Default `catalog`.
    public var lastRoute: ShellRoute = .catalog
    /// The launcher's search text. Default empty; a longer text keeps its first `maxSearchLength` characters.
    public var searchText: String = "" {
        didSet { searchText = Self.cut(searchText) }
    }
    /// The quality tier override, 0 to 7; `nil` is automatic. A value outside the range becomes `nil`.
    public var qualityOverride: Int? {
        didSet { qualityOverride = Self.accepted(qualityOverride) }
    }
    /// The reduce-motion choice. Default `system`.
    public var reduceMotion: AccessibilityChoice = .system
    /// The reduce-flashing choice. Default `system`.
    public var reduceFlashing: AccessibilityChoice = .system

    /// The defaults: welcome not seen, the catalog, no search, automatic quality, both choices `system`.
    public init() {}

    private static func cut(_ text: String) -> String {
        text.count > maxSearchLength ? String(text.prefix(maxSearchLength)) : text
    }

    private static func accepted(_ quality: Int?) -> Int? {
        guard let quality, qualityRange.contains(quality) else { return nil }
        return quality
    }

    private enum CodingKeys: String, CodingKey {
        case schema, welcomeSeen, lastRoute, searchText, qualityOverride, reduceMotion, reduceFlashing
    }

    private struct SchemaProbe: Decodable {
        let schema: Int
    }

    /// Decodes schema 1. An absent key takes its default; a value of the wrong type or an unknown route or choice
    /// is a decoding error. A search text over the limit is cut and a quality outside 0 to 7 is dropped.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let found = try container.decode(Int.self, forKey: .schema)
        guard found == Self.schema else {
            throw DecodingError.dataCorruptedError(forKey: .schema, in: container, debugDescription: "unsupported schema")
        }
        welcomeSeen = try container.decodeIfPresent(Bool.self, forKey: .welcomeSeen) ?? false
        lastRoute = try container.decodeIfPresent(ShellRoute.self, forKey: .lastRoute) ?? .catalog
        searchText = Self.cut(try container.decodeIfPresent(String.self, forKey: .searchText) ?? "")
        qualityOverride = Self.accepted(try container.decodeIfPresent(Int.self, forKey: .qualityOverride))
        reduceMotion = try container.decodeIfPresent(AccessibilityChoice.self, forKey: .reduceMotion) ?? .system
        reduceFlashing = try container.decodeIfPresent(AccessibilityChoice.self, forKey: .reduceFlashing) ?? .system
    }

    /// Encodes schema 1 with the keys of data-model section 1; an automatic quality writes no key.
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(Self.schema, forKey: .schema)
        try container.encode(welcomeSeen, forKey: .welcomeSeen)
        try container.encode(lastRoute, forKey: .lastRoute)
        try container.encode(searchText, forKey: .searchText)
        try container.encodeIfPresent(qualityOverride, forKey: .qualityOverride)
        try container.encode(reduceMotion, forKey: .reduceMotion)
        try container.encode(reduceFlashing, forKey: .reduceFlashing)
    }

    /// Reads stored preferences. It never throws and never traps.
    ///
    /// - `nil` data: the defaults and no note (a first start).
    /// - Data above `maxBytes`, data that is not the JSON of schema 1, or a schema below 1: the defaults and the
    ///   note `preferences.unreadable`.
    /// - A schema above 1: the defaults and the note `preferences.newer`.
    public static func decode(_ data: Data?) -> (preferences: ShellPreferences, note: String?) {
        guard let data else { return (ShellPreferences(), nil) }
        guard data.count <= maxBytes else { return (ShellPreferences(), noteUnreadable) }
        let decoder = JSONDecoder()
        guard let probe = try? decoder.decode(SchemaProbe.self, from: data) else { return (ShellPreferences(), noteUnreadable) }
        guard probe.schema <= schema else { return (ShellPreferences(), noteNewer) }
        guard let preferences = try? decoder.decode(ShellPreferences.self, from: data) else {
            return (ShellPreferences(), noteUnreadable)
        }
        return (preferences, nil)
    }

    /// The preferences as JSON with sorted keys. Encoding these plain values cannot fail; if it ever did, the
    /// result would be empty data, which `decode` reads as unreadable.
    public func encoded() -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return (try? encoder.encode(self)) ?? Data()
    }
}

// MARK: - Launcher

/// One tile of the launcher: what the app draws for an experience that can be opened.
public struct LauncherTile: Sendable, Equatable, Identifiable {
    /// The experience the tile opens.
    public let id: ExperienceID
    /// The display name.
    public let title: String
    /// One sentence about the experience.
    public let summary: String
    /// The visible tier text: `Free` or `Premium`.
    public let tierText: String
    /// Whether the experience belongs to the premium library.
    public let isPremium: Bool
    /// Exactly two colors the tile is drawn from, each `#RRGGBB`: the first two of the descriptor's palette (a
    /// single color twice), or two colors derived from the seed when the palette is empty.
    public let colors: [String]
    /// The seed the tile is drawn from (the descriptor's `tileSeed`).
    public let seed: UInt32
    /// The accessibility identifier of the tile: `vc.tile.<id>`.
    public let accessibilityIdentifier: String

    /// The tile of a catalog entry.
    public init(_ descriptor: ExperienceDescriptor) {
        id = descriptor.id
        title = descriptor.title
        summary = descriptor.summary
        isPremium = descriptor.tier == .premium
        tierText = descriptor.tier == .premium ? "Premium" : "Free"
        seed = descriptor.tileSeed
        accessibilityIdentifier = "vc.tile." + descriptor.id.rawValue
        if let first = descriptor.palette.first {
            colors = [first, descriptor.palette.count > 1 ? descriptor.palette[1] : first]
        } else {
            colors = Self.derivedColors(seed: descriptor.tileSeed)
        }
    }

    /// Two colors of the same family for a seed: a hue from the seed and a second hue 40 degrees further, in
    /// whole-number arithmetic so that every device computes the same text.
    static func derivedColors(seed: UInt32) -> [String] {
        let hue = Int(seed % 360)
        return [color(hue: hue, value: 217, chroma: 130), color(hue: (hue + 40) % 360, value: 150, chroma: 100)]
    }

    private static func color(hue: Int, value: Int, chroma: Int) -> String {
        let floor = value - chroma
        let middle = floor + chroma * (60 - abs(hue % 120 - 60)) / 60
        let rgb: (Int, Int, Int) = switch hue / 60 {
        case 0: (value, middle, floor)
        case 1: (middle, value, floor)
        case 2: (floor, value, middle)
        case 3: (floor, middle, value)
        case 4: (middle, floor, value)
        default: (value, floor, middle)
        }
        return "#" + hex(rgb.0) + hex(rgb.1) + hex(rgb.2)
    }

    private static func hex(_ component: Int) -> String {
        let text = String(min(max(component, 0), 255), radix: 16, uppercase: true)
        return text.count < 2 ? "0" + text : text
    }
}

/// One section of the launcher: a category that has tiles.
public struct LauncherSection: Sendable, Equatable, Identifiable {
    /// The category of the section.
    public let id: ExperienceCategory
    /// The heading: the title of the category list, or the category's name with a capital when no list names it.
    public let title: String
    /// The tiles of the section; never empty.
    public let tiles: [LauncherTile]
}

/// What the launcher shows.
public enum LauncherState: Sendable, Equatable {
    /// The catalog could not be loaded; `code` is the stable code of the catalog error.
    case error(code: String)
    /// No experience is both available and registered.
    case empty
    /// Experiences exist but the search finds none of them.
    case noMatch
    /// One section per category that has tiles.
    case sections([LauncherSection])
}

/// The launcher's rules (data-model section 2).
public enum LauncherModel {
    /// The experiences the launcher may show: available in the catalog and registered in the app, in catalog order.
    public static func shown(manifest: CatalogManifest, registered: Set<ExperienceID>) -> [ExperienceDescriptor] {
        manifest.experiences.filter { $0.isAvailable && registered.contains($0.id) }
    }

    /// The launcher's state.
    ///
    /// A failed catalog gives `error` with `code(of:)`. Without a shown experience the state is `empty`. The search
    /// is the manifest's own `search`, kept to the shown experiences; without a hit the state is `noMatch`.
    /// Otherwise there is one section per category that has tiles, in the order of the category list (a category
    /// the list does not hold, or every category when there is no list, follows in the order of its first shown
    /// experience); the tiles of a section keep the order of the search result, which is the catalog order for an
    /// empty search text.
    public static func state(manifest: Result<CatalogManifest, CatalogError>, categories: CategoryList?,
                             registered: Set<ExperienceID>, searchText: String) -> LauncherState {
        let catalog: CatalogManifest
        switch manifest {
        case .failure(let error): return .error(code: code(of: error))
        case .success(let loaded): catalog = loaded
        }
        let visible = shown(manifest: catalog, registered: registered)
        guard !visible.isEmpty else { return .empty }
        let visibleIDs = Set(visible.map(\.id))
        let hits = catalog.search(searchText).filter { visibleIDs.contains($0.id) }
        guard !hits.isEmpty else { return .noMatch }

        var order = categories?.categories.map(\.id) ?? []
        for entry in visible where !order.contains(entry.category) {
            order.append(entry.category)
        }
        var sections: [LauncherSection] = []
        for category in order {
            let tiles = hits.filter { $0.category == category }.map(LauncherTile.init)
            guard !tiles.isEmpty else { continue }
            let title = categories?.title(of: category) ?? fallbackTitle(of: category)
            sections.append(LauncherSection(id: category, title: title, tiles: tiles))
        }
        return .sections(sections)
    }

    /// The stable code of a catalog error for the launcher and the diagnostics: `catalog.` and the name of the
    /// case, for example `catalog.unsupportedSchema`. It carries no detail of the file.
    public static func code(of error: CatalogError) -> String {
        let name = switch error {
        case .tooLarge: "tooLarge"
        case .unreadable: "unreadable"
        case .unsupportedSchema: "unsupportedSchema"
        case .tooManyEntries: "tooManyEntries"
        case .missingField: "missingField"
        case .unknownField: "unknownField"
        case .wrongType: "wrongType"
        case .invalidValue: "invalidValue"
        case .invalidNumber: "invalidNumber"
        case .duplicate: "duplicate"
        case .outOfOrder: "outOfOrder"
        case .allocation: "allocation"
        }
        return "catalog." + name
    }

    private static func fallbackTitle(of category: ExperienceCategory) -> String {
        category.rawValue.prefix(1).uppercased() + category.rawValue.dropFirst()
    }
}

// MARK: - Startup

/// What the app does when it starts (data-model section 3).
public struct ShellStartup: Sendable, Equatable {
    /// Whether the welcome is shown first.
    public let showWelcome: Bool
    /// The route the shell starts on (under the welcome when it is shown).
    public let route: ShellRoute
    /// The first shown experience that is free: what the welcome's action opens. `nil` when there is none.
    public let firstFree: ExperienceID?

    /// The route the welcome's action opens: the first free experience, or the catalog when there is none.
    public var welcomeRoute: ShellRoute {
        firstFree.map(ShellRoute.experience) ?? .catalog
    }

    /// Decides the start from the preferences and the shown experiences (`LauncherModel.shown`).
    ///
    /// While the welcome was not seen it is shown over the catalog. Afterwards a stored experience route is kept
    /// only when that experience is shown, otherwise the catalog; every other stored route is kept.
    public static func decide(preferences: ShellPreferences, shown: [ExperienceDescriptor]) -> ShellStartup {
        let firstFree = shown.first { $0.tier == .free }?.id
        guard preferences.welcomeSeen else {
            return ShellStartup(showWelcome: true, route: .catalog, firstFree: firstFree)
        }
        var route = preferences.lastRoute
        if case .experience(let id) = route, !shown.contains(where: { $0.id == id }) {
            route = .catalog
        }
        return ShellStartup(showWelcome: false, route: route, firstFree: firstFree)
    }
}

// MARK: - Reset

/// What a reset removes (data-model section 4). The app closes an open experience first.
public enum ResetPlan: Sendable, Equatable {
    /// The stored data of one experience.
    case experience(ExperienceID)
    /// The stored data of every experience and the shell preferences.
    case all

    /// The storage namespaces whose folders are removed: that of the one experience, or those of all known ids in
    /// the given order.
    public func namespaces(known: [ExperienceID]) -> [String] {
        switch self {
        case .experience(let id): [id.storageNamespace]
        case .all: known.map(\.storageNamespace)
        }
    }

    /// Whether the shell preferences are removed too, so that the app is as after a first start.
    public var removesPreferences: Bool {
        self == .all
    }
}
