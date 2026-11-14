// JourneyPresetStoreTests — feature 057 (A07-P04) T-A07-403 (FR-A07-401, FR-A07-403, FR-A07-404; SC-A07-401–403;
// story 1). The journey store in a temporary experience storage, short runs only (each test well under 10 s): built-ins
// listed first; seeded save → reload in a new store → apply on a core round trips restoring every journey field (world,
// the three mappings, speed target, easing, calm motion, name); names unique ignoring case after 200 seeded saves,
// renames and deletes; the numbered suffix on a clash (built-in names included); built-ins refused for rename and delete
// with plain messages; delete removing the file; planted damaged, newer and built-in-id files counted and left
// byte-identical; a save beyond the storage file limit refused with the storage code and nothing changed; reload sorting
// by name ignoring case with ties by id.
import Foundation
import XCTest
@testable import AudioOdysseyExperience
import AudioOdysseyCore
import VisualCoreExperience

/// SplitMix64: a small seeded generator (deterministic for a seed).
private struct SplitMix {
    var state: UInt64

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    /// A value in `0..<bound`.
    mutating func below(_ bound: Int) -> Int { Int(next() % UInt64(bound)) }
}

@MainActor
final class JourneyPresetStoreTests: XCTestCase {
    private var root: URL!
    private var defaults: UserDefaults!
    private var suite = ""

    override func setUpWithError() throws {
        suite = "dev.visualcore.a07-p04.journeys.\(UUID().uuidString)"
        defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        root = FileManager.default.temporaryDirectory.appendingPathComponent(suite, isDirectory: true)
    }

    override func tearDown() {
        defaults?.removePersistentDomain(forName: suite)
        if let root { try? FileManager.default.removeItem(at: root) }
    }

    private var storage: ExperienceStorage {
        ExperienceStorage(id: ExperienceID(rawValue: "a07.journey-test")!, root: root, defaults: defaults)
    }

    /// The user journeys (entries after the built-ins).
    private func userPresets(_ store: JourneyPresetStore) -> [JourneyPreset] {
        Array(store.entries.dropFirst(JourneyPreset.builtIns.count))
    }

    /// A seeded journey state with every journey field drawn at random.
    private func randomState(_ rng: inout SplitMix) -> JourneyState {
        func mapping() -> ChannelMapping {
            ChannelMapping(channel: EnvelopeChannel.allCases[rng.below(EnvelopeChannel.allCases.count)],
                           sensitivity: Sensitivity.allCases[rng.below(Sensitivity.allCases.count)])
        }
        let mappings = JourneyWorld.allCases.map { _ in WorldMapping(primary: mapping(), light: mapping()) }
        return JourneyState(seed: rng.next(), world: JourneyWorld.allCases[rng.below(3)],
                            distance: Double(rng.below(500)), speedTarget: 0.5 + Double(rng.below(14)) * 0.5,
                            speed: Double(rng.below(4)), paused: rng.below(2) == 1, source: .demo,
                            easing: Easing.allCases[rng.below(3)], calmMotion: rng.below(2) == 1, mappings: mappings)
    }

    /// A state that differs from every field of the defaults, for a single save.
    private var customState: JourneyState {
        var mappings = WorldMapping.allDefaults
        mappings[1] = WorldMapping(primary: ChannelMapping(channel: .high, sensitivity: .low),
                                   light: ChannelMapping(channel: .transient, sensitivity: .high))
        return JourneyState(seed: 3, world: .landscape, speedTarget: 5.5, easing: .brisk, calmMotion: true,
                            mappings: mappings)
    }

    func testBuiltInsAreListedFirst() throws {
        let store = JourneyPresetStore(storage: storage)
        XCTAssertEqual(store.entries.map(\.id), JourneyPreset.builtIns.map(\.id))
        XCTAssertEqual(store.entries.map(\.name), ["Deep tunnel", "Rolling hills", "Night stars"])
        XCTAssertTrue(store.entries.allSatisfy(\.isBuiltIn))
        _ = try XCTUnwrap(store.save(name: "aardvark", from: customState))
        XCTAssertEqual(Array(store.entries.prefix(3)).map(\.id), JourneyPreset.builtIns.map(\.id))
        XCTAssertEqual(userPresets(store).map(\.name), ["aardvark"])
        XCTAssertEqual(store.unreadable, 0)
        XCTAssertEqual(store.newer, 0)
        XCTAssertNil(store.lastMessage)
    }

