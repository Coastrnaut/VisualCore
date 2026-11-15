// ArcadePresenter — feature 075 (A10-P01) T-A10-104 (FR-A10-120, FR-A10-121, FR-A10-122; clarifications 1, 4 and 5;
// edge cases "very small screens", "Reduce Motion"). Draws Neon Dodge through the host only (the host's context and
// registry, VisualCore's `PrimitiveRenderer` with a `Camera2D`; no context of its own). The scene is code, rebuilt
// every frame from the core's run, which the presenter only reads:
//   - Mapping: the 9 × 16 field (game units, y up) is scaled uniformly to fit the canvas and centred; the canvas is
//     cleared in a near-black letterbox colour, and four letterbox masks above everything else hide whatever lies
//     outside the field (objects entering above or leaving below). The simulation never sees the canvas.
//   - Field: one dark rect (#07061A); seven faint horizontal lines drift down over the band y 2…16 at 0.6 units/s of
//     game time (the step count), so a paused run holds still.
//   - Objects at their rule sizes: a circle object (spike ball, glow orb) is one circle of its radius; a bar is a
//     capsule — a line 2 × radius wide between its two segment ends plus a circle of its radius at each end. Each
//     object has a glow behind it (a circle, or a line for a bar, 1.6 × its radius) whose alpha pulses as
//     0.35 + 0.15 × sin(step × 0.08). Colours come from the catalog item (fallbacks for an unknown item).
//   - Player: a glow, a ring (a closed polyline of 33 points) of radius equal to the hit radius 0.4 and a chevron
//     pointing up inside it; while invulnerable the ring and chevron blink (dim every other 8 steps). Drawing only.
//   - Score and lives: the score in seven-segment digits (lines) at the top left of the field, the lives as three
//     small circles at the top right (lost lives faint). Paused: two bars in the middle; over: a dark shade over the
//     field and a cross in the hazard colour.
//   - Waves (feature 076, A10-P02, T-A10-203; FR-A10-220; clarification 5): five dim lane guides — thin vertical lines
//     (0.03 units, faint cyan at alpha 0.07) at the lane centres `Lanes.centres` from y 2 (above the player's band, keeping the
//     bottom-centre frame probe on plain field) to the top of the field, drawn under the glows, objects, player and HUD so they never hide or resize a collision shape — and the
//     wave number in the same seven-segment digits beside the score (from x 4.6, at most three digits, in cyan). The
//     spoken description names the wave ("wave 3"). Rule sizes are unchanged.
// Reduce Motion halves the glow pulse amplitude (0.15 → 0.075) and the background drift speed (0.6 → 0.3 units/s);
// the game itself — and so the core's state and digest — never depends on it. Nothing flashes. No audio.
// The canvas drag goes through `ArcadeGestures` (`run.steer`); every action also has a native control.
// Screens and effects — feature 077 (A10-P03) T-A10-304 (FR-A10-310, FR-A10-311, FR-A10-320, FR-A10-321; SC-A10-301,
// SC-A10-304; clarifications 2–5): the overlay follows the core's screen. Title: a dark shade, the player's ring and
// chevron enlarged as an emblem and a cyan play triangle; paused: the two bars; game over: the shade, the cross and the
// run's final score and wave in the same seven-segment digits, centred under the cross. A change of screen cross-fades
// the old overlay out and the new one in over `transitionDuration(0.25, reduceMotion:)` seconds of frame time (0
// under Reduce Motion: the change is immediate); presentation only, the first screen drawn appears at once. The
// effects of `ArcadeEffectsLayer` (bursts, ring, tint or outline only under reduced flashing, sweep, sounds and
// haptics as the settings allow) are advanced from the last drawn run to the current one in each draw. The scene is
// drawn in three passes through the host's registry: the back layer (field, drift lines, lane guides, tint, sweep and
// rings), the particles (`ParticleRenderer`), then the glows, objects, player, HUD, overlays and letterbox masks, so
// the collision shapes are always above every effect. Sounds stop on teardown and when the experience is suspended
// (`suspended()`); the presenter never changes the core and sends nothing on its own (the suspension's `run.pause` is
// sent by `ArcadeExperience` through the port).
// Scores and accessibility — feature 078 (A10-P04) T-A10-403 (FR-A10-401, FR-A10-411–413, FR-A10-420, FR-A10-421;
// SC-A10-401–404; clarifications 1, 2 and 4): the presenter owns the experience's `HighScoreStore` (loaded from the
// launch storage). Each drawn frame that shows the game-over screen offers the run to the store under the core's run
// number (entered once; an ending watched while drawn — the screen changed to over since the last drawn state — is
// `live`). The title and game-over screens draw the best scores below their emblem or final score: the top three
// entries in seven-segment digits, each row centred, and the run just entered marked in magenta with a small arrow
// beside it (as a fourth row when it ranks below third). The canvas drag reaches full steering at the reach of the
// drawn state's sensitivity step. Announcements: the drawn effect cues without the game-over cue (the effect plan caps
// cues at three and may drop it) plus a game-over cue when the presenter watched the run end go through an
// `ArcadeAnnouncer` (`AnnouncementPlanner(minimumInterval: 1.0)`; "Hit, n lives left", "Wave n", "Game over, score s"
// or "New high score s" when the run entered the table; never pickups) on the presentation clock (the sum of the drawn
// frame times), and every announcement it returns goes to the host's `ExperienceFeedback.announce`. The description
// and the controls name the best score ("best score none" / "best score 1,230").
// Quality levels — feature 079 (A10-P05) T-A10-503 (FR-A10-501–503; SC-A10-501; clarifications 1 and 2; research
// D1; edge cases "the quality level drops mid-burst", "Low Power Mode and the host's level"): every drawn frame
// chooses an `ArcadeBudget` before anything else (`applyQuality(tier:)`): level 0 (the lowest) while Low Power Mode is
// on (injected `lowPowerMode`, default `ProcessInfo.processInfo.isLowPowerModeEnabled`), otherwise the level of the
// host's tier. The host counts its tiers from the best (tier 0 = the best drawing, as `QualityGovernor` and
// `QualityPolicy` step toward higher tiers under heat and Low Power Mode) while `ArcadeBudget` counts its levels from
// the lowest, so host tier t (clamped to 0…2) draws budget level 2 − t: tier 0 → level 2 (the full drawing of
// A10-P01…P04), tier 2 → level 0 (`budgetLevel(tier:lowPower:)`). With the budget:
//   - each glow (objects and player) has the radius `glowFactor` × the object's radius (1.2, 1.4, 1.6) and the alpha
//     `budget.glowAlpha(base: 0.35, pulse: amount × sin(step × 0.08))`, at most the level's cap (0.25, 0.30, 0.35);
//     the pulse term is used only on a level that pulses and never under reduced flashing (a steady glow at the cap);
//     Reduce Motion still halves the amplitude (0.15 → 0.075);
//   - the effects layer scales each burst by `burstCount` and keeps the live particles drawn within `particleCap`
//     (oldest removed first when the level drops; see `ArcadeEffectsLayer`).
// The collision shapes keep their rule sizes and stay above every glow and particle at every level. The tier is
// presentation only: the core stores none and its digest is the same at every level. The frame probe keeps the full
// glow reach (1.6 ×), the largest of any level.
import Foundation
import SwiftUI
import NeonArcadeCore
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreRendering
import VisualCoreScenes
import VisualCoreSimulation

/// What the controls show, updated only when a field changes.
@MainActor
@Observable
final class ArcadeMirror {
    /// Whether a state was seen (the controls show a progress indicator before).
    var ready = false
    /// The score.
    var score = 0
    /// The lives left.
    var lives = GameRun.startLives
    /// Whether the run is paused.
    var paused = false
    /// Whether the run is over.
    var over = false
    /// The held steering value, −1…1.
    var steering = 0.0
    /// The screen shown (feature 077).
    var screen = ArcadeScreen.title
    /// Whether sound effects are on (feature 077).
    var sound = true
    /// Whether haptics are on (feature 077).
    var haptics = true
    /// The status line: score, lives and the screen.
    var status = ""
    /// The steering sensitivity step 0…4 (feature 078).
    var sensitivity = Sensitivity.defaultStep
    /// The best-score text of the controls (feature 078), for example "Best score: none".
    var best = ArcadePresenter.bestWords(nil, newRank: nil)
    /// The high-score problem to show, or nil (feature 078).
    var scoresProblem: String?
}

