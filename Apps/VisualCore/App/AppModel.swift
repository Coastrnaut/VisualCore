// AppModel — feature 190 T-U04-011 (FR-U04-010 to FR-U04-012, FR-U04-020 to FR-U04-024, FR-U04-031, FR-U04-033,
// FR-U04-040 to FR-U04-042, FR-U04-050 to FR-U04-052, FR-U04-060; research R2, R4, R6; data-model sections 1 to 5).
// The one observable model of the app shell. It loads the catalog, compares it with the registry, keeps the
// preferences and owns the one experience session. Every decision is taken by the pure shell model of
// VisualCoreExperience; this type only carries the decisions out and stores their result.
import Foundation
import Observation
import VisualCoreExperience
import VisualCoreExperienceHost

/// What the app knows about its own start and its last reset (data-model section 5).
struct AppDiagnostics: Equatable {
    /// The catalog state: `loaded: <n> experiences, <m> available`, or the code of the catalog error.
    var catalog: String
    /// The ids that are registered but not available, available but not registered, or registered twice; sorted.
    var registryMismatches: [String]
    /// The note of the preferences store, when the stored value was unreadable or newer.
    var preferencesNote: String?
    /// Test arguments the debug support did not understand.
    var unknownArguments: [String]
    /// What the last reset removed: storage namespaces and, after a reset of all data, the preferences key.
    var lastReset: [String]

    /// The diagnostics as lines of text.
    var text: String {
        ["catalog: \(catalog)",
         "registryMismatches: \(registryMismatches.joined(separator: ","))",
         "preferencesNote: \(preferencesNote ?? "")",
         "unknownArguments: \(unknownArguments.joined(separator: ","))",
         "lastReset: \(lastReset.joined(separator: ","))"].joined(separator: "\n")
    }
}

/// Everything the model takes from outside: the two catalog files, the registry, the stores and the arguments.
struct AppEnvironment {
    /// The data of `experiences.json`; nil when the file is missing.
    var catalogData: Data?
    /// The data of `categories.json`; nil when the file is missing.
    var categoriesData: Data?
    /// The registered experiences.
    var registry: [ExperienceRegistration]
    /// Where the preferences are stored.
    var defaults: UserDefaults
    /// The folder below which every experience has its data folder.
    var dataRoot: URL
    /// The launch arguments of the process.
    var arguments: [String]

    /// The environment of the shipped app: the bundled catalog, the explicit registry, the standard defaults,
    /// `Application Support/Experiences` and the arguments of the process.
    static func live() -> AppEnvironment {
        AppEnvironment(catalogData: bundled("experiences"), categoriesData: bundled("categories"),
                       registry: ExperienceRegistry.all, defaults: .standard,
                       dataRoot: ExperienceDataStore.defaultRoot(), arguments: ProcessInfo.processInfo.arguments)
    }

    /// The data of a JSON resource at the root of the main bundle.
    static func bundled(_ name: String) -> Data? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "json") else { return nil }
        return try? Data(contentsOf: url)
    }
}

/// The model of the app shell: launcher, routes, welcome, preferences, reset and the one session.
@MainActor @Observable
final class AppModel {
    /// The one session of the app; at most one experience is open.
    let session: ExperienceSession
    /// What the launcher shows.
    private(set) var launcher: LauncherState
    /// The current route.
    private(set) var route: ShellRoute
    /// Whether the welcome is shown.
    private(set) var showWelcome: Bool
    /// The stored preferences.
    private(set) var preferences: ShellPreferences
    /// True after a premium tile was chosen, until the notice is dismissed.
    private(set) var premiumNotice = false
    /// The quality tier applied to the last opened experience; nil for automatic.
    private(set) var lastAppliedTier: Int? = nil
    /// The diagnostics of the start and of the last reset.
    private(set) var diagnostics: AppDiagnostics
    /// The storage namespaces that have a data folder, sorted.
    private(set) var dataNamespaces: [String]

    /// The launch arguments the model was created with.
    let arguments: [String]

    private let manifest: Result<CatalogManifest, CatalogError>
    private let categories: CategoryList?
    private let registrations: [ExperienceID: ExperienceRegistration]
    private let store: PreferencesStore
    private let dataStore: ExperienceDataStore
    /// The ids the launcher may show when they are available: see `showableIDs(_:_:)`.
    private let showable: Set<ExperienceID>
    private var restored = false

