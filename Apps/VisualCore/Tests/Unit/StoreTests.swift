// StoreTests — feature 190 T-U04-006 (US1; FR-U04-052, FR-U04-060; SC-U04-006): the preferences store keeps a
// value across two instances and replaces damaged data by defaults with a note; the data store creates, lists and
// removes one folder per storage namespace; a reset removes exactly what its plan names.
import Foundation
import VisualCoreExperience
import XCTest
@testable import VisualCoreApp

/// A private defaults suite and a temporary data folder for one test; both are removed after the test.
struct TestStorage {
    let suite: String
    let defaults: UserDefaults
    let root: URL

    @MainActor
    init(_ test: XCTestCase) throws {
        let suite = "dev.visualcore.VisualCore.tests." + UUID().uuidString
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("vc-tests-" + UUID().uuidString)
        self.suite = suite
        self.defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        self.root = root
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        test.addTeardownBlock {
            UserDefaults.standard.removePersistentDomain(forName: suite)
            try? FileManager.default.removeItem(at: root)
            // The property list of the private suite is a file in the app's container; the unit tests run
            // inside the app, so it would stay there and the container inventory would rightly name it.
            try? FileManager.default.removeItem(at: Self.propertyList(of: suite))
        }
    }

    /// The file the system keeps the defaults suite `suite` in.
    static func propertyList(of suite: String) -> URL {
        URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
            .appendingPathComponent("Library/Preferences/\(suite).plist")
    }

    /// An environment on this storage.
    func environment(catalog: Data?, categories: Data?, registry: [ExperienceRegistration],
                     arguments: [String] = []) -> AppEnvironment {
        AppEnvironment(catalogData: catalog, categoriesData: categories, registry: registry, defaults: defaults,
                       dataRoot: root, arguments: arguments)
    }

    /// The storage handle of `id` on this storage.
    func handle(_ id: ExperienceID) -> ExperienceStorage {
        ExperienceStorage(id: id, root: root, defaults: defaults)
    }

    /// What the shell hands to the experience `id` on this storage, with the default accessibility choices.
    func launch(_ id: ExperienceID) -> ExperienceLaunch {
        ExperienceLaunch(storage: handle(id))
    }
}

@MainActor
final class StoreTests: XCTestCase {
    // MARK: Preferences

    func testPreferencesAreKeptAcrossTwoInstances() throws {
        let storage = try TestStorage(self)
        var preferences = ShellPreferences()
        preferences.welcomeSeen = true
        preferences.lastRoute = .settings
        preferences.searchText = "rain"
        preferences.qualityOverride = 3
        preferences.reduceMotion = .on
        preferences.reduceFlashing = .off
        PreferencesStore(defaults: storage.defaults).save(preferences)

        let loaded = PreferencesStore(defaults: storage.defaults).load()
        XCTAssertEqual(loaded.preferences, preferences)
        XCTAssertNil(loaded.note)
        XCTAssertNotNil(storage.defaults.object(forKey: ShellPreferences.storageKey))
    }

    func testAnEmptySuiteGivesDefaultsWithoutNote() throws {
        let storage = try TestStorage(self)
        let loaded = PreferencesStore(defaults: storage.defaults).load()
        XCTAssertEqual(loaded.preferences, ShellPreferences())
        XCTAssertNil(loaded.note)
    }

    func testDamagedPreferencesAreReplacedByDefaultsWithANote() throws {
        let storage = try TestStorage(self)
        storage.defaults.set(Data("{ this is not a preferences value".utf8), forKey: ShellPreferences.storageKey)
        let loaded = PreferencesStore(defaults: storage.defaults).load()
        XCTAssertEqual(loaded.preferences, ShellPreferences())
        XCTAssertEqual(loaded.note, "preferences.unreadable")
    }

    func testRemoveDeletesTheStoredValue() throws {
        let storage = try TestStorage(self)
        let store = PreferencesStore(defaults: storage.defaults)
        var preferences = ShellPreferences()
        preferences.welcomeSeen = true
        store.save(preferences)
        store.remove()
        XCTAssertNil(storage.defaults.object(forKey: ShellPreferences.storageKey))
        XCTAssertEqual(PreferencesStore(defaults: storage.defaults).load().preferences, ShellPreferences())
    }

    // MARK: Experience data