/// A failure the presenter injects for tests (`failNextDraw`).
enum ArcadeDrawError: Error, Equatable {
    /// The injected failure.
    case injected
}

/// Draws Neon Arcade and owns its presentation state (the Reduce Motion preference, the scene nodes, the gesture).
@MainActor
final class ArcadePresenter: ExperiencePresenter {
    /// The field's width in game units.
    nonisolated static let fieldWidth = GameRun.fieldWidth
    /// The field's height in game units.
    nonisolated static let fieldHeight = GameRun.fieldHeight
    /// The clear colour around the field.
    nonisolated static let letterboxColor = Vec4(0.008, 0.008, 0.02, 1)
    /// The field colour (#07061A).
    nonisolated static let fieldColor = Vec4(0.027, 0.024, 0.102, 1)
    /// The colour of the drifting background lines: faint cyan.
    nonisolated static let driftColor = Vec4(0.13, 0.9, 1.0, 0.08)
    /// The number of drifting background lines.
    nonisolated static let driftLines = 7
    /// The spacing of the drifting lines in game units.
    nonisolated static let driftSpacing = 2.0
    /// The lowest y of a drifting line (the band below, with the player, stays plain).
    nonisolated static let driftBottom = 2.0
    /// The drift speed in game units per second at full motion.
    nonisolated static let driftSpeed = 0.6
    /// The glow alpha around which the pulse swings.
    nonisolated static let glowBase = 0.35
    /// The glow pulse amplitude (alpha) at full motion.
    nonisolated static let glowPulse = 0.15
    /// The pulse's angular rate per simulation step.
    nonisolated static let pulseRate = 0.08
    /// A glow's radius as a multiple of its object's radius at the full drawing (level 2, the largest of any level;
    /// the frame probe keeps this reach). The drawn factor is the budget's `glowFactor`.
    nonisolated static let glowScale = 1.6
    /// The number of quality levels the presenter draws: `ArcadeBudget.levels` (equal to `ArcadeCore.qualityTiers`).
    nonisolated static let levelCount = ArcadeBudget.levels
    /// The player ring's line width in game units.
    nonisolated static let ringWidth = 0.07
    /// The number of points of the player ring (closed: the last equals the first).
    nonisolated static let ringPoints = 33
    /// The chevron inside the player ring, relative to its centre in game units, pointing up (star-shaped from the
    /// tip, so any polygon fill draws it).
    nonisolated static let chevron = [Vec2(0, 0.26), Vec2(0.22, -0.14), Vec2(0, -0.03), Vec2(-0.22, -0.14)]
    /// The invulnerability blink: the player dims every other `blinkSteps` steps to `blinkAlpha`.
    nonisolated static let blinkSteps = 8, blinkAlpha = 0.35
    /// The most digits of the score (9,999,999).
    nonisolated static let maxDigits = 7
    /// A digit's width and height in game units.
    nonisolated static let digitWidth = 0.34, digitHeight = 0.6
    /// The distance from one digit to the next in game units.
    nonisolated static let digitAdvance = 0.48
    /// The top-left corner of the first digit in game units.
    nonisolated static let digitOrigin = Vec2(0.35, 15.65)
    /// The width of a digit's segment lines in game units.
    nonisolated static let segmentWidth = 0.08
    /// The seven segments a…g lit for each digit 0…9 (a top, b top right, c bottom right, d bottom, e bottom left,
    /// f top left, g middle).
    nonisolated static let segmentTable: [[Int]] = [
        [0, 1, 2, 3, 4, 5], [1, 2], [0, 1, 3, 4, 6], [0, 1, 2, 3, 6], [1, 2, 5, 6],
        [0, 2, 3, 5, 6], [0, 2, 3, 4, 5, 6], [0, 1, 2], [0, 1, 2, 3, 4, 5, 6], [0, 1, 2, 3, 5, 6],
    ]
    /// The centre of the first life marker, the spacing to the next (leftwards) and the marker radius, game units.
    nonisolated static let livesOrigin = Vec2(8.6, 15.35), livesSpacing = 0.45, lifeRadius = 0.17
    /// The colour of the lane guides: faint cyan.
    nonisolated static let laneColor = Vec4(0.13, 0.9, 1.0, 0.07)
    /// The width of a lane guide in game units.
    nonisolated static let laneWidth = 0.03
    /// The most digits of the wave number (999).
    nonisolated static let maxWaveDigits = 3
    /// The top-left corner of the wave number's first digit in game units (beside the score's seven digits).
    nonisolated static let waveOrigin = Vec2(4.6, 15.65)
    /// The colour of the wave digits.
    nonisolated static let waveColor = Vec4(0.13, 0.9, 1.0, 0.9)
    /// The colour of the score digits.
    nonisolated static let hudColor = Vec4(0.85, 0.98, 1.0, 1)
    /// The alpha of a lost life's marker.
    nonisolated static let lostLifeAlpha = 0.2
    /// The pause bars' colour.
    nonisolated static let pauseColor = Vec4(0.9, 0.95, 1.0, 0.8)
    /// The shade over the field once the run is over.
    nonisolated static let overShade = Vec4(0, 0, 0, 0.45)
    /// The fallback colours of an object whose item is not in the catalog.
    nonisolated static let fallbackHazard = Vec4(1.0, 0.2, 0.45, 1), fallbackOrb = Vec4(0.75, 1.0, 0.3, 1)
    /// The z of the field, the drift lines, the lane guides, the effects (in the back layer), the glows, the objects,
    /// the player, the HUD, the screen overlays and the letterbox masks.
    nonisolated static let fieldZ = 0, driftZ = 1, laneZ = 1, effectZ = 1, glowZ = 2, objectZ = 3, playerZ = 4,
                           hudZ = 6, stateZ = 7, maskZ = 9
    /// The shade over the field on the title screen.
    nonisolated static let titleShade = Vec4(0, 0, 0, 0.5)
    /// The centre of the title emblem (game units), its ring radius and the chevron's scale.
    nonisolated static let emblemCenter = Vec2(4.5, 9.5), emblemRadius = 1.5, emblemScale = 4.0
    /// The title's play triangle: its centre (game units) and half size.
    nonisolated static let playCenter = Vec2(4.5, 6.4), playSize = 0.6
    /// The colour of the play triangle: cyan.
    nonisolated static let playColor = Vec4(0.13, 0.9, 1.0, 1)
    /// The top of the game-over score digits and of the wave digits under them (game units).
    nonisolated static let overScoreTop = 6.4, overWaveTop = 5.4
    /// The length of a screen cross-fade at full motion in seconds.
    nonisolated static let screenFade = 0.25
    /// The field point (game units) near the bottom centre where the frame probe is taken when it lies in the field.
    nonisolated static let probeMargin = 0.35
    /// The most best-score rows drawn: the top three and the new entry below them (feature 078).
    nonisolated static let bestRows = 4
    /// The top entries always drawn (feature 078).
    nonisolated static let bestShown = 3
    /// The top of the first best-score row on the title and game-over screens and the distance between rows (game
    /// units; feature 078).
    nonisolated static let titleBestTop = 5.0, overBestTop = 4.2, bestSpacing = 0.8
    /// The colour of the best-score rows and of the marked new entry (feature 078).
    nonisolated static let bestColor = Vec4(0.85, 0.98, 1.0, 0.75), newEntryColor = Vec4(1.0, 0.35, 0.85, 1)
    /// The gap between the new-entry arrow and its row, and the arrow's half height (game units; feature 078).
    nonisolated static let markerGap = 0.25, markerSize = 0.22

