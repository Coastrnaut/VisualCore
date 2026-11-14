// ShellModelTests — feature 190 T-U04-003 (FR-U04-011, FR-U04-020 to FR-U04-024, FR-U04-033, FR-U04-041, FR-U04-042,
// FR-U04-052, FR-U04-060, FR-U04-061; SC-U04-003). The tables of data-model.md sections 1 to 4 are written out here
// a second time, so the test does not take its expectation from the code under test.
import Foundation
import Testing
@testable import VisualCoreExperience

@Suite struct ShellModelTests {
    // MARK: - Fixture: six available and registered experiences in three categories

    /// Entry indices of the 100-entry test manifest and the ids the builder gives them.
    private static let shownIDs = ["a01.e1", "a02.e2", "a03.e3", "a04.e4", "r02-g01.e26", "r03-g01.e51"]
    private static let unregisteredID = "a05.e5"       // available, not registered
    private static let unavailableID = "a07.e7"        // registered, not available

    private static func id(_ text: String) throws -> ExperienceID { try ExperienceID(text) }

    private static func registered() throws -> Set<ExperienceID> {
        Set(try (shownIDs + [unavailableID]).map(id))
    }

    /// First appearance of the categories is audio, create, puzzle; the category list says create, audio, puzzle.
    private static func manifest() throws -> CatalogManifest {
        let data = ManifestBuilder.changing { b in
            for index in [0, 1, 2, 3, 4, 25, 50] { b.set(index, "available", true) }
            b.set(0, "category", "audio"); b.set(0, "title", "Prism Garden"); b.set(0, "summary", "An aurora over the garden")
            b.set(0, "palette", ["#112233", "#445566", "#778899"])
            b.set(1, "title", "Aurora Loom"); b.set(1, "palette", ["#ABCDEF"])
            b.set(2, "category", "audio"); b.set(2, "title", "Prism Aurora")
            b.set(3, "title", "Quiet Tide"); b.set(3, "tags", ["wave-mathematics", "prism"])
            b.set(4, "title", "Aurora Unregistered")
            b.set(6, "title", "Prism Hidden")
            b.set(25, "summary", "A prism in every room")
            b.set(50, "title", "Aurora Géode")
        }
        return try CatalogManifest(data: data)
    }

    private static func categories() throws -> CategoryList {
        try CategoryList(data: CatalogFixture.data("categories.json"))
    }

    private static func state(_ search: String = "", categories: CategoryList? = nil) throws -> LauncherState {
        LauncherModel.state(manifest: .success(try manifest()), categories: try categories ?? Self.categories(),
                            registered: try registered(), searchText: search)
    }

    private static func sections(_ state: LauncherState) -> [LauncherSection] {
        guard case .sections(let sections) = state else { return [] }
        return sections
    }

    private static func tileIDs(_ state: LauncherState) -> [[String]] {
        sections(state).map { $0.tiles.map(\.id.rawValue) }
    }

    private static func json(_ object: [String: Any]) throws -> Data {
        try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
    }

    // MARK: - Routes

    @Test func routeTextRoundTripForTheFourRoutes() throws {
        let experience = ShellRoute.experience(try Self.id("a05.infinite-geometry"))
        let table: [(ShellRoute, String)] = [
            (.catalog, "catalog"), (.settings, "settings"), (.about, "about"), (experience, "experience:a05.infinite-geometry"),
        ]
        for (route, text) in table {
            #expect(route.text == text)
            #expect(ShellRoute(text: text) == route)
        }
    }

    @Test func malformedRouteTextIsNil() {
        let malformed = ["", "Catalog", " catalog", "catalog ", "experience", "experience:", "experience:A05.x", "experience:a05",
                         "experience:a05.Bad", "experience:a05.x:y", "experience: a05.x", "home", "settings/about"]
        for text in malformed {
            #expect(ShellRoute(text: text) == nil, "accepted \(text.debugDescription)")
        }
    }

