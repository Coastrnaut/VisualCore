// ProjectTests — feature 159 (A22-P01) T-A22-105 (FR-A22-101, FR-A22-102; SC-A22-101; clarifications Q2, Q3). The
// limits' constants; a project round-trips byte-identical within 65,536 bytes with sorted keys; one hand-built sample
// per refusal code (damaged, newer-version, too-large, not-finite, out-of-range); the name, limit and texture-input
// bounds at the bound and one past it. Synthetic data only.
import Foundation
import Testing
import VisualCoreParameters
import VisualCoreShaderSource
@testable import ShaderStudioCore

@Suite struct ProjectTests {
    /// A valid uniform.
    private static func uniform(_ name: String = "u_speed") throws -> ParameterDefinition {
        try ParameterDefinition(name: name, title: "Speed", unit: "×", range: 0...4, defaultValue: 1)
    }

    /// A valid project with one uniform and one texture input.
    private static func sample() throws -> ShaderProject {
        try ShaderProject(name: "Gradient / test", source: """
            uniform float u_speed;
            uniform sampler2D u_image;
            void main() { fragColor = vec4(v_uv, 0.5 + 0.5 * sin(u_time * u_speed), 1.0); }
            """, uniforms: [uniform()], limits: .standard, textureInputs: ["u_image"])
    }

    /// The JSON object of the sample's file.
    private static func envelope() throws -> [String: Any] {
        try #require(try JSONSerialization.jsonObject(with: sample().encoded()) as? [String: Any])
    }

    /// A hand-built file with `body`, `kind` and `version`.
    private static func file(_ body: Any, kind: String = ShaderProject.kind, version: Int = 1) throws -> Data {
        let object: [String: Any] = ["body": body, "kind": kind, "version": version]
        return try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
    }

    /// The sample's file with the body's `key` set to `value`.
    private static func file(setting key: String, to value: Any) throws -> Data {
        var body = try #require(envelope()["body"] as? [String: Any])
        body[key] = value
        return try file(body)
    }

    /// The sample's file with the first uniform's `key` set to `value`.
    private static func file(settingUniform key: String, to value: Any) throws -> Data {
        var body = try #require(envelope()["body"] as? [String: Any])
        var uniforms = try #require(body["uniforms"] as? [[String: Any]])
        uniforms[0][key] = value
        body["uniforms"] = uniforms
        return try file(body)
    }

    /// The refusal thrown by decoding `data`, or nil when it decoded.
    private static func refusal(_ data: Data) -> ShaderProjectRefusal? {
        do {
            _ = try ShaderProject.decode(data)
            return nil
        } catch {
            return error
        }
    }

    /// The refusal thrown by `make`, or nil when it succeeded.
    private static func refusal(_ make: () throws(ShaderProjectRefusal) -> ShaderProject) -> ShaderProjectRefusal? {
        do {
            _ = try make()
            return nil
        } catch {
            return error
        }
    }