    /// Creates the model: loads the catalog, compares it with the registry, loads the preferences and decides
    /// the start. Nothing is opened here; `restoreRoute()` opens a restored experience.
    init(environment: AppEnvironment) {
        session = ExperienceSession()
        arguments = environment.arguments
        let loaded = Self.loadCatalog(catalog: environment.catalogData, categories: environment.categoriesData)
        manifest = loaded.manifest
        categories = loaded.categories
        let table = Dictionary(environment.registry.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        registrations = table
        let preferencesStore = PreferencesStore(defaults: environment.defaults)
        let folders = ExperienceDataStore(root: environment.dataRoot)
        store = preferencesStore
        dataStore = folders

        let stored = preferencesStore.load()
        let catalogText: String
        var mismatches: [String] = []
        var visible: [ExperienceDescriptor] = []
        var registered: Set<ExperienceID> = []
        switch loaded.manifest {
        case .success(let catalog):
            catalogText = "loaded: \(catalog.experiences.count) experiences, \(catalog.available.count) available"
            let report = catalog.registryReport(registered: environment.registry.map(\.id))
            let ids = report.unexpectedRegistrations + report.missingRegistrations + report.duplicates
            mismatches = Set(ids.map(\.rawValue)).sorted()
            registered = Self.showableIDs(catalog, table)
            visible = LauncherModel.shown(manifest: catalog, registered: registered)
        case .failure(let error):
            catalogText = LauncherModel.code(of: error)
        }
        showable = registered
        let startup = ShellStartup.decide(preferences: stored.preferences, shown: visible)
        preferences = stored.preferences
        route = startup.route
        showWelcome = startup.showWelcome
        launcher = LauncherModel.state(manifest: loaded.manifest, categories: loaded.categories,
                                       registered: registered, searchText: stored.preferences.searchText)
        diagnostics = AppDiagnostics(catalog: catalogText, registryMismatches: mismatches,
                                     preferencesNote: stored.note, unknownArguments: [], lastReset: [])
        dataNamespaces = folders.existing()
    }

    // MARK: - Catalog

    /// The experiences the launcher shows, in catalog order: available and registered, and the available premium
    /// experiences (see `showableIDs(_:_:)`).
    var shown: [ExperienceDescriptor] {
        guard case .success(let catalog) = manifest else { return [] }
        return LauncherModel.shown(manifest: catalog, registered: showable)
    }

    /// The ids handed to the launcher model as registered: the registered ids and the ids of the available
    /// premium experiences. This feature never opens a premium experience (FR-U04-012), so its tile needs no
    /// factory; a premium experience that is available but not registered is still listed as a registry mismatch.
    private static func showableIDs(_ catalog: CatalogManifest,
                                 _ registrations: [ExperienceID: ExperienceRegistration]) -> Set<ExperienceID> {
        Set(registrations.keys).union(catalog.available.filter { $0.tier == .premium }.map(\.id))
    }

    /// The catalog entry of `id`, if the catalog was loaded and holds it.
    func descriptor(for id: ExperienceID) -> ExperienceDescriptor? {
        guard case .success(let catalog) = manifest else { return nil }
        return catalog.experience(id)
    }

    /// The launcher's search text, at most `ShellPreferences.maxSearchLength` characters. Setting it recomputes
    /// `launcher` and saves the preferences.
    var searchText: String {
        get { preferences.searchText }
        set {
            var changed = preferences
            changed.searchText = newValue
            guard changed != preferences else { return }
            preferences = changed
            refreshLauncher()
            store.save(preferences)
        }
    }

    private func refreshLauncher() {
        let state = LauncherModel.state(manifest: manifest, categories: categories,
                                        registered: showable, searchText: preferences.searchText)
        if state != launcher { launcher = state }
    }

    private static func loadCatalog(catalog: Data?, categories: Data?)
        -> (manifest: Result<CatalogManifest, CatalogError>, categories: CategoryList?) {
        guard let catalog else { return (.failure(.unreadable(reason: "the catalog is missing")), nil) }
        do {
            var list: CategoryList?
            if let categories { list = try CategoryList(data: categories) }
            return (.success(try CatalogManifest(data: catalog, categories: list)), list)
        } catch {
            return (.failure(error), nil)
        }
    }

    // MARK: - Routes

    /// Goes to the catalog, the settings or the about page and closes an open experience. An experience route
    /// is not taken here: `open(_:)` opens an experience.
    func go(_ route: ShellRoute) {
        if case .experience = route { return }
        session.close()
        setRoute(route)
    }

    /// Opens the experience `id` in the session.
    ///
    /// An id that is not shown (unknown, not available or not registered) changes nothing and returns false. A
    /// premium experience is not opened: `premiumNotice` becomes true and the result is false. Otherwise the
    /// route becomes the experience and the session opens it; after a successful open the quality override is
    /// applied (an undeclared tier is replaced by the last declared one) and the result is true. After a failed
    /// open the route stays on the experience, where the session shows its failure view, and the result is false.
    @discardableResult
    func open(_ id: ExperienceID) async -> Bool {
        guard let descriptor = shown.first(where: { $0.id == id }) else { return false }
        guard descriptor.tier != .premium else {
            premiumNotice = true
            return false
        }
        guard let registration = registrations[id] else { return false }
        premiumNotice = false
        lastAppliedTier = nil
        setRoute(.experience(id))
        let request = ExperienceOpenRequest(id: id, seed: Self.seed(for: id), make: registration.make)
        switch await session.open(request) {
        case .running, .suspended:
            lastAppliedTier = applyQualityOverride()
            setRoute(.experience(id))
            return true
        case .failed, .superseded:
            return false
        case .cancelled:
            if route == .experience(id) { setRoute(.catalog) }
            return false
        }
    }

    /// Closes the open experience and returns to the catalog.
    func closeExperience() {
        session.close()
        setRoute(.catalog)
    }

    /// Opens the experience of a restored route. It acts once; the root view calls it when it appears.
    func restoreRoute() async {
        guard !restored else { return }
        restored = true
        guard case .experience(let id) = route, session.state == .idle else { return }
        let opened = await open(id)
        if !opened, session.state == .idle { setRoute(.catalog) }
    }

    /// Hides the premium notice.
    func dismissPremiumNotice() {
        premiumNotice = false
    }

    private func setRoute(_ route: ShellRoute) {
        if self.route != route { self.route = route }
        guard preferences.lastRoute != route else { return }
        preferences.lastRoute = route
        store.save(preferences)
    }

    /// A stable seed for an experience: the first eight bytes of its id, folded into one number.
    static func seed(for id: ExperienceID) -> UInt64 {
        id.rawValue.utf8.prefix(8).reduce(UInt64(0)) { ($0 << 8) | UInt64($1) }
    }

    /// Applies the stored quality override to the open experience and returns the tier that was applied: the
    /// override, or the experience's last declared tier when it did not declare the override; nil for automatic.
    private func applyQualityOverride() -> Int? {
        guard let override = preferences.qualityOverride, let experience = session.experience else { return nil }
        do {
            try experience.setQualityTier(override)
            return override
        } catch {
            guard case .invalidTier(_, let tiers) = error, tiers > 0 else { return nil }
            do {
                try experience.setQualityTier(tiers - 1)
                return tiers - 1
            } catch {
                return nil
            }
        }
    }

    // MARK: - Welcome

    /// Ends the welcome and remembers that it was seen. With `openFirst` it opens the first free experience
    /// that is shown; without one the catalog stays.
    func finishWelcome(openFirst: Bool) async {
        showWelcome = false
        if !preferences.welcomeSeen {
            preferences.welcomeSeen = true
            store.save(preferences)
        }
        guard openFirst else { return }
        if let first = ShellStartup.decide(preferences: preferences, shown: shown).firstFree {
            await open(first)
        }
    }

    // MARK: - Settings

    /// Stores the quality override: nil for automatic, or a tier from 0 to 7.
    func setQualityOverride(_ tier: Int?) {
        preferences.qualityOverride = tier
        store.save(preferences)
    }

    /// Stores the reduce-motion and the reduce-flashing choice.
    func setAccessibility(reduceMotion: VisualCoreExperience.AccessibilityChoice,
                          reduceFlashing: VisualCoreExperience.AccessibilityChoice) {
        preferences.reduceMotion = reduceMotion
        preferences.reduceFlashing = reduceFlashing
        store.save(preferences)
    }

    /// Reads again which storage namespaces have a data folder.
    func refreshDataNamespaces() {
        let found = dataStore.existing()
        if found != dataNamespaces { dataNamespaces = found }
    }

    /// Carries out a reset. An open experience is closed first. `.experience` removes the folder of that
    /// experience; `.all` removes every experience folder and the preferences, and shows the welcome again.
    func reset(_ plan: ResetPlan) {
        session.close()
        if case .experience = route { setRoute(.catalog) }
        let found = dataStore.existing()
        var known = found.compactMap(ExperienceID.init(rawValue:))
        if case .success(let catalog) = manifest { known += catalog.experiences.map(\.id) }
        var names = plan.namespaces(known: known)
        if plan.removesPreferences { names += found }
        var removed = dataStore.remove(namespaces: names)
        if plan.removesPreferences {
            store.remove()
            removed.append(ShellPreferences.storageKey)
            preferences = ShellPreferences()
            route = .catalog
            premiumNotice = false
            lastAppliedTier = nil
            refreshLauncher()
            showWelcome = ShellStartup.decide(preferences: preferences, shown: shown).showWelcome
        }
        diagnostics.lastReset = removed
        refreshDataNamespaces()
    }

    // MARK: - Diagnostics

    /// Records test arguments that were not understood.
    func noteUnknownArguments(_ items: [String]) {
        for item in items where !diagnostics.unknownArguments.contains(item) {
            diagnostics.unknownArguments.append(item)
        }
    }
}
