// Scaffold check (feature 002 T-F104): every pure module links and reports its version.
import Testing
import VisualCoreAudioDSP
import VisualCoreDiagnostics
import VisualCoreEffectsGraph
import VisualCoreMath
import VisualCorePersistence
import VisualCoreScenes
import VisualCoreShaderSource
import VisualCoreSimulation
import VisualCoreTestSupport

@Test func everyPureModuleStartsAtZeroDotOne() {
    let versions = [MathInfo.version, SimulationInfo.version, ScenesInfo.version, ShaderSourceInfo.version,
                    EffectsGraphInfo.version, DiagnosticsInfo.version, AudioDSPInfo.version,
                    PersistenceInfo.version, TestSupportInfo.version]
    #expect(versions.allSatisfy { $0 == "0.1.0" })
}
