// ShaderHashTests — feature 203 T-R02F03-011 (FR-R02F03-040, SC-R02F03-005): golden values for the CPU twin of
// vc/hash.glsl. The goldens were computed independently in Python (no numpy) straight from the GLSL formulas:
// uint32 arithmetic masked with 0xFFFFFFFF; floatBitsToUint via struct.pack('<f'); float(uint) rounded to the
// nearest float32 (ties to even) with struct.pack('<f')/unpack, then divided by 4294967296 (exact, a power of two).
// Float goldens are pinned by their IEEE-754 bit patterns, so the comparison is exact.
import Testing
import VisualCoreMath

@Suite struct ShaderHashTests {
    @Test func pcgGoldens() {
        #expect(ShaderHash.pcg(0) == 129_708_002)
        #expect(ShaderHash.pcg(1) == 2_831_084_092)
        #expect(ShaderHash.pcg(12345) == 4_099_845_390)
        #expect(ShaderHash.pcg(UInt32.max) == 3_861_530_882)
    }

    @Test func hash11Goldens() {
        #expect(ShaderHash.hash11(0.0).bitPattern == 0x3CF7_65FC)    // 0.030199997
        #expect(ShaderHash.hash11(0.5).bitPattern == 0x3E76_BD06)    // 0.24095544
        #expect(ShaderHash.hash11(-1.25).bitPattern == 0x3F7E_7CF4)  // 0.99409413
        #expect(ShaderHash.hash11(1.0).bitPattern == 0x3F71_BB4A)    // 0.94426405
    }

    @Test func hash21Goldens() {
        #expect(ShaderHash.hash21(3.0, 7.5).bitPattern == 0x3DF5_1989)   // 0.11967761
        #expect(ShaderHash.hash21(0.0, 0.0).bitPattern == 0x3E42_F80D)   // 0.19039936
        #expect(ShaderHash.hash21(-1.25, 0.5).bitPattern == 0x3EA9_D641) // 0.33171275
    }

    @Test func hash22Goldens() {
        let a = ShaderHash.hash22(3.0, 7.5), b = ShaderHash.hash22(0.0, 0.0), c = ShaderHash.hash22(-1.25, 0.5)
        #expect(a.0.bitPattern == 0x3DF5_1989 && a.1.bitPattern == 0x3EFE_3185)
        #expect(b.0.bitPattern == 0x3E42_F80D && b.1.bitPattern == 0x3EFF_BB69)
        #expect(c.0.bitPattern == 0x3EA9_D641 && c.1.bitPattern == 0x3D41_1A0A)
        #expect(a.0 == ShaderHash.hash21(3.0, 7.5), "the first component is hash21")
    }

    @Test func floatInputsAreTakenByBitPattern() {
        // 0.0 and -0.0 are equal floats with different bit patterns, so the shader hashes them differently.
        #expect(ShaderHash.hash11(0.0) != ShaderHash.hash11(-0.0))
        #expect(ShaderHash.hash11(-0.0) == Float(ShaderHash.pcg(0x8000_0000)) / 4_294_967_296.0)
    }
}
