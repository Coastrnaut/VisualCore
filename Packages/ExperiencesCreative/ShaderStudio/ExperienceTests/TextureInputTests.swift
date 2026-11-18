// TextureInputTests — feature 161 (A22-P03) T-A22-309 (FR-A22-304, FR-A22-305; SC-A22-303, SC-A22-304; US4 AC1, AC2;
// US3 AC4; clarifications Q4, Q5; contract gap G-TEXTURES). Through the one app's session host, drawn off screen at
// frame time 0: the three texture choices give three pairwise different `texture-mix` pictures; each generated input
// is a 64 × 64 `.rgba8` target holding its recipe's bytes (checksum) and is bound to its sampler in input order; after
// `recreateContext` the textures are made again from code, the picture is the same and nothing leaks; a project
// without texture inputs keeps the A22-P02 scene; an A22-P02 snapshot without `textures` restores as [0, 1]; a
// snapshot round trip keeps the values and textures; an input index past the template's inputs is refused. Short
// runs only.
import Foundation
import Testing
import ShaderStudioCore
@testable import ShaderStudioExperience
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreRendering

@MainActor
@Suite(.serialized) struct TextureInputTests {
    /// The index of `texture-mix` in `ShaderTemplates.all`.
    static var mix: Int { ShaderTemplates.ids.firstIndex(of: "texture-mix") ?? 3 }

    /// Opens the studio on `texture-mix` (selected and run).
    static func openMix(_ session: ExperienceSession) async throws -> ExperienceShell<StudioPresenter> {
        let shell = try await StudioTest.open(session)
        StudioTest.accept(shell, "template.select", [Double(mix)])
        try StudioTest.draw(session)
        #expect(shell.presenter.pipeline.status == .compiled([]))
        #expect(shell.presenter.pipeline.live is TexturedPreview)
        return shell
    }