    let experienceID: ExperienceID
    let mirror = ArcadeMirror()
    /// With Reduce Motion on, the glow pulse and the background drift are halved (presentation only).
    let reduceMotion: Bool

    /// Set by a test to make the next draw throw `ArcadeDrawError.injected` (the seam clears itself).
    var failNextDraw = false
    /// Whether the scene is set up.
    private(set) var isLive = false
    /// The last core drawn or described.
    private(set) var lastCore: ArcadeCore?
    /// The scale of the last frame (pixels per game unit) and its canvas size in pixels.
    private(set) var lastScale = 0.0, lastCanvas = Vec2(0, 0)
    /// The number of falling objects drawn in the last frame.
    private(set) var lastObjectsDrawn = 0
    /// The score text and the number of lit lives of the last frame.
    private(set) var lastScoreText = "", lastLivesLit = 0
    /// The wave text of the last frame.
    private(set) var lastWaveText = ""
    /// The state mark of the last frame: "none" (playing), "title", "paused" (two bars) or "over" (shade and cross).
    private(set) var lastStateMark = "none"
    /// The final score and wave texts the game-over screen showed in the last frame (empty when not shown).
    private(set) var lastOverScoreText = "", lastOverWaveText = ""
    /// The alpha of the current screen's overlay in the last frame (1 once the cross-fade is complete).
    private(set) var lastTransitionProgress = 1.0
    /// The particles drawn in the last frame.
    private(set) var lastParticlesDrawn = 0
    /// The sounds and haptics started since the presenter was made (tests).
    private(set) var soundsStarted = 0, hapticsStarted = 0
    /// With reduced flashing a hit keeps only its ring (no full-field tint).
    let reduceFlashing: Bool
    /// The effects (particles, rings, tint, sweep).
    let effects: ArcadeEffectsLayer
    /// Where the sounds go.
    let soundSink: any ArcadeSoundSink
    /// The host's haptic route.
    let feedback: ExperienceFeedback
    /// The screen whose overlay is shown (nil before the first frame) and the screen fading out, with the seconds of
    /// frame time since the change.
    private(set) var shownScreen: ArcadeScreen?, fadingScreen: ArcadeScreen?
    private var transitionElapsed = 0.0
    /// The glow pulse amplitude and the drift speed the last frame was drawn with.
    private(set) var lastPulseAmount = 0.0, lastDriftAmount = 0.0
    /// Whether Low Power Mode is on (injected; by default the system's state). Read once per drawn frame.
    let lowPowerMode: @MainActor () -> Bool
    /// The host tier the last drawn frame was given (nil before the first draw).
    private(set) var lastHostTier: Int?
    /// Whether Low Power Mode was on for the last drawn frame.
    private(set) var lastLowPower = false
    /// The pulse amplitude actually applied in the last laid-out frame (0 on a level without pulse or under reduced
    /// flashing; otherwise `pulseAmount`).
    private(set) var lastPulseApplied = 0.0
    /// The glow alpha of the objects in the last laid-out frame (the player's is this × its blink alpha).
    private(set) var lastGlowAlpha = 0.0
    /// The glow radius factor of the last laid-out frame.
    private(set) var lastGlowFactor = 0.0
    /// The canvas gesture (a drag steers).
    private var gestures = ArcadeGestures()
    /// The high-score table in the experience's storage (feature 078).
    let highScores: HighScoreStore
    /// The rate limit of the announcements (feature 078).
    private(set) var announcer = ArcadeAnnouncer()
    /// The presentation clock of the announcer: the sum of the drawn frame times in seconds (feature 078).
    private(set) var presentationTime = 0.0
    /// The announcements sent to the feedback route since the presenter was made, with their presentation times
    /// (tests; feature 078).
    private(set) var announced: [Announcement] = []
    /// The core of the last presented frame (feature 078: the game-over transition is detected against it).
    private(set) var lastPresented: ArcadeCore?
    /// The best-score rows of the last frame as drawn texts (empty when none were shown) and the marked row's index
    /// (feature 078).
    private(set) var lastBestTexts: [String] = []
    private(set) var lastBestMarkedRow: Int?
    /// The port of the last canvas pointer event: a held drag keeps steering through it as the player moves
    /// (T-A10-115).
    private var followPort: ExperienceActionPort?

    private let clear = ClearColorScene(red: 0, green: 0, blue: 0)
    /// The renderers of the back layer, the particles and the front layer (created in `setup`, released in
    /// `teardown`).
    private var backPrimitives: PrimitiveRenderer?
    private var particleRenderer: ParticleRenderer?
    private var primitives: PrimitiveRenderer?
    /// The back layer (field, drift lines, lane guides, effects) and the front layer (everything else).
    let backRoot = SceneNode(id: "arcade.back")
    let root = SceneNode(id: "arcade")
    /// The field rectangle.
    let field = SceneNode(id: "field", z: ArcadePresenter.fieldZ)
    /// The drifting background lines.
    private(set) var driftNodes: [SceneNode] = []
    /// The five lane guides.
    private(set) var laneNodes: [SceneNode] = []
    /// The glow, body and two capsule end nodes of each object slot.
    private(set) var glowNodes: [SceneNode] = [], bodyNodes: [SceneNode] = []
    private var capNodes: [(SceneNode, SceneNode)] = []
    /// The player's glow, ring and chevron.
    let playerGlow = SceneNode(id: "player.glow", z: ArcadePresenter.glowZ)
    let playerRing = SceneNode(id: "player.ring", z: ArcadePresenter.playerZ)
    let playerChevron = SceneNode(id: "player.chevron", z: ArcadePresenter.playerZ)
    /// The seven segment nodes of each score digit.
    private var digitNodes: [[SceneNode]] = []
    /// The seven segment nodes of each wave digit.
    private(set) var waveDigitNodes: [[SceneNode]] = []
    /// The life markers.
    private(set) var lifeNodes: [SceneNode] = []
    private var pauseNodes: [SceneNode] = []
    private let shade = SceneNode(id: "over.shade", z: ArcadePresenter.stateZ)
    private var crossNodes: [SceneNode] = []
    private var maskNodes: [SceneNode] = []
    /// The title screen's shade, emblem ring, emblem chevron and play triangle.
    let titleShadeNode = SceneNode(id: "title.shade", z: ArcadePresenter.stateZ)
    let titleRing = SceneNode(id: "title.ring", z: ArcadePresenter.stateZ)
    let titleChevron = SceneNode(id: "title.chevron", z: ArcadePresenter.stateZ)
    let titlePlay = SceneNode(id: "title.play", z: ArcadePresenter.stateZ)
    /// The seven segment nodes of each final score digit and final wave digit on the game-over screen.
    private(set) var overScoreNodes: [[SceneNode]] = [], overWaveNodes: [[SceneNode]] = []
    /// The seven segment nodes of each digit of each best-score row and the new-entry arrow (feature 078).
    private(set) var bestNodes: [[[SceneNode]]] = []
    let bestMarker = SceneNode(id: "best.marker", z: ArcadePresenter.stateZ)