    @Test func routeIsCodedAsItsText() throws {
        let routes: [ShellRoute] = [.catalog, .experience(try Self.id("r02-g01.aurora-loom")), .settings, .about]
        let data = try JSONEncoder().encode(routes)
        #expect(String(decoding: data, as: UTF8.self) == #"["catalog","experience:r02-g01.aurora-loom","settings","about"]"#)
        #expect(try JSONDecoder().decode([ShellRoute].self, from: data) == routes)
        #expect((try? JSONDecoder().decode([ShellRoute].self, from: Data(#"["home"]"#.utf8))) == nil)
    }

    // MARK: - Preferences

    @Test func preferenceConstantsAndDefaults() {
        #expect(ShellPreferences.schema == 1)
        #expect(ShellPreferences.maxBytes == 65_536)
        #expect(ShellPreferences.maxSearchLength == 100)
        #expect(ShellPreferences.storageKey == "vc.shell.preferences")
        let defaults = ShellPreferences()
        #expect(defaults.welcomeSeen == false)
        #expect(defaults.lastRoute == .catalog)
        #expect(defaults.searchText == "")
        #expect(defaults.qualityOverride == nil)
        #expect(defaults.reduceMotion == .system && defaults.reduceFlashing == .system)
        #expect(AccessibilityChoice.allCases.map(\.rawValue) == ["system", "on", "off"])
        let absent = ShellPreferences.decode(nil)
        #expect(absent.preferences == defaults)
        #expect(absent.note == nil)
    }

    @Test func preferencesRoundTrip() throws {
        var preferences = ShellPreferences()
        preferences.welcomeSeen = true
        preferences.lastRoute = .experience(try Self.id("a05.infinite-geometry"))
        preferences.searchText = "aurora géode"
        preferences.qualityOverride = 7
        preferences.reduceMotion = .on
        preferences.reduceFlashing = .off
        let data = preferences.encoded()
        let read = ShellPreferences.decode(data)
        #expect(read.preferences == preferences)
        #expect(read.note == nil)
        #expect(preferences.encoded() == data)

        let object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(object.keys.sorted() == ["lastRoute", "qualityOverride", "reduceFlashing", "reduceMotion", "schema", "searchText",
                                         "welcomeSeen"])
        #expect(object["schema"] as? Int == 1)
        #expect(object["lastRoute"] as? String == "experience:a05.infinite-geometry")
        #expect(object["reduceMotion"] as? String == "on" && object["reduceFlashing"] as? String == "off")
        #expect(object["qualityOverride"] as? Int == 7)

        let defaults = ShellPreferences().encoded()
        #expect(String(decoding: defaults, as: UTF8.self) == #"{"lastRoute":"catalog","reduceFlashing":"system","#
            + #""reduceMotion":"system","schema":1,"searchText":"","welcomeSeen":false}"#)
        let readDefaults = ShellPreferences.decode(defaults)
        #expect(readDefaults.preferences == ShellPreferences() && readDefaults.note == nil)
    }

