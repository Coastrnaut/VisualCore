// RendererRecordTests — feature 202 (R02-F02) T-R02F02-008 (FR-R02F02-006, FR-R02F02-007; data-model.md): the
// renderer record round-trips with snake_case keys, ignores unknown keys, and an evidence environment with or without
// `renderer` decodes.
import Foundation
import Testing
import VisualCoreExperience

@Suite struct RendererRecordTests {
    /// A record with every field set.
    private static let full = RendererRecord(
        glVersion: "OpenGL ES 3.0 (ANGLE)", glslVersion: "OpenGL ES GLSL ES 3.00", renderer: "ANGLE (Metal)",
        vendor: "Google Inc.", eglVersion: "1.5 (ANGLE)", maxTextureSize: 16384, maxSamples: 4, maxDrawBuffers: 8,
        maxColorAttachments: 8, missingEntryPoints: 0, generation: 2, floorFindings: ["max_samples 2 < 4"])

    /// The JSON object of an encodable value.
    private static func object<T: Encodable>(_ value: T) throws -> [String: Any] {
        let data = try JSONEncoder().encode(value)
        return try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    @Test func roundTripsWithEveryField() throws {
        let data = try JSONEncoder().encode(Self.full)
        #expect(try JSONDecoder().decode(RendererRecord.self, from: data) == Self.full)
    }

    @Test func keysAreSnakeCase() throws {
        let keys = Set(try Self.object(Self.full).keys)
        #expect(keys == [
            "gl_version", "glsl_version", "renderer", "vendor", "egl_version", "max_texture_size", "max_samples",
            "max_draw_buffers", "max_color_attachments", "missing_entry_points", "generation", "floor_findings",
        ])
    }

    @Test func unknownKeysInsideTheRendererAreIgnored() throws {
        let json = #"{"gl_version": "OpenGL ES 3.0", "max_samples": 4, "future_field": {"x": 1}}"#
        let record = try JSONDecoder().decode(RendererRecord.self, from: Data(json.utf8))
        #expect(record == RendererRecord(glVersion: "OpenGL ES 3.0", maxSamples: 4))
    }

    @Test func anEnvironmentWithoutRendererDecodesWithNil() throws {
        let json = #"{"kind": "simulator", "os_version": "27.2", "os_build": null, "device_type": null, "xcode": null, "swift": null, "sdk": null, "host_os": null, "signing": "none"}"#
        let environment = try JSONDecoder().decode(EvidenceRecord.Environment.self, from: Data(json.utf8))
        #expect(environment.renderer == nil)
        #expect(environment.osVersion == "27.2")
        #expect(try Self.object(environment)["renderer"] == nil)
    }

    @Test func anEnvironmentWithRendererRoundTrips() throws {
        let environment = EvidenceRecord.Environment(kind: "simulator", osVersion: "27.2", renderer: Self.full)
        let data = try JSONEncoder().encode(environment)
        #expect(try JSONDecoder().decode(EvidenceRecord.Environment.self, from: data) == environment)
        let renderer = try #require(try Self.object(environment)["renderer"] as? [String: Any])
        #expect(renderer["max_texture_size"] as? Int == 16384)
    }
}