    func testTheDataStoreCreatesListsAndRemovesOneFolderPerNamespace() throws {
        let storage = try TestStorage(self)
        let store = ExperienceDataStore(root: storage.root)
        XCTAssertEqual(store.existing(), [])
        try store.ensure(namespace: "a01.first")
        try store.ensure(namespace: "a02.second")
        try store.ensure(namespace: "a01.first")   // a second call changes nothing
        XCTAssertEqual(store.existing().sorted(), ["a01.first", "a02.second"])

        var isDirectory: ObjCBool = false
        let folder = store.folder(for: "a01.first")
        XCTAssertTrue(FileManager.default.fileExists(atPath: folder.path, isDirectory: &isDirectory))
        XCTAssertTrue(isDirectory.boolValue)
        XCTAssertEqual(folder.deletingLastPathComponent().standardizedFileURL.path, storage.root.standardizedFileURL.path)
        XCTAssertNotEqual(folder, store.folder(for: "a02.second"))
        try Data("kept".utf8).write(to: folder.appendingPathComponent("state.json"))

        XCTAssertEqual(store.remove(namespaces: ["a01.first"]), ["a01.first"])
        XCTAssertEqual(store.existing(), ["a02.second"])
        XCTAssertFalse(FileManager.default.fileExists(atPath: folder.path))
        XCTAssertEqual(store.remove(namespaces: ["a01.first"]), [], "nothing is reported for a folder that is not there")
        XCTAssertEqual(store.remove(namespaces: ["a02.second"]), ["a02.second"])
        XCTAssertEqual(store.existing(), [])
    }

    func testTheDefaultRootIsInsideTheAppContainer() {
        let root = ExperienceDataStore.defaultRoot()
        XCTAssertTrue(root.isFileURL)
        XCTAssertTrue(root.path.hasPrefix(NSHomeDirectory()), root.path)
    }

    // MARK: Reset through the app model

    #if DEBUG
    private func fixtureModel(_ storage: TestStorage) -> AppModel {
        AppModel(environment: storage.environment(catalog: DebugLaunch.fixtureCatalogData,
                                                  categories: DebugLaunch.fixtureCategoriesData,
                                                  registry: DebugLaunch.fixtureRegistry))
    }

    func testResetOfOneExperienceRemovesOnlyItsFolder() async throws {
        let storage = try TestStorage(self)
        let model = fixtureModel(storage)
        await model.finishWelcome(openFirst: false)
        let ids = model.shown.map(\.id)
        XCTAssertGreaterThanOrEqual(ids.count, 2)
        let store = ExperienceDataStore(root: storage.root)
        for id in ids { try store.ensure(namespace: id.storageNamespace) }

        model.reset(.experience(ids[0]))
        XCTAssertEqual(store.existing().sorted(), ids.dropFirst().map(\.storageNamespace).sorted())
        XCTAssertEqual(model.diagnostics.lastReset, [ids[0].storageNamespace])
        XCTAssertFalse(model.showWelcome, "the preferences are kept")
        XCTAssertTrue(PreferencesStore(defaults: storage.defaults).load().preferences.welcomeSeen)
    }

    func testResetOfAllRemovesEveryFolderAndThePreferences() async throws {
        let storage = try TestStorage(self)
        let model = fixtureModel(storage)
        await model.finishWelcome(openFirst: false)
        model.setQualityOverride(2)
        model.setAccessibility(reduceMotion: .on, reduceFlashing: .off)
        model.go(.settings)
        XCTAssertNotEqual(PreferencesStore(defaults: storage.defaults).load().preferences, ShellPreferences())
        let ids = model.shown.map(\.id)
        let store = ExperienceDataStore(root: storage.root)
        for id in ids { try store.ensure(namespace: id.storageNamespace) }

        model.reset(.all)
        XCTAssertEqual(store.existing(), [])
        XCTAssertEqual(model.diagnostics.lastReset.sorted().filter { ids.map(\.storageNamespace).contains($0) },
                       ids.map(\.storageNamespace).sorted())
        XCTAssertEqual(PreferencesStore(defaults: storage.defaults).load().preferences, ShellPreferences())
        XCTAssertEqual(model.preferences, ShellPreferences())
        XCTAssertTrue(model.showWelcome, "the app is as after a first start")
        XCTAssertNil(model.session.experience)
    }

    func testResetClosesAnOpenExperienceFirst() async throws {
        let storage = try TestStorage(self)
        let model = fixtureModel(storage)
        await model.finishWelcome(openFirst: false)
        let id = try XCTUnwrap(model.shown.first { $0.tier == .free }?.id)
        let opened = await model.open(id)
        XCTAssertTrue(opened)
        model.reset(.experience(id))
        XCTAssertNil(model.session.experience, "an open experience is closed before its data is removed")
        XCTAssertEqual(model.route, .catalog)
        model.closeExperience()
    }

