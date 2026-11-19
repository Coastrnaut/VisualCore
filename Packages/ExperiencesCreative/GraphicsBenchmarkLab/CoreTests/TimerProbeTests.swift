// TimerProbeTests — feature 175 (A24-P03) T-A24-306 (clarification Q3). The probe's two outcomes: a list holding
// `GL_EXT_disjoint_timer_query` is supported; an empty list, a list without it and a list with only a similar name are
// unsupported with the fixed reason. The outcome round-trips through JSON. Synthetic extension lists only.
import Foundation
import Testing
@testable import GraphicsBenchmarkLabCore

@Suite struct TimerProbeTests {
    @Test func supportedWhenTheExtensionIsListed() {
        let lists: [[String]] = [
            ["GL_EXT_disjoint_timer_query"],
            ["GL_OES_texture_float", "GL_EXT_disjoint_timer_query", "GL_EXT_color_buffer_float"],
        ]
        for list in lists {
            let decision = TimerProbe.decide(extensions: list)
            #expect(decision == .supported)
        }
    }

    @Test func unsupportedOtherwise() {
        let lists: [[String]] = [
            [],
            ["GL_OES_texture_float", "GL_EXT_color_buffer_float"],
            ["GL_EXT_disjoint_timer_query_webgl2", "gl_ext_disjoint_timer_query"],
        ]
        for list in lists {
            let decision = TimerProbe.decide(extensions: list)
            #expect(decision == .unsupported(reason: "GL_EXT_disjoint_timer_query is not offered by this renderer"))
        }
    }

    @Test func extensionNameAndCoding() throws {
        let name = TimerProbe.extensionName
        #expect(name == "GL_EXT_disjoint_timer_query")
        let outcomes: [TimerSupport] = [.supported, .unsupported(reason: TimerProbe.unsupportedReason)]
        for outcome in outcomes {
            let data = try JSONEncoder().encode(outcome)
            let decoded = try JSONDecoder().decode(TimerSupport.self, from: data)
            #expect(decoded == outcome)
        }
    }
}
