// RenderCapabilitiesProbeTests — feature 202 (R02-F02) T-R02F02-002 and T-R02F02-005 (FR-R02F02-001 to 005, 007;
// SC-R02F02-001 to 003). The simulator's values are context only (constitution V); device values come from the device
// campaign. The tests check the OpenGL ES 3.0 floors and the shape of the report, never simulator-specific numbers.
import Foundation
import XCTest
@testable import VisualCoreRendering

@MainActor
final class RenderCapabilitiesProbeTests: XCTestCase {
    func testAFreshHostReportsEveryProbedValueAtOrAboveTheFloors() throws {
        let host = try RenderHost(scene: ClearColorScene(red: 0, green: 0, blue: 0))
        defer { host.destroy() }
        let caps = host.capabilities
        for (name, value) in [("maxSamples", caps.maxSamples), ("maxDrawBuffers", caps.maxDrawBuffers),
                              ("maxColorAttachments", caps.maxColorAttachments), ("maxVertexAttribs", caps.maxVertexAttribs),
                              ("maxVertexUniformVectors", caps.maxVertexUniformVectors),
                              ("maxFragmentUniformVectors", caps.maxFragmentUniformVectors),
                              ("maxTextureImageUnits", caps.maxTextureImageUnits), ("maxVaryingVectors", caps.maxVaryingVectors),
                              ("missingEntryPoints", caps.missingEntryPoints), ("generation", caps.generation)] {
            XCTAssertNotNil(value, name)
        }
        XCTAssertNotNil(caps.vertexHighp)
        XCTAssertNotNil(caps.vertexMediump)
        XCTAssertNotNil(caps.fragmentHighInt)
        XCTAssertFalse(caps.eglVersion?.isEmpty ?? true)
        XCTAssertNotNil(caps.eglExtensions)
        XCTAssertEqual(caps.missingEntryPoints, 0)
        XCTAssertEqual(caps.generation, host.generation)
        XCTAssertEqual(caps.floorFindings(), [], "simulator context only")
        print("capabilities (simulator context only): samples \(caps.maxSamples ?? -1), draw buffers \(caps.maxDrawBuffers ?? -1)")
    }

    func testTheFloorCheckListsAValueBelowItsMinimumAndSkipsAbsentValues() {
        var caps = RenderCapabilities()
        caps.maxTextureSize = 4096
        caps.maxRenderbufferSize = 4096
        XCTAssertEqual(caps.floorFindings(), [], "absent values are not findings")
        caps.maxDrawBuffers = 2
        caps.maxSamples = 4
        XCTAssertEqual(caps.floorFindings(), [FloorFinding(name: "maxDrawBuffers", minimum: 4, reported: 2)])
        caps.maxTextureSize = 1024
        XCTAssertEqual(caps.floorFindings().map(\.name), ["maxTextureSize", "maxDrawBuffers"])
    }

    func testAFailedQueryGivesNoValue() {
        XCTAssertNil(RenderCapabilities.limit { _ in (value: 7, failed: true) })
        XCTAssertEqual(RenderCapabilities.limit { _ in (value: 7, failed: false) }, 7)
    }

    func testTheReportFollowsEveryContextRecreation() throws {
        let host = try RenderHost(scene: ClearColorScene(red: 0, green: 0, blue: 0))
        defer { host.destroy() }
        XCTAssertEqual(host.capabilities.generation, 1)
        for expected in 2...4 {
            host.recreateContext()
            XCTAssertEqual(host.generation, expected)
            XCTAssertEqual(host.capabilities.generation, expected)
            XCTAssertEqual(host.capabilities.missingEntryPoints, 0)
            XCTAssertNotNil(host.capabilities.maxDrawBuffers)
        }
    }

    func testAReportFromBeforeThisFeatureDecodesWithTheNewValuesAbsent() throws {
        let old = #"{"glVersion":"OpenGL ES 3.0","glslVersion":"","renderer":"","vendor":"","eglVendor":"","extensions":[],"maxTextureSize":4096,"maxViewport":{"width":4096,"height":4096},"maxRenderbufferSize":4096}"#
        let caps = try JSONDecoder().decode(RenderCapabilities.self, from: Data(old.utf8))
        XCTAssertNil(caps.maxSamples)
        XCTAssertNil(caps.generation)
        XCTAssertNil(caps.eglExtensions)
        XCTAssertEqual(caps.maxTextureSize, 4096)
    }
}