    /// A presenter.
    /// - Parameters:
    ///   - experienceID: The experience's id.
    ///   - reduceMotion: Halves the glow pulse and the background drift and makes screen changes immediate
    ///     (presentation only).
    ///   - reduceFlashing: A hit keeps only its ring (no full-field tint).
    ///   - soundSink: Where the sounds go (by default VisualCore's `SoundEffectPlayer`).
    ///   - feedback: The haptic and announcement route (by default the host's shared `ExperienceFeedback`).
    ///   - highScores: The high-score table (by default one kept in memory only; the app passes one over the
    ///     experience's storage).
    ///   - lowPowerMode: Whether Low Power Mode is on (nil: `ProcessInfo.processInfo.isLowPowerModeEnabled`); while
    ///     it is, every frame draws quality level 0.
    init(experienceID: ExperienceID, reduceMotion: Bool = false, reduceFlashing: Bool = false,
         soundSink: (any ArcadeSoundSink)? = nil, feedback: ExperienceFeedback? = nil,
         highScores: HighScoreStore? = nil, lowPowerMode: (@MainActor () -> Bool)? = nil) {
        self.experienceID = experienceID
        self.lowPowerMode = lowPowerMode ?? { ProcessInfo.processInfo.isLowPowerModeEnabled }
        self.highScores = highScores ?? HighScoreStore(storage: nil)
        self.reduceMotion = reduceMotion
        self.reduceFlashing = reduceFlashing
        self.soundSink = soundSink ?? ArcadeSoundPlayer()
        self.feedback = feedback ?? .shared
        effects = ArcadeEffectsLayer(reduceFlashing: reduceFlashing, z: Self.effectZ)
        backRoot.add(field)
        for index in 0..<Self.driftLines {
            let node = SceneNode(id: "drift\(index)", z: Self.driftZ)
            backRoot.add(node)
            driftNodes.append(node)
        }
        for lane in 0..<Lanes.count {
            let node = SceneNode(id: "lane\(lane)", z: Self.laneZ)
            backRoot.add(node)
            laneNodes.append(node)
        }
        for node in effects.nodes { backRoot.add(node) }
        for slot in 0..<GameRun.maxObjects {
            let glow = SceneNode(id: "o\(slot).glow", z: Self.glowZ)
            let body = SceneNode(id: "o\(slot)", z: Self.objectZ)
            let capA = SceneNode(id: "o\(slot).a", z: Self.objectZ)
            let capB = SceneNode(id: "o\(slot).b", z: Self.objectZ)
            for node in [glow, body, capA, capB] { root.add(node) }
            glowNodes.append(glow)
            bodyNodes.append(body)
            capNodes.append((capA, capB))
        }
        root.add(playerGlow)
        root.add(playerRing)
        root.add(playerChevron)
        for digit in 0..<Self.maxDigits {
            var segments: [SceneNode] = []
            for segment in 0..<7 {
                let node = SceneNode(id: "digit\(digit).\(segment)", z: Self.hudZ)
                root.add(node)
                segments.append(node)
            }
            digitNodes.append(segments)
        }
        for digit in 0..<Self.maxWaveDigits {
            var segments: [SceneNode] = []
            for segment in 0..<7 {
                let node = SceneNode(id: "wave\(digit).\(segment)", z: Self.hudZ)
                root.add(node)
                segments.append(node)
            }
            waveDigitNodes.append(segments)
        }
        for life in 0..<GameRun.startLives {
            let node = SceneNode(id: "life\(life)", z: Self.hudZ)
            root.add(node)
            lifeNodes.append(node)
        }
        for bar in 0..<2 {
            let node = SceneNode(id: "pause\(bar)", z: Self.stateZ)
            root.add(node)
            pauseNodes.append(node)
        }
        root.add(shade)
        for line in 0..<2 {
            let node = SceneNode(id: "over\(line)", z: Self.stateZ)
            root.add(node)
            crossNodes.append(node)
        }
        for (count, prefix) in [(Self.maxDigits, "overScore"), (Self.maxWaveDigits, "overWave")] {
            var digits: [[SceneNode]] = []
            for digit in 0..<count {
                var segments: [SceneNode] = []
                for segment in 0..<7 {
                    let node = SceneNode(id: "\(prefix)\(digit).\(segment)", z: Self.stateZ)
                    root.add(node)
                    segments.append(node)
                }
                digits.append(segments)
            }
            if prefix == "overScore" { overScoreNodes = digits } else { overWaveNodes = digits }
        }
        for node in [titleShadeNode, titleRing, titleChevron, titlePlay] { root.add(node) }
        for row in 0..<Self.bestRows {
            var digits: [[SceneNode]] = []
            for digit in 0..<Self.maxDigits {
                var segments: [SceneNode] = []
                for segment in 0..<7 {
                    let node = SceneNode(id: "best\(row).\(digit).\(segment)", z: Self.stateZ)
                    root.add(node)
                    segments.append(node)
                }
                digits.append(segments)
            }
            bestNodes.append(digits)
        }
        root.add(bestMarker)
        for side in 0..<4 {
            let node = SceneNode(id: "mask\(side)", z: Self.maskZ)
            root.add(node)
            maskNodes.append(node)
        }
    }

    /// The factor of the glow pulse and the background drift: ½ with Reduce Motion, 1 otherwise.
    var motionFactor: Double { reduceMotion ? 0.5 : 1 }
    /// The glow pulse amplitude this presenter draws with (0.15, or 0.075 with Reduce Motion).
    var pulseAmount: Double { Self.glowPulse * motionFactor }
    /// The background drift speed in game units per second this presenter draws with (0.6, or 0.3 with Reduce Motion).
    var driftAmount: Double { Self.driftSpeed * motionFactor }
    /// The drawing budget in force (the full drawing, level 2, until a frame is drawn with another).
    var budget: ArcadeBudget { effects.budget }

    /// The budget level (0 the lowest … 2 the full drawing) for the host's `tier` (0 the best; clamped to 0…2):
    /// 0 while `lowPower` is on, otherwise `ArcadeBudget.levels − 1 − tier`.
    nonisolated static func budgetLevel(tier: Int, lowPower: Bool) -> Int {
        if lowPower { return 0 }
        return levelCount - 1 - min(max(tier, 0), levelCount - 1)
    }

    /// Chooses the budget of a frame drawn at the host's `tier` (Low Power Mode read now) and hands it to the
    /// effects. Presentation only.
    func applyQuality(tier: Int) {
        let lowPower = lowPowerMode()
        lastHostTier = tier
        lastLowPower = lowPower
        effects.apply(ArcadeBudget.level(Self.budgetLevel(tier: tier, lowPower: lowPower)))
    }

    /// The length of a screen cross-fade this presenter draws with: `transitionDuration(0.25, reduceMotion:)`, so 0
    /// under Reduce Motion.
    var screenTransitionDuration: Double {
        VisualCoreSimulation.transitionDuration(Self.screenFade, reduceMotion: reduceMotion)
    }

    // MARK: Screens and effects

    /// Notes the screen of the core being drawn: a change starts a cross-fade from the shown screen (the first
    /// screen appears at once; with a cross-fade of 0 s the change is immediate).
    func noteScreen(_ screen: ArcadeScreen) {
        guard let shown = shownScreen else {
            shownScreen = screen
            return
        }
        guard shown != screen else { return }
        fadingScreen = screenTransitionDuration > 0 ? shown : nil
        shownScreen = screen
        transitionElapsed = 0
    }

    /// The progress 0…1 of the current cross-fade (1 when none runs).
    var transitionProgress: Double {
        guard fadingScreen != nil else { return 1 }
        let duration = screenTransitionDuration
        return duration > 0 ? min(max(transitionElapsed / duration, 0), 1) : 1
    }

    /// The alpha of the overlay of `screen` now: the shown screen fades in, the screen before it fades out.
    func overlayAlpha(_ screen: ArcadeScreen) -> Double {
        if screen == shownScreen { return transitionProgress }
        if screen == fadingScreen { return 1 - transitionProgress }
        return 0
    }

    /// The presentation step of one drawn frame of `seconds`: the screen and its cross-fade, then the effects of the
    /// run change since the last drawn run, with their sounds (sound setting on) and haptics (haptics setting on), the
    /// game-over entry into the high-score table and the announcements (feature 078). Reads `core` only.
    func advancePresentation(_ core: ArcadeCore, seconds: Double) {
        let previous = lastPresented
        lastPresented = core
        let before = shownScreen
        noteScreen(core.screen)
        if before == shownScreen, fadingScreen != nil, seconds.isFinite, seconds > 0 {
            transitionElapsed += seconds
            if transitionProgress >= 1 { fadingScreen = nil }
        }
        let cues = effects.advance(to: core.run)
        for cue in cues {
            guard let sound = cue.sound else { continue }
            if core.sound {
                soundSink.play(sound)
                soundsStarted += 1
            }
            if core.haptics {
                feedback.haptic(sound.haptic)
                hapticsStarted += 1
            }
        }
        let ended = Self.watchedEnding(from: previous, to: core)
        var rank: Int?
        if core.screen == .over {
            rank = highScores.record(run: core.run, number: core.runNumber, live: ended)
        }
        syncScores(core)
        if seconds.isFinite, seconds > 0 { presentationTime += seconds }
        var spoken = cues.filter { $0.kind != .over }
        if ended { spoken.append(EffectCue(kind: .over, position: core.run.player.center, visual: false, sound: nil)) }
        if let announcement = announcer.update(cues: spoken, run: core.run, newHighScore: rank != nil,
                                               time: presentationTime) {
            feedback.announce(announcement.text, kind: announcement.kind)
            announced.append(announcement)
        }
    }