    @Test func damagedDataGivesDefaultsAndTheUnreadableNote() throws {
        let damaged: [Data] = [
            Data(), Data("not json".utf8), Data("[1,2]".utf8), Data(#"{"welcomeSeen":true}"#.utf8), Data([0xFF, 0xFE, 0x00]),
            try Self.json(["schema": "1"]), try Self.json(["schema": 1.5]), try Self.json(["schema": 0]),
            try Self.json(["schema": 1, "welcomeSeen": "yes"]), try Self.json(["schema": 1, "lastRoute": "home"]),
            try Self.json(["schema": 1, "lastRoute": "experience:A05.x"]), try Self.json(["schema": 1, "reduceMotion": "maybe"]),
            try Self.json(["schema": 1, "searchText": 5]), try Self.json(["schema": 1, "qualityOverride": "high"]),
            Data(ShellPreferences().encoded().dropLast()),
        ]
        for data in damaged {
            let read = ShellPreferences.decode(data)
            #expect(read.preferences == ShellPreferences(), "\(String(decoding: data, as: UTF8.self))")
            #expect(read.note == "preferences.unreadable", "\(String(decoding: data, as: UTF8.self))")
        }
    }

    @Test func dataAbove64KiBIsUnreadable() {
        var stored = ShellPreferences()
        stored.welcomeSeen = true
        let valid = stored.encoded()
        let atLimit = valid + Data(repeating: 32, count: ShellPreferences.maxBytes - valid.count)
        #expect(atLimit.count == 65_536)
        let accepted = ShellPreferences.decode(atLimit)
        #expect(accepted.preferences == stored && accepted.note == nil)

        let above = atLimit + Data([32])
        let refused = ShellPreferences.decode(above)
        #expect(refused.preferences == ShellPreferences())
        #expect(refused.note == "preferences.unreadable")
    }

    @Test func newerSchemaGivesDefaultsAndTheNewerNote() throws {
        for data in [try Self.json(["schema": 2, "welcomeSeen": true]), try Self.json(["schema": 99, "lastRoute": ["a", "b"]])] {
            let read = ShellPreferences.decode(data)
            #expect(read.preferences == ShellPreferences())
            #expect(read.note == "preferences.newer")
        }
    }

    @Test func absentKeysTakeTheirDefaults() throws {
        let read = ShellPreferences.decode(try Self.json(["schema": 1, "welcomeSeen": true]))
        var expected = ShellPreferences()
        expected.welcomeSeen = true
        #expect(read.preferences == expected)
        #expect(read.note == nil)
    }

    @Test func searchTextIsCutTo100Characters() throws {
        let long = String(repeating: "é", count: 99) + "xyz"
        var preferences = ShellPreferences()
        preferences.searchText = long
        #expect(preferences.searchText.count == 100)
        #expect(preferences.searchText == String(repeating: "é", count: 99) + "x")
        preferences.searchText = String(repeating: "a", count: 100)
        #expect(preferences.searchText.count == 100)
        preferences.searchText = "short"
        #expect(preferences.searchText == "short")

        let read = ShellPreferences.decode(try Self.json(["schema": 1, "searchText": long]))
        #expect(read.preferences.searchText == String(repeating: "é", count: 99) + "x")
        #expect(read.note == nil)
    }

    @Test func qualityOverrideOutside0To7IsDropped() throws {
        var preferences = ShellPreferences()
        for value in 0...7 {
            preferences.qualityOverride = value
            #expect(preferences.qualityOverride == value)
        }
        for value in [-1, 8, 100, Int.min, Int.max] {
            preferences.qualityOverride = 3
            preferences.qualityOverride = value
            #expect(preferences.qualityOverride == nil, "kept \(value)")
        }
        preferences.qualityOverride = 3
        preferences.qualityOverride = nil
        #expect(preferences.qualityOverride == nil)
        #expect(ShellPreferences.decode(try Self.json(["schema": 1, "qualityOverride": 8])).preferences.qualityOverride == nil)
        #expect(ShellPreferences.decode(try Self.json(["schema": 1, "qualityOverride": -1])).preferences.qualityOverride == nil)
        #expect(ShellPreferences.decode(try Self.json(["schema": 1, "qualityOverride": 0])).preferences.qualityOverride == 0)
        #expect(ShellPreferences.decode(try Self.json(["schema": 1, "qualityOverride": 7])).preferences.qualityOverride == 7)
    }

    // MARK: - Launcher

    @Test func failedCatalogGivesErrorWithTheCodeOfTheCatalogError() throws {
        let table: [(CatalogError, String)] = [
            (.tooLarge(bytes: 2, limit: 1), "catalog.tooLarge"), (.unreadable(reason: "r"), "catalog.unreadable"),
            (.unsupportedSchema(found: 2, supported: 1), "catalog.unsupportedSchema"),
            (.tooManyEntries(count: 401, limit: 400), "catalog.tooManyEntries"),
            (.missingField(entry: "e", field: "f"), "catalog.missingField"),
            (.unknownField(entry: "e", field: "f"), "catalog.unknownField"), (.wrongType(entry: "e", field: "f"), "catalog.wrongType"),
            (.invalidValue(entry: "e", field: "f", reason: "r"), "catalog.invalidValue"),
            (.invalidNumber(entry: "e", field: "f", reason: "r"), "catalog.invalidNumber"),
            (.duplicate(field: "id", value: "v"), "catalog.duplicate"), (.outOfOrder(entry: "e"), "catalog.outOfOrder"),
            (.allocation(code: "A01", reason: "r"), "catalog.allocation"),
        ]
        #expect(Set(table.map(\.1)).count == 12)
        for (error, code) in table {
            #expect(LauncherModel.code(of: error) == code)
            let state = LauncherModel.state(manifest: .failure(error), categories: try Self.categories(),
                                            registered: try Self.registered(), searchText: "aurora")
            #expect(state == .error(code: code))
        }
        // A real refusal of the loader, not only a constructed value.
        var refusal: CatalogError?
        do {
            _ = try CatalogManifest(data: ManifestBuilder.changing { $0.root["schema"] = 2 })
        } catch {
            refusal = error
        }
        let loaded = try #require(refusal)
        #expect(LauncherModel.state(manifest: .failure(loaded), categories: nil, registered: [], searchText: "")
            == .error(code: "catalog.unsupportedSchema"))
    }

