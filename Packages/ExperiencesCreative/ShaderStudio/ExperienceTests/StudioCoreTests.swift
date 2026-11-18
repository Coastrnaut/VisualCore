// StudioCoreTests — feature 160 (A22-P02) T-A22-205 (FR-A22-201, FR-A22-205; SC-A22-204; clarification Q1;
// data-model.md "StudioCore"). The adapter core `StudioCore`: the three actions with their ranges; a template resets
// the values to its defaults and counts a run; a uniform index that is fractional or past the template's uniform
// count is refused (`a22.not-whole`, `a22.no-uniform`) with the state unchanged; the digest covers the template and
// the values, not the run count; the snapshot round trip and the restore refusals; one quality tier `level-0`. Then
// every template drawn in the session host off screen with the status Compiled. Short runs only.
import Foundation
import Testing
import ShaderStudioCore
@testable import ShaderStudioExperience
import VisualCoreExperience
import VisualCoreExperienceHost

@MainActor
@Suite(.serialized) struct StudioCoreTests {
    @Test func theThreeControlsAreDeclaredWithTheirRanges() {
        #expect(StudioCore.experienceID == "a22.shader-studio")
        #expect(ShaderStudioExperience.id?.rawValue == "a22.shader-studio")
        #expect(StudioCore.controls.map(\.id) == StudioCore.actionIDs)
        let ranges = Dictionary(uniqueKeysWithValues: StudioCore.controls.map { ($0.id, $0.ranges) })
        #expect(ranges["template.select"] == [0...3])
        #expect(ranges["uniform.set"] == [0...15, 0...1])
        #expect(ranges["shader.run"] == [1...1])
        #expect(StudioCore.qualityTiers == 1 && StudioCore.qualityProfile.names == ["level-0"])
        #expect(StudioCore.migrations.currentVersion == 1)
        let core = StudioCore()
        #expect(core.template == 0 && core.runs == 0 && core.values.count == 16)
        #expect(core.outcome?.code == "template-gradient")
        let speed = ShaderTemplates.all[0].uniforms[0]
        #expect(core.values[0] == speed.normalized(speed.defaultValue))
        #expect(core.values.dropFirst().allSatisfy { $0 == 0 })
    }

    @Test func aTemplateResetsTheValuesAndCountsARun() throws {
        for (index, template) in ShaderTemplates.all.enumerated() {
            let (moved, _) = studioApplied(StudioCore(), "uniform.set", [0, 0.9])
            let (next, result) = studioApplied(moved, "template.select", [Double(index)])
            #expect(result == .accepted)
            #expect(next.template == index && next.runs == 1)
            #expect(next.outcome?.code == "template-" + template.id)
            for (k, definition) in template.uniforms.enumerated() {
                #expect(next.values[k] == definition.normalized(definition.defaultValue), "\(template.id) \(k)")
            }
            #expect(next.values.dropFirst(template.uniforms.count).allSatisfy { $0 == 0 })
        }
        let (ran, result) = studioApplied(StudioCore(), "shader.run", [1])
        #expect(result == .accepted && ran.runs == 1 && ran.values == StudioCore().values)
    }

    @Test func uniformsAreSetWithinTheTemplatesCount() {
        let (rings, _) = studioApplied(StudioCore(), "template.select", [2])
        for value in [0.0, 0.4, 1.0] {
            let (next, result) = studioApplied(rings, "uniform.set", [1, value])
            #expect(result == .accepted && next.values[1] == value && next.runs == rings.runs)
        }
        let cases: [(core: StudioCore, values: [Double], code: String)] = [
            (StudioCore(), [1, 0.5], "action.rule.a22.no-uniform"),
            (StudioCore(), [15, 0.5], "action.rule.a22.no-uniform"),
            (rings, [2, 0.5], "action.rule.a22.no-uniform"),
            (StudioCore(), [0.5, 0.5], "action.rule.a22.not-whole"),
            (StudioCore(), [16, 0.5], "action.out-of-range"),
            (StudioCore(), [0, 1.01], "action.out-of-range"),
            (StudioCore(), [0, -0.01], "action.out-of-range"),
            (StudioCore(), [0, .nan], "action.non-finite"),
            (StudioCore(), [0], "action.wrong-value-count"),
        ]
        for item in cases {
            let (next, result) = studioApplied(item.core, "uniform.set", item.values)
            #expect(result.code == item.code, "\(item.values)")
            #expect(next == item.core, "\(item.values) changes nothing")
        }
        for values: [Double] in [[Double(ShaderTemplates.all.count)], [-1], [1.5]] {
            let (next, result) = studioApplied(StudioCore(), "template.select", values)
            #expect(!result.isAccepted && next == StudioCore(), "\(values)")
        }
        let (next, result) = studioApplied(StudioCore(), "shader.run", [0])
        #expect(result.code == "action.out-of-range" && next == StudioCore())
    }