    @Test func theThreeChoicesGiveThreeDifferentPictures() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Self.openMix(session)
        let presenter = shell.presenter
        let compiles = presenter.pipeline.compileCount
        var stills: [[UInt8]] = []
        for recipe in TextureRecipes.all {
            StudioTest.accept(shell, "texture.set", [0, Double(recipe.rawValue)])
            stills.append(try StudioTest.still(session))
        }
        #expect(StudioTest.differs(stills[0], stills[1]) && StudioTest.differs(stills[1], stills[2])
                && StudioTest.differs(stills[0], stills[2]), "three pairwise different pictures")
        #expect(stills.allSatisfy { still in still.enumerated().contains { $0.offset % 4 != 3 && $0.element > 0 } },
                "the textures are sampled (not black)")
        #expect(presenter.pipeline.compileCount == compiles, "a texture choice compiles nothing")
        #expect(presenter.mirror.textures == [2, 1])
        #expect(StudioControls.labels(presenter.mirror).filter { $0.name.hasPrefix("texture-") }.map(\.value)
                == ["Noise", "Ramp"])
        #expect(presenter.setTexture(1, recipe: 0) == .accepted)
        #expect(try StudioTest.core(shell).textures == [2, 0])
    }

    @Test func eachInputHasItsSizeAndChecksumAndIsBoundToItsUnit() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Self.openMix(session)
        StudioTest.accept(shell, "texture.set", [0, 2])
        StudioTest.accept(shell, "texture.set", [1, 0])
        var runs: [FieldPass.Run] = []
        FieldPass.runObserver = { runs.append($0) }
        defer { FieldPass.runObserver = nil }
        try StudioTest.draw(session)
        let textured = try #require(shell.presenter.pipeline.live as? TexturedPreview)
        let targets = textured.targets
        #expect(targets.count == 3)
        for (target, recipe) in zip(targets, TextureRecipes.all) {
            #expect(target.width == TextureRecipes.size && target.height == TextureRecipes.size
                    && target.format == .rgba8, "\(recipe)")
            let bytes = target.readFloatPixels().map { UInt8(min(max(($0 * 255).rounded(), 0), 255)) }
            let checksum = String(TextureRecipes.checksum(recipe), radix: 16)
            #expect(bytes == TextureRecipes.bytes(recipe), "\(recipe) holds its recipe (checksum \(checksum))")
        }
        let run = try #require(runs.last)
        #expect(textured.pass?.inputs == ["u_texture0", "u_texture1"], "units 0 and 1 in input order")
        #expect(run.inputs == ["u_texture0": targets[2].colorTexture, "u_texture1": targets[0].colorTexture])
        #expect(run.outputIsFramebuffer)
        #expect(TexturedPreview.bindings(inputs: ["a"], choices: [], targets: targets)["a"] === targets[0],
                "an input without a choice samples the checker")
        let host = try #require(session.renderHost)
        #expect(host.resources.stats.totalBytes <= host.resources.budget.total, "within the budget")
    }

    @Test func aContextLossRebuildsTheTexturesAndThePicture() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Self.openMix(session)
        let presenter = shell.presenter
        StudioTest.accept(shell, "texture.set", [1, 2])
        let before = try StudioTest.still(session)
        let compiles = presenter.pipeline.compileCount
        let host = try #require(session.renderHost)
        host.recreateContext()
        try StudioTest.draw(session)
        let textured = try #require(presenter.pipeline.live as? TexturedPreview)
        #expect(textured.targets.count == 3 && textured.targets.allSatisfy { $0.handle.generation == host.resources.generation })
        #expect(try StudioTest.still(session) == before, "the same picture after the context loss")
        #expect(presenter.pipeline.compileCount == compiles)
        #expect(host.resources.stats.leaked == 0)

        StudioTest.accept(shell, "template.select", [0])
        try StudioTest.draw(session)
        #expect(presenter.pipeline.live is FullScreenShaderScene, "a project without inputs keeps the A22-P02 scene")
        #expect(presenter.mirror.textureInputs.isEmpty)
        #expect(host.resources.stats.leaked == 0)
    }

    @Test func snapshotsKeepTheTexturesAndOldOnesReadTheDefault() throws {
        let zeros = Array(repeating: "0", count: 15).joined(separator: ",")
        let old = #"{"runs":3,"template":3,"values":[0.25,\#(zeros)]}"#
        let restored = try StudioCore.restore(payload: Data(old.utf8), seed: 1)
        #expect(restored.textures == [0, 1] && restored.template == 3 && restored.runs == 3)
        #expect(restored.values[0] == 0.25)

        var core = StudioCore()
        for (control, values) in [("template.select", [Double(Self.mix)]), ("uniform.set", [0, 0.8]),
                                  ("texture.set", [0, 2]), ("texture.set", [1, 2])] {
            #expect(core.apply(ExperienceAction(control: control, values: values, step: 0)) == .accepted)
        }
        let payload = try core.snapshotPayload()
        #expect(String(decoding: payload, as: UTF8.self).contains(#""textures":[2,2]"#))
        let back = try StudioCore.restore(payload: payload, seed: 1)
        #expect(back == core && back.textures == [2, 2] && back.values[0] == 0.8)
        #expect(try studioDigest(back) == studioDigest(core))
    }

    @Test func anInputPastTheTemplatesInputsIsRefused() async throws {
        let shell = try await StudioTest.shell()
        let before = try StudioTest.core(shell)
        for (values, code) in [([0, 1], "action.rule.a22.no-texture"), ([2, 0], "action.out-of-range"),
                               ([0, 3], "action.out-of-range"), ([0.5, 0], "action.rule.a22.not-whole")] {
            #expect(shell.handle(control: "texture.set", values: values).code == code, "\(values)")
        }
        #expect(try StudioTest.core(shell) == before, "Gradient has no texture input; nothing changed")
        StudioTest.accept(shell, "template.select", [Double(Self.mix)])
        StudioTest.accept(shell, "texture.set", [1, 2])
        #expect(shell.handle(control: "texture.set", values: [1, 1.5]).code == "action.rule.a22.not-whole")
        #expect(try StudioTest.core(shell).textures == [0, 2])
    }
}
