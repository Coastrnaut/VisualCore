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
        }
    }

    /// An environment on this storage.
    func environment(catalog: Data?, categories: Data?, registry: [ExperienceRegistration],
                     arguments: [String] = []) -> AppEnvironment {
        AppEnvironment(catalogData: catalog, categoriesData: categories, registry: registry, defaults: defaults,
                       dataRoot: root, arguments: arguments)
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
    #endif
}
