// TruthfulLabelTests — feature 107 (A14-P05) T-A14-502 (FR-A14-504; SC-A14-503; clarification Q4). Truthful scale
// labelling over the 216 states of clarification Q4 (first written as 72, an arithmetic slip): 9 bodies × 2 scale modes × 3 tour states (none, "Inner planets"
// and "Giant planets" at their first stop) × 2 play states × 2 stop reason values ("" and "end-of-range"). Each state is
// a schema-4 `SolarState` decoded from its JSON. The core cannot see the experience target, so the description is
// assembled here from core values exactly as `SolarCore.canvasDescription` composes it (the body, date and distance
// sentence ending with `ScaleMode.label`, then the time words, then during a tour the tour words); the same check
// through `SolarCore` itself belongs in an experience test. Every enhanced description says "not to scale"; no
// true-relative description does. Host-free and short.
import Foundation
import SolarSystemExplorerCore
import Testing

@Suite struct TruthfulLabelTests {
    /// The schema-4 state with the given values at J2000.0 and the overview camera, or nil when refused.
    private func state(selection: Int, mode: ScaleMode, tourIndex: Int, playing: Bool, stopReason: String)
        -> SolarState? {
        let json = "{\"dayOffset\":0,\"pitchDegrees\":35,\"playing\":\(playing),\"rateIndex\":0,"
            + "\"scaleMode\":\(mode.rawValue),\"schema\":4,\"selection\":\(selection),\"stopReason\":\"\(stopReason)\","
            + "\"tourIndex\":\(tourIndex),\"tourPaused\":false,\"tourStep\":0,\"tourStop\":0,\"yawSteps\":0,"
            + "\"zoomSteps\":0}"
        switch SolarState.decode(Data(json.utf8)) {
        case .success(let decoded): return decoded
        case .failure: return nil
        }
    }

    /// The canvas description of `state`, assembled from core values as `SolarCore.canvasDescription` does.
    private func describe(_ state: SolarState) -> String {
        let catalog = BodyCatalog.bundled
        let name = catalog.body(at: state.selection)?.name ?? "Unknown body"
        var distance = ""
        if let body = catalog.body(at: state.selection), body.kind == .planet,
           let au = OrbitModel.bundled.distanceAU(bodyID: body.id, day: state.dayOffset),
           let km = OrbitModel.bundled.distanceKm(bodyID: body.id, day: state.dayOffset) {
            distance = ", " + String(format: "%.3f AU", au) + " (\(Units.storedText((km / 1000).rounded() * 1000)) km)"
                + " from the Sun"
        }
        let base = "Solar System Explorer: \(name) in focus on \(state.date.label)\(distance); "
            + "\(SolarState.bodyCount) bodies. \(state.scaleMode.label)."
        let rate = SimClock.rateLabels.indices.contains(state.rateIndex) ? SimClock.rateLabels[state.rateIndex] : ""
        let motion = state.playing ? "time playing at \(rate)" : "time paused"
        let stop = state.stopReason == SimClock.endOfRange ? " \(SimClock.stopSentence)." : ""
        let time = "Date \(state.date.labelWithTime), \(motion).\(stop)"
        var tourWords = ""
        if let tour = state.tour, let caption = state.tourCaption {
            let held = state.tourPaused ? ", paused" : ""
            tourWords = " Tour \(tour.title), stop \(state.tourStop + 1) of \(tour.stops.count)\(held): \(caption)"
        }
        return base + " " + time + tourWords
    }

    @Test func everyEnhancedDescriptionSaysNotToScaleAndNoTrueRelativeOneDoes() throws {
        let tours: [Int] = [-1, 0, 1]
        let plays: [Bool] = [false, true]
        let reasons: [String] = ["", SimClock.endOfRange]
        var count = 0
        var enhancedCount = 0
        for selection in 0..<SolarState.bodyCount {
            for mode in ScaleMode.allCases {
                for tourIndex in tours {
                    for playing in plays {
                        for reason in reasons {
                            let label = "body \(selection), \(mode.name), tour \(tourIndex), playing \(playing), "
                                + "reason \"\(reason)\""
                            let built: SolarState = try #require(state(selection: selection, mode: mode,
                                                                        tourIndex: tourIndex, playing: playing,
                                                                        stopReason: reason), "\(label)")
                            #expect(built.scaleMode == mode && built.tourIndex == tourIndex, "\(label)")
                            let text = describe(built)
                            count += 1
                            if mode == .enhanced {
                                enhancedCount += 1
                                #expect(text.contains("not to scale"), "\(label): \(text)")
                            } else {
                                #expect(!text.contains("not to scale"), "\(label): \(text)")
                            }
                            #expect(text.contains(mode.label + "."), "\(label)")
                            if tourIndex >= 0 { #expect(text.contains(Tour.bundled[tourIndex].stops[0].caption)) }
                        }
                    }
                }
            }
        }
        #expect(count == 216 && enhancedCount == 108)
        #expect(SolarState.bodyCount == 9 && ScaleMode.allCases.count == 2 && Tour.bundled.count == 2)
    }

    @Test func noTourCaptionOrClockWordClaimsAScale() {
        for tour in Tour.bundled {
            for stop in tour.stops { #expect(!stop.caption.contains("scale"), "\(stop.caption)") }
        }
        for words in SimClock.rateLabels + [SimClock.stopSentence] { #expect(!words.contains("scale")) }
        #expect(ScaleMode.enhanced.label.contains("not to scale"))
        #expect(!ScaleMode.trueRelative.label.contains("not to scale"))
    }
}
