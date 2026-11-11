// CapControlTests — feature 029 T-A03-406 (FR-A03-404, SC-A03-401; US1 AC1–AC3).
import Testing
import VisualCoreMath
@testable import FractalExplorerCore

@Suite struct CapControlTests {
    @Test func sliderMapping() {
        #expect(CapControl.cap(position: 0) == 50)
        #expect(CapControl.cap(position: 1) == 10_000)
        #expect(CapControl.cap(position: CapControl.position(cap: 200)) == 200)
        #expect(CapControl.cap(position: -1) == 50)
        #expect(CapControl.cap(position: .nan) == 50)
        var last = 0
        for i in 0...100 { let c = CapControl.cap(position: Double(i) / 100); #expect(c >= last); last = c }
    }

    @Test func halveAndDoubleClamp() {
        #expect(CapControl.doubled(200) == 400)
        #expect(CapControl.halved(200) == 100)
        #expect(CapControl.doubled(8_000) == 10_000)
        #expect(CapControl.halved(60) == 50)
    }

    @Test func costIsRelativeToTheDefaultCap() {
        let pixels = 1_170.0 * 2_532
        #expect(CapControl.costRatio(cap: 200, pixels: pixels) == 1)
        #expect(CapControl.costRatio(cap: 400, pixels: pixels) == 2)
        #expect(CapControl.costText(cap: 200, pixels: pixels) == "Render cost: 1× the default view (light)")
        #expect(CapControl.costText(cap: 1_000, pixels: pixels) == "Render cost: 5× the default view (moderate)")
        #expect(CapControl.costText(cap: 10_000, pixels: pixels) == "Render cost: 50× the default view (heavy); may be slow on this device")
        #expect(CapControl.costText(cap: 50, pixels: 0) == "Render cost: 0.25× the default view (light)")
    }

    @Test func descriptionNamesANonDefaultCap() {
        var s = FractalState(size: Vec2(300, 400))
        #expect(s.spokenDescription == "Mandelbrot set, centered at −0.5 + 0i, zoom 1×")
        s.iterationCap = 800
        #expect(s.spokenDescription == "Mandelbrot set, centered at −0.5 + 0i, zoom 1×, 800 iterations")
    }
}