    /// The most steps between two drawn states for an ending to count as watched (a frame advances a few steps).
    nonisolated static let watchedSteps = 30

    /// Whether the run of `current` ended while drawn: the last presented state showed another screen for the same run
    /// number, a few steps earlier (a restored game-over screen or the first frame is no watched ending).
    nonisolated static func watchedEnding(from previous: ArcadeCore?, to current: ArcadeCore) -> Bool {
        guard let previous, current.screen == .over, previous.screen != .over,
              previous.runNumber == current.runNumber, current.run.step >= previous.run.step,
              current.run.step - previous.run.step <= watchedSteps,
              current.run.eventCount >= previous.run.eventCount else { return false }
        return true
    }

    /// The experience was suspended: every sound stops (nothing is queued for later).
    func suspended() {
        soundSink.stopAll()
    }

    // MARK: Render scene

    func setup(_ context: RenderContext) throws {
        backPrimitives = try PrimitiveRenderer(registry: context.resources)
        particleRenderer = try ParticleRenderer(registry: context.resources)
        primitives = try PrimitiveRenderer(registry: context.resources)
        isLive = true
    }

    func resize(_ context: RenderContext) {}

    func draw(_ core: ArcadeCore, tier: Int, context: RenderContext, frame: FrameInfo) throws {
        if failNextDraw {
            failNextDraw = false
            throw ArcadeDrawError.injected
        }
        sync(core)
        applyQuality(tier: tier)
        advancePresentation(core, seconds: frame.delta)
        clear.red = Float(Self.letterboxColor.x)
        clear.green = Float(Self.letterboxColor.y)
        clear.blue = Float(Self.letterboxColor.z)
        try clear.render(context, frame: frame)
        let width = Double(max(1, context.pixelWidth)), height = Double(max(1, context.pixelHeight))
        layOut(core, width: width, height: height)
        if backPrimitives == nil { backPrimitives = try PrimitiveRenderer(registry: context.resources) }
        if particleRenderer == nil { particleRenderer = try ParticleRenderer(registry: context.resources) }
        if primitives == nil { primitives = try PrimitiveRenderer(registry: context.resources) }
        let metrics = ViewMetrics(size: Vec2(width, height), scale: 1)
        try backPrimitives?.draw(backRoot, camera: Camera2D(), metrics: metrics)
        let s = lastScale
        let particles = effects.instances.map {
            ParticleInstance(position: Self.world($0.position, scale: s), size: $0.size * s, color: $0.color)
        }
        try particleRenderer?.draw(particles, camera: Camera2D(), metrics: metrics)
        lastParticlesDrawn = particleRenderer?.lastInstanceCount ?? 0
        try primitives?.draw(root, camera: Camera2D(), metrics: metrics)
        // T-A10-115: a finger held still keeps steering by its offset from the drawn player (an action at the next
        // step, recorded like any other; the drawing itself changes nothing), at the drawn sensitivity step.
        if let port = followPort {
            for action in gestures.follow(playerX: core.run.player.x, step: core.sensitivity) {
                _ = port.send(action.control, action.values)
            }
        }
    }

    func teardown(_ context: RenderContext) {
        isLive = false
        gestures.reset()
        followPort = nil
        soundSink.stopAll()
        backPrimitives?.release()
        backPrimitives = nil
        particleRenderer?.release()
        particleRenderer = nil
        primitives?.release()
        primitives = nil
    }

    // MARK: Geometry

    /// The uniform scale (pixels per game unit) that fits the field into `width` × `height` pixels.
    nonisolated static func scale(width: Double, height: Double) -> Double {
        min(width / fieldWidth, height / fieldHeight)
    }

    /// The world point (pixels from the canvas centre, y up) of the field point `p` at `scale`.
    nonisolated static func world(_ p: Vec2, scale: Double) -> Vec2 {
        Vec2((p.x - fieldWidth / 2) * scale, (p.y - fieldHeight / 2) * scale)
    }

    /// The glow alpha at `step` with pulse amplitude `amount` under `budget`:
    /// `budget.glowAlpha(base: 0.35, pulse: amount × sin(step × 0.08))` — at most the level's cap, steady at the cap
    /// on a level without pulse or with `amount` 0.
    nonisolated static func glowAlpha(step: Int, amount: Double, budget: ArcadeBudget) -> Double {
        budget.glowAlpha(base: glowBase, pulse: amount * sin(Double(step) * pulseRate))
    }

    /// How far the background lines have drifted down at `step` with drift speed `speed` (units per second of game
    /// time), modulo the line spacing.
    nonisolated static func driftOffset(step: Int, speed: Double) -> Double {
        let travelled = Double(step) * GameSimulation.step * speed
        let offset = travelled.truncatingRemainder(dividingBy: driftSpacing)
        return offset.isFinite ? offset : 0
    }

    /// The y of background line `index` drifted by `offset`: it starts at the top (16) and wraps inside the band
    /// 2…16.
    nonisolated static func driftLineY(index: Int, offset: Double) -> Double {
        let band = fieldHeight - driftBottom
        return fieldHeight - (Double(index) * driftSpacing + offset).truncatingRemainder(dividingBy: band)
    }

    /// The closed ring of ``ringPoints`` points of `radius` around `center` (game units).
    nonisolated static func ring(center: Vec2, radius: Double) -> [Vec2] {
        (0..<ringPoints).map { i in
            let angle = 2 * Double.pi * Double(i) / Double(ringPoints - 1)
            return center + Vec2(cos(angle) * radius, sin(angle) * radius)
        }
    }

    /// The two ends of segment `segment` (0…6 = a…g) of a digit whose top-left corner is `origin` (game units, y up).
    nonisolated static func segmentEnds(_ segment: Int, origin: Vec2) -> (Vec2, Vec2) {
        let w = digitWidth, h = digitHeight
        let topLeft = origin, topRight = origin + Vec2(w, 0)
        let midLeft = origin + Vec2(0, -h / 2), midRight = origin + Vec2(w, -h / 2)
        let bottomLeft = origin + Vec2(0, -h), bottomRight = origin + Vec2(w, -h)
        switch segment {
        case 0: return (topLeft, topRight)
        case 1: return (topRight, midRight)
        case 2: return (midRight, bottomRight)
        case 3: return (bottomLeft, bottomRight)
        case 4: return (midLeft, bottomLeft)
        case 5: return (topLeft, midLeft)
        default: return (midLeft, midRight)
        }
    }

    /// The score as drawn: its decimal digits, at most ``maxDigits`` (the score is capped at 9,999,999).
    nonisolated static func scoreText(_ score: Int) -> String {
        String(String(min(max(score, 0), GameRun.maxScore)).suffix(maxDigits))
    }

    /// The wave number as drawn: its decimal digits, at most ``maxWaveDigits`` (999 and above draw 999).
    nonisolated static func waveText(_ wave: Int) -> String {
        String(min(max(wave, 1), 999))
    }

    /// The two ends of lane guide `lane` (game units): the lane centre from `driftBottom` to the top of the field, so
    /// the band with the player and the frame probe at the bottom centre stay plain field.
    nonisolated static func laneGuideEnds(_ lane: Int) -> (Vec2, Vec2) {
        let x = Lanes.centre(lane)
        return (Vec2(x, driftBottom), Vec2(x, fieldHeight))
    }