    func testSaveReloadApplyRoundTripsEveryFieldOverSeededStates() throws {
        var rng = SplitMix(state: 0xA07_0403)
        let store = JourneyPresetStore(storage: storage)
        var saved: [(JourneyPreset, JourneyState)] = []
        for index in 0..<24 {
            let state = randomState(&rng)
            let when = Date(timeIntervalSinceReferenceDate: Double(1_000 + index))
            let preset = try XCTUnwrap(store.save(name: "Trip \(index)", from: state, now: when))
            XCTAssertTrue(storage.exists(JourneyPreset.fileName(for: preset.id)))
            saved.append((preset, state))
        }
        let relaunched = JourneyPresetStore(storage: storage)
        XCTAssertEqual(relaunched.entries.map(\.id), store.entries.map(\.id))
        for (index, (preset, state)) in saved.enumerated() {
            let loaded = try XCTUnwrap(relaunched.preset(preset.id))
            XCTAssertEqual(loaded.name, "Trip \(index)")
            XCTAssertEqual(loaded.saved, Date(timeIntervalSinceReferenceDate: Double(1_000 + index)))
            XCTAssertFalse(loaded.isBuiltIn)
            XCTAssertEqual(loaded.world, state.world)
            XCTAssertEqual(loaded.mappings, state.mappings)
            XCTAssertEqual(loaded.speedTarget, state.speedTarget)
            XCTAssertEqual(loaded.easing, state.easing)
            XCTAssertEqual(loaded.calmMotion, state.calmMotion)
            // Applying the loaded journey on a core restores the same fields.
            var core = OdysseyCore(seed: 11)
            XCTAssertTrue(core.apply(ExperienceAction(control: "preset.apply", values: loaded.actionValues,
                                                      step: 0)).isAccepted)
            XCTAssertEqual(core.state.world, state.world)
            XCTAssertEqual(core.state.mappings, state.mappings)
            XCTAssertEqual(core.state.speedTarget, state.speedTarget)
            XCTAssertEqual(core.state.easing, state.easing)
            XCTAssertEqual(core.state.calmMotion, state.calmMotion)
        }
    }

    func testNamesStayUniqueIgnoringCaseOver200SeededOperations() throws {
        var rng = SplitMix(state: 0x5EED_0402)
        let pool = ["Trip", "trip", "TRIP 2", "Night stars", "deep TUNNEL", "   ", "Untitled", "Rolling hills 2",
                    String(repeating: "Long ", count: 20), "Trip 3"]
        let store = JourneyPresetStore(storage: storage)
        for operation in 0..<200 {
            let users = userPresets(store)
            let pick = rng.below(100)
            let name = pool[rng.below(pool.count)]
            if users.count >= 40 || (pick < 15 && !users.isEmpty) {
                XCTAssertTrue(store.delete(users[rng.below(users.count)].id), "operation \(operation)")
            } else if pick < 50 && !users.isEmpty {
                XCTAssertTrue(store.rename(users[rng.below(users.count)].id, to: name), "operation \(operation)")
            } else {
                XCTAssertNotNil(store.save(name: name, from: randomState(&rng)), "operation \(operation)")
            }
            XCTAssertNil(store.lastMessage, "operation \(operation)")
            let names = store.entries.map { $0.name.lowercased() }
            XCTAssertEqual(Set(names).count, names.count, "operation \(operation): \(names)")
            XCTAssertTrue(store.entries.allSatisfy { $0.name.count <= JourneyPreset.nameLimit && !$0.name.isEmpty })
        }
        let relaunched = JourneyPresetStore(storage: storage)
        XCTAssertEqual(relaunched.entries.map(\.name), store.entries.map(\.name))
    }

