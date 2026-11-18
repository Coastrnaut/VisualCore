// ShapeTests — feature 163 (A22-P05) T-A22-507 (FR-A22-503, FR-A22-504; US3 AC1, AC2; clarification Q2;
// contracts/recovery.md "Shape"). The document's shape in the core and the presenter: a project with more uniforms and
// texture inputs than its template opens with every value and texture choice, and each can then be changed; an
// A22-P04 snapshot without `shape` reads the template's counts; a shape change keeps values by position; out-of-range
// and fractional shapes are refused; the presenter's shape follows edits, opens and template choices without
// compiling; a library reopened from a new `ExperienceStorage` on the same root lists and opens the project. Short
// runs only.
import Foundation
import Testing
import ShaderStudioCore
@testable import ShaderStudioExperience
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreParameters

@MainActor
@Suite(.serialized) struct ShapeTests {
    /// A project of three uniforms and one texture input: more than any template's uniforms with an input.
    static func wideProject() throws -> ShaderProject {
        let uniforms = try ["u_speed", "u_a", "u_b"].map {
            try ParameterDefinition(name: $0, title: $0, range: 0...1, defaultValue: 0.5)
        }
        let source = """
        uniform float u_speed;
        uniform float u_a;
        uniform float u_b;
        uniform sampler2D u_tex;
        void main() { fragColor = vec4(texture(u_tex, v_uv).rgb * (u_speed + u_a + u_b) / 3.0, 1.0); }

        """
        return try ShaderProject(name: "Wide", source: source, uniforms: uniforms, textureInputs: ["u_tex"])
    }

    /// The values saved with the wide project.
    static let values: [Double] = [0.1, 0.6, 0.9] + Array(repeating: 0, count: 13)

    /// `core` after each action in order, each required to give `expected`.
    static func applying(_ core: StudioCore, _ actions: [(String, [Double], String)],
                         sourceLocation: SourceLocation = #_sourceLocation) -> StudioCore {
        var next = core
        for (control, values, expected) in actions {
            let result = next.apply(ExperienceAction(control: control, values: values, step: 0))
            #expect(result.code == expected, "\(control) \(values)", sourceLocation: sourceLocation)
        }
        return next
    }

