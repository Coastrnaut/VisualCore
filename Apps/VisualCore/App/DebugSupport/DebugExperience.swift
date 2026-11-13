// DebugExperience — feature 190 T-U04-005 (FR-U04-043, FR-U04-081; research R3). The experience that exists only
// in builds made for testing: a pure core with one control (`tap`), a counter and a phase, and a presenter that
// draws through the public `ClearColorScene`, so that the app contains no direct graphics call. The whole file
// is inside `#if DEBUG`; a release build contains none of these types.
#if DEBUG
import SwiftUI
import VisualCoreDiagnostics
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCorePersistence
import VisualCoreRendering

/// The core of the debug experience: a start value from the seed, a tap counter and a phase that advances with
/// every step. Two quality tiers; schema version 1.
struct DebugExperienceCore: ExperienceCore, Codable, Equatable {
    /// The largest tap count; a tap beyond it is accepted and changes nothing.
    static let maxCount = 1_000_000
    /// The number of start values a seed can give.
    static let startValues = 1_024

    /// The start value of the phase, 0 ..< `startValues`, derived from the seed.
    private(set) var start: Int
    /// How often the control `tap` was used since the preparation or the last reset.
    private(set) var count: Int
    /// The phase, 0 ..< 1.
    private(set) var phase: Double

    static var migrations: MigrationChain { MigrationChain(currentVersion: 1) }
    static var controls: [ExperienceControl] { [ExperienceControl(id: "tap")] }
    static var qualityTiers: Int { 2 }
    /// Two levels: `full` and `reduced` (the presenter draws them with a different blue).
    static var qualityProfile: QualityProfile {
        let levels = [QualityLevel(name: "full"),
                      QualityLevel(name: "reduced", resolutionShare: 0.75, elementShare: 0.5, iterationShare: 0.5)]
        return (try? QualityProfile(levels: levels)) ?? .uniform(levels: 2)
    }

    /// The state of a fresh preparation with the start value `start`.
    private init(start: Int) {
        self.start = start
        count = 0
        phase = Double(start) / Double(Self.startValues)
    }

    static func prepare(seed: UInt64) async throws -> DebugExperienceCore {
        try Task.checkCancellation()
        return DebugExperienceCore(start: Int(seed % UInt64(startValues)))
    }

    mutating func update(step: Int) {
        phase += Self.stepDuration * 0.25
        if phase >= 1 { phase -= 1 }
    }

    mutating func apply(_ action: ExperienceAction) -> ActionResult {
        guard action.control == "tap" else { return .rejected(.unknownControl(action.control)) }
        guard action.values.isEmpty else {
            return .rejected(.wrongValueCount(expected: 0, found: action.values.count))
        }
        count = min(count + 1, Self.maxCount)
        return .accepted
    }

    mutating func reset() {
        self = DebugExperienceCore(start: start)
    }

    /// `taps-counted` once the control was used three times (feature 195): the outcome the completion scenario
    /// reaches. Derived from the count, never stored.
    var outcome: ExperienceOutcome? {
        count >= DebugExperience.tapsToComplete ? ExperienceOutcome(code: "taps-counted") : nil
    }

    /// The red, green and blue of the state, 0…1, as the presenter draws them.
    func colour(tier: Int) -> (red: Double, green: Double, blue: Double) {
        (phase, Double(count % 8) / 8, tier == 0 ? 0.6 : 0.3)
    }

    func writeDigest(into builder: inout DigestBuilder) throws(DigestError) {
        builder.add(start)
        builder.add(count)
        try builder.add(phase)
    }
}

/// Draws the debug experience: a colour made of the phase, the tap count and the quality tier, with a corner mark in
/// the contrasting grey (so that a frame is never one colour), through a `FullScreenShaderScene` it owns. Its one
/// control is a native button.
@MainActor
final class DebugPresenter: ExperiencePresenter {
    typealias Core = DebugExperienceCore

    /// The id of the experience this presenter belongs to; part of the identifier of its control.
    let experienceID: ExperienceID
    /// What the shell handed over when it opened the experience.
    let launch: ExperienceLaunch
    /// When true the setup throws, so that the session shows its failure view.
    let failsSetup: Bool
    private let scene = FullScreenShaderScene(fragment: DebugExperience.fragment, fragmentName: "debug.frag",
                                              bundle: ShaderBundle(files: [:]))
    /// The quality tier of the last draw; the probes use it.
    private var lastTier = 0

    /// Creates the presenter of the debug experience registered as `experienceID`, opened with `launch`.
    init(experienceID: ExperienceID, launch: ExperienceLaunch, failsSetup: Bool = false) {
        self.experienceID = experienceID
        self.launch = launch
        self.failsSetup = failsSetup
    }

    func setup(_ context: RenderContext) throws {
        if failsSetup { throw DebugExperience.SetupFailure() }
        // One value through the experience's own storage handle (feature 191): how often it was set up.
        try? launch.storage.setValue(Data(String(DebugExperience.opens(in: launch.storage) + 1).utf8),
                                     for: DebugExperience.opensKey)
        try scene.setup(context)
    }

    func resize(_ context: RenderContext) {
        scene.resize(context)
    }

    func draw(_ core: DebugExperienceCore, tier: Int, context: RenderContext, frame: FrameInfo) throws {
        lastTier = tier
        let colour = core.colour(tier: tier)
        scene.parameters = ["red": colour.red, "green": colour.green, "blue": colour.blue,
                            "mark": DebugExperience.markIsLight(colour) ? 1 : 0]
        try scene.render(context, frame: frame)
    }

    func teardown(_ context: RenderContext) {
        scene.teardown(context)
    }