    func testSavingOrRenamingToATakenNameGetsTheNextFreeSuffix() throws {
        let store = JourneyPresetStore(storage: storage)
        XCTAssertEqual(store.save(name: "My trip", from: customState)?.name, "My trip")
        XCTAssertEqual(store.save(name: "my TRIP", from: customState)?.name, "my TRIP 2")
        XCTAssertEqual(store.save(name: "Rolling hills", from: customState)?.name, "Rolling hills 2",
                       "a built-in's name is taken too")
        XCTAssertEqual(store.save(name: " \n ", from: customState)?.name, "Untitled")
        let fixed = Date(timeIntervalSinceReferenceDate: 5_000)
        let other = try XCTUnwrap(store.save(name: "Other", from: customState, now: fixed))
        XCTAssertTrue(store.rename(other.id, to: "MY TRIP"))
        let renamed = try XCTUnwrap(store.preset(other.id))
        XCTAssertEqual(renamed.name, "MY TRIP 3")
        XCTAssertEqual(renamed.saved, fixed, "a rename keeps the saved time")
        XCTAssertEqual(renamed.world, customState.world)
        XCTAssertEqual(renamed.mappings, customState.mappings)
        XCTAssertTrue(store.rename(other.id, to: "my trip 3"), "its own name in another case is no clash")
        XCTAssertEqual(store.preset(other.id)?.name, "my trip 3")
        XCTAssertEqual(JourneyPresetStore(storage: storage).preset(other.id)?.name, "my trip 3", "the file was rewritten")
    }

    func testBuiltInsCannotBeRenamedOrDeleted() throws {
        let store = JourneyPresetStore(storage: storage)
        for builtIn in JourneyPreset.builtIns {
            XCTAssertFalse(store.rename(builtIn.id, to: "Mine"))
            XCTAssertEqual(store.lastMessage, "Built-in journeys can't be renamed.")
            XCTAssertFalse(store.delete(builtIn.id))
            XCTAssertEqual(store.lastMessage, "Built-in journeys can't be deleted.")
            XCTAssertEqual(store.preset(builtIn.id), builtIn)
        }
        XCTAssertEqual(store.entries.map(\.id), JourneyPreset.builtIns.map(\.id))
        XCTAssertTrue(storage.list().isEmpty)
    }

    func testDeleteRemovesTheFile() throws {
        let store = JourneyPresetStore(storage: storage)
        let a = try XCTUnwrap(store.save(name: "Alpha", from: customState))
        let b = try XCTUnwrap(store.save(name: "Beta", from: customState))
        XCTAssertTrue(store.delete(a.id))
        XCTAssertNil(store.lastMessage)
        XCTAssertFalse(storage.exists(JourneyPreset.fileName(for: a.id)))
        XCTAssertTrue(storage.exists(JourneyPreset.fileName(for: b.id)))
        XCTAssertEqual(userPresets(store).map(\.id), [b.id])
        XCTAssertFalse(store.delete(a.id), "already gone")
        let message = try XCTUnwrap(store.lastMessage)
        XCTAssertTrue(message.hasPrefix("Couldn't delete the journey: "), message)
        XCTAssertFalse(store.rename(a.id, to: "Gone"))
        XCTAssertTrue(try XCTUnwrap(store.lastMessage).hasPrefix("Couldn't rename the journey: "))
    }

    func testDamagedNewerAndBuiltInIDFilesAreCountedAndLeftByteIdentical() throws {
        let garbageID = UUID(uuidString: "00000000-0000-4000-8000-000000000a71")!
        let newerID = UUID(uuidString: "00000000-0000-4000-8000-000000000a72")!
        let builtInID = JourneyPreset.builtIns[0].id
        let garbageName = JourneyPreset.fileName(for: garbageID)
        let newerName = JourneyPreset.fileName(for: newerID)
        let builtInName = JourneyPreset.fileName(for: builtInID)
        let garbage = Data("not a journey {".utf8)
        let newerFile = Data(("{\"calm\":false,\"easing\":1,\"format\":2,\"id\":\"\(newerID.uuidString)\","
                              + "\"mappings\":[],\"name\":\"Future\",\"saved\":0,\"speedTarget\":4,\"world\":0}").utf8)
        let builtInFile = try JourneyPreset.builtIns[0].fileData()
        try storage.write(garbage, to: garbageName)
        try storage.write(newerFile, to: newerName)
        try storage.write(builtInFile, to: builtInName)

        let store = JourneyPresetStore(storage: storage)
        XCTAssertEqual(store.unreadable, 2, "the damaged file and the one claiming a built-in id")
        XCTAssertEqual(store.newer, 1)
        XCTAssertEqual(store.entries.map(\.id), JourneyPreset.builtIns.map(\.id))

        let kept = try XCTUnwrap(store.save(name: "Kept", from: customState))
        XCTAssertTrue(store.rename(kept.id, to: "Renamed"))
        XCTAssertFalse(store.rename(newerID, to: "Overwrite"), "a newer file is refused, never rewritten")
        XCTAssertEqual(store.lastMessage, "Couldn't rename the journey: it was made by a newer version.")
        XCTAssertFalse(store.rename(garbageID, to: "Overwrite"))
        XCTAssertEqual(store.lastMessage, "Couldn't rename the journey: it can't be read.")
        XCTAssertTrue(store.delete(kept.id))
        store.reload()
        XCTAssertEqual(store.unreadable, 2)
        XCTAssertEqual(store.newer, 1)

        let relaunched = JourneyPresetStore(storage: storage)
        XCTAssertEqual(relaunched.unreadable, 2)
        XCTAssertEqual(relaunched.newer, 1)
        XCTAssertEqual(try storage.read(garbageName), garbage)
        XCTAssertEqual(try storage.read(newerName), newerFile)
        XCTAssertEqual(try storage.read(builtInName), builtInFile)
        XCTAssertEqual(storage.list().sorted(), [garbageName, newerName, builtInName].sorted())
    }

