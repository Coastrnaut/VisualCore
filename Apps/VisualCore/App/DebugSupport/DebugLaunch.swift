// DebugLaunch — feature 190 T-U04-005 (FR-U04-043, FR-U04-081; research R3). The launch arguments of builds made
// for testing and the fixture catalog. The whole file is inside `#if DEBUG`: in a release build the arguments
// have no effect, because their handling does not exist.
//
//   -vcFixtureCatalog      use the fixture catalog and the fixture registry
//   -vcEmptyRegistry       use the fixture catalog and register nothing
//   -vcResetData           remove the stored preferences and every experience folder before the model starts
//   -vcSkipWelcome         mark the welcome as seen before the model starts
//   -vcDamagedCatalog      use catalog data that cannot be read, so that the launcher shows its error state
//   -vcFailingExperience   with the fixture: every fixture experience fails when it is set up
//   -vcSeedData            create a data folder with one file for the first two free fixture experiences
//   -openExperience <id>   open that experience directly after the start, without the welcome (which stays
//                          unseen); an id that cannot be opened is recorded in the diagnostics and the catalog,
//                          or on a first start the welcome, is shown
#if DEBUG
import Foundation
import VisualCoreExperience

/// The debug launch arguments and the fixture catalog.
enum DebugLaunch {
    static let fixtureCatalogArgument = "-vcFixtureCatalog"
    static let emptyRegistryArgument = "-vcEmptyRegistry"
    static let resetDataArgument = "-vcResetData"
    static let skipWelcomeArgument = "-vcSkipWelcome"
    static let damagedCatalogArgument = "-vcDamagedCatalog"
    static let seedDataArgument = "-vcSeedData"
    static let failingExperienceArgument = "-vcFailingExperience"
    static let openExperienceArgument = "-openExperience"

    /// The debug arguments that take no value.
    static let flags = [fixtureCatalogArgument, emptyRegistryArgument, resetDataArgument, skipWelcomeArgument,
                        damagedCatalogArgument, seedDataArgument, failingExperienceArgument]

    // MARK: - Environment

    /// The environment the debug arguments of `base.arguments` ask for. A reset and a skipped welcome act on the
    /// stores of `base` right here, before a model exists.
    static func environment(base: AppEnvironment) -> AppEnvironment {
        var environment = base
        let arguments = base.arguments
        let preferences = PreferencesStore(defaults: base.defaults)
        if arguments.contains(resetDataArgument) {
            preferences.remove()
            let folders = ExperienceDataStore(root: base.dataRoot)
            folders.remove(namespaces: folders.existing())
        }
        if arguments.contains(skipWelcomeArgument) {
            var stored = preferences.load().preferences
            if !stored.welcomeSeen {
                stored.welcomeSeen = true
                preferences.save(stored)
            }
        }
        let empty = arguments.contains(emptyRegistryArgument)
        if empty || arguments.contains(fixtureCatalogArgument) {
            environment.catalogData = fixtureCatalogData
            environment.categoriesData = fixtureCategoriesData
            environment.registry = empty ? [] : fixtureRegistry
            if !empty, arguments.contains(failingExperienceArgument) {
                environment.registry = fixtureFreeIDs.map(DebugExperience.failingRegistration(for:))
            }
        }
        if arguments.contains(damagedCatalogArgument) {
            environment.catalogData = Data("{ damaged".utf8)
        }
        if arguments.contains(seedDataArgument) {
            let folders = ExperienceDataStore(root: base.dataRoot)
            for id in fixtureFreeIDs.prefix(2) {
                try? folders.ensure(namespace: id.storageNamespace)
                try? Data("seed".utf8).write(to: folders.folder(for: id.storageNamespace)
                    .appendingPathComponent("seed.txt"))
            }
        }
        return environment
    }

    /// The value of `-openExperience` in `arguments`; nil when the argument or its value is absent.
    static func openExperienceID(in arguments: [String]) -> String? {
        guard let index = arguments.firstIndex(of: openExperienceArgument), index + 1 < arguments.count else {
            return nil
        }
        return arguments[index + 1]
    }

    /// Arguments that start with `-vc` and are no debug argument.
    static func unknownArguments(in arguments: [String]) -> [String] {
        arguments.filter { $0.hasPrefix("-vc") && !flags.contains($0) }
    }