    @Test func theEngineRefusesTheSameAndKeepsTheDigest() async throws {
        let shell = try await StudioTest.shell()
        StudioTest.accept(shell, "template.select", [1])
        let before = try StudioTest.core(shell)
        let digest = try shell.engine.digest()
        for (control, values) in [("uniform.set", [2.0, 0.5]), ("uniform.set", [0.5, 0.5]),
                                  ("template.select", [1.5]), ("shader.run", [2.0])] {
            #expect(!shell.handle(control: control, values: values).isAccepted, "\(control) \(values)")
        }
        #expect(try StudioTest.core(shell) == before)
        #expect(try shell.engine.digest() == digest)
    }

    @Test func theDigestIgnoresTheRunCount() throws {
        let (ran, _) = studioApplied(StudioCore(), "shader.run", [1])
        #expect(ran.runs == 1)
        #expect(try studioDigest(ran) == studioDigest(StudioCore()))
        let (moved, _) = studioApplied(StudioCore(), "uniform.set", [0, 0.3])
        #expect(try studioDigest(moved) != studioDigest(StudioCore()))
        let (noise, _) = studioApplied(StudioCore(), "template.select", [1])
        #expect(try studioDigest(noise) != studioDigest(StudioCore()))
    }

    @Test func theSnapshotRoundTripsAndDamageIsRefused() throws {
        var core = StudioCore()
        _ = core.apply(ExperienceAction(control: "template.select", values: [2], step: 0))
        _ = core.apply(ExperienceAction(control: "uniform.set", values: [1, 0.25], step: 0))
        _ = core.apply(ExperienceAction(control: "shader.run", values: [1], step: 0))
        let payload = try core.snapshotPayload()
        let restored = try StudioCore.restore(payload: payload, seed: 9)
        #expect(restored == core && restored.runs == 2)
        #expect(try restored.snapshotPayload() == payload)
        let zeros = Array(repeating: "0", count: 16).joined(separator: ",")
        let refused: [(String, StudioRestoreRefusal)] = [
            ("not json", .damaged),
            (#"{"runs":0,"template":0}"#, .damaged),
            (#"{"runs":0,"template":"a","values":[\#(zeros)]}"#, .damaged),
            (#"{"runs":0,"template":4,"values":[\#(zeros)]}"#, .outOfRange("template")),
            (#"{"runs":0,"template":0,"values":[0]}"#, .outOfRange("values")),
            (#"{"runs":0,"template":0,"values":[2,\#(Array(repeating: "0", count: 15).joined(separator: ","))]}"#,
             .outOfRange("values")),
            (#"{"runs":0,"template":0,"values":[0,0.5,\#(Array(repeating: "0", count: 14).joined(separator: ","))]}"#,
             .outOfRange("values")),
            (#"{"runs":-1,"template":0,"values":[\#(zeros)]}"#, .outOfRange("runs")),
        ]
        for (text, refusal) in refused {
            #expect(throws: refusal, "\(text)") { _ = try StudioCore.restore(payload: Data(text.utf8), seed: 1) }
        }
    }

    @Test func everyTemplateDrawsWithTheStatusCompiled() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await StudioTest.open(session)
        let presenter = shell.presenter
        #expect(presenter.pipeline.status == .compiled([]) && presenter.mirror.status == "Compiled")
        #expect(presenter.maxFramesPerSecond == 30 && shell.maxFramesPerSecond == 30)
        #expect(presenter.describe(try StudioTest.core(shell)) == "Shader Studio, Gradient, Compiled")
        var stills: [[UInt8]] = [try StudioTest.still(session)]
        for (index, template) in ShaderTemplates.all.enumerated().dropFirst() {
            StudioTest.accept(shell, "template.select", [Double(index)])
            try StudioTest.draw(session)
            #expect(presenter.pipeline.status == .compiled([]), "\(template.id)")
            #expect(presenter.pipeline.liveProject == template.project, "\(template.id)")
            #expect(presenter.mirror.uniforms == template.uniforms)
            stills.append(try StudioTest.still(session))
        }
        #expect(StudioTest.differs(stills[0], stills[1]) && StudioTest.differs(stills[1], stills[2]))
        for still in stills {
            #expect(!(still[0] == 26 && still[1] == 26 && still[2] == 26), "not the grey of a failed scene")
        }
        let host = try #require(session.renderHost)
        #expect(host.resources.stats.leaked == 0)
    }
}
