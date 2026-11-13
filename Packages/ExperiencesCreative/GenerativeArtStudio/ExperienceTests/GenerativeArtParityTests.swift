// GenerativeArtParityTests — feature 193 (UA-F07) T-U07-012 (FR-U07-003; SC-U07-005). Parity of the A01 adapter
// with the standalone app: the same edits give the same composition and time as the app's `SceneModel` for three
// seeds, and the first picture of a composition at a time matches the app's own scene within the image tolerance
// of the app's determinism tests (`ImageComparison`: 99 % of channels within 2, mean difference at most 0.5,
// computed here because the test bundle links no package of its own). Hosted by the one app.
import XCTest
import GenerativeArtStudioCore
@testable import GenerativeArtStudioExperience
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreRendering
import VisualCoreSimulation

@MainActor
final class GenerativeArtParityTests: XCTestCase {
    private var id: ExperienceID { GenerativeArtExperience.id ?? ExperienceID(rawValue: "a01.unknown")! }

    /// The standalone model without a render host (its host factory throws), as the app builds it for one family.
    private func standalone(_ family: SceneFamilyID) -> SceneModel {
        SceneModel(family: FamilyCatalog.family(family), reduceMotion: false) { _ in
            throw OffscreenRenderError.unavailable("no host in the parity test")
        }
    }

    func testTheSameEditsGiveTheSameCompositionAndTimeForThreeSeeds() async throws {
        let neon = try XCTUnwrap(FamilyCatalog.palettes.firstIndex { $0.id == "neon" })
        for seed: UInt64 in [5, 77, 0xC0FF_EE00_1234_5678] {
            // The standalone app.
            let model = standalone(.particles)
            defer { model.close() }
            let family = model.family
            model.editor.setSeed(seed)
            model.editor.choosePreset(family.presets[1].id)
            model.editor.setSeed(seed)
            model.editor.choosePalette("neon")
            model.editor.setParameter("spread", normalized: 0.4)
            model.editor.setParameter("drag", normalized: 0.9)
            model.editor.resetParameter("drag")
            var random = SeededRandom(seed: model.document.seed)
            model.editor.shuffleSeed(using: &random)
            for _ in 0..<90 { model.clocked.clock.advance(by: GenerativeArtCore.stepDuration) }
            model.clocked.clock.pause()
            model.clocked.clock.scrub(to: 40)
            model.clocked.clock.play()
            for _ in 0..<30 { model.clocked.clock.advance(by: GenerativeArtCore.stepDuration) }

            // The adapter, with the same edits as actions.
            var engine = ExperienceEngine<GenerativeArtCore>(id: id)
            try await engine.prepare(seed: seed)
            try engine.activate()
            let halves = GenerativeArtCore.halves(of: seed)
            for (control, values) in [("seed.set", [halves.high, halves.low]), ("preset", [1]),
                                      ("seed.set", [halves.high, halves.low]), ("palette", [Double(neon)]),
                                      ("parameter.spread", [0.4]), ("parameter.drag", [0.9]), ("reset.drag", []),
                                      ("seed.shuffle", [])] {
                XCTAssertTrue(engine.handle(control: control, values: values).isAccepted, control)
            }
            try engine.run(steps: 90)
            XCTAssertTrue(engine.handle(control: "pause").isAccepted)
            XCTAssertTrue(engine.handle(control: "scrub", values: [40]).isAccepted)
            XCTAssertTrue(engine.handle(control: "play").isAccepted)
            try engine.run(steps: 30)

            let core = try XCTUnwrap(engine.core)
            XCTAssertEqual(core.document.familyID, model.document.familyID, "seed \(seed)")
            XCTAssertEqual(core.document.seed, model.document.seed, "seed \(seed)")
            XCTAssertEqual(core.document.paletteID, model.document.paletteID, "seed \(seed)")
            XCTAssertEqual(core.document.parameters, model.document.parameters, "seed \(seed)")
            XCTAssertEqual(core.presetID, model.editor.presetID, "seed \(seed)")
            XCTAssertEqual(core.baseline, model.editor.editor.baseline, "seed \(seed)")
            XCTAssertEqual(core.time, model.clocked.clock.time, "seed \(seed)")
            XCTAssertEqual(core.playing, model.clocked.clock.isPlaying, "seed \(seed)")
        }
    }

    func testTheFirstPictureMatchesTheAppsSceneForEveryFamily() async throws {
        let size = CGSize(width: 64, height: 48)
        let time = 5.0
        let scale = UITraitCollection.current.displayScale > 0 ? UITraitCollection.current.displayScale : 2
        for family in 0..<FamilyCatalog.all.count {
            // The adapter in the one app's session.
            let storageRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            let defaults = try XCTUnwrap(UserDefaults(suiteName: "dev.visualcore.ua-f07.parity.\(family)"))
            defer {
                try? FileManager.default.removeItem(at: storageRoot)
                defaults.removePersistentDomain(forName: "dev.visualcore.ua-f07.parity.\(family)")
            }
            let storage = ExperienceStorage(id: id, root: storageRoot, defaults: defaults)
            let id = self.id
            var made: (any Experience)?
            let session = ExperienceSession()
            let opened = await session.open(ExperienceOpenRequest(id: id, seed: 7) {
                let experience = GenerativeArtExperience.make(id: id, storage: storage, reduceMotion: false,
                                                              reduceFlashing: false)
                made = experience
                return experience
            })
            XCTAssertEqual(opened, .running)
            let view = try XCTUnwrap(session.renderHost?.view)
            view.frame = CGRect(origin: .zero, size: size)
            view.layoutIfNeeded()
            let experience = try XCTUnwrap(made)
            for (control, values) in [("family", [Double(family)]), ("pause", []), ("scrub", [time])] {
                XCTAssertTrue(experience.handle(control: control, values: values).isAccepted, control)
            }
            let shell = try XCTUnwrap(experience as? ExperienceShell<GenerativeArtPresenter>)
            let document = try XCTUnwrap(shell.engine.core?.document)
            XCTAssertTrue(session.renderHost?.renderOneFrame(present: false) ?? false)
            let width = Int(size.width * scale), height = Int(size.height * scale)
            let adapted = try session.renderStill(width: width, height: height)
            session.close()

            // The app's own scene for the same composition and time.
            let scene = ArtSceneFactory.makeScene(for: document, bundle: GenerativeArtPresenter.shaders)
            scene.fixedTime = time
            scene.displayScale = scale
            let host = try RenderHost(scene: scene)
            defer { host.destroy() }
            host.view.frame = CGRect(origin: .zero, size: size)
            host.view.layoutIfNeeded()
            XCTAssertTrue(host.renderOneFrame(present: false))
            let original = try host.renderOffscreen(width: width, height: height, time: time)
            XCTAssertNil(scene.errorMessage)

            XCTAssertEqual(original.rgba.count, adapted.rgba.count)
            XCTAssertGreaterThan(Set(original.rgba).count, 8, "family \(family): the picture is not blank")
            let differences = zip(original.rgba, adapted.rgba).map { abs(Int($0) - Int($1)) }
            let within2 = Double(differences.filter { $0 <= 2 }.count) / Double(max(differences.count, 1))
            let mean = Double(differences.reduce(0, +)) / Double(max(differences.count, 1))
            XCTAssertGreaterThanOrEqual(within2, 0.99, "family \(family)")
            XCTAssertLessThanOrEqual(mean, 0.5, "family \(family)")
            print("UA-F07 parity family \(family): within2=\(within2) mean=\(mean) max=\(differences.max() ?? 0)")
        }
    }
}