    @Test func realCatalogShowsOnlyTheIntegratedExperiences() throws {
        let manifest = try CatalogFixture.manifest()
        let categories = try Self.categories()
        let everything = Set(manifest.experiences.map(\.id))
        #expect(LauncherModel.shown(manifest: manifest, registered: everything).map(\.id.rawValue) == ["a01.generative-art-studio", "a02.fluid-art-playground", "a03.fractal-explorer",
                         "a04.particle-universe", "a05.infinite-geometry", "a06.visualcore-music-lab"])
        for search in ["", "aurora"] {
            #expect(LauncherModel.state(manifest: .success(manifest), categories: categories, registered: [],
                                        searchText: search) == .empty, "nothing registered shows nothing")
        }
        #expect(LauncherModel.state(manifest: .success(manifest), categories: categories, registered: everything,
                                    searchText: "") != .empty)
    }

    @Test func sectionsFollowTheCategoryListAndTilesTheCatalogOrder() throws {
        let sections = Self.sections(try Self.state())
        #expect(sections.map(\.id) == [.create, .audio, .puzzle])
        #expect(sections.map(\.title) == ["Create", "Audio", "Puzzles"])
        #expect(sections.map { $0.tiles.map(\.id.rawValue) }
            == [["a02.e2", "a04.e4"], ["a01.e1", "a03.e3"], ["r02-g01.e26", "r03-g01.e51"]])
        #expect(sections.flatMap(\.tiles).count == 6)
        #expect(try Self.state("   \t ") == Self.state())
    }

    @Test func withoutACategoryListSectionsFollowTheFirstAppearance() throws {
        let manifest = try Self.manifest()
        let state = LauncherModel.state(manifest: .success(manifest), categories: nil, registered: try Self.registered(),
                                        searchText: "")
        let sections = Self.sections(state)
        #expect(sections.map(\.id) == [.audio, .create, .puzzle])
        #expect(sections.map(\.title) == ["Audio", "Create", "Puzzle"])
        #expect(Self.tileIDs(state) == [["a01.e1", "a03.e3"], ["a02.e2", "a04.e4"], ["r02-g01.e26", "r03-g01.e51"]])

        // A list that lacks a category does not lose its tiles: the category follows the listed ones.
        let partial = CategoryList(entries: try Self.categories().categories.filter { $0.id == .puzzle })
        let partialState = LauncherModel.state(manifest: .success(manifest), categories: partial,
                                               registered: try Self.registered(), searchText: "")
        #expect(Self.sections(partialState).map(\.id) == [.puzzle, .audio, .create])
        #expect(Self.sections(partialState).map(\.title) == ["Puzzles", "Audio", "Create"])
    }

    @Test func onlyExperiencesThatAreBothAvailableAndRegisteredAreShown() throws {
        let manifest = try Self.manifest()
        let registered = try Self.registered()
        #expect(manifest.available.map(\.id.rawValue) == ["a01.e1", "a02.e2", "a03.e3", "a04.e4", "a05.e5", "r02-g01.e26", "r03-g01.e51"])
        #expect(registered.contains(try Self.id(Self.unavailableID)))
        #expect(LauncherModel.shown(manifest: manifest, registered: registered).map(\.id.rawValue) == Self.shownIDs)

        let shownTiles = Self.tileIDs(try Self.state()).flatMap { $0 }
        #expect(!shownTiles.contains(Self.unregisteredID) && !shownTiles.contains(Self.unavailableID))
        // Both are found by the catalog search, and neither reaches the launcher.
        #expect(manifest.search("unregistered").map(\.id.rawValue) == [Self.unregisteredID])
        #expect(manifest.search("hidden").map(\.id.rawValue) == [Self.unavailableID])
        #expect(try Self.state("unregistered") == .noMatch)
        #expect(try Self.state("hidden") == .noMatch)

        #expect(LauncherModel.shown(manifest: manifest, registered: []).isEmpty)
        #expect(LauncherModel.state(manifest: .success(manifest), categories: nil, registered: [], searchText: "") == .empty)
        let one = LauncherModel.state(manifest: .success(manifest), categories: nil, registered: [try Self.id("r03-g01.e51")],
                                      searchText: "")
        #expect(Self.tileIDs(one) == [["r03-g01.e51"]])
    }

    @Test func searchWithoutResultIsNoMatchAndResultsKeepTheSearchOrder() throws {
        #expect(try Self.state("zzzz") == .noMatch)
        #expect(try Self.state("prism zzzz") == .noMatch)
        // Written out by hand: title hits first, then the tag, then the summary; create, audio, puzzle.
        #expect(Self.tileIDs(try Self.state("prism")) == [["a04.e4"], ["a01.e1", "a03.e3"], ["r02-g01.e26"]])
        // "aurora" is in the title of e3 and only in the summary of e1: the search order reverses the catalog order.
        #expect(Self.tileIDs(try Self.state("aurora")) == [["a02.e2"], ["a03.e3", "a01.e1"], ["r03-g01.e51"]])
        #expect(Self.tileIDs(try Self.state("geode")) == [["r03-g01.e51"]])
    }

    @Test func tenSearchTextsAgreeWithTheCatalogSearch() throws {
        let manifest = try Self.manifest()
        let shown = Set(Self.shownIDs)
        let order: [ExperienceCategory] = [.create, .audio, .puzzle]
        let table: [(text: String, hits: Int)] = [
            ("", 6), ("  \t ", 6), ("prism", 4), ("PRISM", 4), ("aurora", 4), ("prism aurora", 2), ("géode", 1), ("quiet tide", 1),
            ("wave", 6), ("zzzz", 0),
        ]
        #expect(table.count == 10)
        for (text, hits) in table {
            let expected = manifest.search(text).filter { shown.contains($0.id.rawValue) }
            #expect(expected.count == hits, "search(\(text.debugDescription))")
            let state = try Self.state(text)
            if expected.isEmpty {
                #expect(state == .noMatch, "search(\(text.debugDescription))")
                continue
            }
            let grouped = order.map { category in expected.filter { $0.category == category }.map(\.id.rawValue) }
                .filter { !$0.isEmpty }
            #expect(Self.tileIDs(state) == grouped, "search(\(text.debugDescription))")
            #expect(Self.sections(state).map(\.id) == order.filter { category in expected.contains { $0.category == category } })
        }
    }

    @Test func tilesCarryTheIdentifierTheTierTextAndTheDescriptorFields() throws {
        let manifest = try Self.manifest()
        let tiles = Self.sections(try Self.state()).flatMap(\.tiles)
        #expect(tiles.count == 6)
        for tile in tiles {
            let descriptor = try #require(manifest.experience(tile.id))
            #expect(tile.accessibilityIdentifier == "vc.tile." + tile.id.rawValue)
            #expect(tile.title == descriptor.title && tile.summary == descriptor.summary)
            #expect(tile.seed == descriptor.tileSeed)
            #expect(tile.isPremium == (descriptor.tier == .premium))
            #expect(tile.tierText == (descriptor.tier == .premium ? "Premium" : "Free"))
            #expect(tile.colors.count == 2 && tile.colors.allSatisfy(JSONFields.isColor), "\(tile.colors)")
            #expect(tile == LauncherTile(descriptor))
        }
        #expect(tiles.filter(\.isPremium).map(\.id.rawValue) == ["r03-g01.e51"])
        #expect(tiles.map(\.tierText).filter { $0 == "Free" }.count == 5)

        let first = try #require(tiles.first { $0.id.rawValue == "a01.e1" })
        #expect(first.accessibilityIdentifier == "vc.tile.a01.e1")
        #expect(first.title == "Prism Garden" && first.seed == 1)
        #expect(first.colors == ["#112233", "#445566"])                        // the first two of three palette colors
        let second = try #require(tiles.first { $0.id.rawValue == "a02.e2" })
        #expect(second.colors == ["#ABCDEF", "#ABCDEF"])                       // a single palette color twice
        let third = try #require(tiles.first { $0.id.rawValue == "a03.e3" })   // no palette: derived from the seed
        #expect(third.colors == LauncherTile.derivedColors(seed: 3))
        #expect(third.colors[0] != third.colors[1])
        #expect(LauncherTile.derivedColors(seed: 0) == ["#D95757", "#967432"])
        for seed: UInt32 in [0, 59, 60, 119, 120, 180, 240, 300, 359, 360, 4_294_967_295] {
            let colors = LauncherTile.derivedColors(seed: seed)
            #expect(colors.count == 2 && colors.allSatisfy(JSONFields.isColor), "seed \(seed): \(colors)")
            #expect(colors == LauncherTile.derivedColors(seed: seed))
        }
    }

    // MARK: - Startup (data-model.md section 3)

    @Test func startupWelcomeOpensTheFirstFreeExperience() throws {
        let shown = LauncherModel.shown(manifest: try Self.manifest(), registered: try Self.registered())
        var preferences = ShellPreferences()
        preferences.lastRoute = .settings
        let startup = ShellStartup.decide(preferences: preferences, shown: shown)
        let firstFree = try Self.id("a01.e1")
        #expect(startup.showWelcome)
        #expect(startup.route == .catalog)
        #expect(startup.firstFree == firstFree)
        #expect(startup.welcomeRoute == .experience(firstFree))

        // The first shown experience is premium: the first free one is the next.
        let premiumFirst = [shown[5], shown[4], shown[0]]
        let nextFree = try Self.id("r02-g01.e26")
        #expect(ShellStartup.decide(preferences: ShellPreferences(), shown: premiumFirst).firstFree == nextFree)
    }

    @Test func startupWelcomeOpensTheCatalogWhenNothingIsFree() throws {
        let shown = LauncherModel.shown(manifest: try Self.manifest(), registered: try Self.registered())
        for list in [[], [shown[5]]] {
            let startup = ShellStartup.decide(preferences: ShellPreferences(), shown: list)
            #expect(startup == ShellStartup(showWelcome: true, route: .catalog, firstFree: nil))
            #expect(startup.welcomeRoute == .catalog)
        }
        let real = try CatalogFixture.manifest()
        let none = LauncherModel.shown(manifest: real, registered: [])
        #expect(ShellStartup.decide(preferences: ShellPreferences(), shown: none).firstFree == nil)
    }

    @Test func startupReturnsToAShownExperience() throws {
        let shown = LauncherModel.shown(manifest: try Self.manifest(), registered: try Self.registered())
        var preferences = ShellPreferences()
        preferences.welcomeSeen = true
        let last = try Self.id("r03-g01.e51")
        let firstFree = try Self.id("a01.e1")
        preferences.lastRoute = .experience(last)
        let startup = ShellStartup.decide(preferences: preferences, shown: shown)
        #expect(startup == ShellStartup(showWelcome: false, route: .experience(last), firstFree: firstFree))
    }

    @Test func startupFallsBackToTheCatalogForAnExperienceThatIsNotShown() throws {
        let shown = LauncherModel.shown(manifest: try Self.manifest(), registered: try Self.registered())
        var preferences = ShellPreferences()
        preferences.welcomeSeen = true
        for text in [Self.unregisteredID, Self.unavailableID, "a09.e9", "a99.unknown"] {
            preferences.lastRoute = .experience(try Self.id(text))
            let startup = ShellStartup.decide(preferences: preferences, shown: shown)
            #expect(startup.showWelcome == false)
            #expect(startup.route == .catalog, "kept \(text)")
        }
        preferences.lastRoute = .experience(try Self.id("a01.e1"))
        #expect(ShellStartup.decide(preferences: preferences, shown: []).route == .catalog)
    }

    @Test func startupKeepsEveryOtherStoredRoute() throws {
        let shown = LauncherModel.shown(manifest: try Self.manifest(), registered: try Self.registered())
        var preferences = ShellPreferences()
        preferences.welcomeSeen = true
        for route in [ShellRoute.catalog, .settings, .about] {
            preferences.lastRoute = route
            for list in [shown, []] {
                let startup = ShellStartup.decide(preferences: preferences, shown: list)
                #expect(startup.showWelcome == false)
                #expect(startup.route == route)
            }
        }
    }

    // MARK: - Reset (data-model.md section 4)

    @Test func resetPlanNamespacesAndPreferencesFlag() throws {
        let known = try ["a01.e1", "r02-g01.e26", "r03-g01.e51"].map(Self.id)
        let one = ResetPlan.experience(try Self.id("r02-g01.e26"))
        #expect(one.namespaces(known: known) == ["r02-g01.e26"])
        #expect(one.namespaces(known: []) == ["r02-g01.e26"])
        #expect(one.removesPreferences == false)
        #expect(ResetPlan.all.namespaces(known: known) == ["a01.e1", "r02-g01.e26", "r03-g01.e51"])
        #expect(ResetPlan.all.namespaces(known: known) == known.map(\.storageNamespace))
        #expect(ResetPlan.all.namespaces(known: []) == [])
        #expect(ResetPlan.all.removesPreferences)
        #expect(one != .all)
        #expect(one == ResetPlan.experience(known[1]))
    }

    // MARK: - Session state keys and migrations (feature 191 T-U05-010; FR-U05-052)

    @Test func unreadableCopyKeyIsItsOwnKey() {
        #expect(ShellPreferences.unreadableCopyKey == "vc.shell.preferences.unreadable")
        #expect(ShellPreferences.unreadableCopyKey != ShellPreferences.storageKey)
    }

    /// Fails by construction when `schema` rises without a migration from every earlier version.
    @Test func migratedVersionsHoldEveryEarlierSchema() {
        #expect(ShellPreferences.migratedVersions == Array(1..<ShellPreferences.schema))
    }
}