    func testAQuotaRefusalSetsAMessageWithTheCodeAndChangesNothing() throws {
        let store = JourneyPresetStore(storage: storage)
        let kept = try XCTUnwrap(store.save(name: "Kept", from: customState))
        let keptName = JourneyPreset.fileName(for: kept.id)
        let keptData = try storage.read(keptName)
        for i in 0..<(StorageQuota.maxFiles - 1) {
            try storage.write(Data("filler \(i)".utf8), to: "filler-\(i).txt")
        }
        XCTAssertEqual(storage.list().count, StorageQuota.maxFiles)
        let entriesBefore = store.entries
        let filesBefore = storage.list().sorted()

        XCTAssertNil(store.save(name: "Overflow", from: JourneyState(seed: 1)))
        let message = try XCTUnwrap(store.lastMessage)
        XCTAssertTrue(message.hasPrefix("Couldn't save the journey: "), message)
        XCTAssertTrue(message.contains(StorageError.quotaExceeded("files").code), message)
        XCTAssertEqual(store.entries, entriesBefore)
        XCTAssertEqual(storage.list().sorted(), filesBefore)
        XCTAssertEqual(try storage.read(keptName), keptData)

        // A rename replaces the existing file, so it still works at the limit.
        XCTAssertTrue(store.rename(kept.id, to: "Still kept"))
        XCTAssertNil(store.lastMessage)
        XCTAssertEqual(userPresets(store).map(\.name), ["Still kept"])
    }

    func testReloadSortsByNameIgnoringCaseWithTiesByID() throws {
        let ids = ["00000000-0000-4000-8000-000000000b03", "00000000-0000-4000-8000-000000000b01",
                   "00000000-0000-4000-8000-000000000b02", "00000000-0000-4000-8000-000000000b04"]
            .compactMap(UUID.init(uuidString:))
        let names = ["beta", "Alpha", "alpha", "Zulu"]
        for (id, name) in zip(ids, names) {
            let preset = try XCTUnwrap(JourneyPreset(
                id: id, name: name, saved: Date(timeIntervalSinceReferenceDate: 0), world: .tunnel,
                mappings: WorldMapping.allDefaults, speedTarget: 4, easing: .standard, calmMotion: false))
            try storage.write(try preset.fileData(), to: JourneyPreset.fileName(for: id))
        }
        let store = JourneyPresetStore(storage: storage)
        XCTAssertEqual(userPresets(store).map(\.name), ["Alpha", "alpha", "beta", "Zulu"])
        XCTAssertEqual(userPresets(store).map(\.id), [ids[1], ids[2], ids[0], ids[3]])
        // A file added behind the store's back appears on the next reload, in order.
        let late = try XCTUnwrap(JourneyPreset(
            id: UUID(uuidString: "00000000-0000-4000-8000-000000000b05")!, name: "Middle",
            saved: Date(timeIntervalSinceReferenceDate: 0), world: .landscape, mappings: WorldMapping.allDefaults,
            speedTarget: 2, easing: .gentle, calmMotion: true))
        try storage.write(try late.fileData(), to: JourneyPreset.fileName(for: late.id))
        XCTAssertEqual(userPresets(store).count, 4)
        store.reload()
        XCTAssertEqual(userPresets(store).map(\.name), ["Alpha", "alpha", "beta", "Middle", "Zulu"])
    }
}