    /// The left x (game units) of `count` digits centred on the field.
    nonisolated static func centredDigitsX(_ count: Int) -> Double {
        let width = Double(max(count, 1) - 1) * digitAdvance + digitWidth
        return fieldWidth / 2 - width / 2
    }

    /// Lights the segments of `text`'s digits in `nodes` from `origin` (game units) in `color`; unused nodes are
    /// cleared.
    private static func drawDigits(_ text: String, nodes: [[SceneNode]], origin: Vec2, color: Vec4,
                                   world: (Vec2) -> Vec2, width: Double) {
        let digits = text.compactMap { $0.wholeNumberValue }
        for (index, segments) in nodes.enumerated() {
            for node in segments { node.primitive = nil }
            guard index < digits.count else { continue }
            let digitOrigin = origin + Vec2(Double(index) * digitAdvance, 0)
            for segment in segmentTable[digits[index]] {
                let (a, b) = segmentEnds(segment, origin: digitOrigin)
                segments[segment].primitive = .line(world(a), world(b), width: width)
                segments[segment].color = color
            }
        }
    }

    /// A catalog colour as a vector.
    nonisolated static func vector(_ color: RGBA) -> Vec4 { Vec4(color.r, color.g, color.b, color.a) }

    /// `color` with its alpha multiplied by `alpha`.
    nonisolated static func faded(_ color: Vec4, _ alpha: Double) -> Vec4 {
        Vec4(color.x, color.y, color.z, color.w * alpha)
    }

    /// The fill and glow colours of `object` from the catalog (fallbacks when its item is unknown).
    nonisolated static func colors(_ object: FallingObject) -> (fill: Vec4, glow: Vec4) {
        if let item = ArcadeCore.catalog.item(id: object.contentId) {
            return (vector(item.color), vector(item.glowColor))
        }
        let fill = object.kind == .hazard ? fallbackHazard : fallbackOrb
        return (fill, faded(fill, 0.6))
    }

    /// Places every node for a canvas of `width` × `height` pixels (world = pixels from the centre, y up). Reads
    /// `core` only.
    func layOut(_ core: ArcadeCore, width: Double, height: Double) {
        let run = core.run
        noteScreen(core.screen)
        let s = Self.scale(width: width, height: height)
        lastScale = s
        lastCanvas = Vec2(width, height)
        let pulse = pulseAmount, drift = driftAmount
        lastPulseAmount = pulse
        lastDriftAmount = drift
        let onePixel = 1.0
        func world(_ p: Vec2) -> Vec2 { Self.world(p, scale: s) }
        func px(_ units: Double) -> Double { max(units * s, onePixel) }

        field.primitive = .rect(Vec2(Self.fieldWidth * s, Self.fieldHeight * s))
        field.position = world(Vec2(Self.fieldWidth / 2, Self.fieldHeight / 2))
        field.color = Self.fieldColor

        let offset = Self.driftOffset(step: run.step, speed: drift)
        for (index, node) in driftNodes.enumerated() {
            let y = Self.driftLineY(index: index, offset: offset)
            node.primitive = .line(world(Vec2(0, y)), world(Vec2(Self.fieldWidth, y)), width: px(0.03))
            node.color = Self.driftColor
        }

        for (lane, node) in laneNodes.enumerated() {
            let (bottom, top) = Self.laneGuideEnds(lane)
            node.primitive = .line(world(bottom), world(top), width: px(Self.laneWidth))
            node.color = Self.laneColor
        }
        effects.layOut(world: world, scale: s, fieldCenter: field.position,
                       fieldSize: Vec2(Self.fieldWidth * s, Self.fieldHeight * s))

        let budget = self.budget
        let applied = budget.pulse && !reduceFlashing ? pulse : 0
        let glowAlpha = Self.glowAlpha(step: run.step, amount: applied, budget: budget)
        let glowFactor = budget.glowFactor
        lastPulseApplied = applied
        lastGlowAlpha = glowAlpha
        lastGlowFactor = glowFactor
        var drawn = 0
        for slot in 0..<GameRun.maxObjects {
            let glow = glowNodes[slot], body = bodyNodes[slot]
            let capA = capNodes[slot].0, capB = capNodes[slot].1
            for node in [glow, body, capA, capB] { node.primitive = nil; node.position = .zero }
            guard slot < run.objects.count else { continue }
            let object = run.objects[slot]
            let (fill, glowColor) = Self.colors(object)
            glow.color = Self.faded(glowColor, glowAlpha)
            body.color = fill
            if object.isCapsule {
                let a = Vec2(object.position.x - object.halfLength, object.position.y)
                let b = Vec2(object.position.x + object.halfLength, object.position.y)
                glow.primitive = .line(world(a), world(b), width: px(2 * object.radius * glowFactor))
                body.primitive = .line(world(a), world(b), width: px(2 * object.radius))
                capA.primitive = .circle(px(object.radius))
                capA.position = world(a)
                capA.color = fill
                capB.primitive = .circle(px(object.radius))
                capB.position = world(b)
                capB.color = fill
            } else {
                glow.primitive = .circle(px(object.radius * glowFactor))
                glow.position = world(object.position)
                body.primitive = .circle(px(object.radius))
                body.position = world(object.position)
            }
            drawn += 1
        }
        lastObjectsDrawn = drawn

        let player = ArcadeCore.catalog.player
        let playerFill = player.map { Self.vector($0.color) } ?? Self.hudColor
        let playerGlowColor = player.map { Self.vector($0.glowColor) } ?? Self.faded(Self.hudColor, 0.6)
        let blinking = run.player.invulnerableSteps > 0 && (run.player.invulnerableSteps / Self.blinkSteps) % 2 == 1
        let playerAlpha = blinking ? Self.blinkAlpha : 1
        let center = run.player.center
        playerGlow.primitive = .circle(px(run.player.hitRadius * glowFactor))
        playerGlow.position = world(center)
        playerGlow.color = Self.faded(playerGlowColor, glowAlpha * playerAlpha)
        playerRing.primitive = .polyline(Self.ring(center: center, radius: run.player.hitRadius).map(world),
                                         width: px(Self.ringWidth))
        playerRing.color = Self.faded(playerFill, playerAlpha)
        playerChevron.primitive = .polygon(Self.chevron.map { world(center + $0) })
        playerChevron.color = Self.faded(playerFill, playerAlpha)

        let text = Self.scoreText(run.score)
        lastScoreText = text
        Self.drawDigits(text, nodes: digitNodes, origin: Self.digitOrigin, color: Self.hudColor, world: world,
                        width: px(Self.segmentWidth))
        let waveText = Self.waveText(run.wave)
        lastWaveText = waveText
        Self.drawDigits(waveText, nodes: waveDigitNodes, origin: Self.waveOrigin, color: Self.waveColor, world: world,
                        width: px(Self.segmentWidth))
        var lit = 0
        for (index, node) in lifeNodes.enumerated() {
            let alive = index < run.lives
            if alive { lit += 1 }
            node.primitive = .circle(px(Self.lifeRadius))
            node.position = world(Self.livesOrigin - Vec2(Double(index) * Self.livesSpacing, 0))
            node.color = Self.faded(playerFill, alive ? 1 : Self.lostLifeAlpha)
        }
        lastLivesLit = lit

        lastTransitionProgress = transitionProgress
        let pausedAlpha = overlayAlpha(.paused)
        for (index, node) in pauseNodes.enumerated() {
            guard pausedAlpha > 0 else { node.primitive = nil; continue }
            node.primitive = .rect(Vec2(px(0.3), px(1.2)))
            node.position = world(Vec2(Self.fieldWidth / 2 + (index == 0 ? -0.3 : 0.3), Self.fieldHeight / 2))
            node.color = Self.faded(Self.pauseColor, pausedAlpha)
        }
        switch shownScreen ?? core.screen {
        case .title: lastStateMark = "title"
        case .playing: lastStateMark = "none"
        case .paused: lastStateMark = "paused"
        case .over: lastStateMark = "over"
        }
        let hazard = ArcadeCore.catalog.hazards.first.map { Self.vector($0.color) } ?? Self.fallbackHazard
        let overAlpha = overlayAlpha(.over)
        if overAlpha > 0 {
            shade.primitive = .rect(Vec2(Self.fieldWidth * s, Self.fieldHeight * s))
            shade.position = field.position
            shade.color = Self.faded(Self.overShade, overAlpha)
            let c = Vec2(Self.fieldWidth / 2, Self.fieldHeight / 2)
            crossNodes[0].primitive = .line(world(c + Vec2(-1.2, -1.2)), world(c + Vec2(1.2, 1.2)), width: px(0.18))
            crossNodes[1].primitive = .line(world(c + Vec2(-1.2, 1.2)), world(c + Vec2(1.2, -1.2)), width: px(0.18))
            for node in crossNodes { node.color = Self.faded(hazard, overAlpha) }
            let scoreText = Self.scoreText(run.score), waveText = Self.waveText(run.wave)
            lastOverScoreText = scoreText
            lastOverWaveText = waveText
            Self.drawDigits(scoreText, nodes: overScoreNodes,
                            origin: Vec2(Self.centredDigitsX(scoreText.count), Self.overScoreTop),
                            color: Self.faded(Self.hudColor, overAlpha), world: world, width: px(Self.segmentWidth))
            Self.drawDigits(waveText, nodes: overWaveNodes,
                            origin: Vec2(Self.centredDigitsX(waveText.count), Self.overWaveTop),
                            color: Self.faded(Self.waveColor, overAlpha), world: world, width: px(Self.segmentWidth))
        } else {
            shade.primitive = nil
            for node in crossNodes { node.primitive = nil }
            for node in (overScoreNodes + overWaveNodes).joined() { node.primitive = nil }
            lastOverScoreText = ""
            lastOverWaveText = ""
        }
        let titleAlpha = overlayAlpha(.title)
        if titleAlpha > 0 {
            titleShadeNode.primitive = .rect(Vec2(Self.fieldWidth * s, Self.fieldHeight * s))
            titleShadeNode.position = field.position
            titleShadeNode.color = Self.faded(Self.titleShade, titleAlpha)
            let emblem = Self.ring(center: Self.emblemCenter, radius: Self.emblemRadius).map(world)
            titleRing.primitive = .polyline(emblem, width: px(Self.ringWidth * 2))
            titleRing.color = Self.faded(playerFill, titleAlpha)
            titleChevron.primitive = .polygon(Self.chevron.map { world(Self.emblemCenter + $0 * Self.emblemScale) })
            titleChevron.color = Self.faded(playerFill, titleAlpha)
            let p = Self.playCenter, h = Self.playSize
            titlePlay.primitive = .polygon([world(p + Vec2(-h * 0.8, h)), world(p + Vec2(h, 0)),
                                            world(p + Vec2(-h * 0.8, -h))])
            titlePlay.color = Self.faded(Self.playColor, titleAlpha)
        } else {
            for node in [titleShadeNode, titleRing, titleChevron, titlePlay] { node.primitive = nil }
        }
        layOutBestScores(titleAlpha: titleAlpha, overAlpha: overAlpha, world: world, px: px)

        // Letterbox masks: everything outside the field is covered in the clear colour.
        let halfW = Self.fieldWidth / 2 * s, halfH = Self.fieldHeight / 2 * s
        let big = Vec2(max(width, 1) * 2, max(height, 1) * 2)
        let centres = [Vec2(-halfW - big.x / 2, 0), Vec2(halfW + big.x / 2, 0),
                       Vec2(0, halfH + big.y / 2), Vec2(0, -halfH - big.y / 2)]
        for (node, centre) in zip(maskNodes, centres) {
            node.primitive = .rect(big)
            node.position = centre
            node.color = Self.letterboxColor
        }
    }