    // MARK: Resets and stored data (feature 191, T-U05-019; FR-U05-040 to FR-U05-044; SC-U05-006)

    /// Gives `id` a saved state (by a real open and close), a file, a value and a quarantined copy.
    private func fill(_ model: AppModel, _ storage: TestStorage, _ id: ExperienceID) async throws {
        let opened = await model.open(id)
        XCTAssertTrue(opened)
        XCTAssertEqual(model.session.experience?.handle(control: "tap", values: []), .accepted)
        model.closeExperience()
        try storage.handle(id).write(Data("file".utf8), to: "notes.txt")
        try storage.handle(id).setValue(Data("value".utf8), for: "choice")
        let folder = SavedStateStore(root: storage.root).folder(for: id)
        try Data("old".utf8).write(to: folder.appendingPathComponent("quarantine-1.json"))
    }

    /// Every stored item of `id`: the files of its folder and its defaults keys.
    private func items(_ storage: TestStorage, _ id: ExperienceID) -> [String] {
        let folder = SavedStateStore(root: storage.root).folder(for: id)
        let files = (try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []
        let prefix = ExperienceStorage.defaultsPrefix(for: id)
        let keys = storage.defaults.dictionaryRepresentation().keys.filter { $0.hasPrefix(prefix) }
        return (files + keys).sorted()
    }

    func testResetOfOneRemovesAllOfItsItemsAndNoneOfTheOthers() async throws {
        let storage = try TestStorage(self)
        let model = fixtureModel(storage)
        await model.finishWelcome(openFirst: false)
        let ids = Array(model.shown.filter { $0.tier == .free }.map(\.id).prefix(3))
        XCTAssertEqual(ids.count, 3)
        for id in ids { try await fill(model, storage, id) }
        // Data of an id the catalog does not hold: a start and the reset of another experience leave it alone.
        let foreign = try XCTUnwrap(ExperienceID(rawValue: "a97.not-in-the-catalog"))
        try storage.handle(foreign).write(Data("foreign".utf8), to: "kept.txt")
        try storage.handle(foreign).setValue(Data("foreign".utf8), for: "kept")
        let restarted = fixtureModel(storage)
        XCTAssertEqual(items(storage, foreign), ["exp.a97.not-in-the-catalog.kept", "kept.txt"])

        let expected = ["choice", "opens"].map { ExperienceStorage.defaultsPrefix(for: ids[0]) + $0 }
            + ["notes.txt", "quarantine-1.json", "state.json"]
        XCTAssertEqual(items(storage, ids[0]), expected.sorted())
        let others = [items(storage, ids[1]), items(storage, ids[2])]
        XCTAssertEqual(others.map(\.count), [5, 5])

        restarted.reset(.experience(ids[0]))
        XCTAssertEqual(items(storage, ids[0]), [], "100% of the reset experience's items are gone")
        XCTAssertEqual([items(storage, ids[1]), items(storage, ids[2])], others, "0 of the others' items")
        XCTAssertEqual(items(storage, foreign), ["exp.a97.not-in-the-catalog.kept", "kept.txt"])
        XCTAssertEqual(restarted.diagnostics.lastReset.sorted(),
                       ([ids[0].storageNamespace] + ["choice", "opens"].map {
                           ExperienceStorage.defaultsPrefix(for: ids[0]) + $0
                       }).sorted())
        XCTAssertTrue(PreferencesStore(defaults: storage.defaults).load().preferences.welcomeSeen,
                      "the preferences are kept")
        XCTAssertFalse(restarted.showWelcome)

        // The reset experience opens in the state of a fresh preparation with the same seed.
        let opened = await restarted.open(ids[0])
        XCTAssertTrue(opened)
        XCTAssertTrue(restarted.session.experience?.port.summary.contains(" 0 taps") ?? false)
        restarted.closeExperience()
        guard case .state(let fresh) = SavedStateStore(root: storage.root).load(ids[0]) else {
            return XCTFail("no state after the fresh open")
        }
        XCTAssertEqual(fresh.seed, AppModel.seed(for: ids[0]))
    }

    func testResetOfAllLeavesNoFolderNoExperienceKeyAndNoPreferences() async throws {
        let storage = try TestStorage(self)
        let model = fixtureModel(storage)
        await model.finishWelcome(openFirst: false)
        let ids = Array(model.shown.filter { $0.tier == .free }.map(\.id).prefix(3))
        for id in ids { try await fill(model, storage, id) }
        let foreign = try XCTUnwrap(ExperienceID(rawValue: "a97.not-in-the-catalog"))
        try storage.handle(foreign).write(Data("foreign".utf8), to: "kept.txt")
        try storage.handle(foreign).setValue(Data("foreign".utf8), for: "kept")
        storage.defaults.set(Data("{ unreadable".utf8), forKey: ShellPreferences.unreadableCopyKey)
        storage.defaults.set("kept", forKey: "another.key")

        model.reset(.all)
        XCTAssertEqual(ExperienceDataStore(root: storage.root).existing(), [])
        let keys = storage.defaults.dictionaryRepresentation().keys
        XCTAssertEqual(keys.filter { $0.hasPrefix("exp.") }, [])
        XCTAssertNil(storage.defaults.object(forKey: ShellPreferences.storageKey))
        XCTAssertNil(storage.defaults.object(forKey: ShellPreferences.unreadableCopyKey))
        XCTAssertEqual(storage.defaults.string(forKey: "another.key"), "kept", "a key of no experience is not touched")
        XCTAssertTrue(model.showWelcome)
        XCTAssertTrue(model.diagnostics.lastReset.contains(ShellPreferences.unreadableCopyKey))
        XCTAssertTrue(model.diagnostics.lastReset.contains("exp.a97.not-in-the-catalog.kept"))
    }

    func testAResetOfAnOpenExperienceLeavesNoSavedStateAndClearsTheNotice() async throws {
        let storage = try TestStorage(self)
        let model = fixtureModel(storage)
        await model.finishWelcome(openFirst: false)
        let id = try XCTUnwrap(model.shown.first { $0.tier == .free }?.id)
        let opened = await model.open(id)
        XCTAssertTrue(opened)
        XCTAssertEqual(model.session.experience?.handle(control: "tap", values: []), .accepted)
        model.reset(.experience(id))
        XCTAssertEqual(items(storage, id), [], "the close's save is removed with the rest")
        XCTAssertEqual(SavedStateStore(root: storage.root).load(id), .none)

        // A reset while the notice is shown clears the notice and the unreadable state.
        let url = SavedStateStore(root: storage.root).stateURL(for: id)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("garbage".utf8).write(to: url)
        let refused = await model.open(id)
        XCTAssertFalse(refused)
        XCTAssertNotNil(model.unreadable)
        model.reset(.experience(id))
        XCTAssertNil(model.unreadable)
        XCTAssertEqual(model.route, .catalog)
        XCTAssertEqual(items(storage, id), [])
    }

    // MARK: The copy of unreadable preferences (feature 191, T-U05-021; FR-U05-052)

    func testOneCopyOfUnreadablePreferencesIsKeptAndRemovedByTheResetOfAll() async throws {
        let storage = try TestStorage(self)
        let unreadable = Data("{ this is not a preferences value".utf8)
        storage.defaults.set(unreadable, forKey: ShellPreferences.storageKey)
        let store = PreferencesStore(defaults: storage.defaults)
        XCTAssertEqual(store.load().note, "preferences.unreadable")
        XCTAssertEqual(storage.defaults.data(forKey: ShellPreferences.unreadableCopyKey), unreadable)

        // The value is overwritten; a second unreadable value does not replace the copy.
        store.save(ShellPreferences())
        XCTAssertNil(store.load().note)
        storage.defaults.set(Data("second".utf8), forKey: ShellPreferences.storageKey)
        XCTAssertNotNil(store.load().note)
        XCTAssertEqual(storage.defaults.data(forKey: ShellPreferences.unreadableCopyKey), unreadable, "written once")

        // A readable value makes no copy.
        let clean = try TestStorage(self)
        PreferencesStore(defaults: clean.defaults).save(ShellPreferences())
        _ = PreferencesStore(defaults: clean.defaults).load()
        XCTAssertNil(clean.defaults.object(forKey: ShellPreferences.unreadableCopyKey))

        // A value of a newer schema is copied as well.
        let newer = try TestStorage(self)
        let future = Data(#"{"schema":99}"#.utf8)
        newer.defaults.set(future, forKey: ShellPreferences.storageKey)
        XCTAssertEqual(PreferencesStore(defaults: newer.defaults).load().note, "preferences.newer")
        XCTAssertEqual(newer.defaults.data(forKey: ShellPreferences.unreadableCopyKey), future)

        let model = fixtureModel(storage)
        model.reset(.all)
        XCTAssertNil(storage.defaults.object(forKey: ShellPreferences.unreadableCopyKey))
        XCTAssertNil(storage.defaults.object(forKey: ShellPreferences.storageKey))
    }
    #endif
}