    func describe(_ core: DebugExperienceCore) -> String {
        "Debug experience, \(core.count) taps. Motion \(launch.reduceMotion.rawValue), "
            + "flashing \(launch.reduceFlashing.rawValue)."
    }

    /// The lower-left corner shows the mark: light on a dark state colour, dark on a light one (feature 195).
    func probes(_ core: DebugExperienceCore) -> [FrameProbe] {
        let light = DebugExperience.markIsLight(core.colour(tier: lastTier))
        return [FrameProbe(name: "corner", x: 0.1, y: 0.9, expected: light ? "light" : "dark")].compactMap { $0 }
    }

    func makeControls(_ port: ExperienceActionPort) -> AnyView {
        AnyView(DebugControls(port: port, identifier: DebugExperience.tapIdentifier(for: experienceID)))
    }
}

/// The controls of the debug experience: the state in words and one button that sends `tap`.
private struct DebugControls: View {
    let port: ExperienceActionPort
    let identifier: String

    var body: some View {
        VStack(spacing: 8) {
            Text(verbatim: port.summary)
                .font(.body)
                .accessibilityIdentifier(identifier + ".summary")
            Button {
                port.send("tap")
            } label: {
                Text(verbatim: "Tap")
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier(identifier)
        }
    }
}

/// Builds the debug experience for a fixture id.
enum DebugExperience {
    /// The accessibility identifier of the tap button: `experience.<id>.tap`, built from the framework's prefix
    /// for everything inside an experience (`ExperienceID.accessibilityPrefix`).
    static func tapIdentifier(for id: ExperienceID) -> String {
        id.accessibilityPrefix + ".tap"
    }

    /// The name of the value the debug experience keeps in its storage: the number of its set-ups.
    static let opensKey = "opens"

    /// How often the debug experience of `storage` was set up; 0 without the value.
    static func opens(in storage: ExperienceStorage) -> Int {
        guard let data = storage.value(for: opensKey), let text = String(data: data, encoding: .utf8) else {
            return 0
        }
        return Int(text) ?? 0
    }

    #if DEBUG || VISUALCORE_AUTOMATION
    /// The scenarios of the debug experience (feature 195): the nine standard ones as taps. Expected digests are
    /// left to the runner's own checks (a rejection keeps the digest, a restore gives the final digest, a reset the
    /// initial one); the outcome comes from the core.
    static func manifest(for id: ExperienceID, seed: UInt64 = 7) -> ScenarioManifest {
        let tap = ScriptedAction("tap")
        let taps = (0..<4).map { _ in ScenarioStep(steps: 6, action: tap, result: "accepted") }
        let specs = [
            ScenarioSpec(name: "launch-first-frame", seed: seed, entries: []),
            ScenarioSpec(name: "input-response", seed: seed, entries: taps),
            ScenarioSpec(name: "completion", seed: seed, entries: Array(taps.prefix(tapsToComplete)),
                         expect: ScenarioExpectations(outcome: "taps-counted")),
            ScenarioSpec(name: "rejection", seed: seed, entries: [
                ScenarioStep(steps: 0, action: ScriptedAction("tap", [1]), result: "action.wrong-value-count"),
                ScenarioStep(steps: 0, action: ScriptedAction("jump"), result: "action.unknown-control"),
            ]),
            ScenarioSpec(name: "save-restore", seed: seed, entries: taps),
            ScenarioSpec(name: "reset", seed: seed, entries: taps, expect: ScenarioExpectations(resetDigest: true)),
            ScenarioSpec(name: "suspend-resume", seed: seed, entries: []),
            ScenarioSpec(name: "teardown-reentry", seed: seed, entries: [], cycles: 5),
            ScenarioSpec(name: "cancel-prepare", seed: seed, entries: []),
        ]
        return ScenarioManifest(experience: id, kind: .creative, scenarios: specs)
    }
    #endif

    /// The taps after which the debug experience reports its outcome.
    static let tapsToComplete = 3

    /// The fragment shader: the state colour, and the mark in the lower-left quarter.
    static let fragment = """
    precision mediump float;
    in vec2 v_uv;
    uniform float u_red;
    uniform float u_green;
    uniform float u_blue;
    uniform float u_mark;
    out vec4 color;
    void main() {
        vec3 c = vec3(u_red, u_green, u_blue);
        if (v_uv.x < 0.25 && v_uv.y < 0.25) { c = vec3(u_mark); }
        color = vec4(c, 1.0);
    }
    """

    /// Whether the mark is light: when the state colour is dark (Rec. 709 luma below one half).
    static func markIsLight(_ colour: (red: Double, green: Double, blue: Double)) -> Bool {
        0.2126 * colour.red + 0.7152 * colour.green + 0.0722 * colour.blue < 0.5
    }

    /// The debug experience registered as `id`, opened with `launch`.
    @MainActor
    static func make(id: ExperienceID, launch: ExperienceLaunch) -> any Experience {
        ExperienceShell(id: id, presenter: DebugPresenter(experienceID: id, launch: launch))
    }

    /// The registration of the debug experience for `id`.
    static func registration(for id: ExperienceID) -> ExperienceRegistration {
        ExperienceRegistration(id: id, core: DebugExperienceCore.self) { launch in make(id: id, launch: launch) }
    }

    /// The error of a debug experience whose setup is made to fail.
    struct SetupFailure: Error {}

    /// The registration of a debug experience for `id` whose setup always fails: the session ends the open in
    /// its failure view.
    static func failingRegistration(for id: ExperienceID) -> ExperienceRegistration {
        ExperienceRegistration(id: id, core: DebugExperienceCore.self) { launch in
            ExperienceShell(id: id, presenter: DebugPresenter(experienceID: id, launch: launch, failsSetup: true))
        }
    }
}
#endif