    @Test func aWiderProjectOpensWithEveryValueAndEachCanChange() async throws {
        let place = try StudioStoragePlace("shape-wide")
        defer { place.remove() }
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await PresenterLibraryTests.open(session, storage: place.storage)
        let presenter = shell.presenter
        let library = try #require(presenter.library)
        let entry = try #require(StudioLibraryTest.saved(library.save(name: "Wide", project: Self.wideProject(),
                                                                       values: Self.values, textures: [2, 1])))
        #expect(try StudioTest.core(shell).shape == [1, 0], "Gradient's shape")
        let compiles = presenter.pipeline.compileCount
        guard case .success = presenter.openProject(entry.file) else {
            Issue.record("not opened")
            return
        }
        let core = try StudioTest.core(shell)
        #expect(core.shape == [3, 1])
        #expect(Array(core.values.prefix(3)) == [0.1, 0.6, 0.9], "every value is kept")
        #expect(core.textures[0] == 2, "the texture choice is kept")
        #expect(presenter.pipeline.compileCount == compiles, "nothing compiles before the frame")
        try StudioTest.draw(session)
        #expect(presenter.mirror.status == "Compiled")
        #expect(StudioInspector.rows(presenter.mirror).map(\.name) == ["u_speed", "u_a", "u_b"])
        #expect(presenter.mirror.textureInputs == ["u_tex"])

        #expect(presenter.setUniform(2, normalized: 0.3) == .accepted)
        #expect(presenter.setTexture(0, recipe: 1) == .accepted)
        #expect(presenter.setTexture(1, recipe: 1)?.code == "action.rule." + StudioRule.noTexture)
        #expect(presenter.setUniform(3, value: 0.3) == nil, "not a live uniform")
        #expect(presenter.setUniform(3, normalized: 0.3)?.code == "action.rule." + StudioRule.noUniform)
        #expect(shell.handle(control: "uniform.set", values: [3, 0.3]).code == "action.rule." + StudioRule.noUniform)
        let changed = try StudioTest.core(shell)
        #expect(changed.values[2] == 0.3 && changed.textures[0] == 1)
        #expect(presenter.resetUniforms().count == 3)
    }

    @Test func theShapeFollowsTheDocumentWithoutCompiling() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await StudioTest.open(session)
        let presenter = shell.presenter
        let compiles = presenter.pipeline.compileCount
        presenter.replaceDocument(try Self.wideProject())
        #expect(try StudioTest.core(shell).shape == [3, 1])
        #expect(presenter.syncShape() == nil, "nothing more to send")
        #expect(presenter.setSource(StudioTest.fixedSource), "an edit keeps the shape")
        #expect(try StudioTest.core(shell).shape == [3, 1])
        try StudioTest.draw(session, frames: 2)
        #expect(try StudioTest.core(shell).shape == [3, 1], "a frame does not undo it")
        #expect(presenter.pipeline.compileCount == compiles)
        StudioTest.accept(shell, "template.select", [2])
        try StudioTest.draw(session)
        #expect(try StudioTest.core(shell).shape == [2, 0], "a template choice sets the template's shape")
        #expect(presenter.documentShape == [2, 0])
        // The shape action itself is not undone at a frame (the scenario runner plays it as a core action).
        StudioTest.accept(shell, "document.shape", [3, 1])
        try StudioTest.draw(session)
        #expect(try StudioTest.core(shell).shape == [3, 1])
    }

    @Test func aSnapshotWithoutShapeReadsTheTemplatesCounts() throws {
        let zeros = Array(repeating: "0", count: 16).joined(separator: ",")
        for index in ShaderTemplates.all.indices {
            let old = #"{"resets":0,"runs":1,"template":\#(index),"textures":[0,1],"values":[\#(zeros)]}"#
            let restored = try StudioCore.restore(payload: Data(old.utf8), seed: 1)
            #expect(restored.shape == StudioCore.templateShape(index), "\(index)")
            #expect(restored.shape == [ShaderTemplates.all[index].uniforms.count,
                                       ShaderTemplates.all[index].textureInputs.count])
        }
        let shaped = Self.applying(StudioCore(), [("document.shape", [5, 2], "accepted"),
                                                  ("uniform.set", [4, 0.4], "accepted")])
        let back = try StudioCore.restore(payload: shaped.snapshotPayload(), seed: 1)
        #expect(back == shaped && back.shape == [5, 2] && back.values[4] == 0.4)
    }

    @Test func aShapeChangeKeepsValuesByPosition() {
        let noUniform = "action.rule." + StudioRule.noUniform
        let core = Self.applying(StudioCore(), [
            ("uniform.set", [2, 0.7], noUniform),
            ("document.shape", [3, 0], "accepted"),
            ("uniform.set", [2, 0.7], "accepted"),
            ("document.shape", [1, 0], "accepted"),
            ("uniform.set", [2, 0.2], noUniform),
        ])
        #expect(core.values[2] == 0.7, "the value past the new count is kept")
        let wider = Self.applying(core, [("document.shape", [3, 0], "accepted")])
        #expect(wider.values[2] == 0.7, "it is back when the count includes it again")
        let textured = Self.applying(StudioCore(), [("texture.set", [0, 2], "action.rule." + StudioRule.noTexture),
                                                    ("document.shape", [1, 1], "accepted"),
                                                    ("texture.set", [0, 2], "accepted"),
                                                    ("document.shape", [1, 0], "accepted")])
        #expect(textured.textures == [2, 1])
    }

    @Test func outOfRangeShapesAreRefused() {
        let outOfRange = "action.out-of-range"
        let notWhole = "action.rule." + StudioRule.notWhole
        let after = Self.applying(StudioCore(), [("document.shape", [17, 0], outOfRange),
                                                 ("document.shape", [0, 3], outOfRange),
                                                 ("document.shape", [-1, 0], outOfRange),
                                                 ("document.shape", [1.5, 0], notWhole),
                                                 ("document.shape", [1, 0.5], notWhole),
                                                 ("document.shape", [1], "action.wrong-value-count"),
                                                 ("document.shape", [0, .nan], "action.non-finite")])
        #expect(after == StudioCore())
    }

    @Test func aLibraryOnANewStorageOfTheSameRootListsAndOpens() throws {
        let place = try StudioStoragePlace("shape-reopen")
        defer { place.remove() }
        let first = ProjectLibrary(storage: place.storage)
        let project = try Self.wideProject()
        let entry = try #require(StudioLibraryTest.saved(first.save(name: "Wide", project: project,
                                                                     values: Self.values, textures: [2, 1])))
        let defaults = try #require(UserDefaults(suiteName: place.suite))
        let again = ProjectLibrary(storage: ExperienceStorage(id: StudioTest.id, root: place.root, defaults: defaults))
        #expect(again.entries.map(\.name) == ["Wide"])
        guard case .success(let opened) = again.open(entry.file) else {
            Issue.record("not opened")
            return
        }
        #expect(opened.project == project && opened.values == Self.values && opened.textures == [2, 1])
    }
}