    /// Acts on the arguments that need the model: records unknown `-vc` arguments and opens the experience of
    /// `-openExperience`. An id that is malformed or cannot be opened is recorded and the catalog is shown.
    /// It acts once per model.
    @MainActor
    static func start(_ model: AppModel) async {
        guard !model.debugLaunchStarted else { return }
        model.debugLaunchStarted = true
        model.noteUnknownArguments(unknownArguments(in: model.arguments))
        guard let text = openExperienceID(in: model.arguments) else {
            if model.arguments.last == openExperienceArgument { model.noteUnknownArguments([openExperienceArgument]) }
            return
        }
        if let id = ExperienceID(rawValue: text), model.shown.contains(where: { $0.id == id }) {
            model.hideWelcomeForThisLaunch()
            await model.open(id)
        } else {
            model.noteUnknownArguments([openExperienceArgument + " " + text])
            model.go(.catalog)
        }
    }

    // MARK: - Fixture

    /// The fixture: the bundled catalog with six entries made available.
    struct Fixture: Sendable {
        /// The catalog data; empty when the bundled catalog could not be read.
        var catalog = Data()
        /// The five free fixture ids, in catalog order.
        var freeIDs: [ExperienceID] = []
        /// The premium fixture id.
        var premiumID: ExperienceID?
    }

    /// The fixture, built once from the bundled catalog.
    static let fixture = makeFixture(from: AppEnvironment.bundled("experiences"))

    /// The fixture catalog: the bundled catalog in which six experiences are available — five free ones and one
    /// premium one, in three categories. Every other entry stays unavailable.
    static var fixtureCatalogData: Data { fixture.catalog }

    /// The category list of the fixture: the bundled one.
    static var fixtureCategoriesData: Data { AppEnvironment.bundled("categories") ?? Data() }

    /// The five free fixture ids, in catalog order.
    static var fixtureFreeIDs: [ExperienceID] { fixture.freeIDs }

    /// The premium fixture id.
    static var fixturePremiumID: ExperienceID? { fixture.premiumID }

    /// The fixture registry: the debug experience for each of the five free fixture ids. The premium fixture
    /// experience has no factory, because a premium experience is never opened by this feature.
    static var fixtureRegistry: [ExperienceRegistration] {
        fixture.freeIDs.map(DebugExperience.registration(for:))
    }

    /// Builds the fixture from the data of a real catalog by switching `available` to true for six entries.
    ///
    /// The entries are chosen by rule, not by name: the first premium entry; the first free entry of its
    /// category; and the first two free entries of each of the first two other categories, in catalog order.
    /// The launch allocation of the catalog stays as it is, so the result passes the validated loader.
    static func makeFixture(from data: Data?) -> Fixture {
        guard let data, var root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              var entries = root["experiences"] as? [[String: Any]] else {
            return Fixture()
        }
        func text(_ index: Int, _ key: String) -> String { entries[index][key] as? String ?? "" }
        guard let premium = entries.indices.first(where: { text($0, "tier") == "premium" }) else { return Fixture() }
        let premiumCategory = text(premium, "category")
        var chosen: [Int] = []
        var others: [String] = []
        var perCategory: [String: Int] = [:]
        for index in entries.indices where text(index, "tier") == "free" {
            let category = text(index, "category")
            let limit: Int
            if category == premiumCategory {
                limit = 1
            } else {
                if !others.contains(category) {
                    guard others.count < 2 else { continue }
                    others.append(category)
                }
                limit = 2
            }
            guard perCategory[category, default: 0] < limit else { continue }
            perCategory[category, default: 0] += 1
            chosen.append(index)
        }
        var fixture = Fixture()
        for index in chosen + [premium] {
            entries[index]["available"] = true
        }
        fixture.freeIDs = chosen.compactMap { ExperienceID(rawValue: text($0, "id")) }
        fixture.premiumID = ExperienceID(rawValue: text(premium, "id"))
        root["experiences"] = entries
        fixture.catalog = (try? JSONSerialization.data(withJSONObject: root, options: [.sortedKeys])) ?? Data()
        return fixture
    }
}
#endif