    /// The best-score rows to draw: the top ``bestShown`` entries and, when the new entry ranks below them, the new
    /// entry as a further row; with the index of the marked row (the new entry), or nil.
    nonisolated static func bestRowsShown(_ table: HighScoreTable, newEntryIndex: Int?)
        -> (entries: [HighScoreEntry], marked: Int?) {
        var rows = Array(table.entries.prefix(bestShown))
        var marked: Int?
        if let index = newEntryIndex, index < table.entries.count {
            if index < bestShown {
                marked = index
            } else {
                rows.append(table.entries[index])
                marked = rows.count - 1
            }
        }
        return (rows, marked)
    }

    /// Draws the best-score rows on the title screen (below the play triangle) or the game-over screen (below the
    /// final wave), whichever overlay is the more visible, with that overlay's alpha; clears them on other screens.
    private func layOutBestScores(titleAlpha: Double, overAlpha: Double, world: (Vec2) -> Vec2,
                                  px: (Double) -> Double) {
        let alpha = max(titleAlpha, overAlpha)
        let shown = alpha > 0 ? Self.bestRowsShown(highScores.table, newEntryIndex: highScores.newEntryIndex)
                              : (entries: [], marked: nil)
        let top = overAlpha >= titleAlpha ? Self.overBestTop : Self.titleBestTop
        lastBestTexts = shown.entries.map { Self.scoreText($0.score) }
        lastBestMarkedRow = shown.marked
        bestMarker.primitive = nil
        for (row, nodes) in bestNodes.enumerated() {
            guard row < shown.entries.count else {
                for node in nodes.joined() { node.primitive = nil }
                continue
            }
            let text = lastBestTexts[row]
            let origin = Vec2(Self.centredDigitsX(text.count), top - Double(row) * Self.bestSpacing)
            let marked = row == shown.marked
            let color = Self.faded(marked ? Self.newEntryColor : Self.bestColor, alpha)
            Self.drawDigits(text, nodes: nodes, origin: origin, color: color, world: world,
                            width: px(Self.segmentWidth))
            if marked {
                let tip = Vec2(origin.x - Self.markerGap, origin.y - Self.digitHeight / 2)
                let h = Self.markerSize
                bestMarker.primitive = .polygon([world(tip), world(tip + Vec2(-h * 1.6, h)),
                                                 world(tip + Vec2(-h * 1.6, -h))])
                bestMarker.color = color
            }
        }
    }

    // MARK: Words and controls

    /// Brings the controls' mirror in line with `core`.
    func sync(_ core: ArcadeCore) {
        lastCore = core
        let run = core.run
        if !mirror.ready { mirror.ready = true }
        if mirror.score != run.score { mirror.score = run.score }
        if mirror.lives != run.lives { mirror.lives = run.lives }
        if mirror.paused != run.paused { mirror.paused = run.paused }
        if mirror.over != run.over { mirror.over = run.over }
        if mirror.steering != run.steering { mirror.steering = run.steering }
        if mirror.screen != core.screen { mirror.screen = core.screen }
        if mirror.sound != core.sound { mirror.sound = core.sound }
        if mirror.haptics != core.haptics { mirror.haptics = core.haptics }
        let status = Self.status(run, screen: core.screen)
        if mirror.status != status { mirror.status = status }
        if mirror.sensitivity != core.sensitivity { mirror.sensitivity = core.sensitivity }
        syncScores(core)
    }

    /// Brings the best-score text and the high-score problem of the controls in line with the store (feature 078).
    func syncScores(_ core: ArcadeCore) {
        let rank = core.screen == .over ? highScores.newEntryIndex : nil
        let best = Self.bestWords(highScores.best, newRank: rank)
        if mirror.best != best { mirror.best = best }
        let problem = highScores.problem.map { ArcadeControls.sentence($0) }
        if mirror.scoresProblem != problem { mirror.scoresProblem = problem }
    }