    @Test func constants() {
        #expect(ShaderLimits.standard == ShaderLimits(maxSourceBytes: 16_384, maxLines: 400, maxUniforms: 16,
                                                      maxTextureInputs: 2))
        #expect(ShaderLimits.hardCeilingBytes == ShaderLibrary.maxExpandedBytes)
        #expect(ShaderLimits.standard.maxSourceBytes < ShaderLimits.hardCeilingBytes)
        #expect(ShaderProject.kind == "a22.shader-project")
        #expect(ShaderProject.schemaVersion == 1)
        #expect(ShaderProject.maxEncodedBytes == 65_536)
    }

    @Test func roundTripIsByteIdentical() throws {
        let project = try Self.sample()
        let data = try project.encoded()
        #expect(data.count <= ShaderProject.maxEncodedBytes)
        let decoded = try ShaderProject.decode(data)
        #expect(decoded == project)
        #expect(try decoded.encoded() == data)
        let text = try #require(String(data: data, encoding: .utf8))
        #expect(text.hasPrefix(#"{"body":{"limits":"#))
        #expect(text.contains(#""kind":"a22.shader-project","version":1}"#))
        #expect(text.contains("Gradient / test"))
    }

    @Test func emptyProjectRoundTrips() throws {
        let project = try ShaderProject(name: "x", source: "")
        let data = try project.encoded()
        #expect(try ShaderProject.decode(data) == project)
        #expect(try ShaderProject.decode(data).encoded() == data)
    }

    @Test func damaged() throws {
        #expect(Self.refusal(Data("not json".utf8)) == .damaged)
        #expect(Self.refusal(try Self.file([:], kind: "a21.preferences")) == .damaged)
        #expect(Self.refusal(try Self.file(try #require(Self.envelope()["body"]), version: 0)) == .damaged)
        #expect(Self.refusal(try Self.file(setting: "source", to: 3)) == .damaged)
        #expect(Self.refusal(try Self.file(setting: "uniforms", to: "none")) == .damaged)
        #expect(ShaderProjectRefusal.damaged.code == "damaged")
    }

    @Test func newerVersion() throws {
        let refusal = Self.refusal(try Self.file(try #require(Self.envelope()["body"]), version: 2))
        #expect(refusal == .newerVersion(2))
        #expect(refusal?.code == "newer-version")
    }

    @Test func tooLarge() throws {
        let atLimit = Data(repeating: 0x20, count: ShaderProject.maxEncodedBytes)
        #expect(Self.refusal(atLimit) == .damaged)
        let past = Data(repeating: 0x20, count: ShaderProject.maxEncodedBytes + 1)
        #expect(Self.refusal(past) == .tooLarge(ShaderProject.maxEncodedBytes + 1))
        #expect(ShaderProjectRefusal.tooLarge(1).code == "too-large")
        let big = try ShaderProject(name: "big", source: String(repeating: "a", count: ShaderProject.maxEncodedBytes))
        #expect(throws: ShaderProjectRefusal.self) { try big.encoded() }
    }

    @Test func notFinite() throws {
        for key in ["defaultValue", "minimum", "maximum"] {
            for text in ["NaN", "Infinity", "-Infinity"] {
                #expect(Self.refusal(try Self.file(settingUniform: key, to: text)) == .notFinite)
            }
        }
        #expect(ShaderProjectRefusal.notFinite.code == "not-finite")
    }

    @Test func outOfRangeUniforms() throws {
        #expect(Self.refusal(try Self.file(settingUniform: "defaultValue", to: 9)) == .outOfRange("uniforms[0]"))
        #expect(Self.refusal(try Self.file(settingUniform: "minimum", to: 5)) == .outOfRange("uniforms[0]"))
        #expect(Self.refusal(try Self.file(settingUniform: "maximum", to: 0)) == .outOfRange("uniforms[0]"))
        #expect(Self.refusal(try Self.file(settingUniform: "name", to: "9bad")) == .outOfRange("uniforms[0]"))
        #expect(ShaderProjectRefusal.outOfRange("x").code == "out-of-range")
    }

    @Test func outOfRangeFields() throws {
        #expect(Self.refusal(try Self.file(setting: "name", to: "")) == .outOfRange("name"))
        #expect(Self.refusal(try Self.file(setting: "textureInputs", to: ["a", "b", "c"]))
                == .outOfRange("textureInputs"))
        let limits: [String: Any] = ["maxLines": 400, "maxSourceBytes": 16_385, "maxTextureInputs": 2,
                                     "maxUniforms": 16]
        #expect(Self.refusal(try Self.file(setting: "limits", to: limits)) == .outOfRange("limits"))
    }

    @Test func nameBounds() {
        #expect(Self.refusal { () throws(ShaderProjectRefusal) in
            try ShaderProject(name: String(repeating: "n", count: 40), source: "") } == nil)
        #expect(Self.refusal { () throws(ShaderProjectRefusal) in
            try ShaderProject(name: String(repeating: "n", count: 41), source: "") } == .outOfRange("name"))
        #expect(Self.refusal { () throws(ShaderProjectRefusal) in
            try ShaderProject(name: "n", source: "") } == nil)
        #expect(Self.refusal { () throws(ShaderProjectRefusal) in
            try ShaderProject(name: "", source: "") } == .outOfRange("name"))
    }

    @Test func limitBounds() {
        let s = ShaderLimits.standard
        let atStandard = [s,
                          ShaderLimits(maxSourceBytes: 1, maxLines: 1, maxUniforms: 0, maxTextureInputs: 0)]
        for limits in atStandard {
            #expect(Self.refusal { () throws(ShaderProjectRefusal) in
                try ShaderProject(name: "p", source: "", limits: limits) } == nil)
        }
        let past = [
            ShaderLimits(maxSourceBytes: s.maxSourceBytes + 1, maxLines: 400, maxUniforms: 16, maxTextureInputs: 2),
            ShaderLimits(maxSourceBytes: 16_384, maxLines: s.maxLines + 1, maxUniforms: 16, maxTextureInputs: 2),
            ShaderLimits(maxSourceBytes: 16_384, maxLines: 400, maxUniforms: s.maxUniforms + 1, maxTextureInputs: 2),
            ShaderLimits(maxSourceBytes: 16_384, maxLines: 400, maxUniforms: 16,
                         maxTextureInputs: s.maxTextureInputs + 1),
            ShaderLimits(maxSourceBytes: ShaderLimits.hardCeilingBytes + 1, maxLines: 400, maxUniforms: 16,
                         maxTextureInputs: 2),
            ShaderLimits(maxSourceBytes: 0, maxLines: 400, maxUniforms: 16, maxTextureInputs: 2),
            ShaderLimits(maxSourceBytes: 16_384, maxLines: 0, maxUniforms: 16, maxTextureInputs: 2),
            ShaderLimits(maxSourceBytes: 16_384, maxLines: 400, maxUniforms: -1, maxTextureInputs: 2),
            ShaderLimits(maxSourceBytes: 16_384, maxLines: 400, maxUniforms: 16, maxTextureInputs: -1)]
        for limits in past {
            #expect(Self.refusal { () throws(ShaderProjectRefusal) in
                try ShaderProject(name: "p", source: "", limits: limits) } == .outOfRange("limits"))
        }
    }

    @Test func textureInputBounds() {
        #expect(Self.refusal { () throws(ShaderProjectRefusal) in
            try ShaderProject(name: "p", source: "", textureInputs: ["u_a", "u_b"]) } == nil)
        #expect(Self.refusal { () throws(ShaderProjectRefusal) in
            try ShaderProject(name: "p", source: "", textureInputs: ["u_a", "u_b", "u_c"]) }
                == .outOfRange("textureInputs"))
        for bad in ["", "1abc", "a-b", "gl_Image", String(repeating: "a", count: 33)] {
            #expect(Self.refusal { () throws(ShaderProjectRefusal) in
                try ShaderProject(name: "p", source: "", textureInputs: [bad]) } == .outOfRange("textureInputs"))
        }
        #expect(Self.refusal { () throws(ShaderProjectRefusal) in
            try ShaderProject(name: "p", source: "", textureInputs: [String(repeating: "a", count: 32)]) } == nil)
    }
}
