// AmethystEscapePreviewTests — feature 364 (R02-G07-04) T-R02G0704-002 (FR-R02G0704-006; clarification Q5). A drag
// preview of n sectors equals the snapshot after n kernel turns of that shell (offsets, pearl and exit gap), for every
// shell and every n in −⌊S/2⌋ … ⌊S/2⌋, on certified levels; moves and stage are the preview's own (unchanged); an unknown
// shell or a whole turn returns the snapshot unchanged. Host-run (`swift test`); explicit types, plain loops.
import AmethystEscapeCore
import Testing
import VisualCoreExperience

@Suite struct AmethystEscapePreviewTests {
    /// The certified levels the preview is checked on.
    static let levels: [Int] = [1, 21, 41, 61, 81, 100]

    @Test func aPreviewEqualsTheKernelsTurnsOfThatShell() throws {
        for number in Self.levels {
            let core: AmethystEscapeExperienceCore = try AmethystEscapeExperienceCore.opening(number: number)
            let snapshot: AmethystEscapeSceneSnapshot = core.snapshot(time: 0)
            let half: Int = snapshot.sectors / 2
            for shell in snapshot.shells.indices {
                for n in -half...half {
                    let preview: AmethystEscapeSceneSnapshot = snapshot.previewing(shell: shell, sectors: n)
                    // The kernel's turns, one sector at a time, on a copy of the play (crystal only: the moves differ).
                    var crystal: AmethystEscapeCrystal = core.play.crystal
                    for _ in 0..<abs(n) {
                        crystal = crystal.rotating(shell: shell, step: n > 0 ? 1 : -1, level: core.play.level)
                    }
                    #expect(preview.shells.map(\.offset) == crystal.offsets, "level \(number) shell \(shell) n \(n)")
                    #expect(preview.pearl == crystal.pearl, "level \(number) shell \(shell) n \(n)")
                    let outer: Int = core.play.level.outermost
                    let exit: Int = (core.play.level.exitGap + crystal.offsets[outer]) % snapshot.sectors
                    #expect(preview.exitGap == exit, "level \(number) shell \(shell) n \(n)")
                    #expect(preview.moves == snapshot.moves && preview.stage == snapshot.stage)
                    #expect(preview.levelNumber == snapshot.levelNumber && preview.budget == snapshot.budget)
                }
            }
        }
    }

    @Test func anUnknownShellOrAWholeTurnChangesNothing() throws {
        let core: AmethystEscapeExperienceCore = try AmethystEscapeExperienceCore.opening(number: 1)
        let snapshot: AmethystEscapeSceneSnapshot = core.snapshot(time: 0.5)
        #expect(snapshot.previewing(shell: -1, sectors: 1) == snapshot)
        #expect(snapshot.previewing(shell: snapshot.shells.count, sectors: 1) == snapshot)
        #expect(snapshot.previewing(shell: 0, sectors: 0) == snapshot)
        #expect(snapshot.previewing(shell: 0, sectors: snapshot.sectors) == snapshot)
        #expect(snapshot.previewing(shell: 0, sectors: -snapshot.sectors) == snapshot)
    }
}