    /// `value` in decimal digits grouped by commas: "1,230" (feature 078).
    nonisolated static func grouped(_ value: Int) -> String {
        let digits = String(abs(value))
        var groups: [Substring] = []
        var end = digits.endIndex
        while end > digits.startIndex {
            let start = digits.index(end, offsetBy: -3, limitedBy: digits.startIndex) ?? digits.startIndex
            groups.insert(digits[start..<end], at: 0)
            end = start
        }
        return (value < 0 ? "-" : "") + groups.joined(separator: ",")
    }

    /// The best score in words for the description: "best score none" or "best score 1,230" (feature 078).
    nonisolated static func bestScoreWords(_ best: HighScoreEntry?) -> String {
        best.map { "best score \(grouped($0.score))" } ?? "best score none"
    }

    /// The best-score text of the controls: "Best score: none", "Best score: 1,230 in wave 4", and on the game-over
    /// screen after a run that entered the table "… This run is number 2 in the table." (feature 078).
    nonisolated static func bestWords(_ best: HighScoreEntry?, newRank: Int?) -> String {
        guard let best else { return "Best score: none" }
        var text = "Best score: \(grouped(best.score)) in wave \(best.wave)"
        if let rank = newRank { text += ". This run is number \(rank + 1) in the table." }
        return text
    }

    /// "playing", "paused" or "over".
    nonisolated static func stateWord(_ run: GameRun) -> String {
        screenWord(ArcadeScreen.derived(from: run))
    }

    /// The screen in words: "title screen", "playing", "paused" or "over".
    nonisolated static func screenWord(_ screen: ArcadeScreen) -> String {
        switch screen {
        case .title: return "title screen"
        case .playing: return "playing"
        case .paused: return "paused"
        case .over: return "over"
        }
    }

    /// "no lives", "1 life" or "3 lives".
    nonisolated static func livesWords(_ lives: Int) -> String {
        switch lives {
        case ...0: return "no lives"
        case 1: return "1 life"
        default: return "\(lives) lives"
        }
    }

    /// "no objects falling", "1 object falling" or "5 objects falling".
    nonisolated static func objectWords(_ count: Int) -> String {
        switch count {
        case ...0: return "no objects falling"
        case 1: return "1 object falling"
        default: return "\(count) objects falling"
        }
    }

    /// The status line: "score 120, 2 lives, playing".
    nonisolated static func status(_ run: GameRun) -> String {
        status(run, screen: ArcadeScreen.derived(from: run))
    }

    /// The status line on `screen`: "score 0, 3 lives, title screen".
    nonisolated static func status(_ run: GameRun, screen: ArcadeScreen) -> String {
        "score \(run.score), \(livesWords(run.lives)), \(screenWord(screen))"
    }

    /// The canvas description, for example "Neon Arcade: Neon Dodge, wave 3, score 120, 2 lives, 3 objects falling,
    /// playing."
    nonisolated static func description(_ run: GameRun) -> String {
        description(run, screen: ArcadeScreen.derived(from: run))
    }

    /// The canvas description on `screen`, for example "Neon Arcade: Neon Dodge, wave 1, score 0, 3 lives, no objects
    /// falling, title screen." (feature 077: every screen is spoken).
    nonisolated static func description(_ run: GameRun, screen: ArcadeScreen) -> String {
        "Neon Arcade: Neon Dodge, wave \(run.wave), score \(run.score), \(livesWords(run.lives)), "
            + "\(objectWords(run.objects.count)), \(screenWord(screen))."
    }

    /// The canvas description on `screen` with the best score before the screen (feature 078), for example "Neon
    /// Arcade: Neon Dodge, wave 1, score 0, 3 lives, no objects falling, best score none, title screen."
    nonisolated static func description(_ run: GameRun, screen: ArcadeScreen, best: HighScoreEntry?) -> String {
        "Neon Arcade: Neon Dodge, wave \(run.wave), score \(run.score), \(livesWords(run.lives)), "
            + "\(objectWords(run.objects.count)), \(bestScoreWords(best)), \(screenWord(screen))."
    }

    /// The description of `core`'s run on its screen with the best score.
    func describe(_ core: ArcadeCore) -> String {
        sync(core)
        return Self.description(core.run, screen: core.screen, best: highScores.best)
    }

    /// The field point (game units) under the canvas point at fraction (0.5, 0.99) of the last canvas (y from the
    /// top); without a frame the field is assumed to fill the canvas height.
    func probeFieldPoint() -> Vec2 {
        guard lastScale > 0, lastCanvas.y > 0 else { return Vec2(Self.fieldWidth / 2, 0.01 * Self.fieldHeight) }
        let worldY = (0.5 - 0.99) * lastCanvas.y
        return Vec2(Self.fieldWidth / 2, worldY / lastScale + Self.fieldHeight / 2)
    }

    /// The `FrameColorClass` raw value of a colour (0…1 channels) by the frame checks' rules, nil when a channel
    /// difference or the luma lies within 4 of 255 of a threshold (8-bit rounding could change the class).
    nonisolated static func colorClass(red: Double, green: Double, blue: Double) -> String? {
        let r = red * 255, g = green * 255, b = blue * 255
        let luma = 0.2126 * r + 0.7152 * g + 0.0722 * b
        let margin = 4.0
        let checks = [luma - 40, luma - 215, r - g - 30, r - b - 30, g - r - 30, g - b - 30, b - r - 30, b - g - 30,
                      max(r, g, b) - min(r, g, b) - 30]
        guard checks.allSatisfy({ abs($0) > margin }) else { return nil }
        if luma < 40 { return FrameColorClass.dark.rawValue }
        if luma > 215, max(r, g, b) - min(r, g, b) < 30 { return FrameColorClass.light.rawValue }
        if r - g >= 30, r - b >= 30 { return FrameColorClass.red.rawValue }
        if g - r >= 30, g - b >= 30 { return FrameColorClass.green.rawValue }
        if b - r >= 30, b - g >= 30 { return FrameColorClass.blue.rawValue }
        return FrameColorClass.other.rawValue
    }

    /// The colour class of the field (and of the letterbox): `dark`.
    nonisolated static var colorClassOfField: String? {
        colorClass(red: fieldColor.x, green: fieldColor.y, blue: fieldColor.z)
    }

    /// One probe at the bottom centre of the canvas expecting the dark field (or the dark letterbox below it); none
    /// while a falling object or its glow, or an effect (a particle, a hit ring or the wave sweep), lies within reach
    /// of that point.
    func probes(_ core: ArcadeCore) -> [FrameProbe] {
        guard let expected = Self.colorClassOfField,
              Self.colorClass(red: Self.letterboxColor.x, green: Self.letterboxColor.y,
                              blue: Self.letterboxColor.z) == expected else { return [] }
        let point = probeFieldPoint()
        if point.y >= 0 {
            for object in core.run.objects {
                let dx = max(abs(object.position.x - point.x) - object.halfLength, 0)
                let dy = object.position.y - point.y
                if (dx * dx + dy * dy).squareRoot() < object.radius * Self.glowScale + Self.probeMargin { return [] }
            }
            if effects.touches(point, margin: Self.probeMargin) { return [] }
        }
        return [FrameProbe(name: "field", x: 0.5, y: 0.99, expected: expected)].compactMap { $0 }
    }

    func makeControls(_ port: ExperienceActionPort) -> AnyView {
        AnyView(ArcadeControls(port: port, mirror: mirror))
    }

    /// Every action has a native control.
    var nativeActions: Set<String> { Set(ArcadeCore.actionIDs) }

    /// The action the canvas drag sends: `run.steer`.
    var gestureActions: Set<String> { ArcadeGestures.gestureActions }

    /// Turns a canvas pointer event into `run.steer` actions against the player of the last synced run at its
    /// sensitivity step and sends each through `port`; nothing happens before a state was seen.
    func pointer(_ event: PointerEvent, viewSize: Vec2, port: ExperienceActionPort) {
        guard let core = lastCore else { return }
        followPort = port
        let actions = gestures.handle(event, playerX: core.run.player.x, viewSize: viewSize, step: core.sensitivity)
        for action in actions { _ = port.send(action.control, action.values) }
    }
}
